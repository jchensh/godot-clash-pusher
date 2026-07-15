# BattleScene —— 显示层（V3 2D；V3-6a 起加交互手感）。
#
# 只读 Match/Arena 的逻辑状态作画；出牌一律经 player.try_play_card（玩家/AI 对称）。
# 抽象 tile 空间 → 屏幕像素的映射只活在本层（_t2s/_s2t）。
# y=0 敌方底线(屏上)、y=grid_h 玩家底线(屏下)；河横贯中部、左右双桥。
# 出牌 = 拖拽部署（CR 式，决策 41）：按手牌→拖到场上(落点抬到手指上方)→松手落子；
#   拖拽中画落点 ghost(兵剪影/AOE 圈/直伤准星)+合法绿/非法红 + 己方半场高亮；成功落子有涟漪、新兵入场缩放。
# V3-6b 加战斗 juice：移动插值(10Hz→60fps)/受击闪白+浮动伤害数字/命中顿帧/震屏/命中火花（全显示层派生）。
# V3-6c 加 HUD 反馈：分段圣水条+满槽脉动、卡面自绘(费用/不可用扫光/选中)+下一张预览、王冠/倒计时强调。
# 仍为白膜：精灵/粒子皮在 V3-7 接续。
extends Node2D

const MatchScript = preload("res://logic/match.gd")
const BattleScript = preload("res://logic/battle.gd")
const AIControllerScript = preload("res://ai/ai_controller.gd")
const GameStateScript = preload("res://view/game_state.gd")
const RunModifiersScript = preload("res://logic/run_modifiers.gd")
const SpriteDB = preload("res://view/sprite_db.gd")
const FxDraw = preload("res://view/fx_draw.gd")
const HudWidgets = preload("res://view/ui/hud_widgets.gd")   # V5-S9 玩家名片
const ModalScript = preload("res://view/ui/modal.gd")        # F1 弹窗基类（结算层走 UI.modal，KAN-97）
const StageProgressScript = preload("res://logic/stage_progress.gd")   # V5-S7c 闯关判星
const PveRecorderScript = preload("res://net/pve_recorder.gd")         # KAN-79 防作弊录制

const TOPBAR_H := 54.0
const HUD_BOTTOM_H := 176.0

const COL_BG := Color(0.10, 0.12, 0.11)
const COL_PLAYER := Color(0.35, 0.60, 1.0)
const COL_OPPONENT := Color(1.0, 0.42, 0.38)
const COL_ELIXIR := Color(0.80, 0.33, 0.96)
const COL_PANEL := Color(0.10, 0.08, 0.14, 0.96)   # HUD 底，对齐 PixelUI 夜色石板
const COL_PANEL_EDGE := Color(0.34, 0.30, 0.45)    # HUD 底板像素高光描边
const COL_OK := Color(0.45, 1.0, 0.55)        # 落点合法（ghost/高亮）
const COL_BAD := Color(1.0, 0.42, 0.40)       # 落点非法

const DROP_LIFT_TILES := 1.6                   # 落点抬到手指上方（拇指不遮挡，CR 式）
const POP_DUR := 0.22                          # 新单位入场缩放时长（秒）
const POOF_DUR := 0.40                         # 落地涟漪时长（秒）

# —— V3-6b 战斗 juice ——
const SMOOTH_K := 18.0                          # 位置插值平滑系数（越大越贴近逻辑位）
const FLASH_DUR := 0.12                         # 受击闪白时长
const DMGNUM_DUR := 0.75                        # 伤害数字停留时长
const DMGNUM_RISE := 34.0                       # 伤害数字上浮像素
const SPARK_DUR := 0.18                         # 命中火花时长
const SHAKE_DECAY := 42.0                       # 震屏衰减（像素/秒）
const SHAKE_MAX := 14.0                         # 震屏幅度上限
const SHAKE_HIT := 3.0                          # 中等命中震屏
const SHAKE_BIG := 6.0                          # 大伤害震屏
const SHAKE_TOWER := 12.0                       # 塔被摧毁震屏
const SHAKE_HIT_DMG := 80.0                     # 触发小震屏的单次伤害阈值
const HITSTOP_DMG := 200.0                      # 触发顿帧的单次伤害阈值
const HITSTOP_DUR := 0.06                       # 顿帧（冻结 sim）时长

# —— V3-6c HUD 反馈 ——
const COL_CARD_BG := Color(0.23, 0.21, 0.32, 0.96)    # 卡面底 = PixelUI 石板
const COL_CARD_SEL := Color(0.40, 0.33, 0.16, 0.97)   # 选中卡 = 暗金
const COL_CROWN := Color(0.925, 0.725, 0.305)         # 王冠/强调金 = PixelUI COL_GOLD

# —— V3-6d 胜负演出 ——
const END_BTN_DELAY := 0.85                     # 结算按钮淡入延迟（先放胜负演出）

# —— V3-7 精灵贴图（架构 A：immediate _draw + draw_texture；逻辑零改）——
# 单位精灵走 SpriteDB(manifest，含帧网格/走攻行/朝向)；塔/落地 FX 仍在此 preload（塔皮 7b-2、FX 7b-3 再细化）。
# 三国正式塔（0715）：阵营分色贴图（我=蓝顶/敌=红顶）；素材自带配色 → natural 轻染 22% 不再乘 0.5 队伍色。
const TEX_TOWER_KING_BLUE := preload("res://assets/towers/sanguo_tower_king_blue.png")
const TEX_TOWER_KING_RED := preload("res://assets/towers/sanguo_tower_king_red.png")
const TEX_TOWER_ARROW_BLUE := preload("res://assets/towers/sanguo_tower_arrow_blue.png")
const TEX_TOWER_ARROW_RED := preload("res://assets/towers/sanguo_tower_arrow_red.png")
const TEX_EXPLOSION := preload("res://assets/fx/Fire_Explosion_28x28.png")
const EXPLOSION_FPX := 28
const EXPLOSION_N := 12
const TEX_LIGHTNING := preload("res://assets/fx/Lightning_Energy_48x48.png")   # 闪电术命中（扩散电能环）
const TEX_RED_ENERGY := preload("res://assets/fx/Red_Energy_48x48.png")        # 电火花命中（红电环）
const FX_SEQ_FPX := 48        # Lightning/Red_Energy 帧尺寸
const FX_SEQ_N := 9
# 卡 id → 命中 FX 类型；未列出（含 spawn 兵牌）= 中性落地尘土。
const FX_KIND := {
	"fireball": "fireball", "lightning": "lightning", "zap": "zap",
	"arrows": "arrows", "log": "log", "heal": "heal",
}
# —— 远程投射物（路线 A：view 侧检测攻击冷却上升沿=开火）——
const TEX_PROJ_FIREBALL := preload("res://assets/units/fire_skull_fireball.png")
const PROJ_FB_FPX := 16
const PROJ_SPEED := 16.0       # 投射物飞行速度 tile/s
const PROJ_RANGED_MIN := 2.5   # attack_range ≥ 此值才出投射物（排除近战/短手）
const PROJ_KIND := {"archer_body": "arrow", "musketeer_body": "bolt", "baby_dragon_body": "fireball"}
# —— 战场整图背景（三国美术；BG_ENABLED=false 回退 tile 铺地）——
# 特征对齐：以「双桥中心定 x 缩放 + 河中心锚 y」等比取源贴 _field_rect（直接拉伸会变形、桥错位），
# 特征像素为 python 测量值（水带行/桥木色列质心）。0715 新 BG 720×1502：黄土路正好绕六塔逻辑位画。
const TEX_BATTLE_BG := preload("res://assets/map/battle_bg.png")
const BG_ENABLED := true
const BG_BRIDGE1_PX := 188.8   # 图上左桥中心 x（px）
const BG_BRIDGE2_PX := 505.2   # 图上右桥中心 x（px）
const BG_RIVER_PX := 648.0     # 图上河带中心 y（px）
# 单位脚下阴影（正式素材配套；SpriteDB 条目带 "shadow": true 才画）
const TEX_UNIT_SHADOW := preload("res://assets/units/unit_shadow.png")
# —— 地形 tile（7b-4，Lonesome Summer；16px tile 逐逻辑格铺，与河行/桥列对齐）——
const TEX_FLOOR := preload("res://assets/terrain/Lonesome_Forest_FLOOR.png")
const TEX_WATER := preload("res://assets/terrain/simple_water_spritesheet.png")   # 河水动画 4×3=12 帧
const TEX_BRIDGE := preload("res://assets/terrain/Lonesome_Forest_COBBLESTONE_PATH.png")
const TILE_PX := 16
const GROUND_TILES := [Vector2i(4, 1), Vector2i(4, 2)]   # 纯土满铺双变体
const BRIDGE_TILES := [Vector2i(1, 1), Vector2i(2, 1)]   # 鹅卵石桥
const WATER_COLS := 4
const WATER_N := 12
const WATER_FPS := 5.0

