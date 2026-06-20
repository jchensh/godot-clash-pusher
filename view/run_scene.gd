# RunScene —— Roguelite run 中枢（V3-4 最简 view）。
#
# 显示节点连战链 + 当前 run 卡组/relic，驱动「打当前节点 → 回来推进 → 给奖励(draft 卡/relic) → 下一节点」，
# run 结束弹结算并更新 meta + 存盘。所有 run 流转/奖励/解锁/存档都走逻辑层
# （RunState / RunRewards / MetaProgress / SaveSystem / RunModifiers），本场景只做编排与呈现。
# 与 battle_scene 经 GameState.run / run_last_result 握手（玩家在 battle_scene 实打，回来这里结算）。
extends Control

const GameStateScript = preload("res://view/game_state.gd")
const ConfigLoaderScript = preload("res://logic/config_loader.gd")
const RunMapScript = preload("res://logic/run_map.gd")
const RunStateScript = preload("res://logic/run_state.gd")
const RunRewardsScript = preload("res://logic/run_rewards.gd")
const MetaScript = preload("res://logic/meta_progress.gd")
const SaveScript = preload("res://logic/save_system.gd")
const BattleScript = preload("res://logic/battle.gd")
const SpriteDB = preload("res://view/sprite_db.gd")

const BATTLE_SCENE := "res://view/battle_scene.tscn"
const MENU_SCENE := "res://view/main_menu.tscn"
const OFFER_COUNT := 3

const GOLD := Color(1.0, 0.84, 0.36)
const C_DONE := Color(0.30, 0.46, 0.32)
const C_CURRENT := Color(0.95, 0.78, 0.30)
const C_FUTURE := Color(0.30, 0.34, 0.40)
const C_BOSS := Color(0.85, 0.35, 0.32)

var _loader
var _content: Control          # 地图/卡组/按钮层（状态变化时重建）
var _overlay: Control          # 奖励/结算覆盖层
var _mode := "none"            # none / reward / summary
var _reward_kind := "card"     # card / relic
var _offers: Array = []        # 当前奖励候选 id
var _offer_nodes: Dictionary = {}   # 奖励候选 id → 卡节点（选中 flourish 用）
var _picking := false          # 正在播放选中演出，挡二次点击

func _ready() -> void:
	AudioManager.play_music("music_run_map")
	AudioManager.play_ambience("amb_run_campfire")
	_loader = ConfigLoaderScript.new()
	_loader.load_all()
	if GameStateScript.meta == null:
		GameStateScript.meta = SaveScript.load_meta()
	if GameStateScript.run == null:
		GameStateScript.run = SaveScript.load_run(_loader.get_run("default"))
		if GameStateScript.run == null:
			_start_new_run()
	_build_bg()
	_content = _layer()
	_overlay = _layer()
	_process_pending_result()
	_refresh_content()
	_refresh_overlay()

func _run_cfg() -> Dictionary:
	return _loader.get_run("default")

func _start_new_run() -> void:
	var map = RunMapScript.new()
	map.build(_run_cfg())
	var starter: Array = _run_cfg().get("starter_deck", [])
	# run 卡组：优先玩家在组卡界面选的，否则用 starter。seed 取系统时钟做每局变化（逻辑仍确定）。
	var deck: Array = GameStateScript.player_deck.duplicate() if not GameStateScript.player_deck.is_empty() else starter
	var seed_val := int(Time.get_unix_time_from_system())
	GameStateScript.run = RunStateScript.new(map, deck, seed_val)
	if GameStateScript.meta != null:
		GameStateScript.meta.record_run_start()
		SaveScript.save_meta(GameStateScript.meta)
	SaveScript.save_run(GameStateScript.run)

# 处理从 battle_scene 带回的战斗结果：推进 run、记 meta、决定奖励/结算覆盖层。
func _process_pending_result() -> void:
	var res: int = GameStateScript.run_last_result
	if res == 0:
		return
	GameStateScript.run_last_result = 0
	var run = GameStateScript.run
	var fought: Dictionary = run.current_node()          # 尚未推进 → 这是刚打的节点
	var fought_type := String(fought.get("type", "battle"))
	var won: bool = res == BattleScript.RESULT_PLAYER_WIN
	if won and fought_type == RunMapScript.TYPE_BOSS and GameStateScript.meta != null:
		GameStateScript.meta.record_boss_defeated()
	run.advance(res)
	SaveScript.save_run(run)
	if GameStateScript.meta != null:
		SaveScript.save_meta(GameStateScript.meta)
	if run.is_over():
		if GameStateScript.meta != null:
			GameStateScript.meta.record_run_end(run.status == RunStateScript.RUN_WON)
			SaveScript.save_meta(GameStateScript.meta)
		SaveScript.clear_run_save()                       # run 终结 → 不可续跑
		_mode = "summary"
	elif won:
		_prepare_reward(fought_type)

