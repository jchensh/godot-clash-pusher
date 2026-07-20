# SpriteDB —— V3-7b 单位精灵清单（manifest）。纯表现层数据，逻辑零依赖。
#
# unit_id → 各状态(walk/attack) 的 sheet / 帧网格(fw×fh,cols) / 行索引 / 帧数 / fps，
# 以及 owner 朝向：row = 朝下/正面（敌兵 + 缺省回退），row_up = 朝上/背面（玩家兵，可选）。
# battle_scene 调 frame() 取 {tex, src(Rect2), scale, tint} 用 draw_texture_rect_region 作画（染队伍色/闪白）。
#
# 帧网格经 tools/_frame_probe.py 自动探测 + 带行号网格图肉眼坐实（见 HISTORY V3-7b）。
# 帧尺寸已坐实；行索引/朝向为初版最佳读数，留真人实机验收逐项校正。
# 状态映射（决策：务实=走+攻；死亡复用现有 FX）：默认 walk；current_target 在 attack_range 内 → attack。
#
# ⚠️ 三国改版 A2.5（2026-07-04）：标 `"ph": true` 的条目 = 占位精灵（复用旧素材 + tint 染色 + scale 区分），
# 等三国正式帧动画逐组替换。**替换正式素材三步**（每条目独立，替换互不影响）：
#   ① PNG 放 assets/units/ → headless 导入；② 定帧网格（tools/_frame_probe.py 或按素材包约定报 fw/fh/cols/行号）；
#   ③ 改本文件该 unit_id 条目的 tex/行号，删 "tint"/"ph"（正式素材自带配色）。跑 tests/test_sprite_db.gd 保覆盖。
# tint 语义：占位期按阵营色语言区分共享贴图（魏蓝/蜀绿/吴红/群雄黄 + 冰蓝/电黄/火橙个体色）；
#   战斗内与队伍色相乘（队伍可读性优先），卡面/图鉴/头像为自然色 tint（个体识别）。
extends RefCounted