# 兵种白膜外形（半径 tile，按队伍色填充；空军画环标记）。精灵渲染框也以 r 为基（×SpriteDB scale）。
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
	# A2.5 三国占位（2026-07-04）：新单位半径按体型档（极小0.35/小0.4/中0.5/大0.62/巨0.85）。
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

var match_obj
var loader
var _font: Font
var _landscape := false       # H2 横版实验（PLAN_V5_HBATTLE）：true=我左敌右投影；只影响变换层，逻辑零感知
var selected_card := -1
var _card_btns: Array = []
# —— V3-5b 新手引导（仅战役有 tutorial 脚本的关）——
var _tut_steps: Array = []   # 当前关引导步骤（tutorial.json）；空=无引导
var _tut_i: int = -1         # 当前步下标；-1=无引导/已结束
var _tut_layer = null        # F2 教程输入实体（Modal，dim=0）：tap 步 STOP 吞点击、action 步 IGNORE 放行出牌
var _result_layer: Control
var _dragging := false
var _drag_screen := Vector2.ZERO
var _elapsed := 0.0
var _battle_elapsed := 0.0    # V5-S7c：累计 sim 战斗时长（不含顿帧/结束后），供星级 time_under 判定
var _fx: Array = []           # 落地涟漪：[{pos:Vector2(tile), t0:float, dur:float}]
var _seen: Dictionary = {}    # 单位 instance_id → 首见 _elapsed（入场缩放）
var _card_base_pos: Array = []
# —— V3-6b 战斗 juice 状态 ——
var _disp: Dictionary = {}    # 单位 id → 显示插值位（tile）
var _uhp: Dictionary = {}     # 单位 id → 上帧 hp
var _thp: Dictionary = {}     # 塔 id → 上帧 hp
var _flash: Dictionary = {}   # id → 闪白结束 _elapsed（单位+塔混用）
var _dmgnums: Array = []      # [{pos:Vector2(tile), text, col, size, t0, dur}]
var _sparks: Array = []       # [{pos:Vector2(tile), t0, dur}]
var _projectiles: Array = [] # 远程投射物：[{from,to:Vector2(tile), t0, dur, kind}]
var _atkcd: Dictionary = {}  # 单位 id → 上帧 _attack_cooldown（检测开火上升沿）
var _tatkcd: Dictionary = {} # 塔 id → 上帧 _attack_cooldown（塔射箭开火检测，A5-2）
# —— 0715 正式素材配套：单位特效（攻击刀光/受击星芒/死亡白烟）+ 镜像朝向 ——
var _ufx: Array = []         # [{pos:Vector2(tile), t0, dur, tex, fw, fh, n, size, flip}]
var _ulast: Dictionary = {}  # 单位 id → {pos, uid} 最后存活位置（死亡白烟定位，消失即触发）
var _face: Dictionary = {}   # 单位 id → 是否水平翻转（true=面朝右；mirror 条目用）
var _facex: Dictionary = {}  # 单位 id → 上帧屏幕 x（走路方向判定）
var _shake := Vector2.ZERO
var _shake_mag := 0.0
var _hitstop_t := 0.0
# —— V3-6d 胜负演出状态 ——
var _ending := false
var _end_t := 0.0
var _end_result := 0
# —— KAN-78/79 PVE 防作弊 ——
var _pve_recorder = null        # PveRecorder（闯关模式才建；null=其他模式零影响）
var _pve_battle_id: int = 0     # PveStart 下发的会话 id
var _pve_http: HTTPRequest = null
var _end_pscore := 0.0
var _end_oscore := 0.0
var _end_buttons_added := false
var _online_paused := false       # E1：在线闯关掉线时冻结 sim/输入并绘制恢复提示
var _stage_returning := false     # E1：战后最终 flush + 跳场景 single-flight
var _stage_result_button: Button = null

@onready var _vw: float = float(get_viewport_rect().size.x)
@onready var _vh: float = float(get_viewport_rect().size.y)

func _ready() -> void:
	# 修复空指针卡死：闯关模式 _ready 内有 await(pve_start 开战报到)，await 期间 match_obj 已建、
	# 但 player/battle 要等 await 后的 setup_stage 才建。处理默认开启会让 _process 在 await 窗口跑到
	# _sync_cards 访问 match_obj.player(Nil) 每帧报错卡死。故先关处理，末尾 setup 完再 set_process(true)。
	set_process(false)
	_font = load("res://assets/fonts/fusion-pixel-12px-proportional-zh_hans.ttf")
	loader = GameStateScript.config()
	match_obj = MatchScript.new(loader)
	var run = GameStateScript.run
	var campaign = GameStateScript.campaign
	var battle_music_id := "music_battle_normal"
	if campaign != null and not campaign.is_over():
		# 战役模式：当前关 level_id + 关卡默认教学卡组（不受组卡影响）。
		if campaign.current_focus() == "boss":
			battle_music_id = "music_battle_boss"
		Log.i("[V5][battle] 模式=战役 关=%s" % campaign.current_level_id())
		match_obj.setup(campaign.current_level_id(), [])
	elif run != null and not run.is_over():
		# Roguelite 模式：当前节点 level_id + run 卡组 + relic/节点难度修正器。
		var node: Dictionary = run.current_node()
		var node_type := String(node.get("type", "battle"))
		if node_type == "elite" or node_type == "boss":
			battle_music_id = "music_battle_boss"
		var mods: Array = RunModifiersScript.relic_mods(run.relics, loader.relics)
		var nm: Dictionary = RunModifiersScript.node_mod(loader.get_run("default"), node_type)
		if not nm.is_empty():
			mods.append(nm)
		Log.i("[V5][battle] 模式=肉鸽 关=%s" % String(node.get("level_id")))
		match_obj.setup(String(node.get("level_id")), run.deck, mods)
	elif GameStateScript.stage_id != "":
		# V5-S7c 闯关模式：setup_stage 注入 coef/遭遇/ai + 服务器拉来的养成档（for_battle，权威 level/rank）。
		# KAN-78 开战报到：拿 battle_id（服务器时钟记 started_at + 权威养成快照）；
		# 报到失败 = 不让开战（决策 48 断线即不可玩），弹回闯关地图。
		_pve_http = HTTPRequest.new()
		add_child(_pve_http)
		var start_res: Dictionary = await GameStateScript.economy().pve_start(
			_pve_http, GameStateScript.session().token(), GameStateScript.stage_id, GameStateScript.player_deck)
		if not bool(start_res.get("ok", false)):
			Log.w("[V5][pve] 开战报到失败 → 弹回闯关地图（断线即不可玩）")
			GameStateScript.stage_id = ""
			GameStateScript.deck_mode = ""
			Router.goto("stage_map")
			return
		_pve_battle_id = int(start_res.get("battle_id", 0))
		var pdata = GameStateScript.economy().for_battle(loader.cards.keys())
		Log.i("[V5][battle] 模式=闯关 stage=%s deck=%s battle_id=%d" % [GameStateScript.stage_id, str(GameStateScript.player_deck), _pve_battle_id])
		match_obj.setup_stage(GameStateScript.stage_id, GameStateScript.player_deck, pdata)
		# KAN-79：录制器挂双方出牌 + 周期哈希，战斗中批量上报（重放验证的证据链）。
		_pve_recorder = PveRecorderScript.new()
		_pve_recorder.battle_id = _pve_battle_id
		_pve_recorder.attach(match_obj)
	else:
		Log.i("[V5][battle] 模式=自由 关=%s" % GameStateScript.level_id)
		match_obj.setup(GameStateScript.level_id, GameStateScript.player_deck)
	# H2 横版实验开关：仅 PvE 生效；战役/新手引导强制竖版（教程高亮是竖版语义，且新手不吃实验特性）。
	var pve_free: bool = (campaign == null or campaign.is_over()) and not GameStateScript.tutorial
	_landscape = pve_free and GameStateScript.battle_layout() == "landscape"
	Log.i("[V5][battle] 版式=%s" % ("横版(实验·我左敌右)" if _landscape else "竖版"))
	# 0716 首批 BGM：普通战斗 = 双曲轮播集（曲终随机换）；boss 关保留专属曲意图（素材未到位时自动落轮播）
	if battle_music_id != "music_battle_boss" or not AudioManager.play_music(battle_music_id):
		AudioManager.play_music_set(["music_battle_normal", "music_battle_hunt"])
	AudioManager.play_ambience("amb_battle_wind")
	match_obj.set_opponent_controller(AIControllerScript.new(match_obj, loader))
	_build_cards()
	_build_result_panel()
	_init_tutorial()
	_build_player_nameplate()
	set_process(true)

