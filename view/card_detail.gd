# CardDetail —— V5-S7d 养成详情（升级 / 升阶 / 解锁，决策48 服务器权威）。
#
# 展示 GameState.detail_card：肖像 + 名 + Lv + 阶 pip + 战力/生命/攻击 + 下一阶解锁预告。
# 升级/升阶/解锁经 EconomyStateCache 门面 → 服务器算成本+校验+落库 → 回新状态刷新本屏。
# 展示侧成本/数值用本地 ConfigLoader（即时预览，非权威）；不足/满级/满阶按钮拦截 + toast。
extends Control

const PixelUI := preload("res://view/ui/pixel_ui.gd")
const HudWidgets := preload("res://view/ui/hud_widgets.gd")
const GameStateScript := preload("res://view/game_state.gd")
const SpriteDB := preload("res://view/sprite_db.gd")
const BG_TEX := preload("res://assets/ui/menu_bg.png")

const COLLECTION_SCENE := "res://view/card_collection.tscn"
const RARITY_COL := {
	"common": Color("9aa0ad"), "rare": Color("4a6db0"),
	"epic": Color("7c5ea8"), "legendary": Color("d8a23a"),
}

var _http: HTTPRequest
var _token := ""
var _all_ids: Array = []
var _config
var _cid := ""
var _content: Control
var _wallet_holder: Control
var _busy := false

func _ready() -> void:
	AudioManager.play_music("music_main_menu")
	_cid = GameStateScript.detail_card
	_build_static()
	_http = HTTPRequest.new()
	add_child(_http)
	await _bootstrap()

func _build_static() -> void:
	var bg := TextureRect.new()
	bg.texture = BG_TEX
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	_wallet_holder = Control.new()
	_wallet_holder.position = Vector2(80, 24)
	_wallet_holder.size = Vector2(560, 44)
	_wallet_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_wallet_holder)
	_content = Control.new()
	_content.set_anchors_preset(Control.PRESET_FULL_RECT)
	_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_content)
	_back_button(1168)

func _bootstrap() -> void:
	var session = GameStateScript.session()
	if not await session.ensure(_http):
		_center_label("（离线）未连接服务器", 200, 22, PixelUI.COL_HINT, _content)
		return
	_token = session.token()
	_config = GameStateScript.config()
	_all_ids = _config.cards.keys()
	var econ = GameStateScript.economy()
	if not econ.is_loaded:
		await econ.refresh(_http, _token, _all_ids)
	_populate()

