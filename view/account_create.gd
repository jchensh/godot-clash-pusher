# AccountCreate —— V5-S9 创号页（首次登录起名 + 选怪物头像）。
#
# 进入条件：登录后 session.needs_account_setup()（服务器 avatar_card_id 为空）。
# 起名：中英文数字，显示宽度 ≤ 10（中文/全角=1、英数=0.5）；头像：全部怪物卡（有立绘的兵种卡）。
# 确认 → session.update_identity（服务器权威落库）→ 回主菜单（由主菜单路由去新手引导）。
extends Control

const PixelUI := preload("res://view/ui/pixel_ui.gd")
const GameStateScript := preload("res://view/game_state.gd")
const DragScroll := preload("res://view/ui/drag_scroll.gd")
const SpriteDB := preload("res://view/sprite_db.gd")
const BG_TEX := preload("res://assets/ui/menu_bg.png")
const MENU_SCENE := "res://view/main_menu.tscn"

const NAME_MAX_HALF := 20   # 宽度上限：中文/全角=2 半格、英数=1 半格 → 10 全角

var _http: HTTPRequest
var _name_edit: LineEdit
var _counter: Label
var _confirm_btn: Button
var _selected_avatar := ""
var _avatar_frames := {}     # card_id -> 选中金边 Panel
var _av_content: Control     # 头像网格滚动内容层（48 卡后头像池 ~39 超屏，拖动/滚轮滑动）
var _config
var _busy := false

func _ready() -> void:
	AudioManager.play_music("music_main_menu")
	AudioManager.stop_ambience()
	_config = GameStateScript.config()
	_http = HTTPRequest.new()
	add_child(_http)
	_build()

func _build() -> void:
	var bg := TextureRect.new()
	bg.texture = BG_TEX
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	_title("创建你的英雄", 116, 58)
	_center_label("CREATE YOUR HERO", 190, 24, PixelUI.COL_MUTED)

	# —— 名字 ——
	_center_label("起个名字", 272, 26, PixelUI.COL_PARCHMENT)
	_name_edit = LineEdit.new()
	_name_edit.position = Vector2(110, 318)
	_name_edit.size = Vector2(500, 78)
	_name_edit.placeholder_text = "中英文数字皆可"
	_name_edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_edit.max_length = 40   # 粗上限（真正限制走宽度校验）；防超长粘贴
	_name_edit.add_theme_font_size_override("font_size", 36)
	_name_edit.add_theme_color_override("font_color", Color(1, 1, 1))
	_name_edit.add_theme_stylebox_override("normal", PixelUI.sbpixel(Color("1c1626"), 3, Color("4a3a14")))
	_name_edit.add_theme_stylebox_override("focus", PixelUI.sbpixel(Color("241c30"), 3, PixelUI.COL_GOLD))
	_name_edit.text_changed.connect(_on_name_changed)
	add_child(_name_edit)
	_counter = _center_label("0 / 10", 408, 22, PixelUI.COL_HINT)
	_center_label("最多 10 个中文字（英文数字算半个）", 440, 18, PixelUI.COL_HINT)

	# —— 头像网格（全部怪物卡；ScrollContainer：头像池 ~39 超屏，滚轮 + 按住拖动滑动）——
	_center_label("选择头像", 500, 26, PixelUI.COL_PARCHMENT)
	var ids := _monster_cards()
	var cols := 4
	var cell := 150.0
	var gap := 16.0
	var grid_w: float = cols * cell + (cols - 1) * gap
	var x0: float = (720.0 - grid_w) / 2.0
	var rows_n: int = int(ceil(ids.size() / float(cols)))
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(28, 538)
	scroll.size = Vector2(664, 564)   # 到确认按钮(1150)上方；内容在此窗内滚动
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER   # 隐藏滚条不占列宽；拖动/滚轮仍可滚
	scroll.scroll_deadzone = 16   # 真机触摸：阈值内=点选头像，超出=原生拖动滚动
	add_child(scroll)
	DragScroll.attach(scroll)   # 桌面鼠标按住拖动（触摸走原生）
	_av_content = Control.new()
	_av_content.custom_minimum_size = Vector2(664.0, ((rows_n - 1) * (cell + gap) + cell + 8.0) if rows_n > 0 else 0.0)
	scroll.add_child(_av_content)
	for i in ids.size():
		var col := i % cols
		var row := i / cols
		var x: float = (x0 - 28.0) + col * (cell + gap)   # 内容层局部坐标
		var y: float = 4.0 + row * (cell + gap)
		_avatar_tile(ids[i], x, y, cell)

	# —— 确认 ——
	_confirm_btn = _mk_button("确认", 1150, _on_confirm, "gold", 44)
	_refresh_confirm()

func _monster_cards() -> Array:
	var out := []
	for cid in _config.cards.keys():
		var id := str(cid)
		if _is_troop(id) and SpriteDB.card_portrait_tex(id, _config) != null:
			out.append(id)
	return out

func _is_troop(id: String) -> bool:
	for sk in (_config.get_card(id).get("skills", []) as Array):
		if typeof(sk) == TYPE_DICTIONARY and sk.get("type") == "spawn_unit":
			return true
	return false

