package kingdom

import (
	"context"
	"encoding/json"
	"errors"
	"sort"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jchensh/godot-clash-pusher/server/internal/economy"
	"github.com/jchensh/godot-clash-pusher/server/internal/store"
)

// Rejection reasons (mapped to error codes in the handler).
var (
	ErrUnknownBuilding = errors.New("unknown building")
	ErrAtCap           = errors.New("building at max level")
	ErrKeepGate        = errors.New("level capped by keep level")
	ErrChapterLocked   = errors.New("keep upgrade requires chapter progress")
	ErrBuilderBusy     = errors.New("builder busy or building already upgrading")
	ErrInsufficient    = errors.New("insufficient resources or gems")
	ErrNotUpgrading    = errors.New("building is not upgrading")
)

type BuildingRow struct {
	Building     string
	Level        int
	UpgradeEndTs int64
}

// State is the authoritative kingdom snapshot returned to handlers.
type State struct {
	Resources   map[string]int64
	Buildings   []BuildingRow
	Now         int64
	Pending     map[string]int64 // 各资源可收取量（含 gold；服务器算好，客户端只显示）
	PendingGold int64
}

type Repo struct {
	db *store.DB
}

func NewRepo(db *store.DB) *Repo { return &Repo{db: db} }

// —— 纯函数（单测覆盖；全部服务器时钟/整数运算，无浮点漂移）——

// pendingProduction accrues per-producer output since lastCollect, capped by the
// producer's own storage. 施工中的建筑按当前等级继续产出（P0 简化，注释留档）。
// K3（铸币坊接管挂机金库）：produces=gold 的建筑不走 rate_per_h/storage，改走
// goldRatePerH（= economy.json idle 章节曲线，由调用方按 highest_cleared 算好传入）
// × idle_mult_pct%，封顶 = 该速率 × goldCapHours（沿用 economy idle.cap_hours）。
func pendingProduction(cfg *Config, rows map[string]BuildingRow, lastCollect, now int64,
	goldRatePerH int64, goldCapHours int) map[string]int64 {
	out := map[string]int64{}
	if lastCollect <= 0 || now <= lastCollect {
		return out
	}
	dt := now - lastCollect
	for name, b := range cfg.Buildings {
		if b.Kind != "producer" {
			continue
		}
		row := rows[name]
		if row.Level < 1 {
			continue
		}
		lv, ok := cfg.LevelRow(name, row.Level)
		if !ok {
			continue
		}
		var accrued int64
		if b.Produces == "gold" {
			rate := goldRatePerH * lv.IdleMultPct / 100
			if rate <= 0 {
				continue
			}
			accrued = rate * dt / 3600
			if cap := rate * int64(goldCapHours); accrued > cap {
				accrued = cap
			}
		} else {
			if lv.RatePerH <= 0 {
				continue
			}
			accrued = lv.RatePerH * dt / 3600
			if accrued > lv.Storage {
				accrued = lv.Storage
			}
		}
		if accrued > 0 {
			out[b.Produces] += accrued
		}
	}
	return out
}

// speedupGems prices finishing `remaining` seconds now. 整数上取整：불足一小时按比例。
func speedupGems(cfg *Config, remaining int64) int64 {
	if remaining <= 0 {
		return 0
	}
	cost := (remaining*cfg.Rules.SpeedupGemsPerHour + 3599) / 3600
	if cost < cfg.Rules.SpeedupMinGems {
		cost = cfg.Rules.SpeedupMinGems
	}
	return cost
}

// applyStorageCap adds amount into held resources respecting the warehouse cap.
func applyStorageCap(cfg *Config, held map[string]int64, res string, amount, granaryLevel int64) {
	cap := cfg.StorageCap(res, int(granaryLevel))
	v := held[res] + amount
	if v > cap {
		v = cap
	}
	if v < held[res] { // cap 已被旧值超出（配置下调后），不没收存量
		v = held[res]
	}
	held[res] = v
}

// —— 仓储层 ——

// Get returns the current snapshot; lazily finalizes finished constructions.
func (r *Repo) Get(ctx context.Context, accountID int64, cfg *Config, econCfg *economy.Config) (State, error) {
	return r.mutate(ctx, accountID, cfg, econCfg, func(context.Context, pgx.Tx, *txState) error { return nil })
}