const T_KNIGHT_NC := preload("res://assets/units/Heavy_Knight_Non-Combat_Animations.png")
const T_KNIGHT_CB := preload("res://assets/units/Heavy_Knight_Combat_Animations.png")
# 三国正式素材（0721 美术更新版重打包，管线同 KAN-104：谷切→脚线锚定→单行帧条，k=1 不缩放）：
# 走帧 10 帧单行 160×160 脚线 y158；攻击 8 帧 200×200 脚线 y178=158+(200-160)/2 → sc=200/160 脚底不跳。
const T_SANGUO_KNIGHT := preload("res://assets/units/sanguo_knight_walk.png")
const T_SANGUO_KNIGHT_ATK := preload("res://assets/units/sanguo_knight_attack.png")
# 立绘（322×346 原图）：卡面/图鉴/头像肖像优先用立绘，不再取走帧 col0。
const T_SANGUO_KNIGHT_PORTRAIT := preload("res://assets/units/sanguo_knight_portrait.png")
# 配套战斗特效条带（battle_scene 经 unit_fx() 取用；size=直径 tile 数）：
# 攻击刀光 4×116×116 / 受击星芒 6×72×40（原图非均匀摆放经谷切重打包）/ 死亡白烟 8×200×150。
const T_SANGUO_KNIGHT_FX_ATK := preload("res://assets/fx/sanguo_knight_attack_fx.png")
const T_SANGUO_KNIGHT_FX_HIT := preload("res://assets/fx/sanguo_knight_hit_fx.png")
const T_SANGUO_KNIGHT_FX_DEATH := preload("res://assets/fx/sanguo_knight_death_fx.png")
# 0721 批次正式素材（testAssets/7.21.2026/角色战斗动画 重打包；全部 natural 彩色、地面单位带脚线锚定）：
const T_SANGUO_BAT := preload("res://assets/units/sanguo_bat_walk.png")
const T_SANGUO_BAT_ATK := preload("res://assets/units/sanguo_bat_attack.png")
const T_SANGUO_GIANT := preload("res://assets/units/sanguo_giant_walk.png")
const T_SANGUO_GIANT_ATK := preload("res://assets/units/sanguo_giant_attack.png")
const T_SANGUO_GIANT_FX_ATK := preload("res://assets/fx/sanguo_giant_attack_fx.png")
const T_SANGUO_DRAGON := preload("res://assets/units/sanguo_dragon_walk.png")
const T_SANGUO_DRAGON_ATK := preload("res://assets/units/sanguo_dragon_attack.png")
const T_SANGUO_DRAGON_FX_IMPACT := preload("res://assets/fx/sanguo_dragon_impact_fx.png")
# 刘晔霹雳车：炮车静帧双行（row0=正面朝下/敌方，row1=背面朝上/我方）；攻击表现走弹道+落点爆花。
const T_SANGUO_RG := preload("res://assets/units/sanguo_royal_giant.png")
const T_SANGUO_RG_FX_IMPACT := preload("res://assets/fx/sanguo_royal_giant_impact_fx.png")
const T_SANGUO_RG_FX_DEATH := preload("res://assets/fx/sanguo_royal_giant_death_fx.png")
# 通用受击星芒（0721 批次新角色共用 hit 特效）。
const T_SANGUO_FX_HIT := preload("res://assets/fx/sanguo_generic_hit_fx.png")
# 远程投射物贴图（0721 起投射物绘制收口本文件，battle_scene/net_battle_scene 共用）。
const T_PROJ_FIREBALL := preload("res://assets/units/fire_skull_fireball.png")
const T_PROJ_STONE := preload("res://assets/units/sanguo_stone_projectile.png")
const T_PROJ_DRAGONFIRE := preload("res://assets/units/sanguo_dragon_projectile.png")
const PROJ_FB_FPX := 16
const T_ARCHER_NC := preload("res://assets/units/Archer_Non-Combat.png")
const T_ARCHER_CB := preload("res://assets/units/Archer_Combat.png")
const T_MAGE_NC := preload("res://assets/units/Mage_Hooded_BROWN.png")
const T_MAGE_CB := preload("res://assets/units/Mage_Hooded_BROWN-Combat.png")
const T_AXE := preload("res://assets/units/axe_warrior_combat_32x32.png")
const T_GOBLIN := preload("res://assets/units/goblin.png")
const T_SKELLY := preload("res://assets/units/skelly.png")
const T_FIRE_SKULL := preload("res://assets/units/fire_skull.png")
const T_ORC := preload("res://assets/units/orc_champion.png")
# A2.5 占位新启用的素材包同源贴图（64×224 = 4列×14行 16px；slime 4×8）——网格按包约定，行号留真人校正。
const T_GOB_SLINGER := preload("res://assets/units/goblin_slinger.png")
const T_SKELLY_WARRIOR := preload("res://assets/units/skelly_warrior.png")
const T_ORC_PLAIN := preload("res://assets/units/orc.png")
const T_ORC_SOLDIER := preload("res://assets/units/orc_soldier.png")
const T_ORC_ARCHER := preload("res://assets/units/orc_archer.png")
const T_WRAITH := preload("res://assets/units/wraith.png")
const T_SLIME := preload("res://assets/units/slime.png")
# 法术卡肖像用的特效帧（菜单/draft；arrows/log/heal/rock_shower 无单帧贴图→卡面回退文字）。
const T_FX_FIRE := preload("res://assets/fx/Fire_Explosion_28x28.png")
const T_FX_LIGHT := preload("res://assets/fx/Lightning_Energy_48x48.png")
const T_FX_RED := preload("res://assets/fx/Red_Energy_48x48.png")
const T_FX_ICE_CRYSTAL := preload("res://assets/fx/Ice-Burst_crystal_48x48.png")
const T_FX_ICE_BLUE := preload("res://assets/fx/Ice-Burst_transparent-blue_outline_48x48.png")
const SPELL_ICON := {
	"fireball": {"tex": T_FX_FIRE, "fpx": 28, "frame": 4},
	"lightning": {"tex": T_FX_LIGHT, "fpx": 48, "frame": 4},
	"zap": {"tex": T_FX_RED, "fpx": 48, "frame": 4},
	"giant_snowball": {"tex": T_FX_ICE_CRYSTAL, "fpx": 48, "frame": 3},
	"freeze": {"tex": T_FX_ICE_BLUE, "fpx": 48, "frame": 3},
}

