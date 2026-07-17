extends Node2D
# NetBattleScene —— V4-S3 联机对战场景。
#
# KAN-49（2026-06-28）：把单机 battle_scene 的完整视觉（精灵/地形/juice/FX/HUD/演出/音频）
# 搬进来，替换原矢量白膜。逻辑层零改动（lockstep 跑同一 logic/match.gd，接口同构），
# 纯 view 层搬运 + 联机特有的三处适配：
#   ① match_obj.player → _client.local_player()（side2 本方是 opponent）
#   ② owner/side 翻转：颜色/王冠/胜负/落点 owner/己方半场高亮 按 _flip 处理
#   ③ sim 由 battle_client.poll 驱动，view 不调 update()；顿帧改纯视觉（冻结 _elapsed 增量）
#
# 流程：匿名登录(device_id) → 连 gateway → 等配对 → lockstep 对战 → 结算。
# 渲染只读 _client.match_obj 的逻辑状态作画（与单机 battle_scene 同理念）。
# 本地出兵走 _client.send_deploy（不当场落子，等服务端把指令广播回来两端同 tick 落子）。
# 视角：side 2 整场 180° 翻转，让本方半场永远在屏幕下方（对称体验）。
#
# 0716 PVP 视觉补课：同步单机 battle_scene 的三国正式美术——KAN-107 32×32 正方形屏幕格、
# 整图 BG 特征对齐、三国阵营分色塔（本方蓝/敌方红）、塔+单位 Y-sort 伪深度单通道、
# 单位脚下影/natural 轻染/mirror 朝向、攻击刀光/受击星芒/死亡白烟。屏幕方向语义
# （塔锚点/箭口/镜像判定）统一经 _t2s/_screen_up_tiles，_flip 视角自动正确。
#
# 单机训练营 battle_scene.gd 完全不受影响（这是独立新场景）。

const GameStateScript := preload("res://view/game_state.gd")
const BattleClientScript := preload("res://net/battle_client.gd")
const BattleScript := preload("res://logic/battle.gd")
const SpriteDB := preload("res://view/sprite_db.gd")
const HudWidgets := preload("res://view/ui/hud_widgets.gd")   # V5-S9 双方名片
const ModalScript := preload("res://view/ui/modal.gd")        # F1 弹窗基类（结算层走 UI.modal，修 KAN-98）

const TOPBAR_H := 54.0
const HUD_BOTTOM_H := 176.0
const DROP_LIFT_TILES := 1.6                    # 落点抬到手指上方（拇指不遮挡，CR 式）

# —— 色板（对齐 PixelUI 夜色石板）——
const COL_BG := Color(0.10, 0.12, 0.11)
const COL_SELF := Color(0.35, 0.60, 1.0)        # 本方（不论 side，颜色统一蓝）
const COL_FOE := Color(1.0, 0.42, 0.38)         # 敌方
const COL_ELIXIR := Color(0.80, 0.33, 0.96)
const COL_PANEL := Color(0.10, 0.08, 0.14, 0.96)
const COL_PANEL_EDGE := Color(0.34, 0.30, 0.45)
const COL_OK := Color(0.45, 1.0, 0.55)
const COL_BAD := Color(1.0, 0.42, 0.40)
const COL_CARD_BG := Color(0.23, 0.21, 0.32, 0.96)
const COL_CARD_SEL := Color(0.40, 0.33, 0.16, 0.97)
const COL_CROWN := Color(0.925, 0.725, 0.305)
const COL_MUTED := Color(0.7, 0.7, 0.75)

# —— 出场缩放 / 落地涟漪 ——
const POP_DUR := 0.22
const POOF_DUR := 0.40

# —— 战斗 juice（V3-6b；联机顿帧改纯视觉，见 _process）——
const SMOOTH_K := 18.0                          # 位置插值平滑系数
const FLASH_DUR := 0.12                         # 受击闪白时长
const DMGNUM_DUR := 0.75
const DMGNUM_RISE := 34.0
const SPARK_DUR := 0.18
const SHAKE_DECAY := 42.0
const SHAKE_MAX := 14.0
const SHAKE_HIT := 3.0
const SHAKE_BIG := 6.0
const SHAKE_TOWER := 12.0
const SHAKE_HIT_DMG := 80.0
const HITSTOP_DMG := 200.0
const HITSTOP_DUR := 0.06                       # 顿帧时长（纯视觉：冻结 _elapsed 增量）

# —— 胜负演出 ——
const END_BTN_DELAY := 0.85

# —— V3-7 精灵贴图（架构 A：immediate _draw + draw_texture；逻辑零改）——
# 0716 PVP 视觉补课：塔换三国正式素材（阵营分色）。本方恒蓝、敌方恒红（_flip 已保证本方在下半场）。
const TEX_TOWER_KING_BLUE := preload("res://assets/towers/sanguo_tower_king_blue.png")
const TEX_TOWER_KING_RED := preload("res://assets/towers/sanguo_tower_king_red.png")
const TEX_TOWER_ARROW_BLUE := preload("res://assets/towers/sanguo_tower_arrow_blue.png")
const TEX_TOWER_ARROW_RED := preload("res://assets/towers/sanguo_tower_arrow_red.png")
const TEX_EXPLOSION := preload("res://assets/fx/Fire_Explosion_28x28.png")
const EXPLOSION_FPX := 28
const EXPLOSION_N := 12
const TEX_LIGHTNING := preload("res://assets/fx/Lightning_Energy_48x48.png")   # 闪电术命中
const TEX_RED_ENERGY := preload("res://assets/fx/Red_Energy_48x48.png")        # 电火花命中
const FX_SEQ_FPX := 48
const FX_SEQ_N := 9
# 卡 id → 命中 FX 类型；未列出（含 spawn 兵牌）= 中性落地尘土。
const FX_KIND := {
	"fireball": "fireball", "lightning": "lightning", "zap": "zap",
	"arrows": "arrows", "log": "log", "heal": "heal",
}
# —— 远程投射物（路线 A：view 检测攻击冷却上升沿=开火）——
const TEX_PROJ_FIREBALL := preload("res://assets/units/fire_skull_fireball.png")
const PROJ_FB_FPX := 16
const PROJ_SPEED := 16.0
const PROJ_RANGED_MIN := 2.5
const PROJ_KIND := {"archer_body": "arrow", "musketeer_body": "bolt", "baby_dragon_body": "fireball"}
# —— 整图战场背景（0715 正式素材；与单机 battle_scene 同款特征对齐算法）——
# 特征对齐：以「双桥中心定 x 缩放 + 河中心锚 y」等比取源贴 _field_rect（直接拉伸会变形、桥错位）。
# _flip 不参与 BG：场地河/桥上下左右对称，双方视角贴同一张图即可。
const TEX_BATTLE_BG := preload("res://assets/map/battle_bg.png")
const BG_ENABLED := true
const BG_BRIDGE1_PX := 188.8   # 图上左桥中心 x（px）
const BG_BRIDGE2_PX := 505.2   # 图上右桥中心 x（px）
const BG_RIVER_PX := 648.0     # 图上河带中心 y（px）
# 正式单位素材配套脚下椭圆影（贴地、不染队伍色）
const TEX_UNIT_SHADOW := preload("res://assets/units/unit_shadow.png")
# —— 地形 tile（7b-4，Lonesome Summer；16px tile 逐逻辑格铺；BG_ENABLED=false 时回退用）——
const TEX_FLOOR := preload("res://assets/terrain/Lonesome_Forest_FLOOR.png")
const TEX_WATER := preload("res://assets/terrain/simple_water_spritesheet.png")   # 河水动画 4×3=12 帧
const TEX_BRIDGE := preload("res://assets/terrain/Lonesome_Forest_COBBLESTONE_PATH.png")
const TILE_PX := 16
const GROUND_TILES := [Vector2i(4, 1), Vector2i(4, 2)]
const BRIDGE_TILES := [Vector2i(1, 1), Vector2i(2, 1)]
const WATER_COLS := 4
const WATER_N := 12
const WATER_FPS := 5.0

# 兵种白膜回退外形（无精灵时；按 owner 队伍色填）。精灵渲染框也以 r 为基（×SpriteDB scale）。
const UNIT_VIS := {
	"giant_body":      {"r": 0.85},
	"knight_body":     {"r": 0.55},
	"mini_pekka_body": {"r": 0.6},
	"musketeer_body":  {"r": 0.5},
	"archer_body":     {"r": 0.45},
	"baby_dragon_body":{"r": 0.75},
	"minion_body":     {"r": 0.45},
	"goblin_body":     {"r": 0.4},
	"skeleton_body":   {"r": 0.38},
	"golem_body":      {"r": 0.85},
	# A2.5 三国占位（2026-07-04）：新单位半径按体型档（极小0.35/小0.4/中0.5/大0.62/巨0.85）。与 battle_scene 同表。
	"spear_goblin_body": {"r": 0.38}, "bat_body": {"r": 0.32}, "barbarian_body": {"r": 0.5},
	"ice_spirit_body": {"r": 0.35}, "fire_spirit_body": {"r": 0.35}, "electro_spirit_body": {"r": 0.35},
	"squire_body": {"r": 0.45}, "axe_thrower_body": {"r": 0.42}, "cave_spider_body": {"r": 0.35},
	"bone_ram_body": {"r": 0.62}, "royal_giant_body": {"r": 0.8}, "hog_rider_body": {"r": 0.55},
	"valkyrie_body": {"r": 0.55}, "bomber_body": {"r": 0.4}, "mega_minion_body": {"r": 0.48},
	"battle_ram_body": {"r": 0.6}, "wizard_body": {"r": 0.48}, "executioner_body": {"r": 0.52},
	"balloon_body": {"r": 0.65}, "phoenix_body": {"r": 0.5}, "phoenix_reborn_body": {"r": 0.45},
	"lava_hound_body": {"r": 0.85}, "lava_pup_body": {"r": 0.35}, "ice_wizard_body": {"r": 0.45},
	"electro_wizard_body": {"r": 0.48}, "princess_body": {"r": 0.42}, "inferno_dragon_body": {"r": 0.52},
	"golemite_body": {"r": 0.5}, "fire_pup_body": {"r": 0.35},
}

