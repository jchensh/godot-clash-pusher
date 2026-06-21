# DeckBuilder —— 组卡界面（V3 UI 像素设计系统）。自由从卡池选任意 8 张唯一卡进对局。
#
# 菜单 → 选关 → 组卡 → 对局。选满 8 → 写 GameState.player_deck → 对局；BACK 回选关。
# 兵牌/法术牌肖像走 SpriteDB；样式走 PixelUI（夜色背景 + 像素方块卡 + 9-slice 按钮）。
extends Control

const PixelUI := preload("res://view/ui/pixel_ui.gd")
const GameStateScript = preload("res://view/game_state.gd")
const ConfigLoaderScript = preload("res://logic/config_loader.gd")
const SpriteDB = preload("res://view/sprite_db.gd")
const BATTLE_SCENE := "res://view/battle_scene.tscn"
const LEVEL_SELECT_SCENE := "res://view/level_select.tscn"
const DECK_SIZE := 8

const TROOP_BG := Color(0.20, 0.30, 0.42)
const TROOP_BORDER := Color(0.45, 0.62, 0.85)
const SPELL_BG := Color(0.34, 0.22, 0.44)
const SPELL_BORDER := Color(0.74, 0.55, 0.95)
const GOLD := Color("ecb94e")
const SLOT_FILLED_BG := Color(0.18, 0.24, 0.20)
const SLOT_EMPTY_BG := Color(0.12, 0.14, 0.13)

var _loader
var _selected := []            # 有序 card_id（<= 8）
var _frames := {}              # card_id -> 选中金边 Panel（切换 visible）
var _slots := []               # 8 x {btn, label, portrait}
var _count_label: Label
var _battle_btn: Button

func _ready() -> void:
	_loader = ConfigLoaderScript.new()
	_loader.load_all()
	_init_selection()
	_build()
	_refresh()

func _init_selection() -> void:
	var src: Array = GameStateScript.player_deck
	if src.is_empty():
		src = (_loader.get_level(GameStateScript.level_id).get("player_deck", []) as Array)
	for id in src:
		if _loader.has_card(id) and not (id in _selected) and _selected.size() < DECK_SIZE:
			_selected.append(id)

func _cost(id) -> int:
	return int(_loader.get_card(id).get("elixir_cost", 0))

func _card_name(id) -> String:
	return tr("card_" + str(id))

func _is_troop(id) -> bool:
	for sk in (_loader.get_card(id).get("skills", []) as Array):
		if typeof(sk) == TYPE_DICTIONARY and sk.get("type") == "spawn_unit":
			return true
	return false

func _build() -> void:
	PixelUI.add_background(self)
	_title(tr("deck_title"), 40, 46)
	_center_label(tr("deck_stage") % GameStateScript.level_id.to_upper(), 116, 22, PixelUI.COL_MUTED)

	# 当前卡组 8 格（2 行 x 4）
	_pin_label(tr("deck_your"), Vector2(30, 162), Vector2(360, 28), 24, PixelUI.COL_PARCHMENT, HORIZONTAL_ALIGNMENT_LEFT)
	for i in DECK_SIZE:
		var col := i % 4
		var row := i / 4
		var x := 30.0 + col * 170.0
		var y := 200.0 + row * 86.0
		var btn := Button.new()
		btn.position = Vector2(x, y)
		btn.size = Vector2(150, 70)
		btn.focus_mode = Control.FOCUS_NONE
		btn.add_theme_stylebox_override("normal", PixelUI.sbpixel(SLOT_FILLED_BG, 2, Color(0.40, 0.55, 0.42)))
		btn.add_theme_stylebox_override("hover", PixelUI.sbpixel(SLOT_FILLED_BG.lightened(0.12), 2, GOLD))
		btn.add_theme_stylebox_override("pressed", PixelUI.sbpixel(SLOT_FILLED_BG.darkened(0.1), 2, Color(0.40, 0.55, 0.42)))
		btn.pressed.connect(_remove_at.bind(i))
		add_child(btn)
		var port := TextureRect.new()       # 已选槽肖像（_refresh 按选中卡设纹理/隐显）
		port.position = Vector2(x + 50, y + 3)
		port.size = Vector2(50, 34)
		port.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		port.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		port.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		port.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(port)
		var lbl := _pin_label("", Vector2(x, y + 36), Vector2(150, 30), 18, Color(1, 1, 1), HORIZONTAL_ALIGNMENT_CENTER)
		_slots.append({"btn": btn, "label": lbl, "portrait": port})

	_count_label = _pin_label("", Vector2(400, 162), Vector2(290, 28), 24, GOLD, HORIZONTAL_ALIGNMENT_RIGHT)

	# 分隔线 + 卡池
	_rect(Color(0.30, 0.34, 0.30, 0.8), Vector2(30, 386), Vector2(660, 3))
	_pin_label(tr("deck_pool"), Vector2(30, 398), Vector2(660, 26), 20, PixelUI.COL_MUTED, HORIZONTAL_ALIGNMENT_LEFT)
	var ids: Array = _loader.cards.keys()
	for i in ids.size():
		var id = ids[i]
		var col := i % 4
		var row := i / 4
		var x := 30.0 + col * 170.0
		var y := 440.0 + row * 100.0
		_pool_tile(id, x, y)

	# 底部按钮
	_action_button(tr("btn_back"), 70, 988, 240, "dark", _on_back)
	_battle_btn = _action_button(tr("btn_battle"), 410, 988, 240, "gold", _on_battle)
	_battle_btn.add_theme_stylebox_override("disabled", PixelUI.sbpixel(Color(0.18, 0.18, 0.20), 3, Color(0.30, 0.30, 0.33)))
	_battle_btn.add_theme_color_override("font_disabled_color", Color(0.5, 0.5, 0.55))
	_center_label(tr("deck_need8"), 1086, 20, PixelUI.COL_HINT)

