# KingdomBuildingModal —— 王国建筑操作弹窗（K2 场景化改版配套；F1 规约：经 UI.modal 推入）。
#
# 场景里点建筑 → 本弹窗展示 等级/效果/成本/施工状态，动作（建造/升级/加速）经
# KingdomStateCache 走服务器结算；成功后 kingdom_changed 广播刷新场景与本窗。
extends "res://view/ui/modal.gd"

const PixelUI := preload("res://view/ui/pixel_ui.gd")
const HudWidgets := preload("res://view/ui/hud_widgets.gd")
const GameStateScript := preload("res://view/game_state.gd")

var building := ""            # 配置键（open 前由调用方设置）
var _http: HTTPRequest
var _title: Label
var _lv: Label
var _info: Label
var _status: Label
var _act_btn: Button
var _busy := false

static func reject_text(code: int) -> String:
	match code:
		500: return "资源或宝石不足"
		501: return "已达等级上限"
		502: return "条件未满足（王城等级/章节进度）"
	return "操作失败，请稍后再试"

func _build() -> void:
	close_on_bg_click = true
	_http = HTTPRequest.new()
	add_child(_http)
	var panel := Panel.new()
	panel.position = Vector2(60, 420)
	panel.size = Vector2(600, 380)
	panel.add_theme_stylebox_override("panel", PixelUI.sbpixel(Color(0.10, 0.08, 0.14, 0.97), 3, Color("4a3a14")))
	add_child(panel)
	_title = _lbl(panel, Vector2(0, 22), 30, PixelUI.COL_GOLD)
	_lv = _lbl(panel, Vector2(0, 66), 22, PixelUI.COL_PARCHMENT)
	_info = _lbl(panel, Vector2(0, 104), 19, PixelUI.COL_MUTED)
	_status = _lbl(panel, Vector2(0, 148), 20, PixelUI.COL_PARCHMENT)
	_act_btn = Button.new()
	_act_btn.position = Vector2(170, 210)
	_act_btn.size = Vector2(260, 76)
	_act_btn.pivot_offset = _act_btn.size * 0.5
	_act_btn.focus_mode = Control.FOCUS_NONE
	PixelUI.style_button(_act_btn, "gold", 26)
	_act_btn.pressed.connect(_on_action)
	panel.add_child(_act_btn)
	var close_btn := Button.new()
	close_btn.text = "关闭"
	close_btn.position = Vector2(230, 302)
	close_btn.size = Vector2(140, 56)
	close_btn.focus_mode = Control.FOCUS_NONE
	PixelUI.style_button(close_btn, "dark", 22)
	close_btn.pressed.connect(close)
	panel.add_child(close_btn)
	Events.kingdom_changed.connect(_on_kingdom_changed)
	_refresh()

func _on_kingdom_changed(_kd) -> void:
	_refresh()

func _refresh() -> void:
	var kd = GameStateScript.kingdom()
	var bcfg := _bcfg()
	_title.text = str(bcfg.get("display_zh", building))
	var lv := int(kd.building_level(building))
	_lv.text = ("等级 Lv %d" % lv) if lv > 0 else "未建造（空地）"
	_info.text = _info_text(lv)
	var remain := int(kd.remaining_s(building))
	if remain > 0:
		_status.text = "施工中 · 剩 %s" % _fmt_dur(remain)
		_act_btn.text = "宝石加速"
		_act_btn.disabled = _busy
		return
	var next := _level_row(lv + 1)
	if next.is_empty():
		_status.text = "已满级"
		_act_btn.text = "已满级"
		_act_btn.disabled = true
		return
	var parts: Array = []
	for r in (next.get("cost", {}) as Dictionary):
		if int(next["cost"][r]) > 0:
			parts.append("%s %s" % [_res_zh(str(r)), HudWidgets.format_int(int(next["cost"][r]))])
	_status.text = "下一级：%s · 耗时 %s" % [
		" ".join(parts) if not parts.is_empty() else "免费", _fmt_dur(int(next.get("time_s", 0)))]
	if building == "keep" and int(next.get("chapter_req", 0)) > 0:
		_status.text += "\n需通关第 %d 章" % int(next.get("chapter_req", 0))
	_act_btn.text = "升级" if lv > 0 else "建造"
	_act_btn.disabled = _busy

func _on_action() -> void:
	if _busy:
		return
	AudioManager.play_sfx("ui_button_press")
	_busy = true
	_act_btn.disabled = true
	var kd = GameStateScript.kingdom()
	var token: String = GameStateScript.session().token()
	var res: Dictionary
	if int(kd.remaining_s(building)) > 0:
		res = await kd.speedup(_http, token, building)
	else:
		res = await kd.upgrade(_http, token, building)
	_busy = false
	if not bool(res.get("ok", false)):
		UI.toast(reject_text(int(res.get("error_code", 0))))
	_refresh()   # 成功路径 kingdom_changed 也会刷；这里兜底恢复按钮态

# ---------- 展示助手（与场景侧共用口径：全部读 config/kingdom.json）----------
func _bcfg() -> Dictionary:
	return (GameStateScript.config().kingdom.get("buildings", {}) as Dictionary).get(building, {})

func _level_row(level: int) -> Dictionary:
	var lvs: Array = _bcfg().get("levels", [])
	if level < 1 or level > lvs.size():
		return {}
	return lvs[level - 1]

func _info_text(lv: int) -> String:
	var bcfg := _bcfg()
	var cur := _level_row(maxi(lv, 1))
	match str(bcfg.get("kind", "")):
		"core":
			return "其余建筑等级上限 = 王城等级 ×%d" % int(
					(GameStateScript.config().kingdom.get("rules", {}) as Dictionary).get("keep_cap_mult", 2))
		"producer":
			var unit := _res_zh(str(bcfg.get("produces", "")))
			if lv <= 0:
				return "产出%s（建造后生效）" % unit
			return "产出 %d %s/小时 · 存量上限 %d" % [int(cur.get("rate_per_h", 0)), unit, int(cur.get("storage", 0))]
		"storage":
			if lv <= 0:
				return "扩建仓库上限（建造后生效）"
			var bonus: Dictionary = cur.get("storage_bonus", {})
			return "仓库上限 +粮%d +木%d" % [int(bonus.get("food", 0)), int(bonus.get("wood", 0))]
		"defense":
			var first := _level_row(1)
			var f := "tower_hp_pct" if first.has("tower_hp_pct") else "tower_dmg_pct"
			return "%s +%d%%/级（对战城防）" % ["塔 HP" if f == "tower_hp_pct" else "塔攻", int(first.get(f, 0))]
	return ""

func _res_zh(res: String) -> String:
	match res:
		"food": return "粮草"
		"wood": return "木石"
		"gold": return "金币"
	return res

func _fmt_dur(s: int) -> String:
	if s <= 0:
		return "即时"
	if s < 3600:
		return "%d分%02d秒" % [s / 60, s % 60]
	if s < 86400:
		return "%d小时%d分" % [s / 3600, (s % 3600) / 60]
	return "%d天%d小时" % [s / 86400, (s % 86400) / 3600]

func _lbl(parent: Control, pos: Vector2, font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.position = pos
	l.size = Vector2(600, float(font_size) * 2 + 12)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l