var _loader
var _session
var _client
var _http: HTTPRequest
var _matchmaking := false
var _cancel_btn: Button
var _font: Font
var _status := "连接中…"
var _flip := false                              # side2 时整场翻转视角

# 出牌交互
var _selected := -1
var _dragging := false
var _drag_screen := Vector2.ZERO
var _card_btns: Array = []
var _card_base_pos: Array = []

# 视觉状态（juice/FX/插值，基于 instance_id + hp/cooldown diff，owner/side 无关）
var _elapsed := 0.0
var _fx: Array = []                             # 落地涟漪/命中爆点：[{pos, t0, dur, kind, radius}]
var _seen: Dictionary = {}                      # 单位 instance_id → 首见 _elapsed（入场缩放）
var _disp: Dictionary = {}                      # 单位 id → 显示插值位（tile）
var _uhp: Dictionary = {}                       # 单位 id → 上帧 hp
var _thp: Dictionary = {}                       # 塔 id → 上帧 hp
var _flash: Dictionary = {}                     # id → 闪白结束 _elapsed（单位+塔混用）
var _dmgnums: Array = []                        # [{pos, text, col, size, t0, dur}]
var _sparks: Array = []                         # [{pos, t0, dur}]
var _projectiles: Array = []                    # [{from, to, t0, dur, kind}]
var _atkcd: Dictionary = {}                     # 单位 id → 上帧 _attack_cooldown
var _tatkcd: Dictionary = {}                    # 塔 id → 上帧 _attack_cooldown
# —— 0715 正式素材配套：单位特效（攻击刀光/受击星芒/死亡白烟）+ 镜像朝向 ——
var _ufx: Array = []         # [{pos(tile), t0, dur, tex, fw, fh, n, size, flip}]
var _ulast: Dictionary = {}  # 单位 id → {pos, uid} 最后存活位置（死亡白烟定位，消失即触发）
var _face: Dictionary = {}   # 单位 id → 是否水平翻转（true=面朝右；mirror 条目用）
var _facex: Dictionary = {}  # 单位 id → 上帧屏幕 x（走路方向判定）
var _shake := Vector2.ZERO
var _shake_mag := 0.0
var _hitstop_t := 0.0                           # 纯视觉顿帧剩余（冻结 _elapsed 增量，不影响 lockstep）

# 胜负演出状态（由 _on_result 服务端信号触发，非本地 is_over 判定）
var _ending := false
var _end_t := 0.0
var _end_winner := 0                            # 服务端判定的 winner（0=平/1=side1/2=side2）
var _end_result_layer: Control
var _end_buttons_added := false

@onready var _vw: float = float(get_viewport_rect().size.x)
@onready var _vh: float = float(get_viewport_rect().size.y)


func _ready() -> void:
	_font = load("res://assets/fonts/fusion-pixel-12px-proportional-zh_hans.ttf")
	_loader = GameStateScript.config()
	_http = HTTPRequest.new()
	add_child(_http)
	_build_result_panel()
	set_process(true)
	_connect_flow()


func _connect_flow() -> void:
	_session = GameStateScript.session()
	_status = "登录中…"
	if not await _session.ensure(_http):
		_status = "登录失败，请检查网络/服务器"
		Log.w("[net] 登录失败，无法进入 PVP 匹配")
		return
	Log.i("[net] 登录成功，ws=%s，进入 PVP 匹配" % _session.ws_url)
	_matchmaking = true
	_status = "匹配中…"
	_show_cancel_button()
	_client = BattleClientScript.new(_loader)
	_client.matched.connect(_on_matched)
	_client.joined.connect(_on_joined)
	_client.result.connect(_on_result)
	_client.reconnecting.connect(_on_reconnecting)
	_client.disconnected.connect(_on_disconnected)
	_client.deploy_applied.connect(_on_deploy_applied)
	_client.start(_session.ws_url, _session.token(), 1)   # 卡组槽 1


func _show_cancel_button() -> void:
	if _cancel_btn != null:
		return
	_cancel_btn = Button.new()
	_cancel_btn.text = tr("btn_back")
	_cancel_btn.size = Vector2(160, 56)
	_cancel_btn.position = Vector2(_vw * 0.5 - 80, _vh * 0.5 + 50)
	_cancel_btn.pressed.connect(_on_cancel_pressed)
	add_child(_cancel_btn)


func _on_cancel_pressed() -> void:
	Log.i("[net] 用户取消匹配，返回主菜单")
	if _client != null:
		_client.cancel_match()
	Router.goto("main_menu")


func _on_matched(_your_side: int, opponent_name: String, _opponent_avatar: String) -> void:
	Log.i("[net] UI 收到匹配成功，对手=%s，等待进房建局" % opponent_name)
	if opponent_name != "":
		_status = "已匹配：%s，准备开战…" % opponent_name
	else:
		_status = "已匹配，准备开战…"


func _on_joined(your_side: int, opponent_name: String, opponent_avatar: String) -> void:
	Log.i("[net] UI 进房完成，我方 side=%d，视角翻转=%s，对手=%s，开始渲染战斗" % [your_side, str(your_side == 2), opponent_name])
	_flip = your_side == 2
	_matchmaking = false
	_status = "对手：%s" % opponent_name if opponent_name != "" else ""
	if _cancel_btn != null:
		_cancel_btn.queue_free()
		_cancel_btn = null
	_build_cards()
	_build_nameplates(opponent_name, opponent_avatar)
	# 联机对战音乐 + 战场环境音（AudioManager 全局 autoload，缺资源静默 no-op，与单机一致）。
	# 0716 首批 BGM：与单机同一套双曲轮播集（曲终随机换下一首）。
	AudioManager.play_music_set(["music_battle_normal", "music_battle_hunt"])
	AudioManager.play_ambience("amb_battle_wind")


# V5-S9：双方名片（己方左下、对手右上；头像走怪物卡 SpriteDB 立绘）。重连重入会清旧再建。
func _build_nameplates(opp_name: String, opp_avatar: String) -> void:
	for n in ["np_mine", "np_foe"]:
		var ex := get_node_or_null(NodePath(n))
		if ex != null:
			ex.queue_free()
	var session = GameStateScript.session()
	var vp := get_viewport_rect().size
	var mine := HudWidgets.nameplate(session.nickname(), session.avatar_card_id(), _loader, -1, true)
	mine.name = "np_mine"
	mine.position = Vector2(16, vp.y - HUD_BOTTOM_H - 78.0)
	mine.z_index = 50
	add_child(mine)
	var foe := HudWidgets.nameplate(opp_name, opp_avatar, _loader, -1, false)
	foe.name = "np_foe"
	foe.position = Vector2(vp.x - foe.size.x - 16.0, TOPBAR_H + 10.0)
	foe.z_index = 50
	add_child(foe)


func _on_result(winner: int, _reason: int) -> void:
	Log.i("[net] UI 收到对局结算，winner=%d（1=我方/2=对方/0=平）" % winner)
	_end_winner = winner
	_start_ending()
	# 刷新档案，回主菜单时杯数已更新。
	if _session != null:
		_session.refresh_profile(_http)


func _on_disconnected() -> void:
	Log.w("[net] UI 连接彻底断开（重连窗口耗尽或匹配前断开）")
	if not _ending:
		_status = "连接断开"


func _on_reconnecting() -> void:
	Log.i("[net] UI 连接中断，重连中…")
	if not _ending:
		_status = "连接中断，重连中…"


func _process(delta: float) -> void:
	if _client != null:
		_client.poll(delta)
	if not GameStateScript.is_online_ready() and not _ending:
		_status = "在线会话中断，恢复中…"
		_dragging = false
	# 纯视觉顿帧：冻结 _elapsed 增量让 FX/演出定格（联机 sim 由 tick bundle 驱动，
	# 不能像单机那样冻结 sim；这里只冻视觉时钟，不影响 lockstep 推进）。
	if _hitstop_t > 0.0:
		_hitstop_t -= delta
	else:
		_elapsed += delta
	if _client != null and _client.match_obj != null:
		_detect_events()
		_detect_attacks()
		_update_disp(delta)
	_update_shake(delta)
	if _dragging:
		_drag_screen = get_viewport().get_mouse_position()
	_cull_transients()
	_sync_cards()
	if _ending:
		_end_t += delta
		if _end_t >= END_BTN_DELAY and not _end_buttons_added:
			_add_result_buttons()
	queue_redraw()


# —— 本方判定（owner 不随 side 翻转：恒 player=0/opponent=1；_flip 决定谁是本方）——
func _is_mine(owner_id: int) -> bool:
	return (owner_id == 0 and not _flip) or (owner_id == 1 and _flip)


# 本方对应的 Player（side1→player，side2→opponent）。
func _local_player():
	if _client == null:
		return null
	return _client.local_player()


# —— 坐标映射（side 2 整场翻转：本方半场永远在屏幕下方）——
# 竖版 32×32 正方形屏幕格（KAN-107，与单机 battle_scene 同款）：格边长取整数、letterbox 居中——
# 720×1280 基准下 = 32px/格、场地 576×1024，两侧各 72px 装饰边栏（露 COL_BG 深底）。
func _field_rect() -> Rect2:
	var zone := Rect2(0.0, TOPBAR_H, _vw, _vh - TOPBAR_H - HUD_BOTTOM_H)
	var a = _client.match_obj.battle.arena
	var ts: float = floor(minf(zone.size.x / float(a.grid_w), zone.size.y / float(a.grid_h)))
	var fs := Vector2(ts * float(a.grid_w), ts * float(a.grid_h))
	return Rect2(zone.position + (zone.size - fs) * 0.5, fs)

func _t2s(p: Vector2) -> Vector2:
	var a = _client.match_obj.battle.arena
	var x: float = (a.grid_w - p.x) if _flip else p.x
	var y: float = (a.grid_h - p.y) if _flip else p.y
	var fr := _field_rect()
	return Vector2(fr.position.x + x / a.grid_w * fr.size.x,
			fr.position.y + y / a.grid_h * fr.size.y) + _shake   # _shake 只动场内、HUD 不抖

