# GameState —— 跨场景会话状态（仅显示层流程用）。
#
# 难度选择界面写入 ai_difficulty，battle_scene 读取并据此构造 AIController。
# 用静态变量在场景切换间保持（不引入 autoload）；通过 preload 引用访问读写。
extends RefCounted

static var ai_difficulty := "normal"   # "easy" / "normal" / "hard"