# scale = 屏幕渲染相对 body 半径的倍率（16px 帧字符偏小 → 倍率更大）。
# 各状态：fw/fh 帧尺寸、cols 列数、row 朝下行、row_up 朝上行(可选)、n 帧数、fps、
#   sc 该状态相对 scale 的补偿倍率(可选，补不同帧画布字符占比差)。
# 条目级可选：tint（占位染色，Color）、ph（true=占位待正式素材）、shadow（true=正式素材带脚下阴影贴图，
#   battle_scene 据此在地面单位脚下画 unit_shadow.png 椭圆影）、natural（true=正式彩色素材：战斗内不再
#   全强度乘队伍色——高饱和贴图会被乘糊成黑剪影，改轻染 22% 队伍倾向，同塔的画法）、
#   mirror（true=单方向侧脸素材：battle_scene 按移动/攻击朝向水平镜像——素材默认朝左，向右走/砍时翻转）。
const DB := {
	# ============ 已坐实素材（V3-7b 10 条，三国正式素材到位后同样逐条替换） ============
	"knight_body": {  # 虎贲校尉：0721 美术更新版（走/攻/刀光新版；受击星芒/死亡白烟/立绘沿用 0715）。
		# 单方向素材：无背面行。scale 1.35→1.7 补新画布身高占比（126/160 vs 旧 94/96）。
		"scale": 1.7, "shadow": true, "natural": true, "mirror": true,
		"portrait": T_SANGUO_KNIGHT_PORTRAIT,
		"walk":   {"tex": T_SANGUO_KNIGHT, "fw": 160, "fh": 160, "cols": 10, "row": 0, "n": 10, "fps": 12.0},
		"attack": {"tex": T_SANGUO_KNIGHT_ATK, "fw": 200, "fh": 200, "cols": 8, "row": 0, "n": 8,
				"fps": 12.0, "sc": 1.25},
		"fx": {
			"attack": {"tex": T_SANGUO_KNIGHT_FX_ATK, "fw": 160, "fh": 160, "n": 3, "dur": 0.25, "size": 2.0},
			"hit":    {"tex": T_SANGUO_KNIGHT_FX_HIT, "fw": 72, "fh": 40, "n": 6, "dur": 0.3, "size": 1.6},
			"death":  {"tex": T_SANGUO_KNIGHT_FX_DEATH, "fw": 200, "fh": 150, "n": 8, "dur": 0.55, "size": 2.4},
		},
	},
	"archer_body": {  # 魏武强弩手：nc 16×16 4列(走) + cb 32×32 4列(射击)
		"scale": 1.5,
		"walk":   {"tex": T_ARCHER_NC, "fw": 16, "fh": 16, "cols": 4, "row": 0, "row_up": 14, "n": 4, "fps": 8.0},
		"attack": {"tex": T_ARCHER_CB, "fw": 32, "fh": 32, "cols": 4, "row": 2, "row_up": 3, "n": 4, "fps": 8.0, "sc": 1.5},
	},
	"musketeer_body": {  # 神射黄忠：mage nc 16×16 4列(走) + cb(施法)
		"scale": 1.5,
		"walk":   {"tex": T_MAGE_NC, "fw": 16, "fh": 16, "cols": 4, "row": 0, "row_up": 14, "n": 4, "fps": 7.0},
		"attack": {"tex": T_MAGE_CB, "fw": 16, "fh": 16, "cols": 4, "row": 0, "row_up": 6, "n": 4, "fps": 9.0},
	},
	"mini_pekka_body": {  # 黑甲周仓：axe cb 32×32 4列(走 rows14-18 / 攻 rows0-13 挥斧)
		"scale": 1.3,
		"walk":   {"tex": T_AXE, "fw": 32, "fh": 32, "cols": 4, "row": 16, "row_up": 14, "n": 4, "fps": 8.0},
		"attack": {"tex": T_AXE, "fw": 32, "fh": 32, "cols": 4, "row": 0, "n": 4, "fps": 10.0},
	},
	"goblin_body": {  # 山越短刀兵：16×16 4×14
		"scale": 1.5,
		"walk":   {"tex": T_GOBLIN, "fw": 16, "fh": 16, "cols": 4, "row": 2, "row_up": 0, "n": 4, "fps": 9.0},
		"attack": {"tex": T_GOBLIN, "fw": 16, "fh": 16, "cols": 4, "row": 9, "n": 4, "fps": 10.0},
	},
	"skeleton_body": {  # 黄巾阴兵：16×16 4×14（正面为主，朝向不分）
		"scale": 1.5,
		"walk":   {"tex": T_SKELLY, "fw": 16, "fh": 16, "cols": 4, "row": 0, "n": 4, "fps": 9.0},
		"attack": {"tex": T_SKELLY, "fw": 16, "fh": 16, "cols": 4, "row": 8, "n": 4, "fps": 10.0},
	},
	"giant_body": {  # 黄巾攻城力士：0721 正式素材（石甲力士；走 12 帧脚线 y189、攻 12 帧 256 格 sc 补偿）
		"scale": 1.3, "shadow": true, "natural": true, "mirror": true,
		"walk":   {"tex": T_SANGUO_GIANT, "fw": 192, "fh": 192, "cols": 12, "row": 0, "n": 12, "fps": 10.0},
		"attack": {"tex": T_SANGUO_GIANT_ATK, "fw": 256, "fh": 256, "cols": 12, "row": 0, "n": 12,
				"fps": 12.0, "sc": 1.333},
		"fx": {
			"attack": {"tex": T_SANGUO_GIANT_FX_ATK, "fw": 224, "fh": 224, "n": 5, "dur": 0.32, "size": 2.2},
			"hit":    {"tex": T_SANGUO_FX_HIT, "fw": 176, "fh": 96, "n": 5, "dur": 0.28, "size": 1.8},
		},
	},
	"golem_body": {  # 江东镇岳巨械：orc_champion 放大（缺真素材，暂换皮）
		"scale": 1.6, "tint": Color(1.0, 0.62, 0.55), "ph": true,
		"walk":   {"tex": T_ORC, "fw": 16, "fh": 16, "cols": 4, "row": 0, "n": 4, "fps": 6.0},
		"attack": {"tex": T_ORC, "fw": 16, "fh": 16, "cols": 4, "row": 8, "n": 4, "fps": 7.0},
	},
	"minion_body": {  # 魂鸦：fire_skull 16×16 4×10（对称飞行，朝向不分）
		"scale": 1.5,
		"walk":   {"tex": T_FIRE_SKULL, "fw": 16, "fh": 16, "cols": 4, "row": 0, "n": 4, "fps": 8.0},
		"attack": {"tex": T_FIRE_SKULL, "fw": 16, "fh": 16, "cols": 4, "row": 4, "n": 4, "fps": 9.0},
	},
	"baby_dragon_body": {  # 黄盖火龙鸢：fire_skull（无真龙，暂替）
		"scale": 1.7, "tint": Color(1.0, 0.68, 0.5), "ph": true,
		"walk":   {"tex": T_FIRE_SKULL, "fw": 16, "fh": 16, "cols": 4, "row": 0, "n": 4, "fps": 7.0},
		"attack": {"tex": T_FIRE_SKULL, "fw": 16, "fh": 16, "cols": 4, "row": 4, "n": 4, "fps": 8.0},
	},
	# ============ A2.5 占位铺满（29 条，2026-07-04）——阵营色：魏蓝/蜀绿/吴红/群雄黄 ============
	# —— 吴（赤红系）——
	"spear_goblin_body": {  # 山越投矛兵：占位=goblin_slinger（投掷哥布林）
		"scale": 1.5, "tint": Color(1.0, 0.75, 0.68), "ph": true,
		"walk":   {"tex": T_GOB_SLINGER, "fw": 16, "fh": 16, "cols": 4, "row": 2, "row_up": 0, "n": 4, "fps": 9.0},
		"attack": {"tex": T_GOB_SLINGER, "fw": 16, "fh": 16, "cols": 4, "row": 9, "n": 4, "fps": 10.0},
	},
	"bat_body": {  # 江东机关蜂：0721 正式素材（黄蜂；飞行整高裁切保留悬浮起伏）
		# body_radius 仅 0.3 → scale 拉大补可读性（0721 验收反馈"太小看不清"）。
		"scale": 2.6, "natural": true, "mirror": true,
		"walk":   {"tex": T_SANGUO_BAT, "fw": 128, "fh": 128, "cols": 10, "row": 0, "n": 10, "fps": 14.0},
		"attack": {"tex": T_SANGUO_BAT_ATK, "fw": 128, "fh": 128, "cols": 7, "row": 0, "n": 7, "fps": 14.0},
		"fx": {
			"hit": {"tex": T_SANGUO_FX_HIT, "fw": 176, "fh": 96, "n": 5, "dur": 0.28, "size": 1.2},
		},
	},
	"fire_spirit_body": {  # 赤焰符童：占位=slime 染火橙
		"scale": 1.0, "tint": Color(1.0, 0.55, 0.35), "ph": true,
		"walk":   {"tex": T_SLIME, "fw": 16, "fh": 16, "cols": 4, "row": 0, "n": 4, "fps": 9.0},
		"attack": {"tex": T_SLIME, "fw": 16, "fh": 16, "cols": 4, "row": 4, "n": 4, "fps": 10.0},
	},
	"valkyrie_body": {  # 山越旋刃卫：占位=axe warrior（旋斩）
		"scale": 1.25, "tint": Color(1.0, 0.62, 0.55), "ph": true,
		"walk":   {"tex": T_AXE, "fw": 32, "fh": 32, "cols": 4, "row": 16, "row_up": 14, "n": 4, "fps": 8.0},
		"attack": {"tex": T_AXE, "fw": 32, "fh": 32, "cols": 4, "row": 0, "n": 4, "fps": 10.0},
	},
	"wizard_body": {  # 都督周瑜：占位=mage 染赤
		"scale": 1.5, "tint": Color(1.0, 0.62, 0.55), "ph": true,
		"walk":   {"tex": T_MAGE_NC, "fw": 16, "fh": 16, "cols": 4, "row": 0, "row_up": 14, "n": 4, "fps": 7.0},
		"attack": {"tex": T_MAGE_CB, "fw": 16, "fh": 16, "cols": 4, "row": 0, "row_up": 6, "n": 4, "fps": 9.0},
	},
	"princess_body": {  # 枭姬孙尚香：占位=archer 染赤
		"scale": 1.45, "tint": Color(1.0, 0.60, 0.58), "ph": true,
		"walk":   {"tex": T_ARCHER_NC, "fw": 16, "fh": 16, "cols": 4, "row": 0, "row_up": 14, "n": 4, "fps": 8.0},
		"attack": {"tex": T_ARCHER_CB, "fw": 32, "fh": 32, "cols": 4, "row": 2, "row_up": 3, "n": 4, "fps": 8.0, "sc": 1.5},
	},
	# —— 群雄（黄系 + 亡灵/南蛮个体色）——
	"electro_spirit_body": {  # 雷符童子：占位=slime 染电黄
		"scale": 1.0, "tint": Color(1.0, 0.95, 0.5), "ph": true,
		"walk":   {"tex": T_SLIME, "fw": 16, "fh": 16, "cols": 4, "row": 0, "n": 4, "fps": 9.0},
		"attack": {"tex": T_SLIME, "fw": 16, "fh": 16, "cols": 4, "row": 4, "n": 4, "fps": 10.0},
	},
	"bone_ram_body": {  # 阴兵撞车：占位=skelly_warrior 放大
		"scale": 1.7, "tint": Color(1.0, 0.9, 0.62), "ph": true,
		"walk":   {"tex": T_SKELLY_WARRIOR, "fw": 16, "fh": 16, "cols": 4, "row": 0, "n": 4, "fps": 8.0},
		"attack": {"tex": T_SKELLY_WARRIOR, "fw": 16, "fh": 16, "cols": 4, "row": 8, "n": 4, "fps": 9.0},
	},
	"lava_hound_body": {  # 南蛮火鸢母兽：占位=fire_skull 巨黑红
		"scale": 2.2, "tint": Color(0.95, 0.45, 0.4), "ph": true,
		"walk":   {"tex": T_FIRE_SKULL, "fw": 16, "fh": 16, "cols": 4, "row": 0, "n": 4, "fps": 6.0},
		"attack": {"tex": T_FIRE_SKULL, "fw": 16, "fh": 16, "cols": 4, "row": 4, "n": 4, "fps": 7.0},
	},
	"lava_pup_body": {  # 南蛮幼鸢：占位=fire_skull 小橙
		"scale": 0.95, "tint": Color(1.0, 0.62, 0.35), "ph": true,
		"walk":   {"tex": T_FIRE_SKULL, "fw": 16, "fh": 16, "cols": 4, "row": 0, "n": 4, "fps": 9.0},
		"attack": {"tex": T_FIRE_SKULL, "fw": 16, "fh": 16, "cols": 4, "row": 4, "n": 4, "fps": 10.0},
	},
	"electro_wizard_body": {  # 天公将军张角：占位=mage 染黄
		"scale": 1.5, "tint": Color(1.0, 0.9, 0.5), "ph": true,
		"walk":   {"tex": T_MAGE_NC, "fw": 16, "fh": 16, "cols": 4, "row": 0, "row_up": 14, "n": 4, "fps": 7.0},
		"attack": {"tex": T_MAGE_CB, "fw": 16, "fh": 16, "cols": 4, "row": 0, "row_up": 6, "n": 4, "fps": 9.0},
	},
	# —— 魏（黑蓝系）——
	"barbarian_body": {  # 青州悍卒：占位=orc 染蓝灰
		"scale": 1.2, "tint": Color(0.72, 0.80, 1.0), "ph": true,
		"walk":   {"tex": T_ORC_PLAIN, "fw": 16, "fh": 16, "cols": 4, "row": 0, "n": 4, "fps": 8.0},
		"attack": {"tex": T_ORC_PLAIN, "fw": 16, "fh": 16, "cols": 4, "row": 8, "n": 4, "fps": 9.0},
	},
	"squire_body": {  # 虎贲新兵：占位=knight 小号淡蓝
		"scale": 1.1, "tint": Color(0.78, 0.84, 1.0), "ph": true,
		"walk":   {"tex": T_KNIGHT_NC, "fw": 24, "fh": 24, "cols": 4, "row": 0, "row_up": 16, "n": 4, "fps": 8.0},
		"attack": {"tex": T_KNIGHT_CB, "fw": 32, "fh": 32, "cols": 4, "row": 0, "row_up": 5, "n": 4, "fps": 10.0, "sc": 1.25},
	},
	"royal_giant_body": {  # 刘晔霹雳车：0721 正式素材（炮车静帧：row=正面朝下/敌方、row_up=背面朝上/我方；
		# 无侧脸不 mirror；攻击表现=石弹弹道+落点爆花（impact），死亡=火焰爆炸（机关车炸毁）。
		"scale": 1.6, "shadow": true, "natural": true,
		"walk": {"tex": T_SANGUO_RG, "fw": 152, "fh": 200, "cols": 1, "row": 0, "row_up": 1,
				"n": 1, "fps": 1.0},
		"fx": {
			"impact": {"tex": T_SANGUO_RG_FX_IMPACT, "fw": 152, "fh": 152, "n": 6, "dur": 0.35, "size": 2.2},
			"death":  {"tex": T_SANGUO_RG_FX_DEATH, "fw": 232, "fh": 232, "n": 4, "dur": 0.5, "size": 2.6},
			"hit":    {"tex": T_SANGUO_FX_HIT, "fw": 176, "fh": 96, "n": 5, "dur": 0.28, "size": 1.8},
		},
	},
	"hog_rider_body": {  # 虎豹破城骑：占位=knight 染深蓝（走帧加速表冲锋）
		"scale": 1.4, "tint": Color(0.62, 0.72, 0.98), "ph": true,
		"walk":   {"tex": T_KNIGHT_NC, "fw": 24, "fh": 24, "cols": 4, "row": 0, "row_up": 16, "n": 4, "fps": 12.0},
		"attack": {"tex": T_KNIGHT_CB, "fw": 32, "fh": 32, "cols": 4, "row": 0, "row_up": 5, "n": 4, "fps": 10.0, "sc": 1.25},
	},
	"battle_ram_body": {  # 青州撞城队：占位=orc_soldier 染蓝灰
		"scale": 1.6, "tint": Color(0.75, 0.80, 0.95), "ph": true,
		"walk":   {"tex": T_ORC_SOLDIER, "fw": 16, "fh": 16, "cols": 4, "row": 0, "n": 4, "fps": 9.0},
		"attack": {"tex": T_ORC_SOLDIER, "fw": 16, "fh": 16, "cols": 4, "row": 8, "n": 4, "fps": 9.0},
	},
	"executioner_body": {  # 恶来典韦：占位=axe warrior 染黑红
		"scale": 1.4, "tint": Color(0.9, 0.55, 0.5), "ph": true,
		"walk":   {"tex": T_AXE, "fw": 32, "fh": 32, "cols": 4, "row": 16, "row_up": 14, "n": 4, "fps": 7.0},
		"attack": {"tex": T_AXE, "fw": 32, "fh": 32, "cols": 4, "row": 0, "n": 4, "fps": 9.0},
	},
	"ice_wizard_body": {  # 冢虎司马懿：占位=mage 染冰蓝
		"scale": 1.5, "tint": Color(0.62, 0.86, 1.0), "ph": true,
		"walk":   {"tex": T_MAGE_NC, "fw": 16, "fh": 16, "cols": 4, "row": 0, "row_up": 14, "n": 4, "fps": 7.0},
		"attack": {"tex": T_MAGE_CB, "fw": 16, "fh": 16, "cols": 4, "row": 0, "row_up": 6, "n": 4, "fps": 9.0},
	},
	# —— 蜀（青绿系 + 机关火系个体色）——
	"axe_thrower_body": {  # 巴郡飞斧手：占位=orc_archer 染青绿
		"scale": 1.35, "tint": Color(0.68, 0.95, 0.66), "ph": true,
		"walk":   {"tex": T_ORC_ARCHER, "fw": 16, "fh": 16, "cols": 4, "row": 0, "n": 4, "fps": 8.0},
		"attack": {"tex": T_ORC_ARCHER, "fw": 16, "fh": 16, "cols": 4, "row": 8, "n": 4, "fps": 9.0},
	},
	"cave_spider_body": {  # 巴蜀毒蛛：占位=slime 染暗绿
		"scale": 1.2, "tint": Color(0.52, 0.75, 0.45), "ph": true,
		"walk":   {"tex": T_SLIME, "fw": 16, "fh": 16, "cols": 4, "row": 0, "n": 4, "fps": 11.0},
		"attack": {"tex": T_SLIME, "fw": 16, "fh": 16, "cols": 4, "row": 4, "n": 4, "fps": 11.0},
	},
	"ice_spirit_body": {  # 寒山符童：占位=slime 染冰蓝
		"scale": 1.0, "tint": Color(0.62, 0.86, 1.0), "ph": true,
		"walk":   {"tex": T_SLIME, "fw": 16, "fh": 16, "cols": 4, "row": 0, "n": 4, "fps": 9.0},
		"attack": {"tex": T_SLIME, "fw": 16, "fh": 16, "cols": 4, "row": 4, "n": 4, "fps": 10.0},
	},
	"bomber_body": {  # 无当火油手：占位=goblin_slinger 染青绿
		"scale": 1.3, "tint": Color(0.7, 0.95, 0.65), "ph": true,
		"walk":   {"tex": T_GOB_SLINGER, "fw": 16, "fh": 16, "cols": 4, "row": 2, "row_up": 0, "n": 4, "fps": 8.0},
		"attack": {"tex": T_GOB_SLINGER, "fw": 16, "fh": 16, "cols": 4, "row": 9, "n": 4, "fps": 9.0},
	},
	"mega_minion_body": {  # 重甲机关隼：占位=fire_skull 染铜青
		"scale": 1.55, "tint": Color(0.6, 0.85, 0.8), "ph": true,
		"walk":   {"tex": T_FIRE_SKULL, "fw": 16, "fh": 16, "cols": 4, "row": 0, "n": 4, "fps": 7.0},
		"attack": {"tex": T_FIRE_SKULL, "fw": 16, "fh": 16, "cols": 4, "row": 4, "n": 4, "fps": 8.0},
	},
	"balloon_body": {  # 孔明轰天灯：占位=fire_skull 大暖黄
		"scale": 1.95, "tint": Color(1.0, 0.85, 0.5), "ph": true,
		"walk":   {"tex": T_FIRE_SKULL, "fw": 16, "fh": 16, "cols": 4, "row": 0, "n": 4, "fps": 5.0},
		"attack": {"tex": T_FIRE_SKULL, "fw": 16, "fh": 16, "cols": 4, "row": 4, "n": 4, "fps": 6.0},
	},
	"phoenix_body": {  # 庞统火鸾：占位=fire_skull 染金红
		"scale": 1.55, "tint": Color(1.0, 0.7, 0.42), "ph": true,
		"walk":   {"tex": T_FIRE_SKULL, "fw": 16, "fh": 16, "cols": 4, "row": 0, "n": 4, "fps": 8.0},
		"attack": {"tex": T_FIRE_SKULL, "fw": 16, "fh": 16, "cols": 4, "row": 4, "n": 4, "fps": 9.0},
	},
	"phoenix_reborn_body": {  # 火鸾·重启：占位=fire_skull 暗金小号
		"scale": 1.25, "tint": Color(0.85, 0.6, 0.38), "ph": true,
		"walk":   {"tex": T_FIRE_SKULL, "fw": 16, "fh": 16, "cols": 4, "row": 0, "n": 4, "fps": 8.0},
		"attack": {"tex": T_FIRE_SKULL, "fw": 16, "fh": 16, "cols": 4, "row": 4, "n": 4, "fps": 9.0},
	},
	"inferno_dragon_body": {  # 蜀汉火脉机关龙：0721 正式素材（飞行整高裁切；远程龙火弹道+落点爆花）
		"scale": 1.7, "natural": true, "mirror": true,
		"walk":   {"tex": T_SANGUO_DRAGON, "fw": 272, "fh": 272, "cols": 10, "row": 0, "n": 10, "fps": 12.0},
		"attack": {"tex": T_SANGUO_DRAGON_ATK, "fw": 272, "fh": 272, "cols": 7, "row": 0, "n": 7, "fps": 10.0},
		"fx": {
			"impact": {"tex": T_SANGUO_DRAGON_FX_IMPACT, "fw": 112, "fh": 112, "n": 7, "dur": 0.3, "size": 1.3},
			"hit":    {"tex": T_SANGUO_FX_HIT, "fw": 176, "fh": 96, "n": 5, "dur": 0.28, "size": 1.6},
		},
	},
	"golemite_body": {  # 石心攻城兽：占位=orc 染石灰
		"scale": 1.15, "tint": Color(0.75, 0.75, 0.82), "ph": true,
		"walk":   {"tex": T_ORC_PLAIN, "fw": 16, "fh": 16, "cols": 4, "row": 0, "n": 4, "fps": 7.0},
		"attack": {"tex": T_ORC_PLAIN, "fw": 16, "fh": 16, "cols": 4, "row": 8, "n": 4, "fps": 8.0},
	},
	"fire_pup_body": {  # 喷火小龙：占位=fire_skull 亮橙
		"scale": 1.0, "tint": Color(1.0, 0.55, 0.28), "ph": true,
		"walk":   {"tex": T_FIRE_SKULL, "fw": 16, "fh": 16, "cols": 4, "row": 0, "n": 4, "fps": 9.0},
		"attack": {"tex": T_FIRE_SKULL, "fw": 16, "fh": 16, "cols": 4, "row": 4, "n": 4, "fps": 10.0},
	},
}