func _avatar_tile(card_id: String, x: float, y: float, cell: float) -> void:
	var btn := Button.new()
	btn.position = Vector2(x, y)
	btn.size = Vector2(cell, cell)
	btn.focus_mode = Control.FOCUS_NONE
	btn.add_theme_stylebox_override("normal", PixelUI.sbpixel(Color(0.20, 0.30, 0.42), 2, Color(0.45, 0.62, 0.85)))
	btn.add_theme_stylebox_override("hover", PixelUI.sbpixel(Color(0.26, 0.37, 0.50), 2, PixelUI.COL_GOLD))
	btn.add_theme_stylebox_override("pressed", PixelUI.sbpixel(Color(0.16, 0.24, 0.34), 2, Color(0.45, 0.62, 0.85)))
	btn.pressed.connect(_on_avatar.bind(card_id))
	_av_content.add_child(btn)
	var port := SpriteDB.make_card_portrait(card_id, _config, Vector2(x + 22, y + 12), Vector2(cell - 44, cell - 52))
	if port != null:
		_av_content.add_child(port)
	var lbl := Label.new()
	lbl.text = tr("card_" + card_id)
	lbl.position = Vector2(x, y + cell - 34)
	lbl.size = Vector2(cell, 28)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 16)
	lbl.add_theme_color_override("font_color", Color(1, 1, 1))
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_av_content.add_child(lbl)
	var frame := Panel.new()
	frame.position = Vector2(x - 2, y - 2)
	frame.size = Vector2(cell + 4, cell + 4)
	frame.add_theme_stylebox_override("panel", PixelUI.sbpixel(Color(0, 0, 0, 0), 4, PixelUI.COL_GOLD))
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.visible = false
	_av_content.add_child(frame)
	_avatar_frames[card_id] = frame

func _on_avatar(card_id: String) -> void:
	AudioManager.play_sfx("ui_button_press")
	_selected_avatar = card_id
	for cid in _avatar_frames:
		_avatar_frames[cid].visible = (cid == card_id)
	_refresh_confirm()

func _on_name_changed(_t: String) -> void:
	var half := _name_half_width(_name_edit.text)
	var w: float = half / 2.0
	_counter.text = "%s / 10" % (str(int(w)) if w == floor(w) else ("%.1f" % w))
	_counter.add_theme_color_override("font_color", PixelUI.COL_HINT if half <= NAME_MAX_HALF else Color(0.9, 0.35, 0.35))
	_refresh_confirm()

# 显示半格宽：英数=1、其余(中文/全角/emoji)=2（与服务端 validateNickname 同口径）。
func _name_half_width(s: String) -> int:
	var n := s.strip_edges()
	var half := 0
	for i in n.length():
		half += 1 if n.unicode_at(i) <= 0xFF else 2
	return half

func _name_valid() -> bool:
	var n := _name_edit.text.strip_edges()
	return n != "" and _name_half_width(n) <= NAME_MAX_HALF

func _refresh_confirm() -> void:
	if _confirm_btn != null:
		_confirm_btn.disabled = _busy or not _name_valid() or _selected_avatar == ""

func _on_confirm() -> void:
	if _busy or not _name_valid() or _selected_avatar == "":
		return
	_busy = true
	_refresh_confirm()
	AudioManager.play_sfx("ui_button_press")
	var nick := _name_edit.text.strip_edges()
	print("[V5][account] 创号提交 name='%s' avatar=%s" % [nick, _selected_avatar])
	var session = GameStateScript.session()
	if not await session.ensure(_http):
		_toast("登录失败，请检查网络")
		_busy = false
		_refresh_confirm()
		return
	var ok: bool = await session.update_identity(_http, nick, _selected_avatar)
	if ok:
		print("[V5][account] 创号成功 → 回主菜单（路由进新手引导）")
		get_tree().change_scene_to_file(MENU_SCENE)
	else:
		_toast("起名被拒（可能太长），换一个试试")
		_busy = false
		_refresh_confirm()

# ---------- ui builders（沿用 base_camp 范式）----------
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

func _mk_button(text: String, y: float, cb: Callable, kind: String, font_size: int) -> Button:
	var bw := 384.0
	var bh := 112.0
	var btn := Button.new()
	btn.text = text
	btn.position = Vector2((720.0 - bw) / 2.0, y)
	btn.size = Vector2(bw, bh)
	btn.pivot_offset = Vector2(bw / 2.0, bh / 2.0)
	btn.focus_mode = Control.FOCUS_NONE
	PixelUI.style_button(btn, kind, font_size)
	btn.pressed.connect(cb)
	btn.button_down.connect(_scale_to.bind(btn, 0.96))
	btn.button_up.connect(_scale_to.bind(btn, 1.0))
	add_child(btn)
	return btn

func _scale_to(c: Control, s: float) -> void:
	create_tween().tween_property(c, "scale", Vector2(s, s), 0.07)

func _toast(msg: String) -> void:
	var l := Label.new()
	l.text = msg
	l.position = Vector2(0, 1080)
	l.size = Vector2(720, 40)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", 24)
	l.add_theme_color_override("font_color", PixelUI.COL_GOLD)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)
	var tw := create_tween()
	tw.tween_interval(1.4)
	tw.tween_property(l, "modulate:a", 0.0, 0.5)
	tw.tween_callback(l.queue_free)