func _s2t(s: Vector2) -> Vector2:
	var a = _client.match_obj.battle.arena
	var fr := _field_rect()
	var x: float = (s.x - fr.position.x) / fr.size.x * a.grid_w
	var y: float = (s.y - fr.position.y) / fr.size.y * a.grid_h
	if _flip:
		x = a.grid_w - x
		y = a.grid_h - y
	return Vector2(x, y)

func _tile_px() -> Vector2:
	var a = _client.match_obj.battle.arena
	var fr := _field_rect()
	return Vector2(fr.size.x / a.grid_w, fr.size.y / a.grid_h)

func _ur() -> float:          # 单位绘制参考半径基准 = tile 屏幕边长均值
	var tp := _tile_px()
	return (tp.x + tp.y) * 0.5

# 「屏幕向上 n 格」对应的逻辑位移（塔顶伤害数字锚点/箭口）：_flip 时逻辑 y 增 = 屏幕向上。
func _screen_up_tiles(n: float) -> Vector2:
	return Vector2(0.0, n if _flip else -n)


# —— 绘制 ——
func _draw() -> void:
	draw_rect(Rect2(0, 0, _vw, _vh), COL_BG)
	if _client == null or _client.match_obj == null:
		_text(Vector2(_vw * 0.5 - 80, _vh * 0.5), _status, Color.WHITE, 24)
		return
	var a = _client.match_obj.battle.arena
	_draw_terrain(a)
	_draw_deploy_hint(a)
	_draw_world(a)   # 塔+单位 Y-sort 伪深度单通道（0715 二验同款）
	_draw_fx()
	_draw_unit_fx()
	_draw_projectiles()
	_draw_combat_fx()
	_draw_drag_ghost(a)
	_draw_topbar()
	draw_rect(Rect2(0, _vh - HUD_BOTTOM_H, _vw, HUD_BOTTOM_H), COL_PANEL)   # 底部 HUD 底板
	_draw_elixir()
	_draw_cards()
	_draw_end_screen()
	if _matchmaking and _status != "":
		# 匹配中遮罩（_draw 在 client 未就绪分支已 return，这里覆盖对局前状态）。
		pass


# —— 地形（0715 整图 BG 特征对齐；BG_ENABLED=false 回退 V3-7b-4 逐格 tile）——
func _draw_terrain(a) -> void:
	if BG_ENABLED:
		_draw_bg_image(a)
	else:
		_draw_terrain_tiles(a)
	# 己方半场可部署区描边提示（按 _flip 选上下半场；本方半场恒在屏幕下方）。
	var fr := _field_rect()
	var y0 := _t2s(Vector2(0, _deploy_y_min(a))).y
	draw_rect(Rect2(fr.position.x, y0, fr.size.x, fr.position.y + fr.size.y - y0),
			Color(0.4, 0.8, 0.5, 0.10))

# 本方半场的部署 y 下界（tile）：side1=deploy_player_y_min，side2=对敌方半场对称。
func _deploy_y_min(a) -> int:
	return a.deploy_player_y_min if not _flip else (a.grid_h - a.deploy_player_y_min)

func _draw_terrain_tiles(a) -> void:
	var tp := _tile_px()
	for ty in range(a.grid_h):
		for tx in range(a.grid_w):
			var t: int = a.tile_type(tx, ty)
			var s := _t2s(Vector2(tx, ty))
			var rect := Rect2(s.x, s.y, tp.x + 1.0, tp.y + 1.0)
			if t == a.TILE_WATER:
				_draw_water_tile(rect)
			elif t != a.TILE_TOWER and ty >= a.river_y_min and ty < a.river_y_max:
				_draw_bridge_tile(tx, ty, rect)   # 河行里的可走 = 桥
			else:
				_draw_ground_tile(tx, ty, rect, ty < a.grid_h / 2)

# 整图背景按特征对齐贴进场地：给定「屏幕上桥1/桥2中心 x 与河中心 y 应落的位置」，
# 反解 BG 的源矩形（等比），使图上河/桥与逻辑河/桥重合（单机 battle_scene 竖版分支同款）。
func _draw_bg_image(a) -> void:
	var fr := _field_rect()
	var b1: float = (a.bridges[0]["x_min"] + a.bridges[0]["x_max"]) * 0.5 / float(a.grid_w)
	var b2: float = (a.bridges[1]["x_min"] + a.bridges[1]["x_max"]) * 0.5 / float(a.grid_w)
	var rv: float = (a.river_y_min + a.river_y_max) * 0.5 / float(a.grid_h)
	var pp := _bg_full(fr, Rect2(0.0, 0.0, _vw, _vh), _bg_src(fr, b1, b2, rv))
	draw_texture_rect_region(TEX_BATTLE_BG,
			Rect2((pp[0] as Rect2).position + _shake, (pp[0] as Rect2).size), pp[1])

func _bg_src(fr: Rect2, b1: float, b2: float, rv: float) -> Rect2:
	var s1: float = b1 * fr.size.x                                   # 桥1中心相对场地左缘（px）
	var s2: float = b2 * fr.size.x
	var k: float = (s2 - s1) / (BG_BRIDGE2_PX - BG_BRIDGE1_PX)       # 屏幕px / 图px 缩放
	var src_x: float = BG_BRIDGE1_PX - s1 / k
	var src_y: float = BG_RIVER_PX - rv * fr.size.y / k
	return Rect2(src_x, src_y, fr.size.x / k, fr.size.y / k)

# BG 铺满全屏——美术出图四周树林/湖是屏幕填充边（长屏适配），中心特征对齐即可。dest 从场地
# 矩形向四周扩到视口边、src 同步扩（以图边为界，不够处露 COL_BG）。返回 [dest, src]。
func _bg_full(fr: Rect2, vp: Rect2, src: Rect2) -> Array:
	var k: float = fr.size.x / src.size.x
	var ts: Vector2 = TEX_BATTLE_BG.get_size()
	var tl := Vector2(clampf(fr.position.x - vp.position.x, 0.0, src.position.x * k),
			clampf(fr.position.y - vp.position.y, 0.0, src.position.y * k))
	var br := Vector2(clampf(vp.end.x - fr.end.x, 0.0, (ts.x - src.end.x) * k),
			clampf(vp.end.y - fr.end.y, 0.0, (ts.y - src.end.y) * k))
	return [Rect2(fr.position - tl, fr.size + tl + br),
			Rect2(src.position - tl / k, src.size + (tl + br) / k)]

func _blit_tile(tex: Texture2D, cell: Vector2i, rect: Rect2, mod: Color) -> void:
	draw_texture_rect_region(tex, rect, Rect2(cell.x * TILE_PX, cell.y * TILE_PX, TILE_PX, TILE_PX), mod)

func _draw_ground_tile(tx: int, ty: int, rect: Rect2, enemy: bool) -> void:
	var cell: Vector2i = GROUND_TILES[(tx * 7 + ty * 13) % GROUND_TILES.size()]
	# 逻辑坐标的 enemy（上半场）经 _t2s 翻转后位置已正确；色调仅作上下半场区分参考。
	_blit_tile(TEX_FLOOR, cell, rect, Color(1.0, 0.90, 0.86) if enemy else Color.WHITE)

func _draw_bridge_tile(tx: int, ty: int, rect: Rect2) -> void:
	_blit_tile(TEX_BRIDGE, BRIDGE_TILES[(tx + ty) % BRIDGE_TILES.size()], rect, Color.WHITE)

func _draw_water_tile(rect: Rect2) -> void:
	var fr: int = int(_elapsed * WATER_FPS) % WATER_N
	_blit_tile(TEX_WATER, Vector2i(fr % WATER_COLS, fr / WATER_COLS), rect, Color.WHITE)


# 塔绘制纯视觉 y 偏移（屏幕语义，+朝屏幕上方；逻辑塔位不动）：与 BG 路环节点对齐（0715 二验同款）。
# 单机版按 owner 定偏移（我王塔/敌箭塔各上移半格）；联机 _flip 已保证本方在屏幕下方，
# 故换算成屏幕语义 = 下半场王塔、上半场箭塔 各上移半格。
func _tower_anchor(t) -> Vector2:
	var c := _t2s(t.pos)
	var mine: bool = _is_mine(t.owner_id)
	if (mine and t.is_king()) or (not mine and not t.is_king()):
		c.y -= _tile_px().y * 0.5
	return c

# 0715 二验：单位/建筑伪深度 Y-sort——视角自屏幕下方往上看，按「接地线」升序绘制：
# 屏幕上方（远处）先画、被下方（近处）盖住；空军恒最上层。逐帧收集塔+单位统一排序（含 _seen 记账）。
func _draw_world(a) -> void:
	var tp := _tile_px()
	var items: Array = []
	for side in [_client.match_obj.battle.player_towers, _client.match_obj.battle.opponent_towers]:
		for t in side:
			items.append([_tower_anchor(t).y + t.fh * tp.y * 0.5, items.size(), false, t])
	var ur: float = _ur()
	var cur := {}
	for u in a.get_units():
		if not u.is_alive():
			continue
		var id: int = u.get_instance_id()
		cur[id] = true
		if not _seen.has(id):
			_seen[id] = _elapsed
		var gy: float = _t2s(_disp_pos(u)).y + float(UNIT_VIS.get(u.unit_id, {"r": 0.5})["r"]) * ur  # 脚线近似
		items.append([gy + (100000.0 if u.target_type == "air" else 0.0), items.size(), true, u])
	items.sort_custom(func(p, q): return p[0] < q[0] if p[0] != q[0] else p[1] < q[1])
	for it in items:
		if it[2]:
			_draw_unit_one(it[3], ur)
		else:
			_draw_tower_one(it[3])
	for k in _seen.keys():
		if not cur.has(k):
			_seen.erase(k)
			_disp.erase(k)
			_uhp.erase(k)
			_atkcd.erase(k)
			_face.erase(k)
			_facex.erase(k)

