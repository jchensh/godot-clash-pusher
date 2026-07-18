extends "res://tests/test_case.gd"

## V4-S3a 确定性地基单测：lockstep 的命门。
## 两个独立 Match 喂入「相同输入序列」必须每 tick 状态哈希全等（确定性）；
## 喂入「不同输入」哈希必须分叉（哈希对 desync 敏感、能真正抓到不同步）。
## 这是「不重写 Go 战斗逻辑、靠两端各跑 logic/ + 哈希对帐」整条路线成立的前提。

const ConfigLoaderScript := preload("res://logic/config_loader.gd")
const MatchScript := preload("res://logic/match.gd")
const PlayerDataScript := preload("res://logic/player_data.gd")

var _loader

func _loader_ready():
	if _loader == null:
		_loader = ConfigLoaderScript.new()
		_loader.load_all()
	return _loader

func _new_match():
	var m = MatchScript.new(_loader_ready())
	m.setup("level_01")
	return m

func _h(m) -> String:
	return m.state_hash().hex_encode()

# 扫出一个对该方合法的落点（己方半场 + 可走地面），避开塔占位/河，确保 deploy 真能落子。
func _valid_pos(arena, owner_id: int) -> Vector2:
	var ys: Array = range(arena.grid_h) if owner_id == 1 else range(arena.grid_h - 1, -1, -1)
	for yy in ys:
		for xx in range(arena.grid_w):
			var p := Vector2(xx + 0.5, yy + 0.5)
			if arena.can_deploy(owner_id, p):
				return p
	return Vector2(arena.grid_w * 0.5, arena.grid_h * 0.5)


func test_advance_tick_increments_net_tick() -> void:
	var m = _new_match()
	assert_eq(m.net_tick, 0)
	for i in 5:
		m.advance_tick([])
	assert_eq(m.net_tick, 5)


func test_empty_ticks_two_matches_identical() -> void:
	# 纯圣水回涨、无出兵：两端每 tick 哈希必须全等。
	var m1 = _new_match()
	var m2 = _new_match()
	assert_eq(_h(m1), _h(m2), "初始状态哈希应相等")
	for t in 60:
		m1.advance_tick([])
		m2.advance_tick([])
		assert_eq(_h(m1), _h(m2), "空 tick %d 哈希分叉" % t)


func test_identical_deploys_keep_hash_equal() -> void:
	# 双方各出一次兵（相同指令喂给两端）：全程哈希必须逐 tick 相等。
	var m1 = _new_match()
	var m2 = _new_match()
	var arena = m1.battle.arena
	var p_pos := _valid_pos(arena, 0)   # side 1 = OWNER_PLAYER
	var e_pos := _valid_pos(arena, 1)   # side 2 = OWNER_OPPONENT

	var deployed_1 := false
	var deployed_2 := false
	for t in 220:
		var deploys: Array = []
		# 攒够圣水再出 side 1 的 hand[0]（card 成本未知，用 can_play 判，稳）。
		if not deployed_1 and m1.player.can_play(0):
			deploys.append({"side": 1, "card_id": m1.player.deck.get_hand()[0], "pos": p_pos})
			deployed_1 = true
		elif deployed_1 and not deployed_2 and m1.opponent.can_play(0):
			deploys.append({"side": 2, "card_id": m1.opponent.deck.get_hand()[0], "pos": e_pos})
			deployed_2 = true
		m1.advance_tick(deploys)
		m2.advance_tick(deploys)
		assert_eq(_h(m1), _h(m2), "相同输入下 tick %d 哈希分叉" % t)
	assert_true(deployed_1, "side1 应已出兵（攒够圣水）")
	assert_true(deployed_2, "side2 应已出兵")
	# 出过兵 + 推进后场上应有单位（哈希真覆盖到 units，而非空场恒等）。
	assert_true(arena.units.size() > 0, "出兵后场上应有单位")


func test_divergent_deploy_forks_hash() -> void:
	# 只给 m1 出一次兵、m2 不出：哈希必须分叉（证明哈希能抓到真实不同步）。
	var m1 = _new_match()
	var m2 = _new_match()
	var p_pos := _valid_pos(m1.battle.arena, 0)
	var deployed := false
	for t in 160:
		var d1: Array = []
		if not deployed and m1.player.can_play(0):
			d1 = [{"side": 1, "card_id": m1.player.deck.get_hand()[0], "pos": p_pos}]
			deployed = true
		m1.advance_tick(d1)
		m2.advance_tick([])   # m2 永远空推进
	assert_true(deployed, "m1 应已出兵")
	assert_ne(_h(m1), _h(m2), "一端出兵一端不出，哈希必须分叉")


# —— KAN-76：养成注入后的确定性（PVP 天梯养成同步的命门） ——

# {card_id: [level, rank]} → 最小 PlayerData（与 battle_client._inject_progress 同构）。
func _pd(progress: Dictionary):
	var pd = PlayerDataScript.new()
	for cid in progress:
		pd.cards[String(cid)] = {
			"level": progress[cid][0], "rank": progress[cid][1],
			"shards": 0, "unlocked": true,
		}
	return pd

# 手牌里第一张会 spawn 单位的卡的下标（法术不生成单位、体现不出 hp 乘区差异）。
func _first_troop_idx(p) -> int:
	var hand: Array = p.deck.get_hand()
	for i in hand.size():
		if p._spawns_troops(hand[i]):
			return i
	return -1