func _populate() -> void:
	for c in _content.get_children():
		c.queue_free()
	var econ = GameStateScript.economy()
	var cache = econ.get_cache()
	if cache == null or _cid == "":
		_center_label("无数据", 200, 22, PixelUI.COL_HINT, _content)
		return
	_set_wallet(cache.gold, cache.gems)
	var rarity := str(_config.get_card_progression(_cid).get("rarity", "common"))
	var bd: Color = RARITY_COL.get(rarity, RARITY_COL["common"])
	var unlocked: bool = cache.is_unlocked(_cid)
	var st: Dictionary = cache.card_state(_cid)

	_title(tr("card_" + _cid), 84, 46)
	_center_label(_rarity_zh(rarity), 142, 20, bd.lightened(0.2), _content)

	# 肖像（稀有度框）
	var frame := Panel.new()
	frame.position = Vector2(70, 188)
	frame.size = Vector2(190, 230)
	frame.add_theme_stylebox_override("panel", PixelUI.sbpixel(Color("1f1830"), 4, bd))
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.add_child(frame)
	var port := SpriteDB.make_card_portrait(_cid, _config, Vector2(86, 210), Vector2(158, 158))
	if port != null:
		_content.add_child(port)

	# 右栏：Lv / 阶 pip / 战力 / 数值条
	var rx := 290.0
	if unlocked:
		_label("Lv.%d" % int(st.get("level", 1)), Vector2(rx, 196), 34, PixelUI.COL_GOLD, 200)
		var pips := HudWidgets.rank_pips(int(st.get("rank", 1)), _max_rank(), 20.0)
		pips.position = Vector2(rx, 246)
		_content.add_child(pips)
		var power := int(cache.card_power(_cid, _config))
		_label("战力 %s" % HudWidgets.format_int(power), Vector2(rx, 286), 24, PixelUI.COL_PARCHMENT, 360)
		var ratio := _mult_ratio(cache)
		var uid := _unit_of(_cid)
		if uid != "":
			var mult := float(cache.card_stat_mult(_cid, _config))
			var hp := int(float(_config.get_unit(uid).get("hp", 0)) * mult)
			var dmg := int(float(_config.get_unit(uid).get("damage", 0)) * mult)
			_stat(rx, 330, "生命", HudWidgets.format_int(hp), ratio, Color("7cc36a"))
			_stat(rx, 376, "攻击", HudWidgets.format_int(dmg), ratio, Color("e0894a"))
	else:
		_label("未解锁", Vector2(rx, 210), 30, PixelUI.COL_MUTED, 360)
		_label("集齐碎片解锁", Vector2(rx, 256), 20, PixelUI.COL_HINT, 360)

	# 下一阶解锁预告（unlocked + 未满阶）
	if unlocked and int(st.get("rank", 1)) < _max_rank():
		var nr := int(st.get("rank", 1)) + 1
		var ru = _config.get_card_progression(_cid).get("rank_unlocks", {})
		var note := str((ru.get(str(nr), {}) as Dictionary).get("note", "")) if ru is Dictionary else ""
		if note != "":
			_skill_hint("阶%d解锁：%s" % [nr, note], 452)

	# 动作区
	if unlocked:
		_build_upgrade_rank(cache, st, 560)
	else:
		_build_unlock(cache, st, rarity, 480)

# ---------- 动作 ----------
func _build_upgrade_rank(cache, st: Dictionary, y: float) -> void:
	var level := int(st.get("level", 1))
	var rank := int(st.get("rank", 1))
	var bw := 300.0
	# 升级
	var cap := int(cache.level_cap(rank, _config))
	if level >= cap:
		_action_btn("升级 已满阶", "stone", "", 0, false, Vector2(60, y), bw, Callable(), "需升阶解锁")
	else:
		var cost := int(cache.upgrade_cost(_cid, _config))
		var ok := int(cache.gold) >= cost
		_action_btn("升级 Lv.%d" % (level + 1), "gold", "coin", cost, ok, Vector2(60, y), bw, _on_upgrade)
	# 升阶
	if rank >= _max_rank():
		_action_btn("已满阶", "stone", "", 0, false, Vector2(60 + bw + 16, y), bw, Callable(), "")
	else:
		var rc: Dictionary = cache.rank_up_cost(_cid, _config)
		var need_sh := int(rc.get("shards", 0))
		var need_gold := int(rc.get("gold", 0))
		var ok := int(st.get("shards", 0)) >= need_sh and int(cache.gold) >= need_gold
		_action_btn2("升阶 阶%d" % (rank + 1), "purple", need_sh, need_gold, ok, Vector2(60 + bw + 16, y), bw, _on_rank_up)

func _build_unlock(cache, st: Dictionary, rarity: String, y: float) -> void:
	var have := int(st.get("shards", 0))
	var need := _unlock_need(rarity)
	_stat(60, y, "碎片", "%d/%d" % [have, need], clampf(float(have) / float(maxi(need, 1)), 0.0, 1.0), Color("b48fe0"), 600.0)
	if cache.can_unlock(_cid, _config):
		_action_btn("解锁", "gold", "shard", need, true, Vector2(210, y + 70), 300, _on_unlock)
	else:
		_action_btn("再集 %d 碎片" % maxi(need - have, 0), "stone", "", 0, false, Vector2(210, y + 70), 300, Callable(), "")

func _on_upgrade() -> void:
	await _do_action("upgrade")

func _on_rank_up() -> void:
	await _do_action("rank_up")

func _on_unlock() -> void:
	await _do_action("unlock")