static func has_sprite(unit_id: String) -> bool:
	return DB.has(unit_id)

# 占位条目清单（供测试/盘点：还剩多少单位等正式素材）。
static func placeholder_ids() -> Array:
	var out: Array = []
	for uid in DB:
		if bool((DB[uid] as Dictionary).get("ph", false)):
			out.append(uid)
	return out

# 取某单位某状态当前帧：返回 {tex, src:Rect2, scale:float, tint:Color}，无则空字典（调用方回退白膜）。
# owner_id==0(玩家,朝上) 且该状态有 row_up → 用背面行；否则用 row（朝下/正面）。
# tint = 占位染色（默认 WHITE=不染）；战斗侧与队伍色相乘、卡面侧作自然色用。
# face_up：正/背双行素材的朝向覆写（0721 霹雳车炮口朝目标）——-1=按 owner 默认（0 朝上/背面），
# 1=强制背面(朝上)，0=强制正面(朝下)。仅对有 row_up 的条目生效。
static func frame(unit_id: String, state: String, owner_id: int, t: float, face_up: int = -1) -> Dictionary:
	if not DB.has(unit_id):
		return {}
	var u: Dictionary = DB[unit_id]
	var s: Dictionary = u.get(state, u.get("walk", {}))
	if s.is_empty():
		return {}
	var fw: int = int(s["fw"])
	var fh: int = int(s["fh"])
	var n: int = maxi(1, int(s["n"]))
	var fps: float = float(s["fps"])
	var row: int = int(s["row"])
	if s.has("row_up") and (face_up == 1 or (face_up == -1 and owner_id == 0)):
		row = int(s["row_up"])
	var col: int = int(t * fps) % n
	var sc: float = float(u.get("scale", 1.2)) * float(s.get("sc", 1.0))
	# base_scale = 不含状态 sc 的条目倍率：阴影等"身体基准"元素用它，不随攻击大方格放大（0715 阴影偏离修复）。
	return {"tex": s["tex"], "src": Rect2(col * fw, row * fh, fw, fh), "scale": sc,
			"base_scale": float(u.get("scale", 1.2)),
			"mirror": bool(u.get("mirror", false)),
			"tint": u.get("tint", Color.WHITE), "shadow": bool(u.get("shadow", false)),
			"natural": bool(u.get("natural", false))}

