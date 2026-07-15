// Package economy is the server-authoritative养成/经济 (决策 48 / V5-N3/N4)：
// per-account 钱包/卡牌养成/关卡进度落 PG，成本/上限/解锁门槛全在服务器用服务器侧
// 配置算（镜像本地 logic/player_data.gd 的曲线，改本地存档/客户端无效）。
package economy

import (
	"encoding/json"
	"fmt"
	"math"
	"sort"
	"strconv"

	"github.com/jchensh/godot-clash-pusher/server/internal/gameconfig"
)

// RankCost is the shards+gold to advance one rank.
type RankCost struct {
	Shards int
	Gold   int
}

// Reward is a fixed gold/gems/shards payout (from first_clear / repeat).
type Reward struct {
	Gold   int
	Gems   int
	Shards map[string]int // card_id -> amount
}

// ShardDrop is a probabilistic per-card shard drop on stage clear.
type ShardDrop struct {
	Chance float64 // 0~1
	Amount int
}

// StarGoal is one star's requirement (stages.json stars[i])。KAN-78 摘要 sanity 用：
// 客户端声称的星数必须与战报摘要自洽（king_hp_pct → 王塔血 ≥ min；time_under → 时长 ≤ sec）。
type StarGoal struct {
	Goal string  // "win" / "king_hp_pct" / "time_under"
	Min  float64 // king_hp_pct 的下限 0~1
	Sec  float64 // time_under 的秒数上限
}

// Stage is one level's definition (parsed from stages.json). 镜像 player_data.grant_stage_reward.
type Stage struct {
	Chapter    int
	Index      int
	Coef       float64
	FirstClear Reward
	Repeat     Reward
	ShardDrop  map[string]ShardDrop // card_id -> {chance, amount}
	Stars      []StarGoal           // KAN-78：星级目标（摘要交叉校验）
	starCap    int                  // len(stars)；缺省 3
}

// Anticheat is the PVE 防作弊配置 (economy.json anticheat 段，KAN-78/79)。
// 缺段时取默认值（MinStageDurationS=15, VerifySampleRate=1.0）。
type Anticheat struct {
	MinStageDurationS int     // 通关墙钟时长下限（秒）——堵秒推
	MaxCmdsPerBattle  int     // 单局指令流长度上限——堵灌爆
	VerifySampleRate  float64 // 层2 重放验证抽样率 0~1
}

// CardMeta from card_progression.json.
type CardMeta struct {
	Rarity    string
	Starter   bool
	BasePower int
}

// Idle is the offline-gold config (parsed from economy.json idle 段)。挂机金币
// 产率按玩家最高通关章节驱动：rate = GoldPerHourPerChapter × chapter；累计封顶 CapHours。
type Idle struct {
	GoldPerHourPerChapter int
	CapHours              int
}

// Config mirrors the养成/经济 curves the server needs to settle actions
// (parsed from the gameconfig bundle's economy.json + card_progression.json +
// stages.json — N5 起通关发奖需读 stages 的奖励/掉落/星数上限; N6 起挂机结算读 idle).
type Config struct {
	LevelStatPerLevel float64
	RankStatMult      float64
	LevelCapPerRank   map[int]int
	UpgradeCostBase   map[string]float64
	UpgradeCostGrowth float64
	RankUp            map[string][]RankCost
	UnlockShards      map[string]int
	Cards             map[string]CardMeta
	Stages            map[string]Stage
	Idle              Idle
	Anticheat         Anticheat // KAN-78/79：PVE 防作弊参数
	orderedStages     []string  // stage_id 按 (chapter,index) 升序；线性解锁/防跳关用
	maxRank           int
}