func _do_action(op: String) -> void:
	if _busy:
		return
	_busy = true
	AudioManager.play_sfx("ui_button_press")
	var econ = GameStateScript.economy()
	var res: Dictionary
	match op:
		"upgrade": res = await econ.upgrade(_http, _token, _cid, _all_ids)
		"rank_up": res = await econ.rank_up(_http, _token, _cid, _all_ids)
		_: res = await econ.unlock(_http, _token, _cid, _all_ids)
	_busy = false
	if bool(res.get("ok", false)):
		AudioManager.play_sfx("ui_card_drop_valid")
		_populate()
	else:
		_toast(_err_text(int(res.get("error_code", 0))))

func _err_text(code: int) -> String:
	return "操作失败（服务器拒绝）"

func _on_back() -> void:
	AudioManager.play_sfx("ui_button_back")
	get_tree().change_scene_to_file(COLLECTION_SCENE)

# ---------- 小部件 ----------
func _action_btn(label: String, kind: String, cost_icon: String, cost: int, ok: bool, pos: Vector2, w: float, cb: Callable, disabled_hint := "") -> void:
	var btn := Button.new()
	btn.position = pos
	btn.size = Vector2(w, 84)
	btn.focus_mode = Control.FOCUS_NONE
	PixelUI.style_button(btn, kind, 26)
	if cb.is_valid():
		btn.pressed.connect(func():
			if ok: cb.call()
			elif cost_icon != "": _toast("货币不足")
			elif disabled_hint != "": _toast(disabled_hint))
	_content.add_child(btn)
	_label(label, pos + Vector2(0, 10), 22, PixelUI.COL_GOLD_INK if kind == "gold" else PixelUI.COL_PARCHMENT, w, HORIZONTAL_ALIGNMENT_CENTER)
	if cost_icon != "":
		var pill := HudWidgets.cost_pill(cost_icon, cost, ok, 120.0)
		pill.position = pos + Vector2((w - 120.0) / 2.0, 46.0)
		_content.add_child(pill)
	elif disabled_hint != "":
		_label(disabled_hint, pos + Vector2(0, 48), 15, PixelUI.COL_HINT, w, HORIZONTAL_ALIGNMENT_CENTER)

func _action_btn2(label: String, kind: String, shards: int, gold: int, ok: bool, pos: Vector2, w: float, cb: Callable) -> void:
	var btn := Button.new()
	btn.position = pos
	btn.size = Vector2(w, 84)
	btn.focus_mode = Control.FOCUS_NONE
	PixelUI.style_button(btn, "stone", 26)
	btn.add_theme_stylebox_override("normal", PixelUI.sbpixel(Color("2a2240"), 3, Color("7c5ea8")))
	btn.pressed.connect(func():
		if ok: cb.call()
		else: _toast("货币不足"))
	_content.add_child(btn)
	_label(label, pos + Vector2(0, 10), 22, PixelUI.COL_PARCHMENT, w, HORIZONTAL_ALIGNMENT_CENTER)
	var p1 := HudWidgets.cost_pill("shard", shards, int(GameStateScript.economy().get_cache().card_state(_cid).get("shards", 0)) >= shards, 100.0)
	p1.position = pos + Vector2(w / 2.0 - 108, 46.0)
	_content.add_child(p1)
	var p2 := HudWidgets.cost_pill("coin", gold, int(GameStateScript.economy().get_cache().gold) >= gold, 116.0)
	p2.position = pos + Vector2(w / 2.0 + 8, 46.0)
	_content.add_child(p2)

func _stat(x: float, y: float, label: String, value: String, pct: float, fill: Color, w := 360.0) -> void:
	var s := HudWidgets.stat_bar(label, value, pct, fill, w)
	s.position = Vector2(x, y)
	_content.add_child(s)