# —— 塔（0716：三国正式素材 阵营分色 + 血条 + 王塔金冠 + 摧毁废墟）——
func _draw_tower_one(t) -> void:
	var tp := _tile_px()
	var mine: bool = _is_mine(t.owner_id)
	var base: Color = COL_SELF if mine else COL_FOE
	var king: bool = t.is_king()
	var c := _tower_anchor(t)
	var fp := Vector2(t.fw * tp.x, t.fh * tp.y)
	var foot_bottom: float = c.y + fp.y * 0.5            # footprint 底边 = 塔贴地处
	var tex: Texture2D
	if king:
		tex = TEX_TOWER_KING_BLUE if mine else TEX_TOWER_KING_RED
	else:
		tex = TEX_TOWER_ARROW_BLUE if mine else TEX_TOWER_ARROW_RED
	var ts: Vector2 = tex.get_size()
	# 保持长宽比、底部贴地；中式塔纵高 → 系数压小防过高（与单机同参）。
	var draw_w: float = fp.x * (0.95 if king else 0.85)
	var draw_h: float = draw_w * ts.y / ts.x
	var rx: float = c.x - draw_w * 0.5
	var ry: float = foot_bottom - draw_h
	if t.is_destroyed():                                  # 摧毁：压低 + 染暗成废墟堆
		var dh: float = draw_h * 0.42
		draw_texture_rect(tex, Rect2(rx, foot_bottom - dh, draw_w, dh), false, Color(0.30, 0.28, 0.26, 0.95))
		return
	var fill: Color = Color.WHITE.lerp(base, 0.22)       # 正式素材自带阵营配色 → natural 轻染
	var fend: float = _flash.get(t.get_instance_id(), 0.0)
	if fend > _elapsed:
		fill = fill.lerp(Color.WHITE, ((fend - _elapsed) / FLASH_DUR) * 0.85)
	draw_texture_rect(tex, Rect2(rx, ry, draw_w, draw_h), false, fill)
	var ratio: float = clampf(t.hp / t.max_hp, 0.0, 1.0)
	var bw := draw_w * 0.8
	var by := ry - 7.0
	draw_rect(Rect2(c.x - bw * 0.5, by, bw, 5.0), Color(0, 0, 0, 0.5))
	draw_rect(Rect2(c.x - bw * 0.5, by, bw * ratio, 5.0), _hp_color(ratio))
	if king:                                              # 王塔顶金王冠标记
		_draw_crown(Vector2(c.x, by - 13.0), 20.0, COL_CROWN, true)

# —— 单位（V3-7b-1 精灵 + 0715/0716：脚下影 + natural 轻染 + mirror 朝向）——
func _draw_unit_one(u, ur: float) -> void:
	var id: int = u.get_instance_id()
	var mine: bool = _is_mine(u.owner_id)
	var base: Color = COL_SELF if mine else COL_FOE
	var c := _t2s(_disp_pos(u))
	var vis: Dictionary = UNIT_VIS.get(u.unit_id, {"r": 0.5})
	var rad: float = float(vis["r"]) * ur * _pop_scale(id)
	var flying: bool = u.target_type == "air"
	if flying:
		draw_circle(c + Vector2(0, ur * 0.5), rad * 0.6, Color(0, 0, 0, 0.25))  # 地面影子
		c -= Vector2(0, ur * 0.7)                                                # 单位上浮
	var fill: Color = base
	var fend: float = _flash.get(id, 0.0)
	if fend > _elapsed:
		fill = base.lerp(Color.WHITE, ((fend - _elapsed) / FLASH_DUR) * 0.85)
	# 状态派生（路线 A）：有索敌目标且在攻击射程内 → attack，否则 walk。
	var st := "walk"
	var ct = u.current_target
	if ct != null and is_instance_valid(ct):
		var reach: float = u.attack_range + 1.0
		if "fw" in ct:
			reach = u.attack_range + maxf(float(ct.fw), float(ct.fh)) * 0.5 + 0.5
		if u.pos.distance_to(ct.pos) <= reach:
			st = "attack"
	# 精灵朝向：owner_id 0 朝上(row_up)、1 朝下(row)。side2 视角下本方(owner1)贴图朝向会反，
	# 故对非翻转方传 owner 原值、翻转方传镜像 owner，让贴图朝向跟随屏幕视角。
	var spr_owner: int = u.owner_id
	if _flip:
		spr_owner = 0 if u.owner_id == 1 else 1
	var spr: Dictionary = SpriteDB.frame(u.unit_id, st, spr_owner, _elapsed)
	if not spr.is_empty():   # 精灵帧（modulate=fill 染队伍色+受击闪白，×占位 tint 区分共享贴图）
		var box: float = rad * 2.0 * float(spr["scale"])
		if spr.get("shadow", false) and not flying:   # 正式素材配套脚下椭圆影（贴地、不染队伍色）
			# 自带 30% alpha 太淡 → 叠两遍 ≈51% 黑、宽 0.9 基准框压脚线。⚠️ 基准用 base_scale
			# （不含状态 sc）：攻击大方格若用 box，阴影会放大下坠（0715 验收实测偏离）。
			var sbox: float = rad * 2.0 * float(spr.get("base_scale", spr["scale"]))
			var sw: float = sbox * 0.9
			var sh: float = sw * 0.4
			var srect := Rect2(c + Vector2(-sw * 0.5, sbox * 0.5 - sh * 0.5), Vector2(sw, sh))
			draw_texture_rect(TEX_UNIT_SHADOW, srect, false)
			draw_texture_rect(TEX_UNIT_SHADOW, srect, false)
		var spr_mod: Color = fill * spr.get("tint", Color.WHITE)
		if spr.get("natural", false):   # 正式彩色素材：轻染队伍倾向（全乘会糊黑），闪白照旧
			spr_mod = Color.WHITE.lerp(base, 0.22)
			if fend > _elapsed:
				spr_mod = spr_mod.lerp(Color.WHITE, ((fend - _elapsed) / FLASH_DUR) * 0.85)
		# 0715 mirror（单方向侧脸素材默认朝左）：攻击朝目标/走路朝移动方向/纵走保持上次；
		# 判定全用屏幕 x（_t2s 已含 _flip），翻转视角自动正确。绕单位中心 -1 缩放翻转。
		if bool(spr.get("mirror", false)):
			if st == "attack" and ct != null and is_instance_valid(ct):
				_face[id] = _t2s(ct.pos).x > c.x
			elif absf(c.x - float(_facex.get(id, c.x))) > 0.2:
				_face[id] = c.x > float(_facex.get(id, c.x))
			_facex[id] = c.x
		draw_set_transform(c, 0.0, Vector2(-1.0 if _face.get(id, false) else 1.0, 1.0))
		draw_texture_rect_region(spr["tex"], Rect2(-Vector2(box, box) * 0.5, Vector2(box, box)),
				spr["src"], spr_mod)
		draw_set_transform(Vector2.ZERO)
	else:                    # 无精灵 → 白膜回退
		draw_circle(c, rad, fill)
		draw_arc(c, rad, 0.0, TAU, 20, base.darkened(0.4), 2.0)
	if flying:
		draw_arc(c, rad + 3.0, 0.0, TAU, 20, Color(1, 1, 1, 0.7), 1.5)
	var ratio: float = clampf(u.hp / u.max_hp, 0.0, 1.0)
	if ratio < 1.0:
		var bw := rad * 2.0
		draw_rect(Rect2(c.x - rad, c.y - rad - 6.0, bw, 3.0), Color(0, 0, 0, 0.5))
		draw_rect(Rect2(c.x - rad, c.y - rad - 6.0, bw * ratio, 3.0), _hp_color(ratio))


# —— 顶栏（王冠计数 + 倒计时强调；王冠按本方/敌方，owner/side 翻转）——
func _draw_topbar() -> void:
	draw_rect(Rect2(0, 0, _vw, TOPBAR_H), COL_PANEL)
	draw_rect(Rect2(0, TOPBAR_H - 3.0, _vw, 3.0), COL_PANEL_EDGE)
	# 本方拆掉的敌塔数：side1→opponent_towers，side2→player_towers。
	var my_crowns := _crowns(_foe_towers())
	var foe_crowns := _crowns(_my_towers())
	_text(Vector2(12, 28), tr("hud_you"), COL_SELF, 16)
	_draw_crowns(Vector2(54, 8), my_crowns, COL_SELF)
	_text(Vector2(_vw - 56, 28), tr("hud_enemy"), COL_FOE, 16)
	_draw_crowns(Vector2(_vw - 150, 8), foe_crowns, COL_FOE)
	# 倒计时：低于 30s 红色脉动强调
	var t: float = _client.match_obj.battle.remaining_time()
	var tcol := Color.WHITE
	var tsize := 24
	if t <= 30.0:
		var pulse: float = 0.5 + 0.5 * sin(_elapsed * 6.0)
		tcol = Color(1, 0.4, 0.35).lerp(Color(1, 0.9, 0.3), pulse)
		tsize = 27
	_text(Vector2(_vw * 0.5 - 30, 32), "%d:%02d" % [int(t) / 60, int(t) % 60], tcol, tsize)
	if _status != "":
		_text(Vector2(_vw * 0.5 - 60, TOPBAR_H + 18), _status, COL_MUTED, 14)

# 本方塔数组（side1→player_towers，side2→opponent_towers）。
func _my_towers() -> Array:
	var b = _client.match_obj.battle
	return b.player_towers if not _flip else b.opponent_towers

# 敌方塔数组。
func _foe_towers() -> Array:
	var b = _client.match_obj.battle
	return b.opponent_towers if not _flip else b.player_towers

func _draw_crowns(start: Vector2, n: int, col: Color) -> void:
	for i in 3:
		_draw_crown(start + Vector2(i * 19 + 9, 9), 15.0, col, i < n)