func _process(delta: float) -> void:
	if match_obj == null:
		return
	_online_paused = GameStateScript.stage_id != "" and not GameStateScript.is_online_ready()
	_elapsed += delta
	if _hitstop_t > 0.0:
		_hitstop_t -= delta            # 顿帧：冻结 sim、画面继续
	elif not match_obj.is_over() and not _online_paused:
		match_obj.update(delta)
		_battle_elapsed += delta       # V5-S7c：仅活跃战斗时长计入（判 time_under 星）
		if _pve_recorder != null:
			# KAN-79：周期攒批上报（fire-and-forget 协程；HTTPRequest 忙时该批自动并入下批）。
			_pve_recorder.poll(delta, GameStateScript.economy(), _pve_http, GameStateScript.session().token())
	_detect_events()                   # 逐帧 diff hp → 伤害数字/闪白/火花/顿帧/震屏（路线 A）
	_detect_attacks()                  # 远程兵开火上升沿 → 投射物（路线 A）
	_update_disp(delta)                # 10Hz→60fps 位置插值
	_update_shake(delta)
	if _dragging:
		_drag_screen = get_viewport().get_mouse_position()
	_cull_transients()
	_sync_cards()
	if _online_paused:
		_dragging = false
		for button in _card_btns:
			(button as Button).disabled = true
	if match_obj.is_over() and not _ending:
		_start_ending()
	if _ending:
		_end_t += delta
		if _end_t >= END_BTN_DELAY and not _end_buttons_added:
			_add_result_buttons()
	queue_redraw()

# —— 坐标映射（H1 统一变换层：逻辑 tile ↔ 屏幕 px 只经本区块，绘制/输入代码禁止手算方向）——
# 逻辑坐标恒为竖版语义：x∈[0,grid_w) 横向、y∈[0,grid_h) 纵深、y 小=敌方（logic 层不知道屏幕）。
# H2 横版（_landscape，PLAN_V5_HBATTLE §2）：敌右我左，sx←(grid_h-y)、sy←x；
# 「屏幕向上 / 部署半场 / footprint」等方向语义全在本区块内翻转，区块外零方向假设。
func _field_rect() -> Rect2:
	var zone := Rect2(0.0, TOPBAR_H, _vw, _vh - TOPBAR_H - HUD_BOTTOM_H)
	var a = match_obj.battle.arena
	if _landscape:
		# H2 临时投影区（H5 切横屏窗口前）：竖屏场区内按 grid_h:grid_w 满宽 letterbox 垂直居中。
		var h: float = zone.size.x * float(a.grid_w) / float(a.grid_h)
		return Rect2(zone.position.x, zone.position.y + (zone.size.y - h) * 0.5, zone.size.x, h)
	# 竖版 32×32 正方形屏幕格（KAN-107，2026-07-13）：格边长取整数、letterbox 居中——
	# 720×1280 基准下 = 32px/格、场地 576×1024，两侧各 72px 装饰边栏（露 COL_BG 深底，边栏素材另出）。
	# 逻辑 18×32 与 _t2s/_s2t 契约不变；美术出图画布随之改 576×1024（1 格=32×32 整除）。
	var ts: float = floor(minf(zone.size.x / float(a.grid_w), zone.size.y / float(a.grid_h)))
	var fs := Vector2(ts * float(a.grid_w), ts * float(a.grid_h))
	return Rect2(zone.position + (zone.size - fs) * 0.5, fs)

func _t2s(p: Vector2) -> Vector2:
	var a = match_obj.battle.arena
	var fr := _field_rect()
	if _landscape:   # 逻辑 y=0（敌底线）→ 屏幕右缘；逻辑 x → 屏幕纵向
		return Vector2(fr.position.x + (a.grid_h - p.y) / a.grid_h * fr.size.x,
				fr.position.y + p.x / a.grid_w * fr.size.y) + _shake
	return Vector2(fr.position.x + p.x / a.grid_w * fr.size.x,
			fr.position.y + p.y / a.grid_h * fr.size.y) + _shake   # _shake 只动场内、HUD 不抖

func _s2t(s: Vector2) -> Vector2:
	var a = match_obj.battle.arena
	var fr := _field_rect()
	if _landscape:
		return Vector2((s.y - fr.position.y) / fr.size.y * a.grid_w,
				(1.0 - (s.x - fr.position.x) / fr.size.x) * a.grid_h)
	return Vector2((s.x - fr.position.x) / fr.size.x * a.grid_w,
			(s.y - fr.position.y) / fr.size.y * a.grid_h)

func _tile_px() -> Vector2:   # 一个逻辑格画在屏幕上的 (宽,高)
	var a = match_obj.battle.arena
	var fr := _field_rect()
	if _landscape:
		return Vector2(fr.size.x / a.grid_h, fr.size.y / a.grid_w)
	return Vector2(fr.size.x / a.grid_w, fr.size.y / a.grid_h)

func _ur() -> float:          # 单位绘制参考半径基准 = tile 屏幕边长均值（对投影方向不敏感）
	var tp := _tile_px()
	return (tp.x + tp.y) * 0.5

func _tile_rect(tx: int, ty: int) -> Rect2:   # 逻辑格 (tx,ty) 的屏幕矩形（terrain 铺 tile 用）
	if _landscape:
		return Rect2(_t2s(Vector2(tx, ty + 1)), _tile_px())   # y 翻转投影 → 屏幕左上角 = 逻辑 (tx, ty+1)
	return Rect2(_t2s(Vector2(tx, ty)), _tile_px())

func _fp_screen(fw: float, fh: float) -> Vector2:   # 建筑 footprint(逻辑格数) → 屏幕 (宽,高)
	var tp := _tile_px()
	if _landscape:
		return Vector2(fh * tp.x, fw * tp.y)   # 逻辑纵深(fh)→屏幕横向、逻辑宽(fw)→屏幕纵向
	return Vector2(fw * tp.x, fh * tp.y)

func _screen_up_tiles(n: float) -> Vector2:   # 「屏幕向上 n 格」对应的逻辑位移（塔顶锚点/箭口）
	if _landscape:
		return Vector2(-n, 0.0)   # 横版屏幕上方 = 逻辑 -x
	return Vector2(0.0, -n)

func _deploy_zone_rect(a) -> Rect2:   # 己方可部署半场的屏幕矩形（部署提示/高亮）
	var fr := _field_rect()
	if _landscape:   # 我方 y≥deploy_y_min 投影为屏幕左段 x≤x1
		var x1: float = _t2s(Vector2(0, a.deploy_player_y_min)).x
		return Rect2(fr.position.x, fr.position.y, x1 - fr.position.x, fr.size.y)
	var y0: float = _t2s(Vector2(0, a.deploy_player_y_min)).y
	return Rect2(fr.position.x, y0, fr.size.x, fr.position.y + fr.size.y - y0)