func _pool_tile(id, x: float, y: float) -> void:
	var troop := _is_troop(id)
	var bg: Color = TROOP_BG if troop else SPELL_BG
	var border: Color = TROOP_BORDER if troop else SPELL_BORDER
	var btn := Button.new()
	btn.position = Vector2(x, y)
	btn.size = Vector2(150, 84)
	btn.focus_mode = Control.FOCUS_NONE
	btn.add_theme_stylebox_override("normal", PixelUI.sbpixel(bg, 2, border))
	btn.add_theme_stylebox_override("hover", PixelUI.sbpixel(bg.lightened(0.15), 2, border))
	btn.add_theme_stylebox_override("pressed", PixelUI.sbpixel(bg.darkened(0.12), 2, border))
	btn.pressed.connect(_toggle.bind(id))
	add_child(btn)
	var port := SpriteDB.make_card_portrait(str(id), _loader, Vector2(x + 49, y + 3), Vector2(52, 40))
	if port != null:   # 有肖像 → 图在上、名+费在下；无肖像(箭雨/滚石/治疗) → 名+费居中
		add_child(port)
		_pin_label("%s\n%d" % [_card_name(id), _cost(id)], Vector2(x, y + 42), Vector2(150, 40), 15, Color(1, 1, 1), HORIZONTAL_ALIGNMENT_CENTER)
	else:
		_pin_label("%s\n%d" % [_card_name(id), _cost(id)], Vector2(x, y), Vector2(150, 84), 21, Color(1, 1, 1), HORIZONTAL_ALIGNMENT_CENTER)
	# 选中金边（默认隐藏，_refresh 控制 visible）
	var frame := Panel.new()
	frame.position = Vector2(x - 2, y - 2)
	frame.size = Vector2(154, 88)
	frame.add_theme_stylebox_override("panel", PixelUI.sbpixel(Color(0, 0, 0, 0), 4, GOLD))
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.visible = false
	add_child(frame)
	_frames[id] = frame

func _toggle(id) -> void:
	var idx: int = _selected.find(id)
	if idx >= 0:
		_selected.remove_at(idx)
	elif _selected.size() < DECK_SIZE:
		_selected.append(id)
	_refresh()

func _remove_at(i: int) -> void:
	if i >= 0 and i < _selected.size():
		_selected.remove_at(i)
		_refresh()

func _refresh() -> void:
	for id in _frames:
		_frames[id].visible = id in _selected
	for i in DECK_SIZE:
		var s = _slots[i]
		if i < _selected.size():
			var id = _selected[i]
			s.label.text = _card_name(id)
			s.portrait.texture = SpriteDB.card_portrait_tex(str(id), _loader)
			s.portrait.visible = s.portrait.texture != null
			s.btn.add_theme_stylebox_override("normal", PixelUI.sbpixel(SLOT_FILLED_BG, 2, Color(0.40, 0.55, 0.42)))
		else:
			s.label.text = "+"
			s.portrait.visible = false
			s.btn.add_theme_stylebox_override("normal", PixelUI.sbpixel(SLOT_EMPTY_BG, 2, Color(0.28, 0.30, 0.28)))
	var full := _selected.size() == DECK_SIZE
	_count_label.text = "%d / %d" % [_selected.size(), DECK_SIZE]
	_count_label.add_theme_color_override("font_color", Color(0.5, 0.9, 0.55) if full else GOLD)
	if _battle_btn != null:
		_battle_btn.disabled = not full

func _on_battle() -> void:
	if _selected.size() != DECK_SIZE:
		return
	GameStateScript.player_deck = _selected.duplicate()
	get_tree().change_scene_to_file(BATTLE_SCENE)

func _on_back() -> void:
	get_tree().change_scene_to_file(LEVEL_SELECT_SCENE)

# ---------- 小工具 ----------
func _rect(color: Color, pos: Vector2, size: Vector2) -> ColorRect:
	var r := ColorRect.new()
	r.color = color
	r.position = pos
	r.size = size
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(r)
	return r

func _action_button(text: String, x: float, y: float, w: float, kind: String, cb: Callable) -> Button:
	var btn := Button.new()
	btn.position = Vector2(x, y)
	btn.size = Vector2(w, 84)
	btn.text = text
	btn.pivot_offset = Vector2(w / 2.0, 42.0)
	btn.focus_mode = Control.FOCUS_NONE
	PixelUI.style_button(btn, kind, 32)
	btn.pressed.connect(cb)
	btn.button_down.connect(_scale_to.bind(btn, 0.96))
	btn.button_up.connect(_scale_to.bind(btn, 1.0))
	add_child(btn)
	return btn

func _scale_to(c: Control, s: float) -> void:
	create_tween().tween_property(c, "scale", Vector2(s, s), 0.07)

func _title(text: String, y: float, fs: int) -> void:
	for off in [Vector2(3, 3), Vector2(-3, 3), Vector2(3, -3), Vector2(-3, -3)]:
		var s := _center_label(text, y, fs, PixelUI.COL_OUTLINE)
		s.position += off
	_center_label(text, y, fs, PixelUI.COL_GOLD)

func _center_label(text: String, y: float, font_size: int, color: Color) -> Label:
	return _pin_label(text, Vector2(0, y), Vector2(720, float(font_size) + 16.0), font_size, color, HORIZONTAL_ALIGNMENT_CENTER)

func _pin_label(text: String, pos: Vector2, size: Vector2, font_size: int, color: Color, align: int) -> Label:
	var l := Label.new()
	l.text = text
	l.position = pos
	l.size = size
	l.horizontal_alignment = align
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)
	return l
