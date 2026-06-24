# MainMenu —— 主菜单（V3 UI/UX 像素设计系统标杆）。
#
# 背景 = 夜色战场 9 图（assets/ui/menu_bg.png）；标题 = 像素金字 + 描边；
# 按钮 = PixelUI 统一 9-slice 石碑（gold CTA / stone / dark 三类 + 按下 scale juice + 音效）。
# 入口 START→选关 / ROGUELITE→run / SETTINGS→设置 / QUIT。文本走 i18n（tr）。
extends Control

const PixelUI := preload("res://view/ui/pixel_ui.gd")
const BG_TEX := preload("res://assets/ui/menu_bg.png")

const LEVEL_SELECT_SCENE := "res://view/level_select.tscn"
const RUN_SCENE := "res://view/run_scene.tscn"
const SETTINGS_SCENE := "res://view/settings.tscn"
const CAMPAIGN_SCENE := "res://view/campaign_scene.tscn"
const NET_BATTLE_SCENE := "res://view/net_battle_scene.tscn"   # V4-S3 天梯对战

func _ready() -> void:
	AudioManager.play_music("music_main_menu")
	AudioManager.stop_ambience()
	_build()

func _build() -> void:
	var bg := TextureRect.new()
	bg.texture = BG_TEX
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	# 标题（拉丁名做 logo 式两行 + 描边）+ 副标题
	_title("CLASH\nPUSHER", 108, 76)
	_center_label(tr("app_subtitle"), 322, 28, PixelUI.COL_MUTED)

	# 主按钮：天梯对战=金 CTA（V4 主轴），其余石板，退出弱化
	_menu_button("天梯对战", 440, _on_ladder_pressed, "gold", 40)
	_menu_button(tr("menu_campaign"), 556, _on_campaign_pressed, "stone", 34)
	_menu_button(tr("menu_roguelite"), 664, _on_run_pressed, "stone", 34)
	_menu_button(tr("menu_start"), 772, _on_start_pressed, "stone", 34)
	_menu_button(tr("btn_settings"), 880, _on_settings_pressed, "stone", 34)
	_menu_button(tr("menu_quit"), 988, _on_quit_pressed, "dark", 34)

	_center_label(tr("app_footer"), 1208, 22, PixelUI.COL_HINT)

# ---------- handlers ----------
func _on_ladder_pressed() -> void:
	get_tree().change_scene_to_file(NET_BATTLE_SCENE)

func _on_campaign_pressed() -> void:
	get_tree().change_scene_to_file(CAMPAIGN_SCENE)

func _on_start_pressed() -> void:
	get_tree().change_scene_to_file(LEVEL_SELECT_SCENE)

func _on_run_pressed() -> void:
	get_tree().change_scene_to_file(RUN_SCENE)

func _on_settings_pressed() -> void:
	get_tree().change_scene_to_file(SETTINGS_SCENE)

func _on_quit_pressed() -> void:
	get_tree().quit()

# ---------- ui builders ----------
func _title(text: String, y: float, font_size: int) -> void:
	for off in [Vector2(3, 3), Vector2(-3, 3), Vector2(3, -3), Vector2(-3, -3)]:
		_mk_label(text, y, font_size, PixelUI.COL_OUTLINE).position += off
	_mk_label(text, y, font_size, PixelUI.COL_GOLD)

func _mk_label(text: String, y: float, font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.position = Vector2(0, y)
	l.size = Vector2(720, float(font_size) * 2.6 + 16.0)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_constant_override("line_spacing", 4)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)
	return l

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

func _menu_button(text: String, y: float, cb: Callable, kind: String = "stone", font_size: int = 34) -> Button:
	var bw := 384.0
	var bh: float = 112.0 if kind == "gold" else 92.0
	var btn := Button.new()
	btn.text = text
	btn.position = Vector2((720.0 - bw) / 2.0, y)
	btn.size = Vector2(bw, bh)
	btn.pivot_offset = Vector2(bw / 2.0, bh / 2.0)
	btn.focus_mode = Control.FOCUS_NONE
	PixelUI.style_button(btn, kind, font_size)
	btn.pressed.connect(_on_menu_button_pressed.bind(cb))
	btn.button_down.connect(_scale_to.bind(btn, 0.96))
	btn.button_up.connect(_scale_to.bind(btn, 1.0))
	add_child(btn)
	return btn

func _scale_to(btn: Button, s: float) -> void:
	create_tween().tween_property(btn, "scale", Vector2(s, s), 0.07)

func _on_menu_button_pressed(cb: Callable) -> void:
	AudioManager.play_sfx("ui_button_press")
	cb.call()