# —— 绘制 ——
func _draw() -> void:
	if match_obj == null or match_obj.battle == null or match_obj.battle.arena == null:
		return
	var a = match_obj.battle.arena
	draw_rect(Rect2(0, 0, _vw, _vh), COL_BG)
	_draw_terrain(a)
	_draw_deploy_hint(a)
	_draw_world(a)   # 塔+单位 Y-sort 伪深度单通道（0715 二验）
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
	_draw_tutorial()
	_draw_online_pause()


func _draw_online_pause() -> void:
	if not _online_paused:
		return
	# 覆盖层只做状态反馈；sim/出牌阻断仍由 _process 与输入 handler 的 ready gate 保证。
	draw_rect(Rect2(0, 0, _vw, _vh), Color(0, 0, 0, 0.58))
	var panel := Rect2(32.0, _vh * 0.42, _vw - 64.0, 116.0)
	draw_rect(panel, COL_PANEL)
	draw_rect(panel, COL_CROWN, false, 3.0)
	draw_string(_font, Vector2(panel.position.x, panel.position.y + 47.0), "在线会话中断",
			HORIZONTAL_ALIGNMENT_CENTER, panel.size.x, 24, Color.WHITE)
	draw_string(_font, Vector2(panel.position.x, panel.position.y + 84.0), "恢复中…",
			HORIZONTAL_ALIGNMENT_CENTER, panel.size.x, 20, COL_CROWN)

func _draw_terrain(a) -> void:
	if BG_ENABLED:
		_draw_bg_image(a)
	else:
		for ty in range(a.grid_h):
			for tx in range(a.grid_w):
				var t: int = a.tile_type(tx, ty)
				var rect := _tile_rect(tx, ty)
				rect.size += Vector2.ONE   # +1px 防瓦片间缝
				if t == a.TILE_WATER:
					_draw_water_tile(rect)
				elif t != a.TILE_TOWER and ty >= a.river_y_min and ty < a.river_y_max:
					_draw_bridge_tile(tx, ty, rect)   # 河行里的可走 = 桥
				else:
					_draw_ground_tile(tx, ty, rect, ty < a.grid_h / 2)   # 塔占位下也铺地（塔贴图透明盖上）
	# 己方半场可部署区描边提示
	draw_rect(_deploy_zone_rect(a), Color(0.4, 0.8, 0.5, 0.10))

# 整图背景按特征对齐贴进场地：给定「屏幕上桥1/桥2中心 x 与河中心 y 应落的位置」，
# 反解 BG 的源矩形（等比），使图上河/桥与逻辑河/桥重合。横版复用同一公式：
# 先 draw_set_transform 绕场心转 90°（图上方=敌方 → 屏幕右），在局部竖版矩形里作画。
func _draw_bg_image(a) -> void:
	var fr := _field_rect()
	var b1: float = (a.bridges[0]["x_min"] + a.bridges[0]["x_max"]) * 0.5 / float(a.grid_w)
	var b2: float = (a.bridges[1]["x_min"] + a.bridges[1]["x_max"]) * 0.5 / float(a.grid_w)
	var rv: float = (a.river_y_min + a.river_y_max) * 0.5 / float(a.grid_h)
	if _landscape:
		draw_set_transform(fr.get_center() + _shake, PI / 2)
		var vfr := Rect2(-fr.size.y * 0.5, -fr.size.x * 0.5, fr.size.y, fr.size.x)   # 局部竖版画布
		var off: Vector2 = Vector2(_vw, _vh) * 0.5 - fr.get_center()   # 屏幕视口映射进局部坐标（绕场心转 -90°），场外也铺 BG
		var vpl := Rect2(Vector2(off.y, -off.x) - Vector2(_vh, _vw) * 0.5, Vector2(_vh, _vw))
		var pl := _bg_full(vfr, vpl, _bg_src(vfr, b1, b2, rv))
		draw_texture_rect_region(TEX_BATTLE_BG, pl[0], pl[1])
		draw_set_transform(Vector2.ZERO)
	else:
		var pp := _bg_full(fr, Rect2(0.0, 0.0, _vw, _vh), _bg_src(fr, b1, b2, rv))
		draw_texture_rect_region(TEX_BATTLE_BG, Rect2((pp[0] as Rect2).position + _shake, (pp[0] as Rect2).size), pp[1])

func _bg_src(fr: Rect2, b1: float, b2: float, rv: float) -> Rect2:
	var s1: float = b1 * fr.size.x                                   # 桥1中心相对场地左缘（px）
	var s2: float = b2 * fr.size.x
	var k: float = (s2 - s1) / (BG_BRIDGE2_PX - BG_BRIDGE1_PX)       # 屏幕px / 图px 缩放
	var src_x: float = BG_BRIDGE1_PX - s1 / k
	var src_y: float = BG_RIVER_PX - rv * fr.size.y / k
	return Rect2(src_x, src_y, fr.size.x / k, fr.size.y / k)

# 0715：BG 铺满全屏——美术出图四周树林/湖是屏幕填充边（长屏适配），中心特征对齐即可。dest 从场地
# 矩形向四周扩到视口边、src 同步扩（以图边为界，不够处露 COL_BG；横版传局部坐标）。返回 [dest, src]。
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
	_blit_tile(TEX_FLOOR, cell, rect, Color(1.0, 0.90, 0.86) if enemy else Color.WHITE)  # 敌方半场微暖辨上下

func _draw_bridge_tile(tx: int, ty: int, rect: Rect2) -> void:
	_blit_tile(TEX_BRIDGE, BRIDGE_TILES[(tx + ty) % BRIDGE_TILES.size()], rect, Color.WHITE)

func _draw_water_tile(rect: Rect2) -> void:
	var fr: int = int(_elapsed * WATER_FPS) % WATER_N
	_blit_tile(TEX_WATER, Vector2i(fr % WATER_COLS, fr / WATER_COLS), rect, Color.WHITE)

# 塔绘制纯视觉 y 偏移（tile，+朝己方底线；逻辑塔位不动）：与 BG 路环节点对齐（0715 验收反馈，
# 二验追加：我王塔从 +0.5 上移一格 → -0.5）。
const TOWER_YOFF_TILE := {"king_p": -0.5, "arrow_e": -0.5}

# 塔绘制用屏幕锚点：中心 c（含 TOWER_YOFF_TILE 视觉偏移）；接地线 = c.y + footprint 高一半。
func _tower_anchor(t) -> Vector2:
	var okey: String = ("king_" if t.is_king() else "arrow_") + ("p" if t.owner_id == 0 else "e")
	return _t2s((t.pos as Vector2) + Vector2(0.0, float(TOWER_YOFF_TILE.get(okey, 0.0))))

# 0715 二验：单位/建筑伪深度 Y-sort——视角自屏幕下方往上看，按「接地线」升序绘制：
# 屏幕上方（远处）先画、被下方（近处）盖住；空军恒最上层。逐帧收集塔+单位统一排序（含 _seen 记账）。
func _draw_world(a) -> void:
	var items: Array = []
	for side in [match_obj.battle.player_towers, match_obj.battle.opponent_towers]:
		for t in side:
			items.append([_tower_anchor(t).y + _fp_screen(t.fw, t.fh).y * 0.5, items.size(), false, t])
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

func _draw_tower_one(t) -> void:
	var base: Color = COL_PLAYER if t.owner_id == 0 else COL_OPPONENT
	var king: bool = t.is_king()
	var c := _tower_anchor(t)
	var fp := _fp_screen(t.fw, t.fh)
	var foot_bottom: float = c.y + fp.y * 0.5            # footprint 底边 = 塔贴地处
	var mine: bool = t.owner_id == 0
	var tex: Texture2D
	if king:
		tex = TEX_TOWER_KING_BLUE if mine else TEX_TOWER_KING_RED
	else:
		tex = TEX_TOWER_ARROW_BLUE if mine else TEX_TOWER_ARROW_RED
	var ts: Vector2 = tex.get_size()
	# 保持长宽比、底部贴地；0715 中式塔纵高 → 系数比旧城堡压小防过高（真人验收可调）。
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

