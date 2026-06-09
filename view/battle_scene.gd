# BattleScene —— 显示层（白膜）。V2-2：3 lane + 出牌选 lane。V2-4：动画与特效。
#
# 只读 Match 的逻辑状态作画；出牌一律经 player.try_play_card（玩家/AI 对称）。
# 逻辑坐标 0~1 → 像素的映射只活在本层：progress 0=己方塔在屏幕下，1=敌方塔在上。
# 3 条 lane（左公主/中王/右公主）；对手由规则 AI 自驱（固定中路）。
# 两段式出牌：先点手牌，再点己方半场落点——落点 lane 由点击 x 最近列决定、progress 由 y 决定。
#
# V2-4 动画/特效（纯显示层，逻辑零改动，路线 A）：
#   - 受击/死亡/塔摧毁：靠逐帧 diff 血量可靠还原。
#   - 攻击顶刺/远程投射物：显示层复刻「目标选择」（同 Lane._find_enemy_in_range + 尽头敌塔）来还原。
#   - 法术爆点：玩家法术按点击点/直伤目标精确出特效；AI 法术按「同帧多单位聚集掉血」推断（近似）。
extends Node2D

const ConfigLoaderScript = preload("res://logic/config_loader.gd")
const MatchScript = preload("res://logic/match.gd")
const UnitScript = preload("res://logic/unit.gd")
const BattleScript = preload("res://logic/battle.gd")
const AIControllerScript = preload("res://ai/ai_controller.gd")
const GameStateScript = preload("res://view/game_state.gd")

const LANE_TOP := 240.0       # progress 1 = 敌方塔
const LANE_BOTTOM := 940.0    # progress 0 = 己方塔
const LANE_XS := [160.0, 360.0, 560.0]   # lane 0 左 / 1 中 / 2 右 的列中心 x
const LANE_HALF_W := 70.0     # 每条 lane 列半宽（用于画道与判定点击归属）
const DEPLOY_MAX := 0.5       # 落点限己方半场

const COL_PLAYER := Color(0.35, 0.55, 1.0)
const COL_OPPONENT := Color(1.0, 0.42, 0.38)

# V2-5b HUD 美化配色（仅显示层）
const COL_ELIXIR := Color(0.80, 0.33, 0.96)          # 圣水紫
const COL_CARD_BG := Color(0.20, 0.24, 0.30)         # 卡面底
const COL_CARD_BORDER := Color(0.45, 0.52, 0.60)     # 卡面描边
const COL_SELECT := Color(1.0, 0.86, 0.30)           # 选中高亮（金）
const COL_HUD_PANEL := Color(0.05, 0.07, 0.06, 0.85) # 顶/底信息条底

# 程序化换皮（V2-3，仅显示层）：每个兵种一套形状+尺寸，队伍色仍区分敌我。
# 阵营色作主体填充→看色辨敌我；形状/大小→看形辨兵种；朝向按推进方向翻转。
const UNIT_VIS := {
	"giant_body":  {"shape": "octagon",  "size": 24.0},   # 巨人：最大八边形
	"knight_body": {"shape": "shield",   "size": 16.0},   # 骑士：盾形
	"archer_body": {"shape": "circle",   "size": 12.0},   # 弓箭手：小圆（远程）
	"goblin_body": {"shape": "triangle", "size": 12.0},   # 哥布林：小尖三角（快）
	"minion_body": {"shape": "diamond",  "size": 13.0},   # 亡灵：菱形 + 翅膀（空中）
}

# V2-4 动画参数（仅显示层时长/像素量）
const RANGED_THRESHOLD := 0.15   # attack_range ≥ 此值视为远程 → 走投射物（仅弓箭手 0.25）
const FLASH_TIME := 0.18         # 受击闪白时长
const LUNGE_TIME := 0.16         # 攻击顶刺时长
const LUNGE_DIST := 9.0          # 攻击顶刺像素位移
const DEATH_TIME := 0.35         # 死亡消散时长
const PROJECTILE_SPEED := 1300.0 # 投射物像素/秒（按距离折算飞行时长）
const TOWER_FLASH_TIME := 0.20   # 塔受击火花节流间隔
const TOWER_SHAKE_TIME := 0.18   # 塔受击抖动时长

const LOG_EVENTS := true      # 运行期把战局事件打到 Output 面板（仅显示层，不入逻辑/单测）

var match_obj
var selected_card := -1
var _ai_diff := "normal"   # 本局 AI 难度（来自难度选择界面），仅显示/接线用

var _result_logged := false
var _tower_hit := {}          # tower -> true（首次受伤已记）
var _tower_down := {}         # tower -> true（摧毁已记）

var unit_layer: Node2D
var fx_layer: Node2D          # 投射物/爆点/碎块（盖在单位与塔之上）
var unit_views := {}          # unit -> rec{node,gfx,body,team,gfx_base,last_hp,beat,lunge,lunge_dir,flash}
var dying_units := []         # 已从逻辑消失、正在播死亡动画的 rec（rec 另带 death 计时）
var projectiles := []         # [{node,from,to,t,dur}]
var effects := []             # [{node,t,dur,expand?,from_scale,to_scale,fade?,vel?,gravity,spin?}]
var _ai_aoe_cd := 0.0         # AI 法术爆点推断节流
var tower_bars := []          # [{tower, fill, full_w, fill_h, body, name, base_pos, last_hp, flash, shake, down}]
var card_slots := []          # [{btn(Button), cost(Label), frame(Panel)}]
var elixir_fill: ColorRect
var elixir_full_w := 0.0
var elixir_label: Label
var time_label: Label
var crown_player_label: Label
var crown_opp_label: Label
var result_layer: Control
var result_title: Label
var result_score: Label

func _ready() -> void:
	var loader = ConfigLoaderScript.new()
	loader.load_all()
	match_obj = MatchScript.new(loader)
	match_obj.setup("level_01")
	_ai_diff = GameStateScript.ai_difficulty
	match_obj.set_opponent_controller(AIControllerScript.new(match_obj, loader, _ai_diff))  # 接入规则 AI（玩家所选难度）
	_build_field()
	unit_layer = Node2D.new()
	add_child(unit_layer)
	_build_towers()
	fx_layer = Node2D.new()
	add_child(fx_layer)
	_build_hud()
	_log("MATCH START  level_01 | 3 lane | AI=%s" % _ai_diff)

