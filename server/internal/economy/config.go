// Package economy is the server-authoritative养成/经济 (决策 48 / V5-N3/N4)：
// per-account 钱包/卡牌养成/关卡进度落 PG，成本/上限/解锁门槛全在服务器用服务器侧
// 配置算（镜像本地 logic/player_data.gd 的曲线，改本地存档/客户端无效）。
package economy

import (
	"encoding/json"
	"fmt"
	"math"
	"strconv"

	"github.com/jchensh/godot-clash-pusher/server/internal/gameconfig"
)

// RankCost is the shards+gold to advance one rank.
type RankCost struct {
	Shards int
	Gold   int
}

// CardMeta from card_progression.json.
type CardMeta struct {
	Rarity    string
	Starter   bool
	BasePower int
}

// Config mirrors the养成/经济 curves the server needs to settle actions
// (parsed from the gameconfig bundle's economy.json + card_progression.json).
type Config struct {
	LevelStatPerLevel float64
	RankStatMult      float64
	LevelCapPerRank   map[int]int
	UpgradeCostBase   map[string]float64
	UpgradeCostGrowth float64
	RankUp            map[string][]RankCost
	UnlockShards      map[string]int
	Cards             map[string]CardMeta
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
