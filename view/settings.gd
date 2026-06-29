# Settings —— 设置场景（V3 UI 像素设计系统）。语言切换（中/英），未来放音量等。
#
# 切换语言 = I18n.set_language（即时 set_locale + 存 user://settings.cfg）→ 重载本页重建。
extends Control

const PixelUI := preload("res://view/ui/pixel_ui.gd")
const GameStateScript := preload("res://view/game_state.gd")
const MENU_SCENE := "res://view/main_menu.tscn"

var _http: HTTPRequest
var _gm_status: Label = null
var _gm_buttons: Array = []

func _ready() -> void:
	_build()
	_http = HTTPRequest.new()
	add_child(_http)
	_build_gm()       # GM 区骨架（标题+状态+按钮）
	_init_gm()        # async：登录 + 拉状态填充（fire-and-forget 协程）

func _build() -> void:
	PixelUI.add_background(self)
	_title(tr("settings_title"), 150, 60)
	_center_label(tr("settings_language"), 420, 34, PixelUI.COL_MUTED)
	var cur := I18n.current_locale()
	_lang_button(tr("lang_zh"), "zh", 150, 500, cur.begins_with("zh"))
	_lang_button(tr("lang_en"), "en", 390, 500, cur.begins_with("en"))
	_back_button(1080)

func _lang_button(text: String, loc: String, x: float, y: float, active: bool) -> void:
	var btn := Button.new()
	btn.text = text
	btn.position = Vector2(x, y)
	btn.size = Vector2(180, 104)
	btn.pivot_offset = Vector2(90, 52)
	btn.focus_mode = Control.FOCUS_NONE
	PixelUI.style_button(btn, "gold" if active else "stone", 34)
	btn.pressed.connect(_set_lang.bind(loc))
	btn.button_down.connect(_scale_to.bind(btn, 0.96))
	btn.button_up.connect(_scale_to.bind(btn, 1.0))
	add_child(btn)

func _set_lang(loc: String) -> void:
	I18n.set_language(loc)
	get_tree().reload_current_scene()   # 以新语言重建本页（即时见效）

func _back_button(y: float) -> void:
	var bw := 240.0
	var btn := Button.new()
	btn.position = Vector2((720.0 - bw) / 2.0, y)
	btn.size = Vector2(bw, 80)
	btn.text = tr("btn_back")
	btn.pivot_offset = Vector2(bw / 2.0, 40.0)
	btn.focus_mode = Control.FOCUS_NONE
	PixelUI.style_button(btn, "dark", 30)
	btn.pressed.connect(_on_back)
	btn.button_down.connect(_scale_to.bind(btn, 0.96))
	btn.button_up.connect(_scale_to.bind(btn, 1.0))
	add_child(btn)

func _on_back() -> void:
	get_tree().change_scene_to_file(MENU_SCENE)

func _scale_to(c: Control, s: float) -> void:
	create_tween().tween_property(c, "scale", Vector2(s, s), 0.07)

func _title(text: String, y: float, fs: int) -> void:
	for off in [Vector2(3, 3), Vector2(-3, 3), Vector2(3, -3), Vector2(-3, -3)]:
		var s := _center_label(text, y, fs, PixelUI.COL_OUTLINE)
		s.position += off
	_center_label(text, y, fs, PixelUI.COL_GOLD)

func _center_label(text: String, y: float, font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.position = Vector2(0, y)
	l.size = Vector2(720, float(font_size) + 16.0)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)
	return l

# —— GM 工具（开发作弊；仅服务器 GM_ENABLED 时生效，直接改服务器 DB）——

func _build_gm() -> void:
	_center_label("GM 工具（开发）", 630, 30, PixelUI.COL_GOLD)
	_gm_status = _center_label("连接服务器中…", 680, 22, PixelUI.COL_MUTED)
	var defs := [
		["金币 +10000", {"add_gold": 10000}],
		["宝石 +1000", {"add_gems": 1000}],
		["全卡 +50 碎片", {"add_shards_all": 50}],
		["解锁全部卡", {"unlock_all": true}],
		["全卡满级满阶", {"max_all_cards": true}],
		["通关全部(ch10)", {"clear_through_chapter": 10}],
		["推进 1 章", {"__advance": true}],
		["重置账号", {"reset": true}],
	]
	var col_w := 330.0
	var bh := 68.0
	for i in defs.size():
		var col: int = i % 2
		var row: int = i / 2
		var x := 20.0 + float(col) * (col_w + 20.0)
		var y := 720.0 + float(row) * (bh + 10.0)
		_gm_button(String(defs[i][0]), defs[i][1], x, y, col_w, bh)

func _gm_button(text: String, ops: Dictionary, x: float, y: float, w: float, h: float) -> void:
	var btn := Button.new()
	btn.text = text
	btn.position = Vector2(x, y)
	btn.size = Vector2(w, h)
	btn.pivot_offset = Vector2(w / 2.0, h / 2.0)
	btn.focus_mode = Control.FOCUS_NONE
	PixelUI.style_button(btn, "stone", 26)
	btn.pressed.connect(_on_gm.bind(ops))
	btn.button_down.connect(_scale_to.bind(btn, 0.96))
	btn.button_up.connect(_scale_to.bind(btn, 1.0))
	add_child(btn)
	_gm_buttons.append(btn)

func _init_gm() -> void:
	var session = GameStateScript.session()
	if not await session.ensure(_http):
		if _gm_status != null:
			_gm_status.text = "GM：需服务器在线（登录失败）"
		_set_gm_enabled(false)
		return
	var econ = GameStateScript.economy()
	await econ.refresh(_http, session.token(), GameStateScript.config().cards.keys())
	_refresh_gm_status()

func _on_gm(ops: Dictionary) -> void:
	var real_ops: Dictionary = ops.duplicate()
	if real_ops.has("__advance"):
		real_ops.erase("__advance")
		var c = GameStateScript.economy().get_cache()
		var cur_ch := 0
		if c != null and String(c.highest_cleared) != "":
			cur_ch = int(GameStateScript.config().get_stage(String(c.highest_cleared)).get("chapter", 0))
		real_ops["clear_through_chapter"] = mini(cur_ch + 1, 10)
	await _do_gm(real_ops)

func _do_gm(ops: Dictionary) -> void:
	if _gm_status != null:
		_gm_status.text = "执行中…"
	_set_gm_enabled(false)
	var session = GameStateScript.session()
	if not await session.ensure(_http):
		if _gm_status != null:
			_gm_status.text = "GM：登录失败"
		_set_gm_enabled(true)
		return
	var econ = GameStateScript.economy()
	var all_ids: Array = GameStateScript.config().cards.keys()
	var res: Dictionary = await econ.gm_apply(_http, session.token(), ops, all_ids)
	_set_gm_enabled(true)
	if bool(res.get("ok", false)):
		_refresh_gm_status()
	elif _gm_status != null:
		_gm_status.text = "GM 失败 status=%d" % int(res.get("status_code", 0))

func _refresh_gm_status() -> void:
	if _gm_status == null:
		return
	var c = GameStateScript.economy().get_cache()
	if c == null:
		_gm_status.text = "GM：状态未知"
		return
	var prog := String(c.highest_cleared) if String(c.highest_cleared) != "" else "无"
	_gm_status.text = "金币 %d · 宝石 %d · 解锁 %d/%d · 进度 %s" % [int(c.gold), int(c.gems), c.unlocked_card_ids().size(), c.cards.size(), prog]

func _set_gm_enabled(on: bool) -> void:
	for b in _gm_buttons:
		b.disabled = not on
