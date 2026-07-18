// Package kingdom implements the server-authoritative kingdom (city-building)
// system — K1 of DESIGN_KINGDOM.md. 决策 48 + 用户拍板（2026-07-19）：服务器权威
// 为永久原则，资源/建筑/施工计时全部服务器结算，客户端只收发数据 + 表现。
//
// 扩展性约定（用户要求：养成/货币经济后续会改）：
//   - 资源集合、建筑集合、逐级数值全部来自 kingdom.json —— 新资源/新建筑零代码改动；
//   - 数值节奏（成本/时长/产出）由运营/策划改表控制，代码只做规则执行。
package kingdom

import (
	"encoding/json"
	"fmt"
	"sort"

	"github.com/jchensh/godot-clash-pusher/server/internal/gameconfig"
)

// BuildingLevel is one row of a building's per-level table.
type BuildingLevel struct {
	Level        int              `json:"level"`
	Cost         map[string]int64 `json:"cost"`
	TimeS        int64            `json:"time_s"`
	ChapterReq   int              `json:"chapter_req"`   // keep 专用：升到本级需通关的章
	RatePerH     int64            `json:"rate_per_h"`    // producer 专用（food/wood）
	Storage      int64            `json:"storage"`       // producer 专用：未收取累积上限
	IdleMultPct  int64            `json:"idle_mult_pct"` // mint 专用（K3）：挂机章节曲线的百分比系数
	StorageBonus map[string]int64 `json:"storage_bonus"` // granary 专用：仓库上限加成
	TowerHpPct   int              `json:"tower_hp_pct"`  // wall 专用（K4 接战斗）
	TowerDmgPct  int              `json:"tower_dmg_pct"` // watchtower 专用（K4 接战斗）
}

type Building struct {
	DisplayZH string          `json:"display_zh"`
	Kind      string          `json:"kind"`     // core / producer / storage / defense
	Produces  string          `json:"produces"` // producer 专用：food/wood/gold
	Levels    []BuildingLevel `json:"levels"`
}

type Rules struct {
	Builders           int              `json:"builders"`
	KeepCapMult        int              `json:"keep_cap_mult"`
	BaseStorage        map[string]int64 `json:"base_storage"`
	SpeedupGemsPerHour int64            `json:"speedup_gems_per_hour"`
	SpeedupMinGems     int64            `json:"speedup_min_gems"`
	Initial            struct {
		Resources map[string]int64 `json:"resources"`
		Buildings map[string]int   `json:"buildings"`
	} `json:"initial"`
}

type Config struct {
	Resources []string            `json:"resources"`
	Rules     Rules               `json:"rules"`
	Buildings map[string]Building `json:"buildings"`
}

// ParseConfig extracts and validates kingdom.json from the gameconfig bundle.
func ParseConfig(b *gameconfig.Bundle) (*Config, error) {
	raw, ok := b.File("kingdom.json")
	if !ok {
		return nil, fmt.Errorf("kingdom: bundle missing kingdom.json")
	}
	var cfg Config
	if err := json.Unmarshal(raw, &cfg); err != nil {
		return nil, fmt.Errorf("kingdom: parse kingdom.json: %w", err)
	}
	if err := cfg.validate(); err != nil {
		return nil, err
	}
	return &cfg, nil
}

func (c *Config) validate() error {
	if len(c.Resources) == 0 {
		return fmt.Errorf("kingdom: resources empty")
	}
	known := map[string]bool{"gold": true} // gold 是主经济货币，铸币坊产出合法目标
	for _, r := range c.Resources {
		known[r] = true
	}
	if _, ok := c.Buildings["keep"]; !ok {
		return fmt.Errorf("kingdom: buildings missing 'keep'")
	}
	if c.Rules.Builders < 1 || c.Rules.KeepCapMult < 1 {
		return fmt.Errorf("kingdom: rules.builders/keep_cap_mult must be >= 1")
	}
	for name, bld := range c.Buildings {
		if len(bld.Levels) == 0 {
			return fmt.Errorf("kingdom: building %s has no levels", name)
		}
		for i, lv := range bld.Levels {
			if lv.Level != i+1 {
				return fmt.Errorf("kingdom: building %s level table not contiguous at index %d", name, i)
			}
			for res := range lv.Cost {
				if res == "gold" || !known[res] {
					// 铁门（DESIGN_KINGDOM §4）：金币不能买城建资源；成本只认王国内资源。
					return fmt.Errorf("kingdom: building %s level %d cost uses invalid resource %q", name, lv.Level, res)
				}
			}
			if lv.TimeS < 0 {
				return fmt.Errorf("kingdom: building %s level %d negative time", name, lv.Level)
			}
		}
		if bld.Kind == "producer" && !known[bld.Produces] {
			return fmt.Errorf("kingdom: building %s produces unknown resource %q", name, bld.Produces)
		}
	}
	for bname, lv := range c.Rules.Initial.Buildings {
		bld, ok := c.Buildings[bname]
		if !ok || lv < 1 || lv > len(bld.Levels) {
			return fmt.Errorf("kingdom: rules.initial building %s invalid", bname)
		}
	}
	return nil
}

// LevelRow returns the level table row for building at level (1-based); ok=false when out of range.
func (c *Config) LevelRow(building string, level int) (BuildingLevel, bool) {
	b, ok := c.Buildings[building]
	if !ok || level < 1 || level > len(b.Levels) {
		return BuildingLevel{}, false
	}
	return b.Levels[level-1], true
}

// MaxLevel returns the table length for a building (0 when unknown).
func (c *Config) MaxLevel(building string) int {
	return len(c.Buildings[building].Levels)
}

// BuildingNames returns config building keys in deterministic order.
func (c *Config) BuildingNames() []string {
	names := make([]string, 0, len(c.Buildings))
	for n := range c.Buildings {
		names = append(names, n)
	}
	sort.Strings(names)
	return names
}

// StorageCap returns the warehouse cap for a resource: base + granary bonus at level.
func (c *Config) StorageCap(resource string, granaryLevel int) int64 {
	cap := c.Rules.BaseStorage[resource]
	if row, ok := c.LevelRow("granary", granaryLevel); ok {
		cap += row.StorageBonus[resource]
	}
	return cap
}