func _process(delta: float) -> void:
	if match_obj == null:
		return
	match_obj.update(delta)
	_sync_units(delta)
	_sync_towers(delta)
	_sync_hud()
	_sync_result()
	_update_projectiles(delta)
	_update_effects(delta)
	_update_dying(delta)

# ---------- 坐标映射（仅显示层） ----------
func _progress_to_y(p: float) -> float:
	return lerpf(LANE_BOTTOM, LANE_TOP, clampf(p, 0.0, 1.0))

func _y_to_progress(y: float) -> float:
	return clampf((LANE_BOTTOM - y) / (LANE_BOTTOM - LANE_TOP), 0.0, 1.0)

# lane 上某点的屏幕坐标（带阵营左右微偏移，与 _sync_units 摆位一致）
func _unit_screen_pos(lane_index: int, progress: float, owner_id: int) -> Vector2:
	var off: float = 12.0 if owner_id == UnitScript.OWNER_PLAYER else -12.0
	return Vector2(LANE_XS[lane_index] + off, _progress_to_y(progress))

# lane 列中心某 progress 的屏幕坐标（落点/爆点用，无阵营偏移）
func _deploy_screen_pos(lane_index: int, progress: float) -> Vector2:
	return Vector2(LANE_XS[lane_index], _progress_to_y(progress))

# 单位推进方向尽头（敌塔所在端）的屏幕坐标
func _lane_end_pos(lane_index: int, forward: bool) -> Vector2:
	return Vector2(LANE_XS[lane_index], LANE_TOP if forward else LANE_BOTTOM)

func _team_color(u) -> Color:
	return COL_PLAYER if u.owner_id == UnitScript.OWNER_PLAYER else COL_OPPONENT

# ---------- 建场景 ----------
func _rect(color: Color, pos: Vector2, size: Vector2) -> ColorRect:
	var r := ColorRect.new()
	r.color = color
	r.position = pos
	r.size = size
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(r)
	return r

func _label(text: String, pos: Vector2, font_size: int = 24, color: Color = Color.WHITE) -> Label:
	var l := Label.new()
	l.text = text
	l.position = pos
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)
	return l

# 圆角填充样式（卡面 / 徽章 / 按钮通用）
func _sbflat(bg: Color, radius: float, border_w: float = 0.0, border_col: Color = Color(0, 0, 0, 0)) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(int(radius))
	if border_w > 0.0:
		sb.set_border_width_all(int(border_w))
		sb.border_color = border_col
	return sb

# 给按钮套一组 normal/hover/pressed 样式
func _style_button(btn: Button, bg: Color, border: Color) -> void:
	btn.add_theme_stylebox_override("normal", _sbflat(bg, 8, 2, border))
	btn.add_theme_stylebox_override("hover", _sbflat(bg.lightened(0.12), 8, 2, border))
	btn.add_theme_stylebox_override("pressed", _sbflat(bg.darkened(0.12), 8, 2, border))
	btn.add_theme_color_override("font_color", Color(0.96, 0.97, 0.98))

# 血条颜色：>50% 绿、25~50% 橙、<25% 红
func _hp_color(ratio: float) -> Color:
	if ratio <= 0.25:
		return Color(0.95, 0.30, 0.25)
	if ratio <= 0.5:
		return Color(0.97, 0.75, 0.20)
	return Color(0.30, 0.90, 0.30)

func _build_field() -> void:
	_rect(Color(0.09, 0.12, 0.10, 1.0), Vector2(0, 0), Vector2(720, 1280))   # 草绿底
	var mid_y := _progress_to_y(DEPLOY_MAX)
	# 敌/我半场淡色分区（整屏）
	_rect(Color(0.55, 0.30, 0.28, 0.10), Vector2(0, LANE_TOP - 60), Vector2(720, mid_y - (LANE_TOP - 60)))   # 敌方半场淡红
	_rect(Color(0.28, 0.40, 0.62, 0.10), Vector2(0, mid_y), Vector2(720, (LANE_BOTTOM + 60) - mid_y))         # 己方半场淡蓝
	# 三条 lane 通道
	for lx in LANE_XS:
		var x0: float = lx - LANE_HALF_W
		_rect(Color(0.18, 0.22, 0.18, 1.0), Vector2(x0, LANE_TOP - 40), Vector2(LANE_HALF_W * 2.0, (LANE_BOTTOM - LANE_TOP) + 80))
		_rect(Color(0, 0, 0, 0.18), Vector2(x0, LANE_TOP - 40), Vector2(3, (LANE_BOTTOM - LANE_TOP) + 80))                            # 通道左描边
		_rect(Color(0, 0, 0, 0.18), Vector2(x0 + LANE_HALF_W * 2.0 - 3, LANE_TOP - 40), Vector2(3, (LANE_BOTTOM - LANE_TOP) + 80))    # 右描边
	# 河（横贯中线）+ 每条 lane 一段木桥（部署分界线的视觉化）
	_rect(Color(0.16, 0.42, 0.62, 0.85), Vector2(0, mid_y - 16), Vector2(720, 32))
	for lx in LANE_XS:
		_rect(Color(0.45, 0.34, 0.22, 1.0), Vector2(lx - LANE_HALF_W * 0.75, mid_y - 19), Vector2(LANE_HALF_W * 1.5, 38))   # 桥面
		_rect(Color(0.30, 0.22, 0.14, 1.0), Vector2(lx - LANE_HALF_W * 0.75, mid_y - 19), Vector2(LANE_HALF_W * 1.5, 3))     # 桥沿

# towers 数组顺序（build_v2_three_lanes）：[0]=王塔(中) [1]=左公主 [2]=右公主。
func _build_towers() -> void:
	var b = match_obj.battle
	_add_tower(b.opponent_towers[0], Vector2(LANE_XS[1], LANE_TOP), COL_OPPONENT, 46.0, "王塔(中)")
	_add_tower(b.opponent_towers[1], Vector2(LANE_XS[0], LANE_TOP), COL_OPPONENT, 34.0, "公主(左)")
	_add_tower(b.opponent_towers[2], Vector2(LANE_XS[2], LANE_TOP), COL_OPPONENT, 34.0, "公主(右)")
	_add_tower(b.player_towers[0], Vector2(LANE_XS[1], LANE_BOTTOM), COL_PLAYER, 46.0, "王塔(中)")
	_add_tower(b.player_towers[1], Vector2(LANE_XS[0], LANE_BOTTOM), COL_PLAYER, 34.0, "公主(左)")
	_add_tower(b.player_towers[2], Vector2(LANE_XS[2], LANE_BOTTOM), COL_PLAYER, 34.0, "公主(右)")