# 投射物绘制（双场景共用，0721 收口）：kind 对应 PROJ_KIND 值；dir=飞行方向（屏幕系），
# 朝左素材（dragonfire）按 dir.x 镜像；t 传场景 _elapsed 做帧循环/旋转。
static func draw_projectile(c: CanvasItem, kind: String, pos: Vector2, dir: Vector2, ur: float, t: float) -> void:
	match kind:
		"arrow":
			var d: Vector2 = dir.normalized() if dir.length() > 0.001 else Vector2.UP
			var perp := Vector2(-d.y, d.x)
			var col := Color(0.93, 0.88, 0.6)
			c.draw_line(pos - d * ur * 0.7, pos, col, 2.0)
			c.draw_line(pos, pos - d * 5.0 + perp * 3.0, col, 1.5)
			c.draw_line(pos, pos - d * 5.0 - perp * 3.0, col, 1.5)
		"bolt":
			c.draw_circle(pos, ur * 0.24, Color(0.8, 0.55, 1.0, 0.85))
			c.draw_circle(pos, ur * 0.12, Color(1, 1, 1, 0.95))
		"fireball":
			var fi: int = 1 + int(t * 14.0) % 7   # 飞行帧循环（避开末尾炸帧）
			var sz: float = ur * 1.0
			c.draw_texture_rect_region(T_PROJ_FIREBALL, Rect2(pos - Vector2(sz, sz) * 0.5, Vector2(sz, sz)),
					Rect2(fi * PROJ_FB_FPX, 0, PROJ_FB_FPX, PROJ_FB_FPX))
		"stone":     # 霹雳车石弹：翻滚旋转
			var ss: float = ur * 0.8
			c.draw_set_transform(pos, t * 9.0, Vector2.ONE)
			c.draw_texture_rect(T_PROJ_STONE, Rect2(-Vector2(ss, ss) * 0.5, Vector2(ss, ss)), false)
			c.draw_set_transform(Vector2.ZERO)
		"dragonfire":  # 机关龙火弹：3 帧循环；素材朝左，向右飞水平镜像
			var di: int = int(t * 12.0) % 3
			var dw: float = ur * 1.1
			var dh: float = dw * 64.0 / 80.0
			c.draw_set_transform(pos, 0.0, Vector2(-1.0 if dir.x > 0.0 else 1.0, 1.0))
			c.draw_texture_rect_region(T_PROJ_DRAGONFIRE, Rect2(Vector2(-dw, -dh) * 0.5, Vector2(dw, dh)),
					Rect2(di * 80, 0, 80, 64))
			c.draw_set_transform(Vector2.ZERO)