func _draw_crown(c: Vector2, s: float, col: Color, filled: bool) -> void:
	var w := s
	var h := s * 0.8
	var pts := PackedVector2Array([
		c + Vector2(-w * 0.5, h * 0.5), c + Vector2(-w * 0.5, -h * 0.25),
		c + Vector2(-w * 0.25, h * 0.1), c + Vector2(0, -h * 0.5),
		c + Vector2(w * 0.25, h * 0.1), c + Vector2(w * 0.5, -h * 0.25),
		c + Vector2(w * 0.5, h * 0.5),
	])
	if filled:
		draw_colored_polygon(pts, col)
	else:
		var line := pts.duplicate()
		line.append(pts[0])
		draw_polyline(line, Color(col.r, col.g, col.b, 0.35), 1.5)

func _crowns(towers: Array) -> int:
	var n := 0
	for t in towers:
		if t.is_destroyed():
			n += 1
	return n


# —— 圣水条（分段 + 满槽脉动 + 下一张预览）——
func _draw_elixir() -> void:
	var lp = _local_player()
	if lp == null:
		return
	var e = lp.elixir
	var amt: float = e.get_amount()
	var mx: int = maxi(1, int(round(float(e.maximum) if "maximum" in e else 10.0)))
	var full: bool = e.is_full()
	var y := _vh - HUD_BOTTOM_H + 10.0
	var x0 := 16.0
	var next_w := 104.0
	var total_w := _vw - 32.0 - next_w
	var gap := 3.0
	var pip_w: float = (total_w - gap * (mx - 1)) / mx
	for i in mx:
		var px := x0 + i * (pip_w + gap)
		draw_rect(Rect2(px, y, pip_w, 20.0), Color(0.10, 0.05, 0.12, 0.85))
		var fillf: float = clampf(amt - float(i), 0.0, 1.0)
		if fillf > 0.0:
			var col := COL_ELIXIR
			if full:
				col = COL_ELIXIR.lerp(Color(1, 0.85, 1), (0.5 + 0.5 * sin(_elapsed * 8.0)) * 0.6)
			draw_rect(Rect2(px, y, pip_w * fillf, 20.0), col)
	_text(Vector2(x0 + 4, y + 16.0), "%d" % e.get_int(), Color.WHITE, 14)
	_draw_next_chip(_vw - next_w - 4.0, y - 2.0, next_w - 6.0, 24.0)

func _draw_next_chip(x: float, y: float, w: float, h: float) -> void:
	var lp = _local_player()
	if lp == null:
		return
	var nx = lp.deck.peek_next()
	if nx == null:
		return
	draw_rect(Rect2(x, y, w, h), Color(0, 0, 0, 0.4))
	_text(Vector2(x + 5, y + 10), tr("hud_next"), Color(0.7, 0.7, 0.7), 10)
	_text(Vector2(x + 5, y + h - 4), _short(tr("card_" + str(nx)), 9), Color.WHITE, 11)
	var cost: int = lp.card_cost(nx)
	draw_circle(Vector2(x + w - 12, y + h * 0.5), 8.0, COL_ELIXIR)
	_text(Vector2(x + w - 15, y + h * 0.5 + 4.0), "%d" % cost, Color.WHITE, 11)


func _hp_color(ratio: float) -> Color:
	if ratio > 0.5:
		return Color(0.3, 0.85, 0.35)
	elif ratio > 0.25:
		return Color(0.95, 0.7, 0.2)
	return Color(0.9, 0.3, 0.25)

func _text(pos: Vector2, s: String, col: Color, size: int) -> void:
	draw_string(_font, pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)


# —— 出牌交互（拖拽部署，CR 式：按卡→拖到场上→松手发 deploy，等服务端落子）——
func _drop_tile() -> Vector2:
	var lift: float = _tile_px().y * DROP_LIFT_TILES
	return _s2t(_drag_screen + Vector2(0.0, -lift))

# 卡牌出什么：spawn=生成兵；否则法术（radius>0=AOE，=0=直伤）。
func _card_info(cid) -> Dictionary:
	for sk in _loader.get_card(cid).get("skills", []):
		if typeof(sk) != TYPE_DICTIONARY:
			continue
		var t = sk.get("type")
		if t == "spawn_unit":
			return {"spawn": true, "unit_id": str(sk.get("unit_id")), "count": int(sk.get("count", 1)), "radius": 0.0}
		elif t == "aoe_damage" or t == "aoe_heal":
			return {"spawn": false, "unit_id": "", "count": 0, "radius": float(sk.get("radius", 1.0))}
		elif t == "direct_damage":
			return {"spawn": false, "unit_id": "", "count": 0, "radius": 0.0}
	return {"spawn": false, "unit_id": "", "count": 0, "radius": 0.0}

func _play_card_audio(cid: String, info: Dictionary) -> void:
	match cid:
		"fireball":
			AudioManager.play_sfx("spell_fireball_cast"); AudioManager.play_sfx("spell_fireball_impact")
		"arrows":
			AudioManager.play_sfx("spell_arrows_cast"); AudioManager.play_sfx("spell_arrows_impact")
		"zap":
			AudioManager.play_sfx("spell_zap_cast"); AudioManager.play_sfx("spell_zap_impact")
		"lightning":
			AudioManager.play_sfx("spell_lightning_cast"); AudioManager.play_sfx("spell_lightning_impact")
		"log":
			AudioManager.play_sfx("spell_log_impact")
		"heal":
			AudioManager.play_sfx("spell_heal_cast")
		_:
			_play_deploy_audio(info)

func _play_deploy_audio(info: Dictionary) -> void:
	var unit_id := String(info.get("unit_id", ""))
	var count := int(info.get("count", 1))
	if unit_id == "giant_body" or unit_id == "golem_body":
		AudioManager.play_sfx("deploy_large")
	elif unit_id == "minion_body" or unit_id == "baby_dragon_body":
		AudioManager.play_sfx("deploy_air")
	elif count >= 3 or unit_id == "goblin_body" or unit_id == "skeleton_body":
		AudioManager.play_sfx("deploy_small")
	else:
		AudioManager.play_sfx("deploy_medium")

# 拖拽中：场上画落点 ghost（兵剪影 / AOE 圈 / 直伤准星）+ 合法绿/非法红。
func _draw_drag_ghost(a) -> void:
	if not _dragging or _selected < 0 or _ending:
		return
	var lp = _local_player()
	if lp == null:
		return
	var hand: Array = lp.deck.get_hand()
	if _selected >= hand.size() or hand[_selected] == null:
		return
	var info: Dictionary = _card_info(str(hand[_selected]))
	var drop_tile: Vector2 = _drop_tile()
	var tp := _tile_px()
	var ur: float = (tp.x + tp.y) * 0.5
	var owner_id: int = _client.your_side - 1   # 本方 owner（side1→0/side2→1）
	var legal: bool = a.can_deploy(owner_id, drop_tile) if info["spawn"] else true
	var col: Color = COL_OK if legal else COL_BAD
	var c: Vector2 = _t2s(drop_tile)
	draw_arc(c, ur * 0.9, 0.0, TAU, 28, col, 2.5)
	if info["spawn"]:
		var n: int = maxi(1, int(info["count"]))
		var vr: float = float(UNIT_VIS.get(info["unit_id"], {"r": 0.5})["r"]) * ur
		for i in n:
			var off := Vector2.ZERO
			if n > 1:
				var ang: float = float(i) / n * TAU
				off = Vector2(cos(ang), sin(ang)) * (vr * 0.9)
			var gc: Vector2 = c + off
			draw_circle(gc, vr, Color(col.r, col.g, col.b, 0.35))
			draw_arc(gc, vr, 0.0, TAU, 20, col, 2.0)
	elif info["radius"] > 0.0:
		var rr: float = float(info["radius"]) * ur
		draw_circle(c, rr, Color(col.r, col.g, col.b, 0.12))
		draw_arc(c, rr, 0.0, TAU, 40, col, 2.0)
	else:
		draw_line(c - Vector2(ur, 0), c + Vector2(ur, 0), col, 2.0)
		draw_line(c - Vector2(0, ur), c + Vector2(0, ur), col, 2.0)

# 拖拽兵牌时高亮己方半场可部署区（轻微脉动）。
func _draw_deploy_hint(a) -> void:
	if not _dragging or _selected < 0 or _ending:
		return
	var lp = _local_player()
	if lp == null:
		return
	var hand: Array = lp.deck.get_hand()
	if _selected >= hand.size() or hand[_selected] == null:
		return
	if not _card_info(str(hand[_selected]))["spawn"]:
		return
	var fr := _field_rect()
	var y0: float = _t2s(Vector2(0, _deploy_y_min(a))).y
	var pulse: float = 0.12 + 0.06 * (0.5 + 0.5 * sin(_elapsed * 6.0))
	draw_rect(Rect2(fr.position.x, y0, fr.size.x, fr.position.y + fr.size.y - y0),
			Color(COL_OK.r, COL_OK.g, COL_OK.b, pulse))


# —— FX（落地涟漪 + 命中爆点；按 kind 分派 sheet 序列帧 / 程序化）——
func _draw_fx() -> void:
	var tp := _tile_px()
	var ur: float = (tp.x + tp.y) * 0.5
	for f in _fx:
		var p: float = clampf((_elapsed - f["t0"]) / f["dur"], 0.0, 1.0)
		var c: Vector2 = _t2s(f["pos"])
		var kind: String = f.get("kind", "spawn")
		var rt: float = float(f.get("radius", 0.0))
		match kind:
			"fireball":
				_fx_seq(TEX_EXPLOSION, EXPLOSION_FPX, EXPLOSION_N, c, (rt * 2.0 * ur) if rt > 0.0 else ur * 2.6, p, Color.WHITE)
			"lightning":
				_fx_seq(TEX_LIGHTNING, FX_SEQ_FPX, FX_SEQ_N, c, (rt * 2.2 * ur) if rt > 0.0 else ur * 3.0, p, Color(0.85, 0.92, 1.0))
			"zap":
				_fx_seq(TEX_RED_ENERGY, FX_SEQ_FPX, FX_SEQ_N, c, ur * 2.0, p, Color.WHITE)
			"arrows":
				_fx_arrows(c, maxf(rt, 1.0) * ur, p)
			"log":
				_fx_dust(c, maxf(rt, 1.0) * ur, p, Color(0.60, 0.50, 0.36))
			"heal":
				_fx_heal(c, maxf(rt, 1.0) * ur, p)
			_:
				_fx_dust(c, ur * 1.2, p, Color(0.78, 0.74, 0.66))