func _prepare_reward(fought_type: String) -> void:
	var run = GameStateScript.run
	var off_seed: int = run.seed * 131 + run.cursor
	if fought_type == RunMapScript.TYPE_ELITE or fought_type == RunMapScript.TYPE_BOSS:
		_reward_kind = "relic"
		var avail: Array = GameStateScript.meta.available_relics(_loader.relics) if GameStateScript.meta != null else _loader.relics.keys()
		_offers = RunRewardsScript.offer_relics(avail, run.relics, OFFER_COUNT, off_seed)
	else:
		_reward_kind = "card"
		_offers = RunRewardsScript.offer_cards(_loader.cards.keys(), run.deck, OFFER_COUNT, off_seed)
	_mode = "reward" if not _offers.is_empty() else "none"

# ---------------- 地图 / 卡组 / 按钮 ----------------
func _refresh_content() -> void:
	_clear(_content)
	var run = GameStateScript.run
	_label(_content, tr("run_title"), Vector2(0, 24), Vector2(720, 50), 40, GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	var prog := tr("run_progress") % [mini(run.cursor + 1, run.map.size()), run.map.size(), run.wins]
	_label(_content, prog, Vector2(0, 78), Vector2(720, 26), 20, Color(0.78, 0.82, 0.78), HORIZONTAL_ALIGNMENT_CENTER)

	# 节点链（线性）：完成=暗绿、当前=金、未来=灰、boss 红描边。
	var y := 120.0
	for i in run.map.size():
		var node: Dictionary = run.map.node_at(i)
		var ntype := String(node.get("type", "battle"))
		var done: bool = i < run.cursor
		var current: bool = i == run.cursor and not run.is_over()
		var base: Color = C_DONE if done else (C_CURRENT if current else C_FUTURE)
		var border: Color = C_BOSS if ntype == RunMapScript.TYPE_BOSS else base.lightened(0.2)
		var mark := "✓" if done else ("▶" if current else "·")
		var txt := tr("run_node_row") % [mark, int(node.get("act", 0)) + 1, tr("node_" + ntype), String(node.get("level_id"))]
		var row := _panel(_content, Vector2(40, y), Vector2(640, 52), base.darkened(0.35), border, 3 if (current or ntype == RunMapScript.TYPE_BOSS) else 1)
		_label(row, txt, Vector2(16, 0), Vector2(610, 52), 20, Color.WHITE if not done else Color(0.7, 0.8, 0.7), HORIZONTAL_ALIGNMENT_LEFT)
		y += 60.0

	# run 卡组 + relic 摘要
	var deck_names: Array = []
	for cid in run.deck:
		deck_names.append(tr("card_" + str(cid)))
	_label(_content, tr("run_deck") % [run.deck.size(), ", ".join(deck_names)], Vector2(40, y + 6), Vector2(640, 48), 16, Color(0.80, 0.86, 0.92), HORIZONTAL_ALIGNMENT_LEFT)
	var relic_names: Array = []
	for rid in run.relics:
		relic_names.append(tr("relic_" + str(rid) + "_name"))
	var rtext: String = ", ".join(relic_names) if not relic_names.is_empty() else tr("run_relics_none")
	_label(_content, tr("run_relics") % rtext, Vector2(40, y + 56), Vector2(640, 44), 16, Color(0.95, 0.85, 0.55), HORIZONTAL_ALIGNMENT_LEFT)

	# 底部按钮
	var disabled: bool = _mode != "none" or GameStateScript.run.is_over()
	var fight := _button(_content, tr("btn_fight"), Vector2(40, 1090), Vector2(300, 84), Color(0.18, 0.42, 0.24), Color(0.45, 0.85, 0.55), _on_fight)
	fight.disabled = disabled
	_button(_content, tr("btn_new_run"), Vector2(360, 1090), Vector2(150, 84), Color(0.34, 0.26, 0.20), Color(0.7, 0.55, 0.4), _on_new_run)
	_button(_content, tr("btn_menu"), Vector2(530, 1090), Vector2(150, 84), Color(0.20, 0.22, 0.26), Color(0.45, 0.50, 0.56), _on_menu)

# ---------------- 奖励 / 结算覆盖层 ----------------
func _refresh_overlay() -> void:
	_clear(_overlay)
	if _mode == "reward":
		_build_reward()
	elif _mode == "summary":
		_build_summary()

func _build_reward() -> void:
	_dim(_overlay)
	_offer_nodes = {}
	var is_relic: bool = _reward_kind == "relic"
	AudioManager.play_sfx("relic_reveal" if is_relic else "reward_panel_open")
	var title := tr("reward_relic_title") if is_relic else tr("reward_card_title")
	var tlbl := _label(_overlay, title, Vector2(0, 250), Vector2(720, 50), 38, GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	_anim_pop(tlbl, 0.0, -24.0)
	var y := 360.0
	var idx := 0
	for id in _offers:
		var name_txt: String
		var sub_txt: String
		if is_relic:
			name_txt = tr("relic_" + str(id) + "_name")
			sub_txt = tr("relic_" + str(id) + "_desc")
		else:
			name_txt = tr("card_" + str(id))
			sub_txt = tr("reward_cost") % int(_loader.get_card(id).get("elixir_cost", 0))
		var card := _button(_overlay, "", Vector2(110, y), Vector2(500, 110), Color(0.16, 0.20, 0.30), GOLD, _on_pick.bind(id))
		if not is_relic:                                  # 卡牌 draft：左侧加单位/法术肖像
			var port := SpriteDB.make_card_portrait(str(id), _loader, Vector2(16, 14), Vector2(82, 82))
			if port != null:
				card.add_child(port)
		_label(card, name_txt, Vector2(20, 18), Vector2(460, 40), 28, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
		_label(card, sub_txt, Vector2(20, 64), Vector2(460, 30), 18, Color(0.8, 0.85, 0.9), HORIZONTAL_ALIGNMENT_CENTER)
		_offer_nodes[id] = card
		_anim_pop(card, 0.12 + idx * 0.10, 40.0)   # 逐张错峰揭示
		idx += 1
		y += 130.0
	var skip := _button(_overlay, tr("btn_skip"), Vector2(260, y + 10.0), Vector2(200, 64), Color(0.22, 0.24, 0.28), Color(0.5, 0.55, 0.6), _on_skip)
	_anim_pop(skip, 0.12 + idx * 0.10, 20.0)

func _build_summary() -> void:
	_dim(_overlay)
	var run = GameStateScript.run
	var won: bool = run.status == RunStateScript.RUN_WON
	_anim_pop(_label(_overlay, tr("run_cleared") if won else tr("run_over"), Vector2(0, 360), Vector2(720, 70), 56, (C_CURRENT if won else C_BOSS), HORIZONTAL_ALIGNMENT_CENTER), 0.0, -30.0)
	var line := (tr("run_summary_win") % run.wins) if won else (tr("run_summary_lose") % run.wins)
	_anim_pop(_label(_overlay, line, Vector2(0, 450), Vector2(720, 30), 22, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER), 0.18, 20.0)
	if GameStateScript.meta != null:
		var m = GameStateScript.meta
		var ms := tr("meta_stats") % [m.runs_won, m.bosses_defeated]
		_anim_pop(_label(_overlay, ms, Vector2(0, 500), Vector2(720, 28), 18, Color(0.8, 0.85, 0.8), HORIZONTAL_ALIGNMENT_CENTER), 0.30, 20.0)
		var newly: Array = m.unlocked_ids(_loader.relics)
		if not newly.is_empty():
			var names: Array = []
			for rid in newly:
				names.append(tr("relic_" + str(rid) + "_name"))
			_anim_pop(_label(_overlay, tr("unlocked") % ", ".join(names), Vector2(0, 540), Vector2(720, 28), 18, GOLD, HORIZONTAL_ALIGNMENT_CENTER), 0.42, 20.0)
	_anim_pop(_button(_overlay, tr("btn_back_menu"), Vector2(210, 620), Vector2(300, 72), Color(0.20, 0.22, 0.26), Color(0.45, 0.50, 0.56), _on_summary_menu), 0.55, 20.0)

# ---------------- 交互回调 ----------------
func _on_fight() -> void:
	if _mode != "none" or GameStateScript.run.is_over():
		return
	AudioManager.play_sfx("run_node_select")
	get_tree().change_scene_to_file(BATTLE_SCENE)   # battle_scene 读 GameState.run 自行建场

func _on_pick(id) -> void:
	if _picking:
		return
	_picking = true
	var run = GameStateScript.run
	if _reward_kind == "relic":
		run.add_relic(id)
		AudioManager.play_sfx("relic_pick")
	else:
		run.add_card(id)
		AudioManager.play_sfx("reward_card_pick")
	SaveScript.save_run(run)
	# 选中 flourish：放大 + 金色，再回中枢。
	var node: Control = _offer_nodes.get(id)
	if node != null:
		node.pivot_offset = node.size * 0.5
		var tw := create_tween()
		tw.tween_property(node, "scale", Vector2(1.18, 1.18), 0.18).set_trans(Tween.TRANS_BACK)
		tw.parallel().tween_property(node, "modulate", GOLD, 0.18)
		tw.tween_interval(0.12)
		tw.tween_callback(_close_reward)
	else:
		_close_reward()

func _on_skip() -> void:
	if _picking:
		return
	AudioManager.play_sfx("reward_skip")
	_close_reward()

func _close_reward() -> void:
	_mode = "none"
	_offers = []
	_offer_nodes = {}
	_picking = false
	call_deferred("_refresh_overlay")
	call_deferred("_refresh_content")

# 入场：从下方(rise)淡入 + 回弹归位；delay 用于错峰。
func _anim_pop(node: Control, delay: float, rise: float) -> void:
	var base := node.position
	node.modulate.a = 0.0
	node.position = base + Vector2(0, rise)
	var tw := create_tween()
	if delay > 0.0:
		tw.tween_interval(delay)
	tw.tween_property(node, "modulate:a", 1.0, 0.25)
	tw.parallel().tween_property(node, "position", base, 0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _on_new_run() -> void:
	AudioManager.play_sfx("ui_button_press")
	SaveScript.clear_run_save()
	GameStateScript.run = null
	_start_new_run()
	_mode = "none"
	_offers = []
	call_deferred("_refresh_overlay")
	call_deferred("_refresh_content")

func _on_menu() -> void:
	AudioManager.play_sfx("ui_button_back")
	get_tree().change_scene_to_file(MENU_SCENE)

func _on_summary_menu() -> void:
	AudioManager.play_sfx("ui_button_back")
	GameStateScript.run = null          # run 已结束，清掉（meta 已存盘）
	get_tree().change_scene_to_file(MENU_SCENE)

# ---------------- 小工具 ----------------
func _build_bg() -> void:
	var r := ColorRect.new()
	r.color = Color(0.09, 0.12, 0.10, 1.0)
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(r)

func _layer() -> Control:
	var c := Control.new()
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(c)
	return c

func _dim(parent: Control) -> void:
	var d := ColorRect.new()
	d.color = Color(0, 0, 0, 0.72)
	d.set_anchors_preset(Control.PRESET_FULL_RECT)
	d.mouse_filter = Control.MOUSE_FILTER_STOP
	parent.add_child(d)

func _clear(c: Control) -> void:
	while c.get_child_count() > 0:
		var n := c.get_child(0)
		c.remove_child(n)
		n.free()

func _panel(parent: Control, pos: Vector2, size: Vector2, bg: Color, border: Color, bw: int) -> Control:
	var p := Panel.new()
	p.position = pos
	p.size = size
	p.add_theme_stylebox_override("panel", _sbflat(bg, 8, bw, border))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(p)
	return p

func _label(parent: Control, text: String, pos: Vector2, size: Vector2, font_size: int, color: Color, align: int) -> Label:
	var l := Label.new()
	l.text = text
	l.position = pos
	l.size = size
	l.horizontal_alignment = align
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.clip_text = true
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l

func _button(parent: Control, text: String, pos: Vector2, size: Vector2, bg: Color, border: Color, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.position = pos
	b.size = size
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 28)
	b.add_theme_stylebox_override("normal", _sbflat(bg, 10, 2, border))
	b.add_theme_stylebox_override("hover", _sbflat(bg.lightened(0.15), 10, 2, border))
	b.add_theme_stylebox_override("pressed", _sbflat(bg.darkened(0.12), 10, 2, border))
	b.add_theme_stylebox_override("disabled", _sbflat(Color(0.18, 0.20, 0.18), 10, 2, Color(0.30, 0.33, 0.30)))
	b.add_theme_color_override("font_color", Color(0.95, 0.96, 0.97))
	b.pressed.connect(cb)
	parent.add_child(b)
	return b

func _sbflat(bg: Color, radius: int, border_w: int, border_col: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(radius)
	sb.set_border_width_all(border_w)
	sb.border_color = border_col
	return sb