// Upgrade starts (or instantly applies) the next level for a building.
// Lv0→1 即建造。econCfg 用于王城的章节门（economy highest_cleared → chapter）。
func (r *Repo) Upgrade(ctx context.Context, accountID int64, building string, cfg *Config, econCfg *economy.Config) (State, error) {
	return r.mutate(ctx, accountID, cfg, econCfg, func(ctx context.Context, tx pgx.Tx, s *txState) error {
		b, ok := cfg.Buildings[building]
		_ = b
		if !ok {
			return ErrUnknownBuilding
		}
		row := s.rows[building]
		next := row.Level + 1
		lv, ok := cfg.LevelRow(building, next)
		if !ok {
			return ErrAtCap
		}
		if building == "keep" {
			if lv.ChapterReq > 0 && s.chapter < lv.ChapterReq {
				return ErrChapterLocked
			}
		} else if next > s.rows["keep"].Level*cfg.Rules.KeepCapMult {
			return ErrKeepGate
		}
		if row.UpgradeEndTs > s.now {
			return ErrBuilderBusy
		}
		busy := 0
		for _, br := range s.rows {
			if br.UpgradeEndTs > s.now {
				busy++
			}
		}
		if busy >= cfg.Rules.Builders {
			return ErrBuilderBusy
		}
		for res, c := range lv.Cost {
			if s.resources[res] < c {
				return ErrInsufficient
			}
		}
		for res, c := range lv.Cost {
			s.resources[res] -= c
		}
		if lv.TimeS <= 0 {
			row.Level = next
		} else {
			row.UpgradeEndTs = s.now + lv.TimeS
		}
		row.Building = building
		s.rows[building] = row
		s.dirty[building] = true
		s.stateDirty = true
		return nil
	})
}

// Collect settles all pending production into the warehouse (gold → 主钱包)。
func (r *Repo) Collect(ctx context.Context, accountID int64, cfg *Config, econCfg *economy.Config) (State, error) {
	return r.mutate(ctx, accountID, cfg, econCfg, func(ctx context.Context, tx pgx.Tx, s *txState) error {
		pending := pendingProduction(cfg, s.rows, s.lastCollect, s.now, s.goldRatePerH, s.goldCapHours)
		granary := int64(s.rows["granary"].Level)
		for res, amt := range pending {
			if res == "gold" {
				continue
			}
			applyStorageCap(cfg, s.resources, res, amt, granary)
		}
		if gold := pending["gold"]; gold > 0 {
			// 主经济播种可能未发生（新号未走 economy API）——最小 seed 后加金。
			if _, err := tx.Exec(ctx,
				`INSERT INTO economy_state (account_id, idle_last_collect_ts) VALUES ($1, $2)
				 ON CONFLICT (account_id) DO NOTHING`, accountID, s.now); err != nil {
				return err
			}
			if _, err := tx.Exec(ctx,
				`UPDATE economy_state SET gold=gold+$2, updated_at=NOW() WHERE account_id=$1`,
				accountID, gold); err != nil {
				return err
			}
		}
		s.lastCollect = s.now
		s.stateDirty = true
		return nil
	})
}

// Speedup finishes an in-progress construction immediately for gems.
func (r *Repo) Speedup(ctx context.Context, accountID int64, building string, cfg *Config, econCfg *economy.Config) (State, error) {
	return r.mutate(ctx, accountID, cfg, econCfg, func(ctx context.Context, tx pgx.Tx, s *txState) error {
		if _, ok := cfg.Buildings[building]; !ok {
			return ErrUnknownBuilding
		}
		row := s.rows[building]
		if row.UpgradeEndTs <= s.now {
			return ErrNotUpgrading
		}
		cost := speedupGems(cfg, row.UpgradeEndTs-s.now)
		if _, err := tx.Exec(ctx,
			`INSERT INTO economy_state (account_id, idle_last_collect_ts) VALUES ($1, $2)
			 ON CONFLICT (account_id) DO NOTHING`, accountID, s.now); err != nil {
			return err
		}
		var gems int64
		if err := tx.QueryRow(ctx,
			`SELECT gems FROM economy_state WHERE account_id=$1 FOR UPDATE`, accountID).Scan(&gems); err != nil {
			return err
		}
		if gems < cost {
			return ErrInsufficient
		}
		if _, err := tx.Exec(ctx,
			`UPDATE economy_state SET gems=gems-$2, updated_at=NOW() WHERE account_id=$1`,
			accountID, cost); err != nil {
			return err
		}
		row.Level++
		row.UpgradeEndTs = 0
		s.rows[building] = row
		s.dirty[building] = true
		return nil
	})
}

