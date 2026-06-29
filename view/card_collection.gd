# CardCollection —— V5-S7d 养成卡格（决策48 服务器权威状态只读展示）。
#
# 全卡池网格（2 列）：肖像 + 稀有度边框 + 等级 + 锁卡(碎片进度) + 可养成红点。
# 点卡 → card_detail。读经济缓存(服务器快照)；展示算用本地 ConfigLoader。
# 多维排序（KAN-67）：顶部分段控件切 稀有度/费/等级/可养成 + 升降序，记忆上次选择（本地 settings.cfg）。
extends Control

const PixelUI := preload("res://view/ui/pixel_ui.gd")
const HudWidgets := preload("res://view/ui/hud_widgets.gd")
const CardSortScript := preload("res://logic/card_sort.gd")
const GameStateScript := preload("res://view/game_state.gd")
const SpriteDB := preload("res://view/sprite_db.gd")
const BG_TEX := preload("res://assets/ui/menu_bg.png")

const BASE_CAMP_SCENE := "res://view/base_camp.tscn"
const CARD_DETAIL_SCENE := "res://view/card_detail.tscn"

const RARITY_COL := {
	"common": Color("9aa0ad"), "rare": Color("4a6db0"),
	"epic": Color("7c5ea8"), "legendary": Color("d8a23a"),
}
const SORT_PREF_PATH := "user://settings.cfg"
const SORT_LABELS := {"rarity": "稀有度", "cost": "费", "level": "等级", "actionable": "可养成"}

var _http: HTTPRequest
var _wallet_holder: Control
var _grid: GridContainer
var _status: Label
var _sort_key := "rarity"
var _sort_asc := true                 # 记忆上次选择；默认稀有度升序（普通→传说）
var _key_btns := {}
var _dir_btn: Button

func _ready() -> void:
	AudioManager.play_music("music_main_menu")
	_load_sort_pref()
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
	_title("养成", 84, 52)
	_status = _center_label("连接中…", 128, 18, PixelUI.COL_HINT)
	_build_sort_bar(160)

	var scroll := ScrollContainer.new()
	scroll.position = Vector2(40, 212)
	scroll.size = Vector2(640, 920)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	_grid = GridContainer.new()
	_grid.columns = 2
	_grid.add_theme_constant_override("h_separation", 16)
	_grid.add_theme_constant_override("v_separation", 16)
	scroll.add_child(_grid)

	_back_button(1168)

func _bootstrap() -> void:
	var session = GameStateScript.session()
	if not await session.ensure(_http):
		_status.text = "（离线）未连接服务器"
		return
	var config = GameStateScript.config()
	var econ = GameStateScript.economy()
	if not econ.is_loaded:
		await econ.refresh(_http, session.token(), config.cards.keys())
	_populate(econ.get_cache(), config)

func _populate(cache, config) -> void:
	for c in _grid.get_children():
		c.queue_free()
	if cache == null:
		_status.text = "（离线）"
		return
	_set_wallet(cache.gold, cache.gems)
	var ids := CardSortScript.sort_ids(config.cards.keys(), cache, config, _sort_key, _sort_asc)
	var unlocked := 0
	for cid in ids:
		if cache.is_unlocked(cid):
			unlocked += 1
		_grid.add_child(_card_tile(cid, cache, config))
	_status.text = "已解锁 %d / %d" % [unlocked, ids.size()]

# —— KAN-67 多维排序控件 ——
func _build_sort_bar(y: float) -> void:
	var x := 40.0
	for key in CardSortScript.KEYS:
		var w: float = 130.0 if key == "actionable" else (80.0 if key == "cost" else (90.0 if key == "level" else 110.0))
		_key_btns[key] = _sort_btn(String(SORT_LABELS[key]), x, y, w, _on_sort_key.bind(key))
		x += w + 8.0
	_dir_btn = _sort_btn(_dir_label(), 580, y, 100, _on_sort_dir)
	_refresh_sort_buttons()

func _sort_btn(label: String, x: float, y: float, w: float, cb: Callable) -> Button:
	var btn := Button.new()
	btn.text = label
	btn.position = Vector2(x, y)
	btn.size = Vector2(w, 40)
	btn.focus_mode = Control.FOCUS_NONE
	PixelUI.style_button(btn, "stone", 20)
	btn.pressed.connect(cb)
	add_child(btn)
	return btn

func _dir_label() -> String:
	return "升序" if _sort_asc else "降序"

# 切某键时套该键的自然默认方向（可再按升降序翻转）。
func _default_asc(key: String) -> bool:
	match key:
		"cost", "rarity": return true    # 便宜在前 / 普通→传说
		_: return false                  # 等级高在前 / 可养成在前
	return true

func _on_sort_key(key: String) -> void:
	AudioManager.play_sfx("ui_button_press")
	_sort_key = key
	_sort_asc = _default_asc(key)
	_dir_btn.text = _dir_label()
	_save_sort_pref()
	_refresh_sort_buttons()
	_rebuild()

func _on_sort_dir() -> void:
	AudioManager.play_sfx("ui_button_press")
	_sort_asc = not _sort_asc
	_dir_btn.text = _dir_label()
	_save_sort_pref()
	_rebuild()

func _refresh_sort_buttons() -> void:
	for key in _key_btns:
		PixelUI.style_button(_key_btns[key], "gold" if key == _sort_key else "stone", 20)