func test_same_progress_hash_equal() -> void:
	# 两端注入同一份养成（含 rank3 触发升阶技能解锁路径）+ 相同出兵：逐 tick 哈希必须全等。
	# 这验证「乘区 + effective_skills」整条管线是确定性的，可以进 lockstep。
	var prog := {"knight": [4, 2], "archers": [10, 3], "giant": [7, 3], "goblins": [3, 2]}
	var m1 = _new_match()
	var m2 = _new_match()
	for m in [m1, m2]:
		m.player.player_data = _pd(prog)
		m.opponent.player_data = _pd({"knight": [2, 1]})
	var p_pos := _valid_pos(m1.battle.arena, 0)
	var e_pos := _valid_pos(m1.battle.arena, 1)
	var deployed_1 := false
	var deployed_2 := false
	for t in 220:
		var deploys: Array = []
		var i1 := _first_troop_idx(m1.player)
		if not deployed_1 and i1 >= 0 and m1.player.can_play(i1):
			deploys.append({"side": 1, "card_id": m1.player.deck.get_hand()[i1], "pos": p_pos})
			deployed_1 = true
		var i2 := _first_troop_idx(m1.opponent)
		if deployed_1 and not deployed_2 and i2 >= 0 and m1.opponent.can_play(i2):
			deploys.append({"side": 2, "card_id": m1.opponent.deck.get_hand()[i2], "pos": e_pos})
			deployed_2 = true
		m1.advance_tick(deploys)
		m2.advance_tick(deploys)
		assert_eq(_h(m1), _h(m2), "同养成同输入下 tick %d 哈希分叉" % t)
	assert_true(deployed_1 and deployed_2, "双方都应已出兵")
	assert_true(m1.battle.arena.units.size() > 0, "出兵后场上应有单位（哈希真覆盖到养成后数值）")

func test_different_progress_forks_hash() -> void:
	# 一端给 side1 挂满养成、另一端白板，喂**相同**出兵指令：落子后哈希必须分叉——
	# 证明 hash 对帐这张保护网抓得住「两端对同一方用了不同养成」这类 desync/作弊。
	var m1 = _new_match()
	var m2 = _new_match()
	m1.player.player_data = _pd({
		"knight": [10, 3], "archers": [10, 3], "giant": [10, 3], "goblins": [10, 3],
		"minions": [10, 3], "fireball": [10, 3], "arrows": [10, 3], "zap": [10, 3],
	})   # m2.player 白板（player_data = null）
	var p_pos := _valid_pos(m1.battle.arena, 0)
	var deployed := false
	for t in 160:
		var deploys: Array = []
		var i := _first_troop_idx(m1.player)
		if not deployed and i >= 0 and m1.player.can_play(i):
			deploys.append({"side": 1, "card_id": m1.player.deck.get_hand()[i], "pos": p_pos})
			deployed = true
		m1.advance_tick(deploys)
		m2.advance_tick(deploys)
	assert_true(deployed, "side1 应已出兵")
	assert_ne(_h(m1), _h(m2), "同指令但养成不同 → 单位数值不同 → 哈希必须分叉")


func test_unknown_card_is_noop() -> void:
	# 不在手牌里的 card_id（非法/作弊指令）→ 确定性 no-op：
	# 喂垃圾卡的 m1 与完全不喂的 m2 哈希必须保持相等。
	var m1 = _new_match()
	var m2 = _new_match()
	var p_pos := _valid_pos(m1.battle.arena, 0)
	for t in 40:
		m1.advance_tick([{"side": 1, "card_id": "___not_a_real_card___", "pos": p_pos}])
		m2.advance_tick([])
		assert_eq(_h(m1), _h(m2), "垃圾卡应被丢弃为 no-op，tick %d 不应分叉" % t)

# —— K5：王国城防注入后的确定性（PVP 城防下发的命门，镜像 KAN-76 两条）——

func test_same_towers_hash_equal() -> void:
	# 两端对 side1/side2 注入同一份城防 + 相同出兵：逐 tick 哈希必须全等。
	var m1 = _new_match()
	var m2 = _new_match()
	for m in [m1, m2]:
		m.scale_side_towers({"hp_pct": 30, "dmg_pct": 20}, {"hp_pct": 6, "dmg_pct": 0})
	var p_pos := _valid_pos(m1.battle.arena, 0)
	var deployed := false
	for t in 200:
		var deploys: Array = []
		var i := _first_troop_idx(m1.player)
		if not deployed and i >= 0 and m1.player.can_play(i):
			deploys.append({"side": 1, "card_id": m1.player.deck.get_hand()[i], "pos": p_pos})
			deployed = true
		m1.advance_tick(deploys)
		m2.advance_tick(deploys)
		assert_eq(_h(m1), _h(m2), "同城防同输入下 tick %d 哈希分叉" % t)
	assert_true(deployed, "side1 应已出兵（塔有交战，哈希覆盖到塔数值）")

func test_different_towers_forks_hash() -> void:
	# 一端注入城防、另一端白板，相同指令：哈希必须分叉——hash 对帐抓得住
	# 「两端对同一方用了不同城防」的 desync/作弊（塔血/塔攻在 state_hash 内）。
	var m1 = _new_match()
	var m2 = _new_match()
	m1.scale_side_towers({"hp_pct": 30, "dmg_pct": 20}, {"hp_pct": 0, "dmg_pct": 0})
	var p_pos := _valid_pos(m1.battle.arena, 0)
	var deployed := false
	for t in 160:
		var deploys: Array = []
		var i := _first_troop_idx(m1.player)
		if not deployed and i >= 0 and m1.player.can_play(i):
			deploys.append({"side": 1, "card_id": m1.player.deck.get_hand()[i], "pos": p_pos})
			deployed = true
		m1.advance_tick(deploys)
		m2.advance_tick(deploys)
	assert_ne(_h(m1), _h(m2), "同指令但城防不同 → 塔数值不同 → 哈希必须分叉")