// TowerBonus returns the kingdom defense → tower percentage bonuses（K4：
// 城墙累计 tower_hp_pct / 箭楼累计 tower_dmg_pct）。只读快照：不落库，但把「已到点
// 未懒结转」的施工按完级计（与任何后续读写的结果一致，防开战瞬间少一级）。
func (r *Repo) TowerBonus(ctx context.Context, accountID int64, cfg *Config) (int, int, error) {
	now := time.Now().Unix()
	rows, err := r.db.Pool.Query(ctx,
		`SELECT building, level, upgrade_end_ts FROM kingdom_buildings
		 WHERE account_id=$1 AND building = ANY($2)`,
		accountID, []string{"wall", "watchtower"})
	if err != nil {
		return 0, 0, err
	}
	defer rows.Close()
	levels := map[string]int{}
	for rows.Next() {
		var b string
		var lv int
		var end int64
		if err := rows.Scan(&b, &lv, &end); err != nil {
			return 0, 0, err
		}
		if end > 0 && end <= now {
			lv++
		}
		levels[b] = lv
	}
	if err := rows.Err(); err != nil {
		return 0, 0, err
	}
	return sumDefensePct(cfg, "wall", levels["wall"], "TowerHpPct"),
		sumDefensePct(cfg, "watchtower", levels["watchtower"], "TowerDmgPct"), nil
}

// sumDefensePct 累计 1..level 各级的城防 pct 字段。
func sumDefensePct(cfg *Config, building string, level int, field string) int {
	total := 0
	for lv := 1; lv <= level; lv++ {
		row, ok := cfg.LevelRow(building, lv)
		if !ok {
			break
		}
		if field == "TowerHpPct" {
			total += row.TowerHpPct
		} else {
			total += row.TowerDmgPct
		}
	}
	return total
}

// —— 事务骨架：seed → 锁读 → 完工结转 → action → 落库 → 装配快照 ——

type txState struct {
	now          int64
	resources    map[string]int64
	rows         map[string]BuildingRow
	lastCollect  int64
	dirty        map[string]bool // 待落库的 building
	stateDirty   bool            // resources/last_collect 待落库
	chapter      int             // 玩家最高通关章（economy highest_cleared；王城门/铸币产率共用）
	goldRatePerH int64           // K3：挂机基线产率 = IdleRatePerHour(chapter)（mint 系数另乘）
	goldCapHours int             // K3：金币累计封顶小时（economy idle.cap_hours）
}