func _skill_hint(text: String, y: float) -> void:
	var p := Panel.new()
	p.position = Vector2(60, y)
	p.size = Vector2(600, 44)
	p.add_theme_stylebox_override("panel", PixelUI.sbpixel(Color("1a2414"), 0, Color("1a2414")))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.add_child(p)
	var bar := ColorRect.new()
	bar.color = Color("7cc36a")
	bar.position = Vector2(60, y)
	bar.size = Vector2(4, 44)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.add_child(bar)
	_label(text, Vector2(76, y + 10), 17, Color("bcd6a0"), 580, HORIZONTAL_ALIGNMENT_LEFT)

func _mult_ratio(cache) -> float:
	var cur := float(cache.card_stat_mult(_cid, _config))
	var econ = _config.get_economy()
	var per := float(econ.get("level_stat_per_level", 0.0))
	var rm := float(econ.get("rank_stat_mult", 1.0))
	var mr := _max_rank()
	var ml := int((econ.get("level_cap_per_rank", {}) as Dictionary).get(str(mr), 1))
	var mx := (1.0 + float(maxi(ml - 1, 0)) * per) * pow(rm, float(maxi(mr - 1, 0)))
	return clampf(cur / mx, 0.0, 1.0) if mx > 0.0 else 0.0

func _unit_of(cid: String) -> String:
	for sk in _config.get_card(cid).get("skills", []):
		if typeof(sk) == TYPE_DICTIONARY and sk.get("type") == "spawn_unit":
			return str(sk.get("unit_id"))
	return ""

func _max_rank() -> int:
	var tbl = _config.get_economy().get("level_cap_per_rank", {})
	var m := 1
	if typeof(tbl) == TYPE_DICTIONARY:
		for k in tbl:
			m = maxi(m, int(k))
	return m

func _unlock_need(rarity: String) -> int:
	var t = _config.get_economy().get("unlock_shards", {})
	return int((t as Dictionary).get(rarity, 0)) if t is Dictionary else 0

func _rarity_zh(r: String) -> String:
	match r:
		"common": return "寻常"
		"rare": return "精良"
		"epic": return "非凡"
		"legendary": return "无双"
	return r

func _set_wallet(gold: int, gems: int) -> void:
	for c in _wallet_holder.get_children():
		c.queue_free()
	_wallet_holder.add_child(HudWidgets.wallet_bar(gold, gems, 560.0))

func _toast(msg: String) -> void:
	var l := Label.new()
	l.text = msg
	l.position = Vector2(0, 760)
	l.size = Vector2(720, 40)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", 24)
	l.add_theme_color_override("font_color", Color("e24b4a"))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)
	var tw := create_tween()
	tw.tween_interval(1.0)
	tw.tween_property(l, "modulate:a", 0.0, 0.5)
	tw.tween_callback(l.queue_free)

func _label(text: String, pos: Vector2, fs: int, col: Color, w: float, align := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.text = text
	l.position = pos
	l.size = Vector2(w, float(fs) + 14.0)
	l.horizontal_alignment = align
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", col)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.add_child(l)
	return l

func _center_label(text: String, y: float, fs: int, col: Color, parent: Control) -> Label:
	var l := Label.new()
	l.text = text
	l.position = Vector2(0, y)
	l.size = Vector2(720, float(fs) + 16.0)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", col)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l

func _title(text: String, y: float, fs: int) -> void:
	for off in [Vector2(3, 3), Vector2(-3, 3), Vector2(3, -3), Vector2(-3, -3)]:
		var s := _center_label(text, y, fs, PixelUI.COL_OUTLINE, _content)
		s.position += off
	_center_label(text, y, fs, PixelUI.COL_GOLD, _content)

func _back_button(y: float) -> void:
	var bw := 240.0
	var btn := Button.new()
	btn.position = Vector2((720.0 - bw) / 2.0, y)
	btn.size = Vector2(bw, 72)
	btn.text = tr("btn_back")
	btn.pivot_offset = Vector2(bw / 2.0, 36.0)
	btn.focus_mode = Control.FOCUS_NONE
	PixelUI.style_button(btn, "dark", 28)
	btn.pressed.connect(_on_back)
	add_child(btn)