# 单位配套战斗特效（attack=攻击刀光/hit=受击星芒/death=死亡消散；无配套返回空字典）。
# 返回 {tex, fw, fh, n, dur, size}；battle_scene 按 dur 推进度、size(直径 tile)×ur 定屏幕尺寸。
static func unit_fx(unit_id: String, kind: String) -> Dictionary:
	if not DB.has(unit_id):
		return {}
	var fx: Dictionary = (DB[unit_id] as Dictionary).get("fx", {})
	return fx.get(kind, {})

# —— 卡片肖像（菜单/draft/组卡 用 TextureRect；7b-5b）——
static func _atlas(tex: Texture2D, col: int, row: int, fw: int, fh: int) -> AtlasTexture:
	var at := AtlasTexture.new()
	at.atlas = tex
	at.region = Rect2(col * fw, row * fh, fw, fh)
	return at

# 卡片肖像纹理：兵牌=正式立绘(有 portrait 字段) > 单位正面静帧；法术=特效帧；
# 其余(箭雨/滚石/治疗/落石)=null 回退文字。
static func card_portrait_tex(card_id: String, loader) -> Texture2D:
	if loader == null or not loader.has_card(card_id):
		return null
	for sk in loader.get_card(card_id).get("skills", []):
		if typeof(sk) == TYPE_DICTIONARY and str(sk.get("type")) == "spawn_unit":
			var uid := str(sk.get("unit_id"))
			if not DB.has(uid):
				return null
			var u: Dictionary = DB[uid]
			if u.has("portrait"):
				return u["portrait"]
			var w: Dictionary = u["walk"]
			return _atlas(w["tex"], 0, int(w["row"]), int(w["fw"]), int(w["fh"]))   # col0,正面行
	if SPELL_ICON.has(card_id):
		var s: Dictionary = SPELL_ICON[card_id]
		return _atlas(s["tex"], int(s["frame"]), 0, int(s["fpx"]), int(s["fpx"]))
	return null