# 塔=方形塔身；王塔顶部城垛（3 块），公主塔尖顶。队伍色填充。
func _add_tower(tower, pos: Vector2, color: Color, s: float, tname: String = "") -> void:
	var root := Node2D.new()
	root.position = pos
	add_child(root)
	# 轮廓（略大，垫底）
	var ol := Polygon2D.new()
	ol.polygon = PackedVector2Array([Vector2(-s * 0.95, -s * 0.45), Vector2(s * 0.95, -s * 0.45), Vector2(s * 0.95, s * 1.05), Vector2(-s * 0.95, s * 1.05)])
	ol.color = color.darkened(0.55)
	root.add_child(ol)
	# 塔身
	var base := Polygon2D.new()
	base.polygon = PackedVector2Array([Vector2(-s * 0.8, -s * 0.3), Vector2(s * 0.8, -s * 0.3), Vector2(s * 0.8, s), Vector2(-s * 0.8, s)])
	base.color = color
	root.add_child(base)
	if tower.is_king():
		for k in 3:                                                  # 城垛
			var bx := -s * 0.55 + k * s * 0.55
			var cren := Polygon2D.new()
			cren.polygon = PackedVector2Array([Vector2(bx - s * 0.16, -s * 0.62), Vector2(bx + s * 0.16, -s * 0.62), Vector2(bx + s * 0.16, -s * 0.3), Vector2(bx - s * 0.16, -s * 0.3)])
			cren.color = color
			root.add_child(cren)
	else:
		var roof := Polygon2D.new()                                  # 尖顶
		roof.polygon = PackedVector2Array([Vector2(-s * 0.85, -s * 0.3), Vector2(s * 0.85, -s * 0.3), Vector2(0, -s * 0.95)])
		roof.color = color.lightened(0.12)
		root.add_child(roof)
	var bar_w := s * 2.2
	var bar_h := 10.0
	var bxp := pos.x - bar_w / 2.0
	var byp := pos.y - s - 20.0
	_rect(Color(0, 0, 0, 0.75), Vector2(bxp - 2, byp - 2), Vector2(bar_w + 4, bar_h + 4))   # 外框
	_rect(Color(0.10, 0.10, 0.10, 0.9), Vector2(bxp, byp), Vector2(bar_w, bar_h))            # 槽底
	var fill := _rect(Color(0.3, 0.9, 0.3), Vector2(bxp, byp), Vector2(bar_w, bar_h))
	tower_bars.append({
		"tower": tower, "fill": fill, "full_w": bar_w, "fill_h": bar_h, "body": root, "name": tname,
		"base_pos": pos, "last_hp": float(tower.hp), "flash": 0.0, "shake": 0.0, "down": false,
	})

func _build_hud() -> void:
	_build_topbar()
	_build_elixir()
	_build_cards()
	_build_result_panel()

# 顶部信息条：剩余时间（中）+ 王冠数（左=我方拆敌塔数 / 右=敌方拆我塔数）。
func _build_topbar() -> void:
	_rect(COL_HUD_PANEL, Vector2(0, 8), Vector2(720, 48))
	crown_player_label = _label("YOU  0", Vector2(24, 16), 26, COL_PLAYER)
	time_label = _label("0:00", Vector2(0, 14), 30, Color(1, 1, 1))
	time_label.size = Vector2(720, 34)
	time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	crown_opp_label = _label("0  ENEMY", Vector2(0, 16), 26, COL_OPPONENT)
	crown_opp_label.size = Vector2(696, 30)
	crown_opp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var diff_lbl := _label("AI: %s" % _ai_diff.to_upper(), Vector2(0, 60), 18, Color(0.72, 0.78, 0.72))
	diff_lbl.size = Vector2(720, 24)
	diff_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

# 圣水条：分段刻度 + 左侧圆形数字徽章。
func _build_elixir() -> void:
	var ex := 24.0
	var ey := 958.0
	var bx := ex + 56.0                       # 条体起点（左侧数字徽章右边）
	var ew := 720.0 - ex - bx                 # 条体宽
	elixir_full_w = ew
	_rect(Color(0, 0, 0, 0.55), Vector2(bx - 3, ey - 3), Vector2(ew + 6, 34))   # 外框
	_rect(Color(0.14, 0.10, 0.16, 1.0), Vector2(bx, ey), Vector2(ew, 28))       # 槽底
	elixir_fill = _rect(COL_ELIXIR, Vector2(bx, ey), Vector2(0, 28))
	var emax: int = int(match_obj.player.elixir.maximum)
	for i in range(1, emax):                  # 段位刻度
		var sx: float = bx + ew * float(i) / float(emax)
		_rect(Color(0, 0, 0, 0.45), Vector2(sx - 1, ey), Vector2(2, 28))
	var badge := Panel.new()                  # 左侧圆形数字徽章
	badge.position = Vector2(ex, ey - 8)
	badge.size = Vector2(44, 44)
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.add_theme_stylebox_override("panel", _sbflat(COL_ELIXIR, 22, 3, Color(0, 0, 0, 0.5)))
	add_child(badge)
	elixir_label = Label.new()
	elixir_label.size = Vector2(44, 44)
	elixir_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	elixir_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	elixir_label.add_theme_font_size_override("font_size", 26)
	elixir_label.add_theme_color_override("font_color", Color(1, 1, 1))
	elixir_label.text = "0"
	elixir_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.add_child(elixir_label)