# 即时重排（不重拉服务器，用缓存重建网格）。
func _rebuild() -> void:
	_populate(GameStateScript.economy().get_cache(), GameStateScript.config())

func _load_sort_pref() -> void:
	var c := ConfigFile.new()
	if c.load(SORT_PREF_PATH) == OK:
		var k := String(c.get_value("card_sort", "key", "rarity"))
		if CardSortScript.KEYS.has(k):
			_sort_key = k
		_sort_asc = bool(c.get_value("card_sort", "asc", true))

func _save_sort_pref() -> void:
	var c := ConfigFile.new()
	c.load(SORT_PREF_PATH)   # 忽略返回：不存在则空配置
	c.set_value("card_sort", "key", _sort_key)
	c.set_value("card_sort", "asc", _sort_asc)
	c.save(SORT_PREF_PATH)

func _card_tile(cid: String, cache, config) -> Control:
	var rarity := str(config.get_card_progression(cid).get("rarity", "common"))
	var bd: Color = RARITY_COL.get(rarity, RARITY_COL["common"])
	var unlocked: bool = cache.is_unlocked(cid)
	var st: Dictionary = cache.card_state(cid)
	var tile := Button.new()
	tile.custom_minimum_size = Vector2(300, 150)
	tile.focus_mode = Control.FOCUS_NONE
	tile.add_theme_stylebox_override("normal", PixelUI.sbpixel(Color("1f1830"), 3, bd))
	tile.add_theme_stylebox_override("hover", PixelUI.sbpixel(Color("271f3a"), 3, bd.lightened(0.2)))
	tile.add_theme_stylebox_override("pressed", PixelUI.sbpixel(Color("191322"), 3, bd))
	tile.pressed.connect(_open_detail.bind(cid))
	# 肖像
	var port := SpriteDB.make_card_portrait(cid, config, Vector2(18, 22), Vector2(96, 96))
	if port != null:
		tile.add_child(port)
	# 名
	tile.add_child(_tile_label(tr("card_" + cid), Vector2(126, 26), 22, PixelUI.COL_PARCHMENT, 160))
	# 稀有度
	tile.add_child(_tile_label(_rarity_zh(rarity), Vector2(126, 58), 16, bd.lightened(0.2), 160))
	if unlocked:
		tile.add_child(_tile_label("Lv.%d" % int(st.get("level", 1)), Vector2(126, 92), 22, PixelUI.COL_GOLD, 160))
		var pips := HudWidgets.rank_pips(int(st.get("rank", 1)), _max_rank(config), 14.0)
		pips.position = Vector2(126, 120)
		tile.add_child(pips)
		if _actionable(cache, config, cid):
			tile.add_child(_red_dot(Vector2(276, 10)))
	else:
		var ov := HudWidgets.locked_overlay("碎片 %d/%d" % [int(st.get("shards", 0)), _unlock_need(config, rarity)], 300, 150)
		tile.add_child(ov)
		if cache.can_unlock(cid, config):
			tile.add_child(_red_dot(Vector2(276, 10)))
	return tile

func _actionable(cache, config, cid: String) -> bool:
	return CardSortScript.actionable(cache, config, cid)

# ---------- handlers ----------
func _open_detail(cid: String) -> void:
	AudioManager.play_sfx("ui_button_press")
	GameStateScript.detail_card = cid
	get_tree().change_scene_to_file(CARD_DETAIL_SCENE)

func _on_back() -> void:
	AudioManager.play_sfx("ui_button_back")
	get_tree().change_scene_to_file(BASE_CAMP_SCENE)

# ---------- helpers ----------
func _rarity_zh(r: String) -> String:
	match r:
		"common": return "普通"
		"rare": return "稀有"
		"epic": return "史诗"
		"legendary": return "传说"
	return r

func _max_rank(config) -> int:
	var tbl = config.get_economy().get("level_cap_per_rank", {})
	var m := 1
	if typeof(tbl) == TYPE_DICTIONARY:
		for k in tbl:
			m = maxi(m, int(k))
	return m

func _unlock_need(config, rarity: String) -> int:
	var t = config.get_economy().get("unlock_shards", {})
	return int((t as Dictionary).get(rarity, 0)) if t is Dictionary else 0

func _red_dot(pos: Vector2) -> Panel:
	var d := Panel.new()
	d.position = pos
	d.size = Vector2(16, 16)
	d.add_theme_stylebox_override("panel", PixelUI.sbpixel(Color("ecb94e"), 0, Color("2c1f06")))
	d.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return d

func _set_wallet(gold: int, gems: int) -> void:
	for c in _wallet_holder.get_children():
		c.queue_free()
	_wallet_holder.add_child(HudWidgets.wallet_bar(gold, gems, 560.0))

func _tile_label(text: String, pos: Vector2, fs: int, col: Color, w: float) -> Label:
	var l := Label.new()
	l.text = text
	l.position = pos
	l.size = Vector2(w, float(fs) + 12.0)
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", col)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

func _title(text: String, y: float, fs: int) -> void:
	for off in [Vector2(3, 3), Vector2(-3, 3), Vector2(3, -3), Vector2(-3, -3)]:
		var s := _center_label(text, y, fs, PixelUI.COL_OUTLINE)
		s.position += off
	_center_label(text, y, fs, PixelUI.COL_GOLD)

func _center_label(text: String, y: float, fs: int, col: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.position = Vector2(0, y)
	l.size = Vector2(720, float(fs) + 16.0)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", col)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)
	return l

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