func _fx_seq(tex: Texture2D, fpx: int, n: int, c: Vector2, size: float, p: float, mod: Color) -> void:
	var fi: int = mini(n - 1, int(p * n))
	draw_texture_rect_region(tex, Rect2(c - Vector2(size, size) * 0.5, Vector2(size, size)), Rect2(fi * fpx, 0, fpx, fpx), mod)

func _fx_dust(c: Vector2, r: float, p: float, col: Color) -> void:
	var rr: float = r * (0.35 + 1.0 * p)
	var a: float = (1.0 - p) * 0.6
	draw_circle(c, rr * 0.85, Color(col.r, col.g, col.b, a * 0.35))
	draw_arc(c, rr, 0.0, TAU, 26, Color(col.r, col.g, col.b, a), 3.0)

func _fx_arrows(c: Vector2, r: float, p: float) -> void:
	var col := Color(0.92, 0.86, 0.6)
	for i in 8:
		var lt: float = clampf((p - float(i) * 0.03) / 0.45, 0.0, 1.0)
		if lt <= 0.0:
			continue
		var ox: float = (float(i) / 7.0 - 0.5) * 1.6 * r
		var tip: Vector2 = c + Vector2(ox, -r * 0.4 + r * 1.3 * lt)
		col.a = 1.0 - lt
		draw_line(tip + Vector2(-7, -18), tip, col, 2.0)
		draw_line(tip, tip + Vector2(-3, -5), col, 1.5)
		draw_line(tip, tip + Vector2(4, -5), col, 1.5)

func _fx_heal(c: Vector2, r: float, p: float) -> void:
	draw_arc(c, r * (0.4 + 0.8 * p), 0.0, TAU, 28, Color(0.4, 1.0, 0.5, (1.0 - p) * 0.7), 2.5)
	for i in 5:
		var ang: float = float(i) / 5.0 * TAU
		var pp: Vector2 = c + Vector2(cos(ang), sin(ang)) * r * 0.45 - Vector2(0, r * 0.7 * p)
		var pa: float = 1.0 - p
		draw_line(pp - Vector2(3, 0), pp + Vector2(3, 0), Color(0.5, 1, 0.6, pa), 2.0)
		draw_line(pp - Vector2(0, 3), pp + Vector2(0, 3), Color(0.5, 1, 0.6, pa), 2.0)

func _fx_dur(kind: String) -> float:
	match kind:
		"fireball": return 0.5
		"lightning": return 0.45
		"zap": return 0.32
		"arrows": return 0.6
		"log": return 0.5
		"heal": return 0.65
		_: return POOF_DUR

func _cull_transients() -> void:
	_fx = _cull_list(_fx)
	_dmgnums = _cull_list(_dmgnums)
	_sparks = _cull_list(_sparks)
	_ufx = _cull_list(_ufx)
	_projectiles = _cull_list(_projectiles)
	for k in _flash.keys():
		if _flash[k] <= _elapsed:
			_flash.erase(k)

func _cull_list(arr: Array) -> Array:
	var keep: Array = []
	for f in arr:
		if _elapsed - f["t0"] < f["dur"]:
			keep.append(f)
	return keep


# —— 单位配套特效（0715：攻击刀光/受击星芒/死亡白烟；SpriteDB.unit_fx 条目驱动）——
func _spawn_unit_fx(fx: Dictionary, pos: Vector2, flip: bool) -> void:
	if fx.is_empty():
		return
	_ufx.append({"pos": pos, "t0": _elapsed, "dur": float(fx["dur"]), "tex": fx["tex"], "fw": int(fx["fw"]),
			"fh": int(fx["fh"]), "n": int(fx["n"]), "size": float(fx["size"]), "flip": flip})

func _draw_unit_fx() -> void:
	var ur := _ur()
	for f in _ufx:
		var p: float = clampf((_elapsed - float(f["t0"])) / float(f["dur"]), 0.0, 0.999)
		var w: float = float(f["size"]) * ur
		var h: float = w * float(f["fh"]) / float(f["fw"])
		var src := Rect2(int(p * float(f["n"])) * int(f["fw"]), 0, int(f["fw"]), int(f["fh"]))
		# 素材默认朝左，flip 绕中心镜像（region 不支持翻转参数）；收尾轻淡出
		draw_set_transform(_t2s(f["pos"]), 0.0, Vector2(-1.0 if f.get("flip", false) else 1.0, 1.0))
		draw_texture_rect_region(f["tex"], Rect2(Vector2(-w, -h) * 0.5, Vector2(w, h)), src,
				Color(1, 1, 1, 1.0 - p * 0.3))
		draw_set_transform(Vector2.ZERO)

# —— 战斗 juice（V3-6b：逐帧 diff 逻辑状态派生反馈；owner/side 无关，零适配）——
func _disp_pos(u) -> Vector2:
	return _disp.get(u.get_instance_id(), u.pos)

func _detect_events() -> void:
	var b = _client.match_obj.battle
	if b == null or b.arena == null:
		return
	var alive_now: Dictionary = {}
	for u in b.arena.get_units():
		if not u.is_alive():
			continue
		var id: int = u.get_instance_id()
		alive_now[id] = true
		_ulast[id] = {"pos": _disp_pos(u), "uid": u.unit_id}
		var cur: float = u.hp
		if _uhp.has(id):
			var d: float = float(_uhp[id]) - cur
			if d > 0.5:
				_on_hit(id, _disp_pos(u), d, u.unit_id)
			elif d < -0.5:
				_spawn_dmgnum(_disp_pos(u), "+%d" % int(-d), COL_OK, 18)
		_uhp[id] = cur
	for id in _ulast.keys():   # 死亡消散（0715 配套 FX）：上帧还活着、本帧消失 = 阵亡 → 最后位置放特效
		if not alive_now.has(id):
			_spawn_unit_fx(SpriteDB.unit_fx(str(_ulast[id]["uid"]), "death"), _ulast[id]["pos"], false)
			_ulast.erase(id)
	for side in [b.player_towers, b.opponent_towers]:
		for t in side:
			var id: int = t.get_instance_id()
			var cur: float = t.hp
			if _thp.has(id):
				var was_alive: bool = float(_thp[id]) > 0.0
				var d: float = float(_thp[id]) - cur
				if d > 0.5:
					_on_hit(id, t.pos + _screen_up_tiles(t.fh * 0.5), d)   # 伤害数字锚在塔身上部（屏幕语义）
					if was_alive and t.is_destroyed():
						_on_tower_destroyed(t.pos, t.is_king())
			_thp[id] = cur

func _on_hit(id: int, pos: Vector2, amount: float, unit_id: String = "") -> void:
	_flash[id] = _elapsed + FLASH_DUR
	var big: bool = amount >= HITSTOP_DMG
	_spawn_dmgnum(pos, "%d" % int(round(amount)), Color(1, 0.92, 0.45) if big else Color.WHITE, 24 if big else 18)
	var hfx: Dictionary = SpriteDB.unit_fx(unit_id, "hit")
	if hfx.is_empty():
		_sparks.append({"pos": pos, "t0": _elapsed, "dur": SPARK_DUR})
	else:   # 0715 配套受击星芒：替换程序化火花（伤害数字/闪白/顿帧照旧）
		_spawn_unit_fx(hfx, pos, false)
	if big:
		_hitstop_t = maxf(_hitstop_t, HITSTOP_DUR)
		_shake_mag = minf(SHAKE_MAX, maxf(_shake_mag, SHAKE_BIG))
		AudioManager.play_sfx("hit_heavy")
	elif amount >= SHAKE_HIT_DMG:
		_shake_mag = minf(SHAKE_MAX, maxf(_shake_mag, SHAKE_HIT))
		AudioManager.play_sfx("hit_medium")
	else:
		AudioManager.play_sfx("hit_light")

func _on_tower_destroyed(pos: Vector2, king: bool) -> void:
	_hitstop_t = maxf(_hitstop_t, HITSTOP_DUR)
	_shake_mag = minf(SHAKE_MAX, maxf(_shake_mag, SHAKE_TOWER))
	_fx.append({"pos": pos, "t0": _elapsed, "dur": 0.6, "kind": "fireball", "radius": 2.5})
	AudioManager.play_sfx("tower_destroy_king" if king else "tower_destroy_princess")


# 远程兵开火检测（路线 A）：攻击冷却上升沿 = 刚出手 → 发射 attacker→target 投射物。
func _detect_attacks() -> void:
	var b = _client.match_obj.battle
	if b == null or b.arena == null:
		return
	for u in b.arena.get_units():
		if not u.is_alive():
			continue
		var ranged: bool = PROJ_KIND.has(u.unit_id) and u.attack_range >= PROJ_RANGED_MIN
		var slash_fx: Dictionary = SpriteDB.unit_fx(u.unit_id, "attack")   # 0715 近战刀光配套
		if not ranged and slash_fx.is_empty():
			continue
		var id: int = u.get_instance_id()
		var cur: float = u._attack_cooldown
		var prev: float = _atkcd.get(id, cur)
		_atkcd[id] = cur
		if cur > prev + 0.01:
			var ct = u.current_target
			if ct != null and is_instance_valid(ct):
				if ranged:
					var dist: float = u.pos.distance_to(ct.pos)
					_projectiles.append({"from": _disp_pos(u), "to": ct.pos, "t0": _elapsed,
							"dur": clampf(dist / PROJ_SPEED, 0.1, 0.45), "kind": PROJ_KIND[u.unit_id]})
					_play_projectile_audio(String(PROJ_KIND[u.unit_id]))
				else:   # 近战刀光落在目标身上；素材默认朝左挥，目标在攻击者右侧时水平镜像。
					# 镜像判定用屏幕 x（_t2s 已含 _flip），side2 视角自动正确。
					_spawn_unit_fx(slash_fx, ct.pos, _t2s(ct.pos).x > _t2s(u.pos).x)
	# 塔射箭：塔反击冷却上升沿 = 刚 mark_attacked → 从塔身射箭到射程内最近敌兵。
	for side in [b.player_towers, b.opponent_towers]:
		for t in side:
			if not t.is_alive() or t.damage <= 0.0:
				continue
			var tid: int = t.get_instance_id()
			var tcur: float = t._attack_cooldown
			var tprev: float = _tatkcd.get(tid, tcur)
			_tatkcd[tid] = tcur
			if tcur > tprev + 0.01:
				var victim = _tower_target(t)
				if victim != null:
					var muzzle: Vector2 = (t.pos as Vector2) + _screen_up_tiles(float(t.fh) * 0.4)   # 箭口=塔身上部（屏幕语义）
					var tdist: float = muzzle.distance_to(victim.pos)
					_projectiles.append({"from": muzzle, "to": victim.pos, "t0": _elapsed,
							"dur": clampf(tdist / PROJ_SPEED, 0.1, 0.5), "kind": "arrow"})