# 手牌卡面：圆角卡 + 左上角费用徽章 + 选中金框；不可出牌走 disabled 灰样式。
func _build_cards() -> void:
	var n := 4
	var gap := 14.0
	var bw := (720.0 - gap * (n + 1)) / float(n)
	var bh := 196.0
	var by := 1004.0
	for i in n:
		var btn := Button.new()
		btn.position = Vector2(gap + i * (bw + gap), by)
		btn.size = Vector2(bw, bh)
		btn.focus_mode = Control.FOCUS_NONE
		btn.clip_text = true
		btn.add_theme_font_size_override("font_size", 22)
		btn.add_theme_color_override("font_color", Color(0.95, 0.96, 0.98))
		btn.add_theme_color_override("font_disabled_color", Color(0.55, 0.58, 0.62))
		btn.add_theme_stylebox_override("normal", _sbflat(COL_CARD_BG, 10, 2, COL_CARD_BORDER))
		btn.add_theme_stylebox_override("hover", _sbflat(COL_CARD_BG.lightened(0.12), 10, 2, COL_CARD_BORDER))
		btn.add_theme_stylebox_override("pressed", _sbflat(COL_CARD_BG.lightened(0.2), 10, 2, COL_SELECT))
		btn.add_theme_stylebox_override("disabled", _sbflat(COL_CARD_BG.darkened(0.45), 10, 2, COL_CARD_BORDER.darkened(0.4)))
		btn.pressed.connect(_on_card_pressed.bind(i))
		add_child(btn)
		var badge := Panel.new()              # 费用徽章
		badge.position = Vector2(6, 6)
		badge.size = Vector2(40, 40)
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		badge.add_theme_stylebox_override("panel", _sbflat(COL_ELIXIR, 20, 2, Color(0, 0, 0, 0.5)))
		btn.add_child(badge)
		var cost_lbl := Label.new()
		cost_lbl.size = Vector2(40, 40)
		cost_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cost_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		cost_lbl.add_theme_font_size_override("font_size", 22)
		cost_lbl.add_theme_color_override("font_color", Color(1, 1, 1))
		cost_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		badge.add_child(cost_lbl)
		var frame := Panel.new()              # 选中金框
		frame.size = Vector2(bw, bh)
		frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
		frame.add_theme_stylebox_override("panel", _sbflat(Color(0, 0, 0, 0), 10, 5, COL_SELECT))
		frame.visible = false
		btn.add_child(frame)
		card_slots.append({"btn": btn, "cost": cost_lbl, "frame": frame})

# ---------- 每帧同步 ----------
func _sync_units(delta: float) -> void:
	var live := {}
	var player_hits := {}   # AI 法术推断：本帧掉血的玩家单位 lane -> [progress...]
	for li in range(LANE_XS.size()):
		var lane = match_obj.battle.get_lane(li)
		if lane == null:
			continue
		var lane_units: Array = lane.get_units()
		for u in lane_units:
			live[u] = true
			var off: float = 12.0 if u.owner_id == UnitScript.OWNER_PLAYER else -12.0
			var target := Vector2(LANE_XS[li] + off, _progress_to_y(u.progress))
			if not unit_views.has(u):
				var parts := _make_unit_node(u)
				var node0: Node2D = parts["node"]
				node0.position = target
				unit_layer.add_child(node0)
				unit_views[u] = {
					"node": node0, "gfx": parts["gfx"], "body": parts["body"],
					"team": _team_color(u), "gfx_base": (parts["gfx"] as Node2D).position,
					"last_hp": float(u.hp), "beat": float(u.attack_speed),
					"lunge": 0.0, "lunge_dir": Vector2.ZERO, "flash": 0.0,
				}
				_log("SPAWN %s %s lane%d p=%.2f" % [_side(u.owner_id), u.unit_id, li, u.progress])
			else:
				var rec = unit_views[u]
				var node: Node2D = rec["node"]
				node.position = node.position.lerp(target, minf(delta * 12.0, 1.0))
				# 受击：血量下降 → 闪白；玩家单位掉血点记下供 AI 法术推断
				if float(u.hp) < float(rec["last_hp"]) - 0.001:
					rec["flash"] = FLASH_TIME
					if u.owner_id == UnitScript.OWNER_PLAYER:
						if not player_hits.has(li):
							player_hits[li] = []
						player_hits[li].append(float(u.progress))
				rec["last_hp"] = float(u.hp)
				# 攻击节拍：交战中按 attack_speed 顶刺/投射（与逻辑同尺度，受击闪白才是真伤判定）
				var tinfo = _view_find_target(u, lane_units, li)
				if tinfo != null and float(u.damage) > 0.0:
					rec["beat"] = float(rec["beat"]) + delta
					if float(rec["beat"]) >= float(u.attack_speed):
						rec["beat"] = 0.0
						var from_pos: Vector2 = node.position
						var to_pos: Vector2 = tinfo["pos"]
						rec["lunge"] = LUNGE_TIME
						rec["lunge_dir"] = (to_pos - from_pos).normalized()
						if float(u.attack_range) >= RANGED_THRESHOLD:
							_spawn_projectile(from_pos, to_pos, rec["team"])
				else:
					rec["beat"] = float(u.attack_speed)   # 未接敌 → 预热，接敌当帧即出手
				_apply_unit_anim(rec, delta)
	# 死亡：从 live 消失 → 进入消亡动画（先冒一缕烟）
	for u in unit_views.keys():
		if not live.has(u):
			var rec = unit_views[u]
			_log("DEATH %s %s lane%d p=%.2f" % [_side(u.owner_id), u.unit_id, u.lane_index, u.progress])
			rec["death"] = DEATH_TIME
			var n: Node2D = rec["node"]
			_spawn_poof(n.position, rec["team"])
			dying_units.append(rec)
			unit_views.erase(u)
	# AI 法术爆点推断（近似，路线 A）：同帧某 lane ≥2 个玩家单位掉血且聚集 → 一次爆炸
	if _ai_aoe_cd > 0.0:
		_ai_aoe_cd = maxf(_ai_aoe_cd - delta, 0.0)
	for li in player_hits.keys():
		var ps: Array = player_hits[li]
		if ps.size() >= 2 and _ai_aoe_cd <= 0.0:
			var mn: float = float(ps.min())
			var mx: float = float(ps.max())
			if mx - mn <= 0.25:
				var c: float = (mn + mx) * 0.5
				_spawn_explosion(_deploy_screen_pos(li, c), 64.0, Color(1.0, 0.5, 0.15))
				_ai_aoe_cd = 0.5

