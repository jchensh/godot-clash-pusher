# Login —— KAN-109 用户名登录页（开发/测试阶段裸登录，无凭证）。
#
# 流程：输入 username → 服务器查库判新老（不看客户端本地数据）：
#   已注册 → login-name → 主菜单（tutorial_done 已完成则不再进引导）
#   未注册 → 选头像页（account_create 注册模式，携带 username）→ 注册 → 引导战
# 本地 user://auth.cfg 只当"记住我"：有记住的 username 时主菜单静默重登、不进本页。
# ⚠️ 顶号风险已知悉（用户 2026-07-15 拍板）：E2 公网安全阶段补凭证。
extends Control

const PixelUI := preload("res://view/ui/pixel_ui.gd")
const GameStateScript := preload("res://view/game_state.gd")
const BG_TEX := preload("res://assets/ui/menu_bg.png")

const NAME_MAX_HALF := 20   # 宽度上限（与服务端 validateUsername 同口径）：中文/全角=2 半格、英数=1

var _http: HTTPRequest
var _name_edit: LineEdit
var _counter: Label
var _enter_btn: Button
var _status: Label
var _busy := false

func _ready() -> void:
	AudioManager.play_music("music_main_menu")
	AudioManager.stop_ambience()
	_http = HTTPRequest.new()
	add_child(_http)
	_build()
	# 已有记住的 username（如从设置误入/回退）→ 直接回主菜单走静默重登
	var session = GameStateScript.session()
	if session != null and not session.needs_login():
		Log.i("[V5][login] 已有记住的账号 → 回主菜单静默重登")
		Router.goto("main_menu")

func _build() -> void:
	var bg := TextureRect.new()
	bg.texture = BG_TEX
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	_title("立名通关", 200, 58)
	_center_label("输入名号，新老将士由军府查验", 300, 24, PixelUI.COL_MUTED)

	_name_edit = LineEdit.new()
	_name_edit.position = Vector2(110, 420)
	_name_edit.size = Vector2(500, 84)
	_name_edit.placeholder_text = "你的名号（中英文数字）"
	_name_edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_edit.max_length = 40
	_name_edit.add_theme_font_size_override("font_size", 36)
	_name_edit.add_theme_color_override("font_color", Color(1, 1, 1))
	_name_edit.add_theme_stylebox_override("normal", PixelUI.sbpixel(Color("1c1626"), 3, Color("4a3a14")))
	_name_edit.add_theme_stylebox_override("focus", PixelUI.sbpixel(Color("241c30"), 3, PixelUI.COL_GOLD))
	_name_edit.text_changed.connect(_on_name_changed)
	_name_edit.text_submitted.connect(func(_t): _on_enter())
	add_child(_name_edit)
	_counter = _center_label("0 / 10", 516, 22, PixelUI.COL_HINT)
	_center_label("最多 10 个中文字（英文数字算半个）", 548, 18, PixelUI.COL_HINT)

	_enter_btn = _mk_button("进 入", 640, _on_enter, "gold", 44)
	_status = _center_label("", 790, 24, PixelUI.COL_MUTED)
	_center_label("老玩家直接进主界面 · 新名号将开始建号", 850, 18, PixelUI.COL_HINT)
	_refresh_enter()

func _on_name_changed(_t: String) -> void:
	var half := _name_half_width(_name_edit.text)
	var w: float = half / 2.0
	_counter.text = "%s / 10" % (str(int(w)) if w == floor(w) else ("%.1f" % w))
	_counter.add_theme_color_override("font_color",
			PixelUI.COL_HINT if half <= NAME_MAX_HALF else Color(0.9, 0.35, 0.35))
	_refresh_enter()

# 显示半格宽：英数=1、其余(中文/全角/emoji)=2（与服务端 validateUsername 同口径）。
func _name_half_width(s: String) -> int:
	var n := s.strip_edges()
	var half := 0
	for i in n.length():
		half += 1 if n.unicode_at(i) <= 0xFF else 2
	return half

func _name_valid() -> bool:
	var n := _name_edit.text.strip_edges()
	return n != "" and _name_half_width(n) <= NAME_MAX_HALF

func _refresh_enter() -> void:
	if _enter_btn != null:
		_enter_btn.disabled = _busy or not _name_valid()

func _on_enter() -> void:
	if _busy or not _name_valid():
		return
	_busy = true
	_refresh_enter()
	AudioManager.play_sfx("ui_button_press")
	var name_v := _name_edit.text.strip_edges()
	_status.text = "查验名号中…"
	Log.i("[V5][login] 查询 username='%s'" % name_v)
	var session = GameStateScript.session()
	var chk: Dictionary = await session.check_name(_http, name_v)
	if not bool(chk.get("ok", false)):
		_fail("连不上服务器，稍后再试")
		return
	if not bool(chk.get("valid", false)):
		_fail("名号不合规（太长或含非法字符）")
		return
	if bool(chk.get("registered", false)):
		_status.text = "老将回营，登录中…"
		Log.i("[V5][login] 老玩家 → login-name")
		if await session.login_with_name(_http, name_v):
			Router.goto("main_menu")
			return
		_fail("登录失败：%s" % str(session.last_error))
		return
	Log.i("[V5][login] 新玩家 → 选头像注册")
	Router.goto("account_create", {"username": name_v})

func _fail(msg: String) -> void:
	_status.text = msg
	UI.toast(msg, PixelUI.COL_GOLD, 1080.0, 1.4)
	_busy = false
	_refresh_enter()

# ---------- ui builders（沿用 account_create 范式）----------
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