func _draw_unit_one(u, ur: float) -> void:
	var id: int = u.get_instance_id()
	var base: Color = COL_PLAYER if u.owner_id == 0 else COL_OPPONENT
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
	# 塔目标因占位较大，射程需加塔半径。
	var st := "walk"
	var ct = u.current_target
	if ct != null and is_instance_valid(ct):
		var reach: float = u.attack_range + 1.0
		if "fw" in ct:
			reach = u.attack_range + maxf(float(ct.fw), float(ct.fh)) * 0.5 + 0.5
		if u.pos.distance_to(ct.pos) <= reach:
			st = "attack"
	var spr: Dictionary = SpriteDB.frame(u.unit_id, st, u.owner_id, _elapsed)
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
		# 0715 mirror（单方向侧脸素材默认朝左）：攻击朝目标/走路朝移动方向/纵走保持上次；绕单位中心 -1 缩放翻转。
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

func _draw_topbar() -> void:
	draw_rect(Rect2(0, 0, _vw, TOPBAR_H), COL_PANEL)
	draw_rect(Rect2(0, TOPBAR_H - 3.0, _vw, 3.0), COL_PANEL_EDGE)   # 底部像素描边分隔
	var p_crowns := _crowns(match_obj.battle.opponent_towers)   # 你拆掉的敌塔
	var o_crowns := _crowns(match_obj.battle.player_towers)
	_text(Vector2(12, 28), tr("hud_you"), COL_PLAYER, 16)
	_draw_crowns(Vector2(54, 8), p_crowns, COL_PLAYER)
	_text(Vector2(_vw - 56, 28), tr("hud_enemy"), COL_OPPONENT, 16)
	_draw_crowns(Vector2(_vw - 150, 8), o_crowns, COL_OPPONENT)
	# 倒计时：低于 30s 红色脉动强调
	var t: float = match_obj.battle.remaining_time()
	var tcol := Color.WHITE
	var tsize := 24
	if t <= 30.0:
		var pulse: float = 0.5 + 0.5 * sin(_elapsed * 6.0)
		tcol = Color(1, 0.4, 0.35).lerp(Color(1, 0.9, 0.3), pulse)
		tsize = 27
	_text(Vector2(_vw * 0.5 - 30, 32), "%d:%02d" % [int(t) / 60, int(t) % 60], tcol, tsize)

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

func _draw_elixir() -> void:
	var e = match_obj.player.elixir
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
		draw_rect(Rect2(px, y, pip_w, 20.0), Color(0.10, 0.05, 0.12, 0.85))   # 空槽
		var fillf: float = clampf(amt - float(i), 0.0, 1.0)
		if fillf > 0.0:
			var col := COL_ELIXIR
			if full:
				col = COL_ELIXIR.lerp(Color(1, 0.85, 1), (0.5 + 0.5 * sin(_elapsed * 8.0)) * 0.6)
			draw_rect(Rect2(px, y, pip_w * fillf, 20.0), col)
	_text(Vector2(x0 + 4, y + 16.0), "%d" % e.get_int(), Color.WHITE, 14)
	_draw_next_chip(_vw - next_w - 4.0, y - 2.0, next_w - 6.0, 24.0)

func _draw_next_chip(x: float, y: float, w: float, h: float) -> void:
	var nx = match_obj.player.deck.peek_next()
	if nx == null:
		return
	draw_rect(Rect2(x, y, w, h), Color(0, 0, 0, 0.4))
	_text(Vector2(x + 5, y + 10), tr("hud_next"), Color(0.7, 0.7, 0.7), 10)
	_text(Vector2(x + 5, y + h - 4), _short(tr("card_" + str(nx)), 9), Color.WHITE, 11)
	var cost: int = match_obj.player.card_cost(nx)
	draw_circle(Vector2(x + w - 12, y + h * 0.5), 8.0, COL_ELIXIR)
	_text(Vector2(x + w - 15, y + h * 0.5 + 4.0), "%d" % cost, Color.WHITE, 11)

func _hp_color(ratio: float) -> Color:
	if ratio > 0.5:
		return Color(0.3, 0.85, 0.35)
	elif ratio > 0.25:
		return Color(0.95, 0.7, 0.2)
	return Color(0.9, 0.3, 0.25)

func _crowns(towers: Array) -> int:
	var n := 0
	for t in towers:
		if t.is_destroyed():
			n += 1
	return n

func _text(pos: Vector2, s: String, col: Color, size: int) -> void:
	draw_string(_font, pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)

# —— 出牌交互（拖拽部署，CR 式：按卡→拖到场上→松手落子，决策 41）——
# 落点抬到手指上方（拇指不遮挡）——「屏幕向上」为屏幕语义，在屏幕空间抬完再 _s2t，横竖版通用。
func _drop_tile_from(screen: Vector2) -> Vector2:
	var lift: float = _tile_px().y * DROP_LIFT_TILES
	return _s2t(screen + Vector2(0.0, -lift))

# 卡牌出什么：spawn=生成兵（含 unit_id/count）；否则法术（radius>0=AOE 圈、=0=直伤准星）。
func _card_info(cid) -> Dictionary:
	for sk in loader.get_card(cid).get("skills", []):
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
			AudioManager.play_sfx("spell_fireball_cast")
			AudioManager.play_sfx("spell_fireball_impact")
		"arrows":
			AudioManager.play_sfx("spell_arrows_cast")
			AudioManager.play_sfx("spell_arrows_impact")
		"zap":
			AudioManager.play_sfx("spell_zap_cast")
			AudioManager.play_sfx("spell_zap_impact")
		"lightning":
			AudioManager.play_sfx("spell_lightning_cast")
			AudioManager.play_sfx("spell_lightning_impact")
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
	if not _dragging or selected_card < 0 or match_obj.is_over():
		return
	var hand: Array = match_obj.player.deck.get_hand()
	if selected_card >= hand.size() or hand[selected_card] == null:
		return
	var info: Dictionary = _card_info(str(hand[selected_card]))
	var drop_tile: Vector2 = _drop_tile_from(_drag_screen)
	var ur: float = _ur()
	var legal: bool = a.can_deploy(0, drop_tile) if info["spawn"] else true
	var col: Color = COL_OK if legal else COL_BAD
	var c: Vector2 = _t2s(drop_tile)
	draw_arc(c, ur * 0.9, 0.0, TAU, 28, col, 2.5)   # 落点标记环
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
	if not _dragging or selected_card < 0:
		return
	var hand: Array = match_obj.player.deck.get_hand()
	if selected_card >= hand.size() or hand[selected_card] == null:
		return
	if not _card_info(str(hand[selected_card]))["spawn"]:
		return
	var pulse: float = 0.12 + 0.06 * (0.5 + 0.5 * sin(_elapsed * 6.0))
	draw_rect(_deploy_zone_rect(a), Color(COL_OK.r, COL_OK.g, COL_OK.b, pulse))

# 命中/落地 FX：按 kind 分派（sheet 序列帧 or 程序化）。AOE 卡用 radius 定大小。
func _draw_fx() -> void:
	var ur: float = _ur()
	for f in _fx:
		var p: float = clampf((_elapsed - f["t0"]) / f["dur"], 0.0, 1.0)
		var c: Vector2 = _t2s(f["pos"])
		var kind: String = f.get("kind", "spawn")
		var rt: float = float(f.get("radius", 0.0))
		match kind:   # 程序化/序列帧绘制助手在 view/fx_draw.gd（抽出腾行数）
			"fireball":
				FxDraw.seq(self, TEX_EXPLOSION, EXPLOSION_FPX, EXPLOSION_N, c, (rt * 2.0 * ur) if rt > 0.0 else ur * 2.6, p, Color.WHITE)
			"lightning":
				FxDraw.seq(self, TEX_LIGHTNING, FX_SEQ_FPX, FX_SEQ_N, c, (rt * 2.2 * ur) if rt > 0.0 else ur * 3.0, p, Color(0.85, 0.92, 1.0))
			"zap":
				FxDraw.seq(self, TEX_RED_ENERGY, FX_SEQ_FPX, FX_SEQ_N, c, ur * 2.0, p, Color.WHITE)
			"arrows":
				FxDraw.arrows(self, c, maxf(rt, 1.0) * ur, p)
			"log":
				FxDraw.dust(self, c, maxf(rt, 1.0) * ur, p, Color(0.60, 0.50, 0.36))
			"heal":
				FxDraw.heal(self, c, maxf(rt, 1.0) * ur, p)
			_:
				FxDraw.dust(self, c, ur * 1.2, p, Color(0.78, 0.74, 0.66))

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