# 卡片肖像染色（占位期区分共享贴图的卡；正式素材/无 tint 返回 WHITE=自然色）。
static func card_portrait_tint(card_id: String, loader) -> Color:
	if loader == null or not loader.has_card(card_id):
		return Color.WHITE
	for sk in loader.get_card(card_id).get("skills", []):
		if typeof(sk) == TYPE_DICTIONARY and str(sk.get("type")) == "spawn_unit":
			var uid := str(sk.get("unit_id"))
			if DB.has(uid):
				return (DB[uid] as Dictionary).get("tint", Color.WHITE)
			return Color.WHITE
	return Color.WHITE

# 现成可加到 Control 的肖像 TextureRect（无肖像返 null；占位 tint 自动应用）。
static func make_card_portrait(card_id: String, loader, pos: Vector2, size: Vector2) -> TextureRect:
	var tex := card_portrait_tex(card_id, loader)
	if tex == null:
		return null
	var t := TextureRect.new()
	# ⚠️ expand_mode 必须先于 texture/size 赋值：默认 EXPAND_KEEP_SIZE 下贴图会把 minimum size
	# 撑到帧尺寸，后设的 size 被 clamp 顶大（100×96 新帧曾把 52×40 的卡池格撑爆超框）。
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	t.texture = tex
	t.modulate = card_portrait_tint(card_id, loader)
	t.position = pos
	t.size = size
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return t