# 塔射程内最近的存活敌方单位（view 侧复刻 arena 选择，路线 A）；无则 null。
func _tower_target(t):
	var best = null
	var best_d := INF
	var r: float = float(t.attack_range) + 0.001
	for u in _client.match_obj.battle.arena.get_units():
		if not u.is_alive() or u.owner_id == t.owner_id:
			continue
		var d: float = (t.pos as Vector2).distance_to(u.pos as Vector2)
		if d <= r and d < best_d:
			best_d = d
			best = u
	return best


# 投射物：from→to 线性飞行，按 kind 画箭/法术弹/火球。
func _draw_projectiles() -> void:
	var tp := _tile_px()
	var ur: float = (tp.x + tp.y) * 0.5
	for pr in _projectiles:
		var t: float = clampf((_elapsed - pr["t0"]) / pr["dur"], 0.0, 1.0)
		var a: Vector2 = _t2s(pr["from"])
		var b: Vector2 = _t2s(pr["to"])
		var pos: Vector2 = a.lerp(b, t)
		match pr["kind"]:
			"arrow":
				var dir: Vector2 = (b - a)
				dir = dir.normalized() if dir.length() > 0.001 else Vector2.UP
				var perp := Vector2(-dir.y, dir.x)
				var col := Color(0.93, 0.88, 0.6)
				draw_line(pos - dir * ur * 0.7, pos, col, 2.0)
				draw_line(pos, pos - dir * 5.0 + perp * 3.0, col, 1.5)
				draw_line(pos, pos - dir * 5.0 - perp * 3.0, col, 1.5)
			"bolt":
				draw_circle(pos, ur * 0.24, Color(0.8, 0.55, 1.0, 0.85))
				draw_circle(pos, ur * 0.12, Color(1, 1, 1, 0.95))
			"fireball":
				var fi: int = 1 + int(_elapsed * 14.0) % 7
				var sz: float = ur * 1.0
				draw_texture_rect_region(TEX_PROJ_FIREBALL, Rect2(pos - Vector2(sz, sz) * 0.5, Vector2(sz, sz)),
						Rect2(fi * PROJ_FB_FPX, 0, PROJ_FB_FPX, PROJ_FB_FPX))

func _play_projectile_audio(kind: String) -> void:
	match kind:
		"arrow": AudioManager.play_sfx("bow_shot")
		"bolt": AudioManager.play_sfx("magic_bolt_cast")
		"fireball": AudioManager.play_sfx("fire_skull_shot")


func _spawn_dmgnum(pos: Vector2, text: String, col: Color, size: int) -> void:
	_dmgnums.append({"pos": pos, "text": text, "col": col, "size": size, "t0": _elapsed, "dur": DMGNUM_DUR})

func _update_disp(delta: float) -> void:
	var b = _client.match_obj.battle
	if b == null or b.arena == null:
		return
	var alpha: float = 1.0 - exp(-SMOOTH_K * delta)
	for u in b.arena.get_units():
		if not u.is_alive():
			continue
		var id: int = u.get_instance_id()
		if _disp.has(id):
			_disp[id] = (_disp[id] as Vector2).lerp(u.pos, alpha)
		else:
			_disp[id] = u.pos

func _update_shake(delta: float) -> void:
	if _shake_mag <= 0.05:
		_shake = Vector2.ZERO
		_shake_mag = 0.0
		return
	_shake = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * _shake_mag
	_shake_mag = maxf(0.0, _shake_mag - SHAKE_DECAY * delta)


# 命中火花（径向短线）+ 浮动伤害数字。
func _draw_combat_fx() -> void:
	var tp := _tile_px()
	var ur: float = (tp.x + tp.y) * 0.5
	for s in _sparks:
		var p: float = clampf((_elapsed - s["t0"]) / s["dur"], 0.0, 1.0)
		var c: Vector2 = _t2s(s["pos"])
		var rr: float = ur * (0.2 + 0.6 * p)
		var al: float = 1.0 - p
		for k in 6:
			var dir := Vector2(cos(float(k) / 6.0 * TAU), sin(float(k) / 6.0 * TAU))
			draw_line(c + dir * rr * 0.4, c + dir * rr, Color(1, 1, 0.6, al), 1.5)
	for dn in _dmgnums:
		var p2: float = clampf((_elapsed - dn["t0"]) / dn["dur"], 0.0, 1.0)
		var c2: Vector2 = _t2s(dn["pos"]) + Vector2(-8.0, -ur * 0.8 - DMGNUM_RISE * p2)
		var col: Color = dn["col"]
		col.a = 1.0 - p2
		draw_string(_font, c2, dn["text"], HORIZONTAL_ALIGNMENT_LEFT, -1, int(dn["size"]), col)


# 入场缩放：新兵从 0.35 弹到 1.0（ease-out）。
func _pop_scale(id: int) -> float:
	var t0: float = _seen.get(id, _elapsed)
	var p: float = (_elapsed - t0) / POP_DUR
	if p >= 1.0:
		return 1.0
	var s: float = clampf(p, 0.0, 1.0)
	return 0.35 + 0.65 * (1.0 - pow(1.0 - s, 3.0))


# —— HUD：手牌 ——
func _build_cards() -> void:
	for b in _card_btns:
		b.queue_free()
	_card_btns.clear()
	_card_base_pos.clear()
	var n := 4
	var bw := (_vw - 16.0 * (n + 1)) / n
	for i in n:
		var b := Button.new()
		b.position = Vector2(16.0 + i * (bw + 16.0), _vh - HUD_BOTTOM_H + 40.0)
		b.size = Vector2(bw, HUD_BOTTOM_H - 56.0)
		b.button_down.connect(_on_card_down.bind(i))
		b.button_up.connect(_on_card_up.bind(i))
		var empty := StyleBoxEmpty.new()             # 透明：仅输入热区，卡面 _draw_cards 自绘
		for sn in ["normal", "hover", "pressed", "disabled", "focus", "hover_pressed"]:
			b.add_theme_stylebox_override(sn, empty)
		b.focus_mode = Control.FOCUS_NONE
		b.text = ""
		add_child(b)
		_card_btns.append(b)
		_card_base_pos.append(b.position)
	_sync_cards()

func _on_card_down(i: int) -> void:
	if _ending or not GameStateScript.is_online_ready():
		return
	_selected = i
	_dragging = true
	_drag_screen = get_viewport().get_mouse_position()
	AudioManager.play_sfx("ui_card_pickup")

func _on_card_up(i: int) -> void:
	var was := _dragging
	var sc := _selected
	_dragging = false
	_selected = -1
	if not was or sc != i or _client == null or _client.match_obj == null or _ending or not GameStateScript.is_online_ready():
		return
	var screen: Vector2 = get_viewport().get_mouse_position()
	if screen.y < TOPBAR_H or screen.y > _vh - HUD_BOTTOM_H:
		AudioManager.play_sfx("ui_card_cancel")
		return
	var lp = _local_player()
	if lp == null:
		return
	var hand: Array = lp.deck.get_hand()
	if sc >= hand.size() or hand[sc] == null:
		return
	var cid: String = str(hand[sc])
	if not lp.can_play(sc):
		return
	# 兵牌落点须本方半场合法（法术不限）；非法不发。owner = 本方 owner。
	var drop: Vector2 = _drop_tile()
	if _card_info(cid)["spawn"] and not _client.match_obj.battle.arena.can_deploy(_client.your_side - 1, drop):
		AudioManager.play_sfx("ui_card_drop_invalid")
		return
	# 联机：发 deploy 指令（不当场落子，等服务端广播回来两端同 tick 落子）。
	# 落地 FX/法术音效不在这里播——改由 _on_deploy_applied 在指令真正落子时触发，
	# 这样对手也能看到/听到本方的法术，且 FX 与落子 tick 对齐（lockstep 表现层对齐）。
	_client.send_deploy(cid, drop)
	AudioManager.play_sfx("ui_card_drop_valid")   # 仅本地即时反馈：卡已松手投出

# 某条出兵指令在两端同 tick 落子（含本方自己的，服务端回广播）→ 落地 FX + 法术/出兵音效。
# 写在这里而非 _on_card_up：保证对手出的法术/兵在本端也看得到/听得到（lockstep 表现层对齐）。
func _on_deploy_applied(_side: int, card_id: String, pos: Vector2) -> void:
	var kind: String = FX_KIND.get(card_id, "spawn")
	var info: Dictionary = _card_info(card_id)
	_fx.append({"pos": pos, "t0": _elapsed, "dur": _fx_dur(kind), "kind": kind, "radius": float(info["radius"])})
	_play_card_audio(card_id, info)

func _sync_cards() -> void:
	var lp = _local_player()
	if lp == null or _client == null or _client.match_obj == null:
		return
	var hand: Array = lp.deck.get_hand()
	for i in _card_btns.size():
		var b: Button = _card_btns[i]
		b.disabled = not (i < hand.size() and hand[i] != null and lp.can_play(i))