# 各 FX 类型时长。
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
	_ufx = _cull_list(_ufx)
	_dmgnums = _cull_list(_dmgnums)
	_sparks = _cull_list(_sparks)
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

# —— V3-6b：逐帧 diff 逻辑状态派生反馈（受击/治疗/塔毁）——
func _disp_pos(u) -> Vector2:
	return _disp.get(u.get_instance_id(), u.pos)

func _detect_events() -> void:
	if match_obj.battle == null or match_obj.battle.arena == null:
		return
	var alive_now: Dictionary = {}
	for u in match_obj.battle.arena.get_units():
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
	for side in [match_obj.battle.player_towers, match_obj.battle.opponent_towers]:
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

# 远程兵开火检测（路线 A）：攻击冷却从 ~0 跳满 = 上升沿 = 刚出手 → 发射 attacker→target 投射物。
func _detect_attacks() -> void:
	if match_obj.battle == null or match_obj.battle.arena == null:
		return
	for u in match_obj.battle.arena.get_units():
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
		# 冷却跳升 = 刚 mark_attacked（逻辑层只会让冷却递减，唯有攻击会设回满）。
		# 注意不能用「prev≈0→cur满」：同 tick 内冷却减到 0 又立即设满，view 永远看不到 0，最低只见 ~0.1。
		if cur > prev + 0.01:
			var ct = u.current_target
			if ct != null and is_instance_valid(ct):
				if ranged:
					var dist: float = u.pos.distance_to(ct.pos)
					_projectiles.append({"from": _disp_pos(u), "to": ct.pos, "t0": _elapsed,
							"dur": clampf(dist / PROJ_SPEED, 0.1, 0.45), "kind": PROJ_KIND[u.unit_id]})
					_play_projectile_audio(String(PROJ_KIND[u.unit_id]))
				else:   # 近战刀光落在目标身上；素材默认朝左挥，目标在攻击者右侧时水平镜像
					_spawn_unit_fx(slash_fx, ct.pos, ct.pos.x > u.pos.x)
	# 塔射箭（A5-2）：塔反击冷却上升沿 = 刚 mark_attacked → 从塔身射箭到射程内最近敌兵。
	for side in [match_obj.battle.player_towers, match_obj.battle.opponent_towers]:
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
	for u in match_obj.battle.arena.get_units():
		if not u.is_alive() or u.owner_id == t.owner_id:
			continue
		var d: float = (t.pos as Vector2).distance_to(u.pos as Vector2)
		if d <= r and d < best_d:
			best_d = d
			best = u
	return best

# 投射物：from→to 线性飞行，按 kind 画箭/法术弹/火球。
func _draw_projectiles() -> void:
	var ur: float = _ur()
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
				var fi: int = 1 + int(_elapsed * 14.0) % 7   # 飞行帧循环（避开末尾炸帧）
				var sz: float = ur * 1.0
				draw_texture_rect_region(TEX_PROJ_FIREBALL, Rect2(pos - Vector2(sz, sz) * 0.5, Vector2(sz, sz)),
						Rect2(fi * PROJ_FB_FPX, 0, PROJ_FB_FPX, PROJ_FB_FPX))

func _play_projectile_audio(kind: String) -> void:
	match kind:
		"arrow":
			AudioManager.play_sfx("bow_shot")
		"bolt":
			AudioManager.play_sfx("magic_bolt_cast")
		"fireball":
			AudioManager.play_sfx("fire_skull_shot")

func _spawn_dmgnum(pos: Vector2, text: String, col: Color, size: int) -> void:
	_dmgnums.append({"pos": pos, "text": text, "col": col, "size": size, "t0": _elapsed, "dur": DMGNUM_DUR})

func _update_disp(delta: float) -> void:
	if match_obj.battle == null or match_obj.battle.arena == null:
		return
	var alpha: float = 1.0 - exp(-SMOOTH_K * delta)
	for u in match_obj.battle.arena.get_units():
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

# 命中火花（白膜：径向短线）+ 浮动伤害数字。
func _draw_combat_fx() -> void:
	var ur: float = _ur()
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
	var n := 4
	var bw := (_vw - 16.0 * (n + 1)) / n
	for i in n:
		var b := Button.new()
		b.position = Vector2(16.0 + i * (bw + 16.0), _vh - HUD_BOTTOM_H + 40.0)
		b.size = Vector2(bw, HUD_BOTTOM_H - 56.0)
		b.button_down.connect(_on_card_down.bind(i))
		b.button_up.connect(_on_card_up.bind(i))
		# 透明：仅作输入热区，卡面由 _draw_cards 自绘（便于 V3-7 贴皮）。
		var empty := StyleBoxEmpty.new()
		for sn in ["normal", "hover", "pressed", "disabled", "focus", "hover_pressed"]:
			b.add_theme_stylebox_override(sn, empty)
		b.focus_mode = Control.FOCUS_NONE
		b.text = ""
		add_child(b)
		_card_btns.append(b)
		_card_base_pos.append(b.position)
	_sync_cards()

# 按下卡牌 = 开始拖拽（disabled 卡不会触发 button_down，出不起的牌拖不动）。
func _on_card_down(i: int) -> void:
	if match_obj == null or match_obj.is_over() or (GameStateScript.stage_id != "" and not GameStateScript.is_online_ready()):
		return
	AudioManager.play_sfx("ui_card_pickup")
	selected_card = i
	_dragging = true
	_drag_screen = get_viewport().get_mouse_position()

# 松手 = 落子：在场上且合法则出牌 + 涟漪；落在 HUD/非法处则取消。
func _on_card_up(i: int) -> void:
	var was_dragging := _dragging
	var sc := selected_card
	_dragging = false
	selected_card = -1
	if (not was_dragging or sc != i or match_obj == null or match_obj.is_over()
			or (GameStateScript.stage_id != "" and not GameStateScript.is_online_ready())):
		return
	var screen: Vector2 = get_viewport().get_mouse_position()
	if screen.y < TOPBAR_H or screen.y > _vh - HUD_BOTTOM_H:
		AudioManager.play_sfx("ui_card_cancel")
		return   # 松手在 HUD/顶栏 → 取消
	var drop_tile: Vector2 = _drop_tile_from(screen)
	var hand: Array = match_obj.player.deck.get_hand()
	var cid: String = str(hand[sc]) if (sc < hand.size() and hand[sc] != null) else ""
	if match_obj.player.try_play_card(sc, drop_tile):
		AudioManager.play_sfx("ui_card_drop_valid")
		var kind: String = FX_KIND.get(cid, "spawn")
		var info: Dictionary = _card_info(cid)
		_fx.append({"pos": drop_tile, "t0": _elapsed, "dur": _fx_dur(kind), "kind": kind, "radius": float(info["radius"])})
		_play_card_audio(cid, info)
		_tut_on_action("card_played")   # 新手引导：出兵步骤推进
	else:
		AudioManager.play_sfx("ui_card_drop_invalid")

# 仅作输入门控：出不起/空格 → disabled（disabled 不触发 button_down，拖不动）。卡面见 _draw_cards。
func _sync_cards() -> void:
	if match_obj == null or match_obj.player == null:
		return
	var hand: Array = match_obj.player.deck.get_hand()
	for i in _card_btns.size():
		var b: Button = _card_btns[i]
		b.disabled = not (i < hand.size() and hand[i] != null and match_obj.player.can_play(i))

