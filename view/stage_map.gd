# StageMap —— V5-S7c 闯关地图（竖向关卡列表，决策48 服务器权威）。
#
# 读经济缓存(服务器快照) + StageProgress 判 cleared/current/locked 三态 + 星级。
# 点当前/已通关关 → 设 stage_id + deck_mode=stage → deck_builder → battle。
# 战后 battle 回本屏并带 stage_last_result → 上报服务器(report_stage_clear) → 领奖开箱 → 刷新。
# 展示算用本地 ConfigLoader；执行(上报/发奖)走服务器。
extends Control

const PixelUI := preload("res://view/ui/pixel_ui.gd")
const HudWidgets := preload("res://view/ui/hud_widgets.gd")
const DragScroll := preload("res://view/ui/drag_scroll.gd")
const GameStateScript := preload("res://view/game_state.gd")
const StageProgressScript := preload("res://logic/stage_progress.gd")
const RewardChestScript := preload("res://view/ui/reward_chest.gd")
const BG_TEX := preload("res://assets/ui/menu_bg.png")

const BASE_CAMP_SCENE := "res://view/base_camp.tscn"
const DECK_BUILDER_SCENE := "res://view/deck_builder.tscn"

const ROW_CLEARED_BG := Color("1f2a24"); const ROW_CLEARED_BD := Color("3b6d3a")
const ROW_CURRENT_BG := Color("2a2110"); const ROW_CURRENT_BD := Color("ecb94e")
const ROW_LOCKED_BG := Color("1a1622");  const ROW_LOCKED_BD := Color("38324e")

var _http: HTTPRequest
var _wallet_holder: Control
var _list: VBoxContainer
var _status: Label

func _ready() -> void:
	AudioManager.play_music("music_main_menu")
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

	_title("闯关", 84, 52)
	_status = _center_label("连接中…", 150, 20, PixelUI.COL_HINT)

	var scroll := ScrollContainer.new()
	scroll.position = Vector2(40, 196)
	scroll.size = Vector2(640, 936)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.scroll_deadzone = 16
	add_child(scroll)
	DragScroll.attach(scroll)   # 桌面鼠标按住拖动（触摸走原生）
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 12)
	_list.custom_minimum_size = Vector2(640, 0)
	scroll.add_child(_list)

	_back_button(1168)

func _bootstrap() -> void:
	var session = GameStateScript.session()
	if not await session.ensure(_http):
		_status.text = "（离线）未连接服务器"
		return
	var token: String = session.token()
	var config = GameStateScript.config()
	var all_ids: Array = config.cards.keys()
	var econ = GameStateScript.economy()
	if not econ.is_loaded:
		await econ.refresh(_http, token, all_ids)
	# 战后回流：上报 + 领奖
	var reward = null
	var pending = GameStateScript.stage_last_result
	if typeof(pending) == TYPE_DICTIONARY and pending.has("stage_id"):
		print("[V5][map] 收到战后结果 %s" % str(pending))
		GameStateScript.stage_last_result = {}
		reward = await _report_and_delta(pending, token, all_ids, econ, config)
		print("[V5][map] 发奖结果 %s" % str(reward))
	_populate(econ.get_cache(), config)
	if reward != null:
		_show_chest(reward)

func _report_and_delta(pending: Dictionary, token: String, all_ids: Array, econ, config):
	var sid := String(pending.get("stage_id", ""))
	var stars := int(pending.get("stars", 0))
	if stars < 1 or sid == "":
		print("[V5][map] %s 未通关(stars=%d) → 不上报、不发奖" % [sid, stars])
		return null   # 未通关 = 不上报、不开箱
	var cache = econ.get_cache()
	var was_cleared := cache != null and bool((cache.stages.get(sid, {}) as Dictionary).get("cleared", false))
	var bgold := int(cache.gold) if cache != null else 0
	var bgems := int(cache.gems) if cache != null else 0
	var bshards := _total_shards(cache)
	# KAN-78：battle_id + 战报摘要随上报（服务器限速/时长/星数摘要交叉校验后才发奖）。
	var res: Dictionary = await econ.report_stage_clear(_http, token, sid, stars, all_ids,
		int(pending.get("battle_id", 0)), pending.get("summary", {}))
	if not bool(res.get("ok", false)):
		return null
	var after = econ.get_cache()
	return {
		"stars": stars, "cap": _star_cap(sid, config), "first": not was_cleared,
		"gold": int(after.gold) - bgold, "gems": int(after.gems) - bgems,
		"shards": _total_shards(after) - bshards,
	}