func (r *Repo) mutate(ctx context.Context, accountID int64, cfg *Config, econCfg *economy.Config,
	action func(context.Context, pgx.Tx, *txState) error) (State, error) {
	now := time.Now().Unix()
	tx, err := r.db.Pool.Begin(ctx)
	if err != nil {
		return State{}, err
	}
	defer tx.Rollback(ctx)

	if err := ensureSeeded(ctx, tx, accountID, cfg, now); err != nil {
		return State{}, err
	}
	s := &txState{now: now, dirty: map[string]bool{}}
	// K3：金币产率基线 = economy 挂机章节曲线（highest_cleared 可能无行 → 章 0 → 产率 0，
	// 与旧挂机金库口径一致：未通关第 1 章前不产金）。
	var highest string
	if err := tx.QueryRow(ctx,
		`SELECT highest_cleared FROM economy_state WHERE account_id=$1`, accountID,
	).Scan(&highest); err != nil && !errors.Is(err, pgx.ErrNoRows) {
		return State{}, err
	}
	s.chapter = econCfg.HighestChapter(highest)
	s.goldRatePerH = int64(econCfg.IdleRatePerHour(s.chapter))
	s.goldCapHours = econCfg.IdleCapHours()

	var rawRes []byte
	if err := tx.QueryRow(ctx,
		`SELECT resources, last_collect_ts FROM kingdom_state WHERE account_id=$1 FOR UPDATE`,
		accountID).Scan(&rawRes, &s.lastCollect); err != nil {
		return State{}, err
	}
	s.resources = map[string]int64{}
	if len(rawRes) > 0 {
		if err := json.Unmarshal(rawRes, &s.resources); err != nil {
			return State{}, err
		}
	}
	s.rows = map[string]BuildingRow{}
	rows, err := tx.Query(ctx,
		`SELECT building, level, upgrade_end_ts FROM kingdom_buildings WHERE account_id=$1 FOR UPDATE`, accountID)
	if err != nil {
		return State{}, err
	}
	for rows.Next() {
		var br BuildingRow
		if err := rows.Scan(&br.Building, &br.Level, &br.UpgradeEndTs); err != nil {
			rows.Close()
			return State{}, err
		}
		s.rows[br.Building] = br
	}
	rows.Close()
	if err := rows.Err(); err != nil {
		return State{}, err
	}

	// 完工结转（lazy）：任何读写路径都先把到点的施工完级——服务器时钟为准。
	for name, br := range s.rows {
		if br.UpgradeEndTs > 0 && br.UpgradeEndTs <= now {
			br.Level++
			br.UpgradeEndTs = 0
			s.rows[name] = br
			s.dirty[name] = true
		}
	}

	if err := action(ctx, tx, s); err != nil {
		return State{}, err
	}

	names := make([]string, 0, len(s.dirty))
	for n := range s.dirty {
		names = append(names, n)
	}
	sort.Strings(names) // 确定性落库顺序
	for _, n := range names {
		br := s.rows[n]
		if _, err := tx.Exec(ctx,
			`INSERT INTO kingdom_buildings (account_id, building, level, upgrade_end_ts, updated_at)
			 VALUES ($1, $2, $3, $4, NOW())
			 ON CONFLICT (account_id, building)
			 DO UPDATE SET level=$3, upgrade_end_ts=$4, updated_at=NOW()`,
			accountID, n, br.Level, br.UpgradeEndTs); err != nil {
			return State{}, err
		}
	}
	if s.stateDirty {
		raw, err := json.Marshal(s.resources)
		if err != nil {
			return State{}, err
		}
		if _, err := tx.Exec(ctx,
			`UPDATE kingdom_state SET resources=$2, last_collect_ts=$3, updated_at=NOW() WHERE account_id=$1`,
			accountID, raw, s.lastCollect); err != nil {
			return State{}, err
		}
	}

	st := assemble(cfg, s)
	if err := tx.Commit(ctx); err != nil {
		return State{}, err
	}
	return st, nil
}

func ensureSeeded(ctx context.Context, tx pgx.Tx, accountID int64, cfg *Config, now int64) error {
	var exists bool
	if err := tx.QueryRow(ctx,
		`SELECT EXISTS(SELECT 1 FROM kingdom_state WHERE account_id=$1)`, accountID).Scan(&exists); err != nil {
		return err
	}
	if exists {
		return nil
	}
	raw, err := json.Marshal(cfg.Rules.Initial.Resources)
	if err != nil {
		return err
	}
	if _, err := tx.Exec(ctx,
		`INSERT INTO kingdom_state (account_id, resources, last_collect_ts) VALUES ($1, $2, $3)`,
		accountID, raw, now); err != nil {
		return err
	}
	names := make([]string, 0, len(cfg.Rules.Initial.Buildings))
	for n := range cfg.Rules.Initial.Buildings {
		names = append(names, n)
	}
	sort.Strings(names) // 确定性播种顺序
	for _, n := range names {
		if _, err := tx.Exec(ctx,
			`INSERT INTO kingdom_buildings (account_id, building, level) VALUES ($1, $2, $3)
			 ON CONFLICT (account_id, building) DO NOTHING`,
			accountID, n, cfg.Rules.Initial.Buildings[n]); err != nil {
			return err
		}
	}
	return nil
}

// assemble builds the client-facing snapshot: 全部配置建筑（无行=Lv0）+ pending 预估。
func assemble(cfg *Config, s *txState) State {
	st := State{
		Resources: map[string]int64{},
		Now:       s.now,
		Pending:   map[string]int64{},
	}
	for k, v := range s.resources {
		st.Resources[k] = v
	}
	for _, name := range cfg.BuildingNames() {
		br, ok := s.rows[name]
		if !ok {
			br = BuildingRow{Building: name}
		}
		br.Building = name
		st.Buildings = append(st.Buildings, br)
	}
	pending := pendingProduction(cfg, s.rows, s.lastCollect, s.now, s.goldRatePerH, s.goldCapHours)
	for res, amt := range pending {
		if res == "gold" {
			st.PendingGold = amt
		} else {
			st.Pending[res] = amt
		}
	}
	return st
}