# 攻击/投射物的目标选择：复刻 Lane._find_enemy_in_range（范围内最近敌方单位），
# 无单位则看尽头敌塔是否在攻击范围内。返回 {pos} 或 null。
func _view_find_target(u, lane_units: Array, lane_index: int):
	var best = null
	var best_d := INF
	for o in lane_units:
		if o == u or not o.is_alive() or o.owner_id == u.owner_id:
			continue
		var d: float = absf(float(o.progress) - float(u.progress))
		if d <= float(u.attack_range) + 0.000001 and d < best_d:
			best = o
			best_d = d
	if best != null:
		return {"pos": _unit_screen_pos(lane_index, best.progress, best.owner_id)}
	var forward: bool = u.get_direction() > 0
	var end_p: float = 1.0 if forward else 0.0
	if absf(end_p - float(u.progress)) <= float(u.attack_range) + 0.000001:
		return {"pos": _lane_end_pos(lane_index, forward)}
	return null

func _apply_unit_anim(rec, delta: float) -> void:
	var gfx: Node2D = rec["gfx"]
	var body: Polygon2D = rec["body"]
	var team: Color = rec["team"]
	# 受击：主体趋白 + 轻微放大（modulate>1 在 Compatibility 不一定提亮，故用颜色 lerp）
	if float(rec["flash"]) > 0.0:
		rec["flash"] = maxf(float(rec["flash"]) - delta, 0.0)
	var fr: float = float(rec["flash"]) / FLASH_TIME
	body.color = team.lerp(Color(1, 1, 1), 0.85 * fr)
	# 攻击：gfx 朝目标方向顶出再回落
	if float(rec["lunge"]) > 0.0:
		rec["lunge"] = maxf(float(rec["lunge"]) - delta, 0.0)
	var lr: float = float(rec["lunge"]) / LUNGE_TIME
	var dir: Vector2 = rec["lunge_dir"]
	var base: Vector2 = rec["gfx_base"]
	gfx.position = base + dir * (LUNGE_DIST * lr)
	gfx.scale = Vector2.ONE * (1.0 + 0.18 * fr)

func _make_unit_node(u) -> Dictionary:
	var root := Node2D.new()
	var is_player: bool = u.owner_id == UnitScript.OWNER_PLAYER
	var team: Color = COL_PLAYER if is_player else COL_OPPONENT
	var vis: Dictionary = UNIT_VIS.get(u.unit_id, {"shape": "circle", "size": 14.0})
	var s: float = float(vis["size"])
	var is_air: bool = str(u.target_type) == "air"

	# 空中单位：地面留阴影，机体抬高（一眼区分地空）
	if is_air:
		var shadow := Polygon2D.new()
		shadow.polygon = _circle_points(s * 0.55, 12)
		shadow.color = Color(0, 0, 0, 0.22)
		shadow.position = Vector2(0, s * 0.95)
		root.add_child(shadow)

	var gfx := Node2D.new()
	if is_air:
		gfx.position = Vector2(0, -s * 0.5)
	root.add_child(gfx)

	var pts := _unit_shape(str(vis["shape"]), s)
	if not is_player:
		pts = _flip_y(pts)                                          # 对手朝向翻转（向下推进）

	if u.unit_id == "minion_body":                                  # 亡灵翅膀
		for sx in [-1.0, 1.0]:
			var wing := Polygon2D.new()
			wing.polygon = PackedVector2Array([Vector2(sx * s * 0.5, -s * 0.35), Vector2(sx * s * 1.25, -s * 0.05), Vector2(sx * s * 0.5, s * 0.35)])
			wing.color = team.lightened(0.25)
			gfx.add_child(wing)

	var outline := Polygon2D.new()                                  # 描边
	outline.polygon = _scale_pts(pts, 1.2)
	outline.color = team.darkened(0.55)
	gfx.add_child(outline)

	var body := Polygon2D.new()                                     # 主体（队伍色）
	body.polygon = pts
	body.color = team
	gfx.add_child(body)

	if u.unit_id == "giant_body":                                   # 巨人内圈铠甲
		var core := Polygon2D.new()
		core.polygon = _scale_pts(pts, 0.5)
		core.color = team.darkened(0.3)
		gfx.add_child(core)
	elif u.unit_id == "archer_body":                                # 弓箭手远程标记
		var dot := Polygon2D.new()
		dot.polygon = _circle_points(s * 0.32, 8)
		dot.color = Color(1, 1, 1, 0.85)
		gfx.add_child(dot)
	return {"node": root, "gfx": gfx, "body": body}

# 兵种基础形状（apex 朝上 -y；朝向由调用方按阵营翻转）。
func _unit_shape(shape: String, s: float) -> PackedVector2Array:
	match shape:
		"octagon":
			var p := PackedVector2Array()
			for i in 8:
				var a := PI / 8.0 + TAU * float(i) / 8.0
				p.append(Vector2(cos(a), sin(a)) * s)
			return p
		"shield":
			return PackedVector2Array([Vector2(-s, -s), Vector2(s, -s), Vector2(s, s * 0.4), Vector2(0, s * 1.15), Vector2(-s, s * 0.4)])
		"triangle":
			return PackedVector2Array([Vector2(0, -s * 1.1), Vector2(s, s * 0.8), Vector2(-s, s * 0.8)])
		"diamond":
			return PackedVector2Array([Vector2(0, -s), Vector2(s * 0.75, 0), Vector2(0, s), Vector2(-s * 0.75, 0)])
		_:
			return _circle_points(s, 16)

