# GameState —— 跨场景会话状态（仅显示层流程用）。
#
# 选关界面写入 level_id，battle_scene 读取后 match.setup(level_id)。
# 关卡 = 独立遭遇战、自带 AI 难度（V2-7b 决策 34），故难度不再单独选，随关卡而定。
# 用静态变量在场景切换间保持（不引入 autoload）；通过 preload 引用访问读写。
extends RefCounted

static var level_id := "level_01"     # 选关界面写入；battle_scene 读取后 match.setup(level_id)
static var player_deck: Array = []    # 组卡界面写入的玩家卡组（8 张 card_id）；空=用关卡默认 player_deck

# —— V3-4 Roguelite run 模式 ——
# run 非空时 battle_scene 进入「run 模式」：用 run 当前节点的 level_id + run 卡组 + relic/节点修正，
# 战斗结束把结果写 run_last_result 并回到 run_scene（由 run_scene 推进 run / 给奖励 / 结算）。
static var run = null                 # RunState（活跃 run）；null = 非 run 模式（战役/单关）
static var run_last_result := 0       # 上一场战斗结果（Battle.RESULT_*）；run_scene 读后清 0
static var meta = null                # MetaProgress（局间持久；run 开始时加载、结算时存盘）