func _populate(cache, config) -> void:
	for c in _list.get_children():
		c.queue_free()
	if cache == null:
		_status.text = "（离线）"
		return
	_set_wallet(cache.gold, cache.gems)
	var sp = StageProgressScript.new(config.stages)
	var ids: Array = sp.ordered_ids()
	if ids.is_empty():
		_status.text = "暂无关卡"
		return
	var next_id: String = sp.next_stage(cache)
	_status.text = "全部通关 · 已毕业" if next_id == "" else "下一关 %s" % _stage_name(config.get_stage(next_id))
	var cur_chapter := -1
	for sid in ids:
		var st: Dictionary = config.get_stage(sid)
		var ch := int(st.get("chapter", 0))
		if ch != cur_chapter:
			cur_chapter = ch
			_list.add_child(_chapter_header(ch, sp, cache))
		var cleared := bool((cache.stages.get(sid, {}) as Dictionary).get("cleared", false))
		var unlocked: bool = sp.is_unlocked(sid, cache)
		var state := "cleared" if cleared else ("current" if unlocked else "locked")
		_list.add_child(_stage_row(sid, st, state, cache))

func _chapter_header(chapter: int, sp, cache) -> Control:
	var got := int(sp.chapter_stars(chapter, cache))
	var total := 0
	for it in sp.ordered:
		if int(it.get("chapter", 0)) == chapter:
			total += _star_cap(String(it.get("id", "")), GameStateScript.config())
	var h := Control.new()
	h.custom_minimum_size = Vector2(620, 40)
	var l := _row_label("第%d章" % chapter, Vector2(6, 6), 26, PixelUI.COL_GOLD, HORIZONTAL_ALIGNMENT_LEFT, 300)
	h.add_child(l)
	var sr := _row_label("星 %d/%d" % [got, total], Vector2(320, 8), 22, PixelUI.COL_MUTED, HORIZONTAL_ALIGNMENT_RIGHT, 294)
	h.add_child(sr)
	return h