func _flip_y(pts: PackedVector2Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in pts:
		out.append(Vector2(p.x, -p.y))
	return out

func _scale_pts(pts: PackedVector2Array, k: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in pts:
		out.append(p * k)
	return out

func _circle_points(r: float, n: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n:
		var a := TAU * float(i) / float(n)
		pts.append(Vector2(cos(a), sin(a)) * r)
	return pts

func _sync_towers(delta: float) -> void:
	for t in tower_bars:
		var tower = t["tower"]
		var ratio: float = (float(tower.hp) / float(tower.max_hp)) if tower.max_hp > 0.0 else 0.0
		t["fill"].size = Vector2(t["full_w"] * clampf(ratio, 0.0, 1.0), t["fill_h"])
		t["fill"].color = _hp_color(ratio)
		# 受击：掉血 → 抖动 + 白色火花（按 flash 节流，避免每 tick 刷屏）
		if float(tower.hp) < float(t["last_hp"]) - 0.001:
			t["shake"] = TOWER_SHAKE_TIME
			if float(t["flash"]) <= 0.0:
				t["flash"] = TOWER_FLASH_TIME
				var bp: Vector2 = t["base_pos"]
				_spawn_poof(Vector2(bp.x, bp.y - 10.0), Color(1, 1, 1))
		t["last_hp"] = float(tower.hp)
		if float(t["flash"]) > 0.0:
			t["flash"] = maxf(float(t["flash"]) - delta, 0.0)
		if not _tower_hit.has(tower) and tower.hp < tower.max_hp and not tower.is_destroyed():
			_tower_hit[tower] = true
			_log("TOWER HIT  %s %s (hp %d/%d)" % [_side(tower.owner_id), t["name"], int(tower.hp), int(tower.max_hp)])
		# 摧毁瞬间：碎块爆裂 + 大抖动 + 置灰
		if tower.is_destroyed() and not t["down"]:
			t["down"] = true
			var t_color: Color = COL_PLAYER if tower.owner_id == UnitScript.OWNER_PLAYER else COL_OPPONENT
			_spawn_debris(t["base_pos"], t_color)
			t["shake"] = TOWER_SHAKE_TIME * 1.6
			_log("TOWER DOWN %s %s" % [_side(tower.owner_id), t["name"]])
		# 应用抖动 / 置灰
		var body: Node2D = t["body"]
		var base_pos: Vector2 = t["base_pos"]
		if float(t["shake"]) > 0.0:
			t["shake"] = maxf(float(t["shake"]) - delta, 0.0)
			var k: float = float(t["shake"]) / TOWER_SHAKE_TIME
			body.position = base_pos + Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * 5.0 * k
		else:
			body.position = base_pos
		if tower.is_destroyed():
			body.modulate = Color(0.4, 0.4, 0.4)

func _sync_hud() -> void:
	var p = match_obj.player
	var b = match_obj.battle
	# 圣水
	var emax: float = float(p.elixir.maximum)
	elixir_fill.size = Vector2(elixir_full_w * clampf(p.elixir.get_amount() / emax, 0.0, 1.0), 28)
	elixir_label.text = str(p.elixir.get_int())
	# 手牌卡面
	var hand = p.deck.get_hand()
	for i in card_slots.size():
		var slot = card_slots[i]
		var btn: Button = slot["btn"]
		var cost_lbl: Label = slot["cost"]
		var frame: Panel = slot["frame"]
		if i < hand.size() and hand[i] != null:
			var cid := str(hand[i])
			btn.text = cid
			cost_lbl.text = str(p.card_cost(cid))
			btn.disabled = not p.can_play(i)
			frame.visible = (i == selected_card)
		else:
			btn.text = ""
			cost_lbl.text = ""
			btn.disabled = true
			frame.visible = false
	# 顶部信息条：剩余时间 + 王冠数（拆塔数）
	var rem: float = b.remaining_time()
	time_label.text = "%d:%02d" % [int(rem) / 60, int(rem) % 60]
	var pc := 0
	for t in b.opponent_towers:
		if t.is_destroyed():
			pc += 1
	var oc := 0
	for t in b.player_towers:
		if t.is_destroyed():
			oc += 1
	crown_player_label.text = "YOU  %d" % pc
	crown_opp_label.text = "%d  ENEMY" % oc

# 结算面板（V2-5a 场景闭环骨架）：胜负标题 + 双方剩余塔血 + REMATCH / MENU。
# 覆盖全屏 Control 并拦截点击——对局结束后只允许点这两个按钮。建于 _build_hud（隐藏），结束时显示。
func _build_result_panel() -> void:
	result_layer = Control.new()
	result_layer.position = Vector2.ZERO
	result_layer.size = Vector2(720, 1280)
	result_layer.mouse_filter = Control.MOUSE_FILTER_STOP
	result_layer.visible = false
	add_child(result_layer)
	var backdrop := ColorRect.new()
	backdrop.color = Color(0, 0, 0, 0.62)
	backdrop.size = Vector2(720, 1280)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	result_layer.add_child(backdrop)
	var pw := 520.0
	var ph := 420.0
	var px := (720.0 - pw) / 2.0
	var py := (1280.0 - ph) / 2.0
	var border := ColorRect.new()
	border.color = Color(0.85, 0.85, 0.5)
	border.position = Vector2(px - 4, py - 4)
	border.size = Vector2(pw + 8, ph + 8)
	border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	result_layer.add_child(border)
	var panel := ColorRect.new()
	panel.color = Color(0.12, 0.15, 0.13, 1.0)
	panel.position = Vector2(px, py)
	panel.size = Vector2(pw, ph)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	result_layer.add_child(panel)
	result_title = Label.new()
	result_title.position = Vector2(px, py + 44)
	result_title.size = Vector2(pw, 80)
	result_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_title.add_theme_font_size_override("font_size", 64)
	result_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	result_layer.add_child(result_title)
	result_score = Label.new()
	result_score.position = Vector2(px, py + 158)
	result_score.size = Vector2(pw, 36)
	result_score.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_score.add_theme_font_size_override("font_size", 26)
	result_score.add_theme_color_override("font_color", Color(0.85, 0.9, 0.85))
	result_score.mouse_filter = Control.MOUSE_FILTER_IGNORE
	result_layer.add_child(result_score)
	var bw := 200.0
	var bh := 72.0
	var gap := 40.0
	var bx := px + (pw - bw * 2.0 - gap) / 2.0
	var by := py + ph - bh - 40.0
	var rematch := Button.new()
	rematch.text = "REMATCH"
	rematch.position = Vector2(bx, by)
	rematch.size = Vector2(bw, bh)
	rematch.focus_mode = Control.FOCUS_NONE
	rematch.add_theme_font_size_override("font_size", 28)
	_style_button(rematch, Color(0.18, 0.42, 0.26), Color(0.45, 0.85, 0.55))
	rematch.pressed.connect(_on_rematch_pressed)
	result_layer.add_child(rematch)
	var menu := Button.new()
	menu.text = "MENU"
	menu.position = Vector2(bx + bw + gap, by)
	menu.size = Vector2(bw, bh)
	menu.focus_mode = Control.FOCUS_NONE
	menu.add_theme_font_size_override("font_size", 28)
	_style_button(menu, Color(0.24, 0.28, 0.34), Color(0.5, 0.56, 0.64))
	menu.pressed.connect(_on_menu_pressed)
	result_layer.add_child(menu)

func _on_rematch_pressed() -> void:
	get_tree().reload_current_scene()   # 重载 battle_scene → 全新一局

func _on_menu_pressed() -> void:
	get_tree().change_scene_to_file("res://view/main_menu.tscn")

func _sync_result() -> void:
	if not match_obj.is_over() or result_layer.visible:
		return
	var r: int = match_obj.get_result()
	var title := "DRAW"
	var col := Color(1, 1, 0.45)
	if r == BattleScript.RESULT_PLAYER_WIN:
		title = "YOU WIN"
		col = Color(0.5, 1.0, 0.55)
	elif r == BattleScript.RESULT_OPPONENT_WIN:
		title = "YOU LOSE"
		col = Color(1.0, 0.5, 0.5)
	result_title.text = title
	result_title.add_theme_color_override("font_color", col)
	var b = match_obj.battle
	var php: int = int(b.total_tower_hp(b.player_towers))
	var ohp: int = int(b.total_tower_hp(b.opponent_towers))
	result_score.text = "Towers    You %d    Enemy %d" % [php, ohp]
	result_layer.visible = true
	if not _result_logged:
		_result_logged = true
		_log("RESULT %s | 我方塔血=%d 敌方塔血=%d" % [title, php, ohp])

# ---------- 特效层（投射物 / 爆点 / 碎块；仅显示层，逻辑零关联） ----------
# 远程投射物：从 from 飞到 to（快照位置），到达后留一缕命中烟。
func _spawn_projectile(from_pos: Vector2, to_pos: Vector2, color: Color) -> void:
	var dist: float = from_pos.distance_to(to_pos)
	var dur: float = clampf(dist / PROJECTILE_SPEED, 0.06, 0.5)
	var dart := Polygon2D.new()
	dart.polygon = PackedVector2Array([Vector2(0, -6), Vector2(2.5, 5), Vector2(-2.5, 5)])
	dart.color = color.lightened(0.15)
	dart.position = from_pos
	dart.rotation = (to_pos - from_pos).angle() + PI / 2.0
	fx_layer.add_child(dart)
	projectiles.append({"node": dart, "from": from_pos, "to": to_pos, "t": 0.0, "dur": dur})

func _update_projectiles(delta: float) -> void:
	for i in range(projectiles.size() - 1, -1, -1):
		var pr = projectiles[i]
		pr["t"] = float(pr["t"]) + delta
		var r: float = clampf(float(pr["t"]) / float(pr["dur"]), 0.0, 1.0)
		var node: Node2D = pr["node"]
		node.position = (pr["from"] as Vector2).lerp(pr["to"], r)
		if float(pr["t"]) >= float(pr["dur"]):
			_spawn_poof(pr["to"], Color(1, 1, 1))
			node.queue_free()
			projectiles.remove_at(i)

# 爆炸：外圈彩盘 + 亮核，扩张并淡出（火球 / AI 法术推断 / zap 复用）。
func _spawn_explosion(pos: Vector2, max_r: float, color: Color) -> void:
	var disc := Polygon2D.new()
	disc.polygon = _circle_points(max_r, 22)
	disc.color = color
	disc.position = pos
	disc.scale = Vector2.ONE * 0.25
	fx_layer.add_child(disc)
	effects.append({"node": disc, "t": 0.0, "dur": 0.35, "expand": true, "from_scale": 0.25, "to_scale": 1.0, "fade": true})
	var core := Polygon2D.new()
	core.polygon = _circle_points(max_r * 0.5, 16)
	core.color = Color(1, 0.95, 0.7)
	core.position = pos
	core.scale = Vector2.ONE * 0.2
	fx_layer.add_child(core)
	effects.append({"node": core, "t": 0.0, "dur": 0.22, "expand": true, "from_scale": 0.2, "to_scale": 1.0, "fade": true})

# 小烟：命中/死亡的轻量反馈。
func _spawn_poof(pos: Vector2, color: Color) -> void:
	var p := Polygon2D.new()
	p.polygon = _circle_points(12.0, 14)
	p.color = Color(color.r, color.g, color.b, 0.9)
	p.position = pos
	p.scale = Vector2.ONE * 0.3
	fx_layer.add_child(p)
	effects.append({"node": p, "t": 0.0, "dur": 0.22, "expand": true, "from_scale": 0.3, "to_scale": 1.1, "fade": true})

# 电击：青蓝爆点 + 几道放射火花。
func _spawn_zap(pos: Vector2) -> void:
	_spawn_explosion(pos, 30.0, Color(0.55, 0.85, 1.0))
	for k in 4:
		var spark := Polygon2D.new()
		spark.polygon = PackedVector2Array([Vector2(-2, 0), Vector2(2, 0), Vector2(0, -22)])
		spark.color = Color(0.8, 0.95, 1.0)
		spark.position = pos
		spark.rotation = TAU * float(k) / 4.0 + 0.3
		fx_layer.add_child(spark)
		effects.append({"node": spark, "t": 0.0, "dur": 0.18, "expand": true, "from_scale": 1.0, "to_scale": 1.3, "fade": true})

# 射箭：几支箭自上而下落入目标点 + 落尘。
func _spawn_arrows(pos: Vector2) -> void:
	for k in 5:
		var dx := randf_range(-22.0, 22.0)
		var dart := Polygon2D.new()
		dart.polygon = PackedVector2Array([Vector2(0, -7), Vector2(2, 5), Vector2(-2, 5)])
		dart.color = Color(0.25, 0.2, 0.15)
		dart.position = pos + Vector2(dx, -70.0 - randf_range(0.0, 30.0))
		fx_layer.add_child(dart)
		effects.append({"node": dart, "t": 0.0, "dur": 0.28, "vel": Vector2(0, 320), "gravity": 0.0, "fade": true})
	_spawn_poof(pos, Color(0.6, 0.55, 0.4))

# 碎块：塔摧毁时向上爆裂、受重力下落、淡出。
func _spawn_debris(pos: Vector2, color: Color) -> void:
	for k in 7:
		var hs := randf_range(3.0, 6.0)
		var sq := Polygon2D.new()
		sq.polygon = PackedVector2Array([Vector2(-hs, -hs), Vector2(hs, -hs), Vector2(hs, hs), Vector2(-hs, hs)])
		sq.color = color.darkened(randf_range(0.0, 0.4))
		sq.position = pos + Vector2(randf_range(-12.0, 12.0), randf_range(-18.0, 4.0))
		fx_layer.add_child(sq)
		effects.append({"node": sq, "t": 0.0, "dur": randf_range(0.5, 0.9), "vel": Vector2(randf_range(-140, 140), randf_range(-280, -120)), "gravity": 720.0, "spin": randf_range(-9.0, 9.0), "fade": true})

func _update_effects(delta: float) -> void:
	for i in range(effects.size() - 1, -1, -1):
		var e = effects[i]
		e["t"] = float(e["t"]) + delta
		var node: Node2D = e["node"]
		var r: float = clampf(float(e["t"]) / float(e["dur"]), 0.0, 1.0)
		if e.has("vel"):
			var v: Vector2 = e["vel"]
			node.position += v * delta
			v.y += float(e.get("gravity", 0.0)) * delta
			e["vel"] = v
		if e.get("expand", false):
			node.scale = Vector2.ONE * lerpf(float(e["from_scale"]), float(e["to_scale"]), r)
		if e.has("spin"):
			node.rotation += float(e["spin"]) * delta
		if e.get("fade", false):
			node.modulate.a = 1.0 - r
		if float(e["t"]) >= float(e["dur"]):
			node.queue_free()
			effects.remove_at(i)

func _update_dying(delta: float) -> void:
	for i in range(dying_units.size() - 1, -1, -1):
		var rec = dying_units[i]
		rec["death"] = float(rec["death"]) - delta
		var dr: float = clampf(float(rec["death"]) / DEATH_TIME, 0.0, 1.0)
		var node: Node2D = rec["node"]
		node.scale = Vector2.ONE * (0.25 + 0.75 * dr)
		node.modulate.a = dr
		node.rotation += delta * 7.0
		if float(rec["death"]) <= 0.0:
			node.queue_free()
			dying_units.remove_at(i)

# ---------- 输入：两段式出牌 ----------
func _on_card_pressed(i: int) -> void:
	selected_card = i
	var hand = match_obj.player.deck.get_hand()
	if i >= 0 and i < hand.size() and hand[i] != null:
		_log("SELECT 手牌[%d] %s" % [i, str(hand[i])])

# 点击 x 归属到最近的 lane 列。
func _lane_from_x(x: float) -> int:
	var best := 0
	var best_d := INF
	for i in range(LANE_XS.size()):
		var d: float = absf(x - float(LANE_XS[i]))
		if d < best_d:
			best_d = d
			best = i
	return best

func _unhandled_input(event: InputEvent) -> void:
	if match_obj == null or match_obj.is_over():
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if selected_card < 0:
			return
		var lane_index := _lane_from_x(event.position.x)
		var progress := minf(_y_to_progress(event.position.y), DEPLOY_MAX)
		var p = match_obj.player
		var hand = p.deck.get_hand()
		var cid := str(hand[selected_card]) if selected_card < hand.size() and hand[selected_card] != null else "?"
		var before: int = p.elixir.get_int()
		if p.try_play_card(selected_card, lane_index, progress):
			_log("PLAY  我方 %s → lane%d p=%.2f | 圣水 %d→%d" % [cid, lane_index, progress, before, p.elixir.get_int()])
			_play_spell_fx(cid, lane_index, progress)
			selected_card = -1
		else:
			var reason := "圣水不足" if not p.can_play(selected_card) else "落点非法"
			_log("PLAY  我方 %s → lane%d 被拒(%s)" % [cid, lane_index, reason])

# 玩家法术特效（可靠：直接知道卡/落点）。兵牌无特效（单位自会出现）。
func _play_spell_fx(card_id: String, lane_index: int, progress: float) -> void:
	var card: Dictionary = match_obj.config.get_card(card_id)
	if card.is_empty() or _has_spawn_block(card):
		return
	if _aoe_radius(card) >= 0.0:
		_spawn_explosion(_deploy_screen_pos(lane_index, progress), 72.0, Color(1.0, 0.5, 0.15))   # 火球
		return
	# 直伤：落在「最逼近自己塔的敌方单位」处（与 SkillSystem 选择一致）；无敌则落点处兜底
	var tp = _first_enemy_screen_pos_for(UnitScript.OWNER_PLAYER, lane_index)
	var at: Vector2 = tp if tp != null else _deploy_screen_pos(lane_index, progress)
	if card_id == "zap":
		_spawn_zap(at)
	else:
		_spawn_arrows(at)

func _has_spawn_block(card: Dictionary) -> bool:
	for sk in card.get("skills", []):
		if typeof(sk) == TYPE_DICTIONARY and str(sk.get("type", "")) == "spawn_unit":
			return true
	return false

func _aoe_radius(card: Dictionary) -> float:
	for sk in card.get("skills", []):
		if typeof(sk) == TYPE_DICTIONARY and str(sk.get("type", "")) == "aoe_damage":
			return float(sk.get("radius", 0.0))
	return -1.0

# 最逼近 my_owner 自己塔的敌方单位的屏幕坐标；无则 null。
func _first_enemy_screen_pos_for(my_owner: int, lane_index: int):
	var lane = match_obj.battle.get_lane(lane_index)
	if lane == null:
		return null
	var toward_zero: bool = my_owner == UnitScript.OWNER_PLAYER
	var best = null
	var best_p := 0.0
	for u in lane.get_units():
		if u.owner_id == my_owner or not u.is_alive():
			continue
		var pr := float(u.progress)
		if best == null or (toward_zero and pr < best_p) or (not toward_zero and pr > best_p):
			best = u
			best_p = pr
	if best == null:
		return null
	return _unit_screen_pos(lane_index, best.progress, best.owner_id)

# ---------- 运行期事件日志（仅显示层；逻辑层与 headless 单测不受影响）----------
func _log(msg: String) -> void:
	if not LOG_EVENTS:
		return
	var t := 0.0
	if match_obj != null and match_obj.battle != null:
		t = match_obj.battle.elapsed
	print("[战局 %6.1fs] %s" % [t, msg])

func _side(owner_id: int) -> String:
	return "我方" if owner_id == UnitScript.OWNER_PLAYER else "敌方"
