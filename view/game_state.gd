# GameState —— 跨场景会话状态（仅显示层流程用）。
#
# 选关界面写入 level_id，battle_scene 读取后 match.setup(level_id)。
# 关卡 = 独立遭遇战、自带 AI 难度（V2-7b 决策 34），故难度不再单独选，随关卡而定。
# 用静态变量在场景切换间保持（不引入 autoload）；通过 preload 引用访问读写。
extends RefCounted

static var level_id := "level_01"     # 选关界面写入；battle_scene 读取后 match.setup(level_id)
static var player_deck: Array = []    # 组卡界面写入的玩家卡组（8 张 card_id）；空=用关卡默认 player_deck

# —— V5-S7（决策48）闯关流转 ——
static var stage_id := ""              # 非空 = 闯关模式（battle 走 setup_stage；deck_builder 回 stage_map）
static var stage_last_result := {}     # 战后回传 {stage_id, stars, outcome}；stage_map 读后上报服务器+开箱+清空
static var deck_mode := ""             # 组卡上下文：""/"level"=自由对战 / "stage"=闯关挑战 / "edit"=基地编辑
static var detail_card := ""           # 养成详情 card_detail 要展示的 card_id（card_collection 写）

# —— V3-4 Roguelite run 模式 ——
# run 非空时 battle_scene 进入「run 模式」：用 run 当前节点的 level_id + run 卡组 + relic/节点修正，
# 战斗结束把结果写 run_last_result 并回到 run_scene（由 run_scene 推进 run / 给奖励 / 结算）。
static var run = null                 # RunState（活跃 run）；null = 非 run 模式（战役/单关）
static var run_last_result := 0       # 上一场战斗结果（Battle.RESULT_*）；run_scene 读后清 0
static var meta = null                # MetaProgress（局间持久；run 开始时加载、结算时存盘）

# —— V3-5 短战役模式 ——
# campaign 非空时 battle_scene 进入「战役模式」：用 campaign 当前关 level_id 建场（关卡默认教学卡组），
# 战斗结束写 campaign_last_result 回 campaign_scene（由 campaign_scene 推进战役、可重打）。
static var campaign = null             # CampaignState（活跃战役）；null = 非战役模式
static var campaign_last_result := 0   # 上一场战役战斗结果（Battle.RESULT_*）；campaign_scene 读后清 0

# —— V4-S4 联机会话（登录 token + 档案/杯数，跨场景复用）——
static var _session = null
static func session():                 # 懒创建；主菜单/联机对战页共用
	if _session == null:
		_session = load("res://net/session.gd").new()
	return _session

# —— V5-S7（决策48）瘦客户端共享件：配置(本地只读，展示+战斗计算) + 经济状态缓存(服务器权威快照) ——
# 沿用 session() 的静态持有范式（不引 autoload），跨基地/闯关/养成/战斗复用同一份。
static var _config = null
static func config():                   # ConfigLoader（本地 JSON，展示侧成本/战力/关卡计算用）
	if _config == null:
		_config = load("res://logic/config_loader.gd").new()
		_config.load_all()
	return _config

static var _economy = null
static func economy():                  # EconomyStateCache（服务器经济/养成状态非权威缓存）
	if _economy == null:
		_economy = load("res://net/economy_state_cache.gd").new(_net_api_url())
	return _economy

static func _net_api_url() -> String:
	var f := FileAccess.open("res://config/network.json", FileAccess.READ)
	if f == null:
		return "http://localhost:8080"
	var d = JSON.parse_string(f.get_as_text())
	return String((d as Dictionary).get("api_url", "http://localhost:8080")) if d is Dictionary else "http://localhost:8080"