# 自绘卡面：底板 + 卡名 + 费用珠 + 不可用「扫光」(暗罩随圣水→费用回落) + 选中高亮 + 拖拽抬起。
func _draw_cards() -> void:
	var hand: Array = match_obj.player.deck.get_hand()
	var e = match_obj.player.elixir
	for i in _card_btns.size():
		if i >= _card_base_pos.size():
			continue
		var sz: Vector2 = (_card_btns[i] as Button).size
		var lifted: bool = _dragging and i == selected_card
		var pos: Vector2 = _card_base_pos[i] - Vector2(0, 14.0 if lifted else 0.0)
		var rect := Rect2(pos, sz)
		var sel: bool = i == selected_card
		draw_rect(rect, COL_CARD_SEL if sel else COL_CARD_BG)
		if i < hand.size() and hand[i] != null:
			var cid := str(hand[i])
			_draw_card_art(cid, pos + Vector2(sz.x * 0.5, sz.y * 0.54), minf(sz.x, sz.y) * 0.66)
			var cost: int = match_obj.player.card_cost(cid)
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
			draw_rect(rect, COL_PANEL_EDGE, false, 2.0)   # 石板高光描边（像素质感）

# 卡面图：兵牌=单位精灵正面静帧（自然色，不染队伍色）；法术牌=代表特效图标。
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

# —— HUD：结算面板（F1 起走 UI.modal 弹窗层：输入隔离由 CanvasLayer 层级保证，KAN-97）——
func _build_result_panel() -> void:
	_result_layer = ModalScript.new()
	_result_layer.dim_alpha = 0.0   # 结算暗幕由 _draw_end_screen 渐入演出，本层只拦输入+装按钮
	# 不立即入树：_start_ending 时 UI.modal() 推入弹窗层（高于场景层，手牌/HUD 机制上收不到点击）。
	# 调暗/标题/王冠/比分由 _draw_end_screen 动画绘制；本层只承载（延迟淡入的）按钮。

func _exit_tree() -> void:
	# 战斗未打完就离场（结算层从未入树）时手动释放，防游离节点泄漏；入树后由 UI 层随场景切换清理。
	if _result_layer != null and not _result_layer.is_inside_tree():
		_result_layer.free()

# 比赛结束：进入演出（调暗/标题 sting/王冠落入/比分滚动），按钮稍后淡入。
func _start_ending() -> void:
	_ending = true
	_end_t = 0.0
	_end_result = match_obj.get_result()
	_end_pscore = match_obj.battle.total_tower_hp(match_obj.battle.player_towers)
	_end_oscore = match_obj.battle.total_tower_hp(match_obj.battle.opponent_towers)
	if _tut_layer != null and is_instance_valid(_tut_layer):
		_tut_layer.close()   # 教程未走完就结束：撤输入实体，别吞结算按钮
		_tut_layer = null
	UI.modal(_result_layer)   # 推入弹窗层：演出期不能出牌（场景切换时该层自动清）
	match _end_result:
		BattleScript.RESULT_PLAYER_WIN:
			AudioManager.play_sfx("stinger_victory")
		BattleScript.RESULT_OPPONENT_WIN:
			AudioManager.play_sfx("stinger_defeat")
		BattleScript.RESULT_DRAW:
			AudioManager.play_sfx("stinger_draw")

func _add_result_buttons() -> void:
	_end_buttons_added = true
	if GameStateScript.tutorial:
		_result_btn("完成", _vh * 0.62, _on_tutorial_done)   # V5-S9：新手引导单局，完成→标记+回菜单
	elif GameStateScript.campaign != null:
		_result_btn(tr("btn_continue"), _vh * 0.62, _on_campaign_continue)   # 战役：回中枢推进/重打
	elif GameStateScript.run != null:
		_result_btn(tr("btn_continue"), _vh * 0.62, _on_run_continue)   # Roguelite：回 run 中枢推进/给奖励/结算
	elif GameStateScript.stage_id != "":
		_stage_result_button = _result_btn(tr("btn_back"), _vh * 0.62, _on_stage_return)   # V5-S7c：回地图结算
	else:
		_result_btn(tr("btn_rematch"), _vh * 0.62, _on_rematch)
		_result_btn(tr("btn_menu"), _vh * 0.62 + 70.0, _on_menu)
	_result_layer.modulate = Color(1, 1, 1, 0.0)
	create_tween().tween_property(_result_layer, "modulate:a", 1.0, 0.3)

# 胜负演出（全 _draw 驱动、单一 _end_t 计时）。
func _draw_end_screen() -> void:
	if not _ending:
		return
	var dimp: float = clampf(_end_t / 0.35, 0.0, 1.0)
	draw_rect(Rect2(0, 0, _vw, _vh), Color(0, 0, 0, 0.62 * dimp))
	var win: bool = _end_result == BattleScript.RESULT_PLAYER_WIN
	var lose: bool = _end_result == BattleScript.RESULT_OPPONENT_WIN
	var title := tr("result_win") if win else (tr("result_lose") if lose else tr("result_draw"))
	var tcol: Color = COL_PLAYER if win else (COL_OPPONENT if lose else Color.WHITE)
	# 标题 sting：透明淡入 + 字号回弹放大
	var ti: float = clampf(_end_t / 0.45, 0.0, 1.0)
	var fs: int = int(40.0 + 24.0 * _ease_back(ti))
	tcol.a = ti
	draw_string(_font, Vector2(0, _vh * 0.34), title, HORIZONTAL_ALIGNMENT_CENTER, _vw, fs, tcol)
	# 王冠落入（你拆掉的敌塔数，逐个延迟 + 回弹下落）
	var earned: int = _crowns(match_obj.battle.opponent_towers)
	var cw := 56.0
	var sx: float = _vw * 0.5 - float(earned - 1) * cw * 0.5
	for i in earned:
		var lt: float = clampf((_end_t - 0.2 - float(i) * 0.12) / 0.4, 0.0, 1.0)
		if lt <= 0.0:
			continue
		var yb: float = _ease_back(lt)
		_draw_crown(Vector2(sx + float(i) * cw, _vh * 0.46 - 60.0 * (1.0 - yb)), 40.0, COL_CROWN, true)
	# 比分滚动
	var cu: float = clampf((_end_t - 0.3) / 0.7, 0.0, 1.0)
	var sc := Color(1, 1, 1, clampf(_end_t * 2.0, 0.0, 1.0))
	draw_string(_font, Vector2(0, _vh * 0.56), tr("result_score") % [int(round(_end_pscore * cu)), int(round(_end_oscore * cu))],
			HORIZONTAL_ALIGNMENT_CENTER, _vw, 22, sc)

# back-out 缓动（0→1，末段回弹过冲 >1）。
func _ease_back(t: float) -> float:
	var c1 := 1.70158
	var c3 := c1 + 1.0
	var x: float = clampf(t, 0.0, 1.0) - 1.0
	return 1.0 + c3 * x * x * x + c1 * x * x

func _result_btn(txt: String, y: float, cb: Callable) -> Button:
	var b := Button.new()
	b.text = txt
	b.position = Vector2(_vw * 0.5 - 120, y)
	b.size = Vector2(240, 56)
	b.pressed.connect(cb)
	_result_layer.add_child(b)
	return b

func _on_run_continue() -> void:
	AudioManager.play_sfx("ui_button_press")
	GameStateScript.run_last_result = match_obj.get_result()
	Router.goto("run")

func _on_campaign_continue() -> void:
	AudioManager.play_sfx("ui_button_press")
	GameStateScript.campaign_last_result = match_obj.get_result()
	Router.goto("campaign")

func _on_rematch() -> void:
	AudioManager.play_sfx("ui_button_press")
	Router.reload()

func _on_menu() -> void:
	AudioManager.play_sfx("ui_button_back")
	Router.goto("main_menu")

# V5-S9 新手引导战结束（胜负不论）：标记引导完成（服务器权威）+ 清状态 → 回主菜单。
func _on_tutorial_done() -> void:
	AudioManager.play_sfx("ui_button_press")
	GameStateScript.tutorial = false
	GameStateScript.campaign = null
	GameStateScript.campaign_last_result = 0
	var http := HTTPRequest.new()
	add_child(http)
	var session = GameStateScript.session()
	await session.mark_tutorial_done(http)
	http.queue_free()
	Router.goto("main_menu")