// ParseConfig builds the server-side economy config from the loaded bundle.
func ParseConfig(b *gameconfig.Bundle) (*Config, error) {
	if b == nil {
		return nil, fmt.Errorf("nil config bundle")
	}
	econRaw, ok := b.File("economy.json")
	if !ok {
		return nil, fmt.Errorf("bundle missing economy.json")
	}
	cardRaw, ok := b.File("card_progression.json")
	if !ok {
		return nil, fmt.Errorf("bundle missing card_progression.json")
	}

	var econ struct {
		LevelStatPerLevel float64                     `json:"level_stat_per_level"`
		RankStatMult      float64                     `json:"rank_stat_mult"`
		LevelCapPerRank   map[string]int              `json:"level_cap_per_rank"`
		UpgradeCostBase   map[string]float64          `json:"upgrade_cost_base"`
		UpgradeCostGrowth float64                     `json:"upgrade_cost_growth"`
		RankUp            map[string][]map[string]int `json:"rank_up"`
		UnlockShards      map[string]int              `json:"unlock_shards"`
		Idle              struct {
			GoldPerHourPerChapter int `json:"gold_per_hour_per_chapter"`
			CapHours              int `json:"cap_hours"`
		} `json:"idle"`
		Anticheat *struct {
			MinStageDurationS int     `json:"min_stage_duration_s"`
			MaxCmdsPerBattle  int     `json:"max_cmds_per_battle"`
			VerifySampleRate  float64 `json:"verify_sample_rate"`
		} `json:"anticheat"`
	}
	if err := json.Unmarshal(econRaw, &econ); err != nil {
		return nil, fmt.Errorf("parse economy.json: %w", err)
	}

	cfg := &Config{
		LevelStatPerLevel: econ.LevelStatPerLevel,
		RankStatMult:      econ.RankStatMult,
		LevelCapPerRank:   map[int]int{},
		UpgradeCostBase:   econ.UpgradeCostBase,
		UpgradeCostGrowth: econ.UpgradeCostGrowth,
		RankUp:            map[string][]RankCost{},
		UnlockShards:      econ.UnlockShards,
		Cards:             map[string]CardMeta{},
		Idle:              Idle{GoldPerHourPerChapter: econ.Idle.GoldPerHourPerChapter, CapHours: econ.Idle.CapHours},
		Anticheat:         Anticheat{MinStageDurationS: 15, MaxCmdsPerBattle: 2000, VerifySampleRate: 1.0},
	}
	if econ.Anticheat != nil {
		cfg.Anticheat = Anticheat{
			MinStageDurationS: econ.Anticheat.MinStageDurationS,
			MaxCmdsPerBattle:  econ.Anticheat.MaxCmdsPerBattle,
			VerifySampleRate:  econ.Anticheat.VerifySampleRate,
		}
	}
	for k, v := range econ.LevelCapPerRank {
		r, err := strconv.Atoi(k)
		if err != nil {
			continue
		}
		cfg.LevelCapPerRank[r] = v
		if r > cfg.maxRank {
			cfg.maxRank = r
		}
	}
	for rarity, arr := range econ.RankUp {
		for _, m := range arr {
			cfg.RankUp[rarity] = append(cfg.RankUp[rarity], RankCost{Shards: m["shards"], Gold: m["gold"]})
		}
	}

	// card_progression.json：{card_id: {rarity, starter, base_power, ...}}；跳过 _ 开头元字段。
	var cards map[string]json.RawMessage
	if err := json.Unmarshal(cardRaw, &cards); err != nil {
		return nil, fmt.Errorf("parse card_progression.json: %w", err)
	}
	for id, raw := range cards {
		if len(id) > 0 && id[0] == '_' {
			continue
		}
		var cm struct {
			Rarity    string `json:"rarity"`
			Starter   bool   `json:"starter"`
			BasePower int    `json:"base_power"`
		}
		if json.Unmarshal(raw, &cm) != nil {
			continue
		}
		cfg.Cards[id] = CardMeta{Rarity: cm.Rarity, Starter: cm.Starter, BasePower: cm.BasePower}
	}
	if len(cfg.Cards) == 0 {
		return nil, fmt.Errorf("card_progression.json has no cards")
	}

	// stages.json（N5 通关发奖用）：{stage_id:{chapter,index,difficulty_coef,stars:[...],
	// first_clear/repeat:{gold,gems,shards:{card:n}}, shard_drop:{card:{chance,amount}}}}.
	// 跳过 _ 开头元字段；缺 stars → starCap 默认 3。
	stagesRaw, ok := b.File("stages.json")
	if ok {
		var stagesMap map[string]json.RawMessage
		if err := json.Unmarshal(stagesRaw, &stagesMap); err != nil {
			return nil, fmt.Errorf("parse stages.json: %w", err)
		}
		cfg.Stages = map[string]Stage{}
		for id, raw := range stagesMap {
			if len(id) > 0 && id[0] == '_' {
				continue
			}
			var s struct {
				Chapter int     `json:"chapter"`
				Index   int     `json:"index"`
				Coef    float64 `json:"difficulty_coef"`
				Stars   []struct {
					Goal string  `json:"goal"`
					Min  float64 `json:"min"`
					Sec  float64 `json:"sec"`
				} `json:"stars"`
				First   struct {
					Gold   int            `json:"gold"`
					Gems   int            `json:"gems"`
					Shards map[string]int `json:"shards"`
				} `json:"first_clear"`
				Repeat struct {
					Gold   int            `json:"gold"`
					Gems   int            `json:"gems"`
					Shards map[string]int `json:"shards"`
				} `json:"repeat"`
				Drop map[string]struct {
					Chance float64 `json:"chance"`
					Amount int     `json:"amount"`
				} `json:"shard_drop"`
			}
			if json.Unmarshal(raw, &s) != nil {
				continue
			}
			st := Stage{
				Chapter: s.Chapter, Index: s.Index, Coef: s.Coef,
				FirstClear: Reward{Gold: s.First.Gold, Gems: s.First.Gems, Shards: s.First.Shards},
				Repeat:     Reward{Gold: s.Repeat.Gold, Gems: s.Repeat.Gems, Shards: s.Repeat.Shards},
				ShardDrop:  map[string]ShardDrop{},
				starCap:    3,
			}
			if len(s.Stars) > 0 {
				st.starCap = len(s.Stars)
				for _, g := range s.Stars {
					st.Stars = append(st.Stars, StarGoal{Goal: g.Goal, Min: g.Min, Sec: g.Sec})
				}
			}
			for cid, d := range s.Drop {
				st.ShardDrop[cid] = ShardDrop{Chance: d.Chance, Amount: d.Amount}
			}
			cfg.Stages[id] = st
		}
		// 有序序列：按 (chapter, index) 升序（镜像 StageProgress.build）。
		ids := make([]string, 0, len(cfg.Stages))
		for id := range cfg.Stages {
			ids = append(ids, id)
		}
		sort.Slice(ids, func(i, j int) bool {
			a, b := cfg.Stages[ids[i]], cfg.Stages[ids[j]]
			if a.Chapter != b.Chapter {
				return a.Chapter < b.Chapter
			}
			return a.Index < b.Index
		})
		cfg.orderedStages = ids
	}

	return cfg, nil
}