# 自绘卡面：底板 + 卡面图(兵牌精灵/法术图标) + 卡名 + 费用珠 + 不可用扫光 + 选中高亮 + 拖拽抬起。
func _draw_cards() -> void:
	var lp = _local_player()
	if lp == null:
		return
	var hand: Array = lp.deck.get_hand()
	var e = lp.elixir
	for i in _card_btns.size():
		if i >= _card_base_pos.size():
			continue
		var sz: Vector2 = (_card_btns[i] as Button).size
		var lifted: bool = _dragging and i == _selected
		var pos: Vector2 = _card_base_pos[i] - Vector2(0, 14.0 if lifted else 0.0)
		var rect := Rect2(pos, sz)
		var sel: bool = i == _selected
		draw_rect(rect, COL_CARD_SEL if sel else COL_CARD_BG)
		if i < hand.size() and hand[i] != null:
			var cid := str(hand[i])
			_draw_card_art(cid, pos + Vector2(sz.x * 0.5, sz.y * 0.54), minf(sz.x, sz.y) * 0.66)
			var cost: int = lp.card_cost(cid)
			var affordable: bool = e.get_int() >= cost
			_text(pos + Vector2(7, 22), _short(tr("card_" + cid), 10), Color.WHITE if affordable else Color(0.62, 0.62, 0.66), 14)
			draw_circle(pos + Vector2(15, sz.y - 15), 11.0, COL_ELIXIR)
			_text(pos + Vector2(11, sz.y - 10), "%d" % cost, Color.WHITE, 14)
			if not affordable:
				var prog: float = clampf(e.get_amount() / float(maxi(1, cost)), 0.0, 1.0)
				draw_rect(Rect2(pos.x, pos.y, sz.x, sz.y * (1.0 - prog)), Color(0, 0, 0, 0.55))
		if sel:
			draw_rect(rect, COL_CROWN, false, 3.0)
		else:
			draw_rect(rect, COL_PANEL_EDGE, false, 2.0)

# 卡面图：兵牌=单位精灵正面静帧（自然色）；法术牌=代表特效图标。
func _draw_card_art(cid: String, c: Vector2, box: float) -> void:
	var info: Dictionary = _card_info(cid)
	if info["spawn"]:
		var spr: Dictionary = SpriteDB.frame(str(info["unit_id"]), "walk", 1, 0.0)   # owner=1→正面行
		if not spr.is_empty():
			draw_texture_rect_region(spr["tex"], Rect2(c - Vector2(box, box) * 0.5, Vector2(box, box)), spr["src"], spr.get("tint", Color.WHITE))
			return
	_draw_card_spell_icon(cid, c, box)

func _draw_card_spell_icon(cid: String, c: Vector2, box: float) -> void:
	var r := Rect2(c - Vector2(box, box) * 0.5, Vector2(box, box))
	var s: float = box * 0.42
	match FX_KIND.get(cid, ""):
		"fireball":
			draw_texture_rect_region(TEX_EXPLOSION, r, Rect2(4 * EXPLOSION_FPX, 0, EXPLOSION_FPX, EXPLOSION_FPX))
		"lightning":
			draw_texture_rect_region(TEX_LIGHTNING, r, Rect2(4 * FX_SEQ_FPX, 0, FX_SEQ_FPX, FX_SEQ_FPX))
		"zap":
			draw_texture_rect_region(TEX_RED_ENERGY, r, Rect2(4 * FX_SEQ_FPX, 0, FX_SEQ_FPX, FX_SEQ_FPX))
		"arrows":
			for k in 3:
				var ox: float = (float(k) - 1.0) * s * 0.55
				draw_line(c + Vector2(ox, s * 0.7), c + Vector2(ox, -s * 0.7), Color(0.93, 0.86, 0.6), 2.0)
				draw_line(c + Vector2(ox, -s * 0.7), c + Vector2(ox - 3, -s * 0.7 + 5), Color(0.93, 0.86, 0.6), 2.0)
				draw_line(c + Vector2(ox, -s * 0.7), c + Vector2(ox + 3, -s * 0.7 + 5), Color(0.93, 0.86, 0.6), 2.0)
		"log":
			draw_circle(c, s * 0.85, Color(0.50, 0.42, 0.30))
			draw_arc(c, s * 0.85, 0.0, TAU, 18, Color(0.28, 0.22, 0.16), 2.5)
		"heal":
			draw_line(c - Vector2(s * 0.6, 0), c + Vector2(s * 0.6, 0), Color(0.4, 1.0, 0.5), 4.0)
			draw_line(c - Vector2(0, s * 0.6), c + Vector2(0, s * 0.6), Color(0.4, 1.0, 0.5), 4.0)
		_:
			pass

func _short(s: String, n: int) -> String:
	return s if s.length() <= n else s.substr(0, n - 1) + "…"


# —— 胜负演出（全 _draw 驱动；由 _on_result 服务端信号触发，result 是 side 语义）——
# F1 起结算层走 UI.modal 弹窗层（CanvasLayer 50）：根治 KAN-98——原先本层建于 _ready、
# 手牌按钮建于进房后 _build_cards，Control 输入按树序命中 → 按钮压在结算层之上拦不住；
# 弹窗层高于场景层，输入隔离由层级保证，与建立顺序无关。
func _build_result_panel() -> void:
	_end_result_layer = ModalScript.new()
	_end_result_layer.dim_alpha = 0.0   # 结算暗幕由 _draw_end_screen 渐入演出，本层只拦输入+装按钮

func _exit_tree() -> void:
	# 对局未结束就离场（结算层从未入树）时手动释放；入树后由 UI 层随场景切换清理。
	if _end_result_layer != null and not _end_result_layer.is_inside_tree():
		_end_result_layer.free()

func _start_ending() -> void:
	if _ending:
		return
	_ending = true
	_end_t = 0.0
	UI.modal(_end_result_layer)   # 推入弹窗层：演出期不能出牌（场景切换时自动清）
	# 服务端 winner: 0=平/1=side1/2=side2。本方胜利 = winner == my_side。
	var mine := 1 if not _flip else 2
	if _end_winner == 0:
		AudioManager.play_sfx("stinger_draw")
	elif _end_winner == mine:
		AudioManager.play_sfx("stinger_victory")
	else:
		AudioManager.play_sfx("stinger_defeat")

func _add_result_buttons() -> void:
	_end_buttons_added = true
	_result_btn(tr("btn_rematch"), _vh * 0.62, _on_rematch)
	_result_btn(tr("btn_menu"), _vh * 0.62 + 70.0, _on_menu)
	_end_result_layer.modulate = Color(1, 1, 1, 0.0)
	create_tween().tween_property(_end_result_layer, "modulate:a", 1.0, 0.3)

func _draw_end_screen() -> void:
	if not _ending:
		return
	var mine := 1 if not _flip else 2
	var dimp: float = clampf(_end_t / 0.35, 0.0, 1.0)
	draw_rect(Rect2(0, 0, _vw, _vh), Color(0, 0, 0, 0.62 * dimp))
	var win: bool = _end_winner == mine and _end_winner != 0
	var lose: bool = _end_winner != 0 and _end_winner != mine
	var title := tr("result_win") if win else (tr("result_lose") if lose else tr("result_draw"))
	var tcol: Color = COL_SELF if win else (COL_FOE if lose else Color.WHITE)
	# 标题 sting：透明淡入 + 字号回弹放大
	var ti: float = clampf(_end_t / 0.45, 0.0, 1.0)
	var fs: int = int(40.0 + 24.0 * _ease_back(ti))
	tcol.a = ti
	draw_string(_font, Vector2(0, _vh * 0.34), title, HORIZONTAL_ALIGNMENT_CENTER, _vw, fs, tcol)
	# 王冠落入（你拆掉的敌塔数，逐个延迟 + 回弹下落）
	var earned: int = _crowns(_foe_towers())
	var cw := 56.0
	var sx: float = _vw * 0.5 - float(earned - 1) * cw * 0.5
	for i in earned:
		var lt: float = clampf((_end_t - 0.2 - float(i) * 0.12) / 0.4, 0.0, 1.0)
		if lt <= 0.0:
			continue
		var yb: float = _ease_back(lt)
		_draw_crown(Vector2(sx + float(i) * cw, _vh * 0.46 - 60.0 * (1.0 - yb)), 40.0, COL_CROWN, true)
	# 比分滚动（本方:敌方塔血）
	var cu: float = clampf((_end_t - 0.3) / 0.7, 0.0, 1.0)
	var pscore: float = _client.match_obj.battle.total_tower_hp(_my_towers())
	var oscore: float = _client.match_obj.battle.total_tower_hp(_foe_towers())
	var sc := Color(1, 1, 1, clampf(_end_t * 2.0, 0.0, 1.0))
	draw_string(_font, Vector2(0, _vh * 0.56), tr("result_score") % [int(round(pscore * cu)), int(round(oscore * cu))],
			HORIZONTAL_ALIGNMENT_CENTER, _vw, 22, sc)

# back-out 缓动（0→1，末段回弹过冲 >1）。
func _ease_back(t: float) -> float:
	var c1 := 1.70158
	var c3 := c1 + 1.0
	var x: float = clampf(t, 0.0, 1.0) - 1.0
	return 1.0 + c3 * x * x * x + c1 * x * x

func _result_btn(txt: String, y: float, cb: Callable) -> void:
	var b := Button.new()
	b.text = txt
	b.position = Vector2(_vw * 0.5 - 120, y)
	b.size = Vector2(240, 56)
	b.pressed.connect(cb)
	_end_result_layer.add_child(b)

func _on_rematch() -> void:
	AudioManager.play_sfx("ui_button_press")
	Router.reload()

func _on_menu() -> void:
	AudioManager.play_sfx("ui_button_back")
	Router.goto("main_menu")


func _unhandled_input(event: InputEvent) -> void:
	if _ending and _end_buttons_added and event is InputEventMouseButton and event.pressed:
		# 演出完毕后点空白也可回主菜单（按钮已淡入可点，此处兜底）。
		pass