# V5-S7c 闯关战后：判星 + 存结果（stage_map 负责上报服务器 + 领奖开箱）+ 回闯关地图。
# KAN-78/79：time_under 判定改用 pve_tick 换算时长（与服务器摘要校验完全同源，消边界分歧）；
# 战后 flush 剩余指令流（重放器要全量证据）→ 摘要 + battle_id 随 stage_last_result 交上报。
func _on_stage_return() -> void:
	if _stage_returning:
		return
	_stage_returning = true
	if _stage_result_button != null:
		_stage_result_button.disabled = true
		_stage_result_button.text = "提交战报中…"
	AudioManager.play_sfx("ui_button_press")
	var sid: String = GameStateScript.stage_id
	var outcome := {
		"won": _end_result == BattleScript.RESULT_PLAYER_WIN,
		"king_hp_pct": _player_king_hp_pct(),
		"duration_sec": (match_obj.pve_tick / 10.0) if match_obj.pve_tick > 0 else _battle_elapsed,
	}
	var goals = loader.get_stage(sid).get("stars", [])
	var stars: int = StageProgressScript.judge_stars(goals if goals is Array else [], outcome)
	Log.i("[V5][battle] 闯关战后 stage=%s won=%s king_hp=%.2f dur=%.1fs → stars=%d"
			% [sid, str(outcome.won), outcome.king_hp_pct, outcome.duration_sec, stars])
	var summary := {}
	if _pve_recorder != null:
		var flushed: bool = await _pve_recorder.flush(GameStateScript.economy(), _pve_http, GameStateScript.session().token())
		if not flushed:
			Log.w("[V5][battle] 最终战报未提交，留在结算页等待重试")
			_stage_returning = false
			if _stage_result_button != null:
				_stage_result_button.disabled = false
				_stage_result_button.text = "重试提交"
			return
		summary = _pve_recorder.summary(int(round(_player_king_hp_pct() * 1000.0)))
	GameStateScript.stage_last_result = {"stage_id": sid, "stars": stars, "battle_id": _pve_battle_id, "summary": summary}
	GameStateScript.stage_id = ""
	GameStateScript.deck_mode = ""
	Router.goto("stage_map")

func _player_king_hp_pct() -> float:
	for t in match_obj.battle.player_towers:
		if t.is_king():
			return clampf(t.hp / t.max_hp, 0.0, 1.0)
	return 0.0

# V5-S9：己方名片（昵称+怪物头像），左下角、在手牌上方（不挡战场/拇指区）。
func _build_player_nameplate() -> void:
	var session = GameStateScript.session()
	var np := HudWidgets.nameplate(session.nickname(), session.avatar_card_id(), loader, -1, true)
	var vp := get_viewport_rect().size
	np.position = Vector2(16, vp.y - HUD_BOTTOM_H - 78.0)
	np.z_index = 50
	add_child(np)

# —— V3-5b 新手引导：加载 / 推进 / 覆盖层绘制（数据驱动 tutorial.json，决策 45）——
func _init_tutorial() -> void:
	_tut_i = -1
	var campaign = GameStateScript.campaign
	if campaign == null or campaign.is_over():
		return
	var tut: Dictionary = loader.get_tutorial(campaign.current_level_id())
	var steps = tut.get("steps", [])
	if typeof(steps) == TYPE_ARRAY and not (steps as Array).is_empty():
		_tut_steps = steps
		_tut_i = 0
		# F2：教程输入实体入弹窗层——tap 步吞点击不再靠前置 _input 手搓（视觉仍由 _draw_tutorial 画）。
		_tut_layer = ModalScript.new()
		_tut_layer.dim_alpha = 0.0            # 暗幕/高亮/气泡在场景层 _draw（引用教程状态），本层只管输入
		_tut_layer.bg_click_cb = _tut_tap     # tap 步点任意处推进
		UI.modal(_tut_layer)
		_tut_sync_layer()

# tap 步点击推进（经 Modal 的点空白回调；action 步时本层 IGNORE，点击直达场景不会走到这）。
func _tut_tap() -> void:
	if _tut_i >= 0 and _tut_i < _tut_steps.size() \
			and str(_tut_steps[_tut_i].get("advance", "tap")) == "tap":
		_tut_next()

# 按当前步骤切输入实体：tap=STOP（吞点击防误出牌）；action（如 card_played）=IGNORE（放行出牌）；结束=撤层。
func _tut_sync_layer() -> void:
	if _tut_layer == null or not is_instance_valid(_tut_layer):
		return
	if _tut_i < 0:
		_tut_layer.close()
		_tut_layer = null
		return
	var tap: bool = str(_tut_steps[_tut_i].get("advance", "tap")) == "tap"
	_tut_layer.mouse_filter = Control.MOUSE_FILTER_STOP if tap else Control.MOUSE_FILTER_IGNORE

func _tut_next() -> void:
	if _tut_i < 0:
		return
	_tut_i += 1
	if _tut_i >= _tut_steps.size():
		_tut_i = -1   # 引导结束
	_tut_sync_layer()

func _tut_on_action(action: String) -> void:
	if _tut_i < 0 or _tut_i >= _tut_steps.size():
		return
	if str(_tut_steps[_tut_i].get("advance", "")) == action:
		_tut_next()

func _draw_tutorial() -> void:
	if _tut_i < 0 or _ending or _tut_i >= _tut_steps.size():
		return
	var step: Dictionary = _tut_steps[_tut_i]
	var hl := str(step.get("highlight", "none"))
	if hl == "none":
		draw_rect(Rect2(0, 0, _vw, _vh), Color(0, 0, 0, 0.55))
	else:
		var r: Rect2 = _tut_rect(hl)
		_tut_dim_except(r)
		var pulse: float = 0.6 + 0.4 * sin(_elapsed * 5.0)
		draw_rect(r, Color(COL_CROWN.r, COL_CROWN.g, COL_CROWN.b, pulse), false, 4.0)
		if str(step.get("finger", "")) != "":
			_tut_finger(r)
	_tut_bubble(tr(str(step.get("text_key", ""))), str(step.get("advance", "tap")) == "tap")

func _tut_dim_except(r: Rect2) -> void:
	var c := Color(0, 0, 0, 0.58)
	draw_rect(Rect2(0, 0, _vw, r.position.y), c)
	draw_rect(Rect2(0, r.end.y, _vw, _vh - r.end.y), c)
	draw_rect(Rect2(0, r.position.y, r.position.x, r.size.y), c)
	draw_rect(Rect2(r.end.x, r.position.y, _vw - r.end.x, r.size.y), c)

func _tut_rect(hl: String) -> Rect2:
	match hl:
		"elixir":
			return Rect2(10, _vh - HUD_BOTTOM_H + 4, _vw - 124, 30)
		"hand":
			return Rect2(6, _vh - HUD_BOTTOM_H + 38, _vw - 12, HUD_BOTTOM_H - 44)
		"field":   # 己方半场（教程仅战役竖版使用；横版实验开关为 PvE 闯关，不相交）
			var fr := _field_rect()
			return Rect2(fr.position.x, fr.position.y + fr.size.y * 0.5, fr.size.x, fr.size.y * 0.5)
	return Rect2(0, 0, _vw, _vh)

func _tut_finger(r: Rect2) -> void:
	var bob: float = 8.0 * sin(_elapsed * 5.0)
	var tip := Vector2(r.get_center().x, r.position.y - 12.0 + bob)
	draw_colored_polygon(PackedVector2Array([tip, tip + Vector2(-13, -20), tip + Vector2(13, -20)]), COL_CROWN)

func _tut_bubble(text: String, show_tap: bool) -> void:
	var bw := _vw - 80.0
	var bx := 40.0
	var by := _vh * 0.40
	var bh := 140.0
	draw_rect(Rect2(bx, by, bw, bh), Color(0.10, 0.08, 0.14, 0.96))
	draw_rect(Rect2(bx, by, bw, bh), COL_CROWN, false, 3.0)
	draw_multiline_string(_font, Vector2(bx + 20, by + 42), text, HORIZONTAL_ALIGNMENT_LEFT, bw - 40, 26, -1, Color(0.93, 0.88, 0.78))
	if show_tap:
		draw_string(_font, Vector2(bx, by + bh - 16), tr("tut_continue"), HORIZONTAL_ALIGNMENT_CENTER, bw, 18, Color(0.72, 0.72, 0.78))