func (c *Config) MaxRank() int { return c.maxRank }

func (c *Config) LevelCap(rank int) int {
	if v, ok := c.LevelCapPerRank[rank]; ok {
		return v
	}
	return 1
}

// UpgradeCost mirrors PlayerData.upgrade_cost: base[rarity]*(1+(level-1)*growth), rounded.
func (c *Config) UpgradeCost(rarity string, level int) (int, bool) {
	base, ok := c.UpgradeCostBase[rarity]
	if !ok {
		return 0, false
	}
	n := level - 1
	if n < 0 {
		n = 0
	}
	return int(math.Round(base * (1 + float64(n)*c.UpgradeCostGrowth))), true
}

// RankUpCost mirrors PlayerData.rank_up_cost: rank_up[rarity][rank-1].
func (c *Config) RankUpCost(rarity string, rank int) (RankCost, bool) {
	arr, ok := c.RankUp[rarity]
	i := rank - 1
	if !ok || i < 0 || i >= len(arr) {
		return RankCost{}, false
	}
	return arr[i], true
}

// UnlockCost is the shards needed to unlock a rarity's card.
func (c *Config) UnlockCost(rarity string) (int, bool) {
	v, ok := c.UnlockShards[rarity]
	return v, ok
}

// Rarity returns a card's rarity (and whether it's a known card).
func (c *Config) Rarity(cardID string) (string, bool) {
	cm, ok := c.Cards[cardID]
	return cm.Rarity, ok
}

// —— Stage 查询（N5 通关发奖 / 防跳关用） ——

// Stage returns one stage's definition (and whether it exists).
func (c *Config) Stage(id string) (Stage, bool) {
	s, ok := c.Stages[id]
	return s, ok
}

// OrderedStageIDs returns stage_ids sorted by (chapter, index) ascending.
func (c *Config) OrderedStageIDs() []string {
	out := make([]string, len(c.orderedStages))
	copy(out, c.orderedStages)
	return out
}

// PrevStage returns the stage immediately before id in the linear sequence
// (and whether id has a predecessor — first stage has none).
func (c *Config) PrevStage(id string) (string, bool) {
	for i, sid := range c.orderedStages {
		if sid == id {
			if i == 0 {
				return "", false
			}
			return c.orderedStages[i-1], true
		}
	}
	return "", false
}

// StarCap returns the max stars for a stage (len of its stars config, default 3).
func (c *Config) StarCap(id string) int {
	if s, ok := c.Stages[id]; ok {
		return s.starCap
	}
	return 0
}

// —— Idle 查询（N6 挂机服务器时钟结算用） ——

// IdleRatePerHour returns the挂机金币产率 for a given highest cleared chapter
// (rate = GoldPerHourPerChapter × chapter; mirrors player_data.idle_rate_per_hour)。
// chapter=0（未通关）→ 0。
func (c *Config) IdleRatePerHour(chapter int) int {
	return c.Idle.GoldPerHourPerChapter * chapter
}

// IdleCapHours returns the offline-gold accumulation cap (hours).
func (c *Config) IdleCapHours() int { return c.Idle.CapHours }

// HighestChapter returns the chapter number of the given highest_cleared stage_id
// (0 if empty/unknown). N6 用它从 highest_cleared 推章节 → idle 产率。
func (c *Config) HighestChapter(highestCleared string) int {
	if highestCleared == "" {
		return 0
	}
	if s, ok := c.Stages[highestCleared]; ok {
		return s.Chapter
	}
	return 0
}
