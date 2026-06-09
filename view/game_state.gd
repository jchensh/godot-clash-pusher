# GameState —— 跨场景会话状态（仅显示层流程用）。
#
# 选关界面写入 level_id，battle_scene 读取后 match.setup(level_id)。
# 关卡 = 独立遭遇战、自带 AI 难度（V2-7b 决策 34），故难度不再单独选，随关卡而定。
# 用静态变量在场景切换间保持（不引入 autoload）；通过 preload 引用访问读写。
extends RefCounted

static var level_id := "level_01"     # 选关界面写入；battle_scene 读取后 match.setup(level_id)
static var player_deck: Array = []    # 组卡界面写入的玩家卡组（8 张 card_id）；空=用关卡默认 player_deck