func _stage_row(sid: String, st: Dictionary, state: String, cache) -> Control:
	var bg: Color; var bd: Color
	match state:
		"cleared": bg = ROW_CLEARED_BG; bd = ROW_CLEARED_BD
		"current": bg = ROW_CURRENT_BG; bd = ROW_CURRENT_BD
		_: bg = ROW_LOCKED_BG; bd = ROW_LOCKED_BD
	var clickable := state != "locked"
	var row: Control
	if clickable:
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_stylebox_override("normal", PixelUI.sbpixel(bg, 3, bd))
		b.add_theme_stylebox_override("hover", PixelUI.sbpixel(bg.lightened(0.1), 3, bd.lightened(0.15)))
		b.add_theme_stylebox_override("pressed", PixelUI.sbpixel(bg.darkened(0.1), 3, bd))
		b.pressed.connect(_challenge.bind(sid))
		row = b
	else:
		var p := Panel.new()
		p.add_theme_stylebox_override("panel", PixelUI.sbpixel(bg, 3, bd))
		p.modulate = Color(1, 1, 1, 0.6)
		row = p
	row.custom_minimum_size = Vector2(620, 88)
	# 序号徽章
	var badge := Panel.new()
	badge.position = Vector2(14, 18)
	badge.size = Vector2(52, 52)
	badge.add_theme_stylebox_override("panel", PixelUI.sbpixel(bd.darkened(0.1), 0, bd))
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(badge)
	row.add_child(_row_label("%d-%d" % [int(st.get("chapter", 0)), int(st.get("index", 0))],
			Vector2(14, 30), 20, Color("141019") if state == "current" else PixelUI.COL_PARCHMENT, HORIZONTAL_ALIGNMENT_CENTER, 52))
	# 名 + 副
	row.add_child(_row_label(_stage_name(st), Vector2(84, 14), 22,
			PixelUI.COL_GOLD if state == "current" else PixelUI.COL_PARCHMENT, HORIZONTAL_ALIGNMENT_LEFT, 340))
	var cap := _star_cap(sid, GameStateScript.config())
	match state:
		"cleared":
			var sw := HudWidgets.stars_row(int((cache.stages.get(sid, {}) as Dictionary).get("stars", 0)), cap, 22.0)
			sw.position = Vector2(84, 52)
			row.add_child(sw)
			row.add_child(_icon_label("已通关", Vector2(516, 32), 20, Color("7cc36a")))
		"current":
			row.add_child(_row_label("下一关 · 推荐战力 %s" % HudWidgets.format_int(int(st.get("recommended_power", 0))),
					Vector2(84, 52), 16, PixelUI.COL_MUTED, HORIZONTAL_ALIGNMENT_LEFT, 360))
			row.add_child(_icon_label("挑战", Vector2(470, 28), 26, PixelUI.COL_GOLD))
		_:
			row.add_child(_row_label("通关前一关解锁", Vector2(84, 52), 16, PixelUI.COL_HINT, HORIZONTAL_ALIGNMENT_LEFT, 360))
			row.add_child(_icon_label("锁定", Vector2(516, 32), 20, PixelUI.COL_HINT))
	return row

# ---------- handlers ----------
func _challenge(sid: String) -> void:
	AudioManager.play_sfx("ui_button_press")
	GameStateScript.stage_id = sid
	GameStateScript.deck_mode = "stage"
	print("[V5][map] 挑战 %s → 组卡(stage)" % sid)
	get_tree().change_scene_to_file(DECK_BUILDER_SCENE)

func _on_back() -> void:
	AudioManager.play_sfx("ui_button_back")
	get_tree().change_scene_to_file(BASE_CAMP_SCENE)

func _show_chest(reward: Dictionary) -> void:
	var chest = RewardChestScript.new()
	chest.setup(int(reward.get("stars", 0)), int(reward.get("cap", 3)),
			int(reward.get("gold", 0)), int(reward.get("gems", 0)), int(reward.get("shards", 0)), bool(reward.get("first", false)))
	UI.modal(chest)   # F2：弹窗层承载（恒高于场景层与滚动拦截，穿透从机制上绝迹）

# ---------- helpers ----------
func _stage_name(st: Dictionary) -> String:
	return "关卡 %d-%d" % [int(st.get("chapter", 0)), int(st.get("index", 0))]

func _star_cap(sid: String, config) -> int:
	var g = config.get_stage(sid).get("stars", [])
	return (g as Array).size() if g is Array and (g as Array).size() > 0 else 3

func _total_shards(cache) -> int:
	if cache == null:
		return 0
	var n := 0
	for cid in cache.cards:
		n += int((cache.cards[cid] as Dictionary).get("shards", 0))
	return n

func _set_wallet(gold: int, gems: int) -> void:
	for c in _wallet_holder.get_children():
		c.queue_free()
	_wallet_holder.add_child(HudWidgets.wallet_bar(gold, gems, 560.0))

func _row_label(text: String, pos: Vector2, fs: int, col: Color, align: int, w: float) -> Label:
	var l := Label.new()
	l.text = text
	l.position = pos
	l.size = Vector2(w, float(fs) + 12.0)
	l.horizontal_alignment = align
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", col)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

func _icon_label(text: String, pos: Vector2, fs: int, col: Color) -> Label:
	return _row_label(text, pos, fs, col, HORIZONTAL_ALIGNMENT_CENTER, 100)

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
