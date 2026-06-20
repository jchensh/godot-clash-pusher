# SpriteDB —— V3-7b 单位精灵清单（manifest）。纯表现层数据，逻辑零依赖。
#
# unit_id → 各状态(walk/attack) 的 sheet / 帧网格(fw×fh,cols) / 行索引 / 帧数 / fps，
# 以及 owner 朝向：row = 朝下/正面（敌兵 + 缺省回退），row_up = 朝上/背面（玩家兵，可选）。
# battle_scene 调 frame() 取 {tex, src(Rect2), scale} 用 draw_texture_rect_region 作画（染队伍色/闪白）。
#
# 帧网格经 tools/_frame_probe.py 自动探测 + 带行号网格图肉眼坐实（见 HISTORY V3-7b）。
# 帧尺寸已坐实；行索引/朝向为初版最佳读数，留真人实机验收逐项校正。
# 状态映射（决策：务实=走+攻；死亡复用现有 FX）：默认 walk；current_target 在 attack_range 内 → attack。
extends RefCounted

const T_KNIGHT_NC := preload("res://assets/units/Heavy_Knight_Non-Combat_Animations.png")
const T_KNIGHT_CB := preload("res://assets/units/Heavy_Knight_Combat_Animations.png")
const T_ARCHER_NC := preload("res://assets/units/Archer_Non-Combat.png")
const T_ARCHER_CB := preload("res://assets/units/Archer_Combat.png")
const T_MAGE_NC := preload("res://assets/units/Mage_Hooded_BROWN.png")
const T_MAGE_CB := preload("res://assets/units/Mage_Hooded_BROWN-Combat.png")
const T_AXE := preload("res://assets/units/axe_warrior_combat_32x32.png")
const T_GOBLIN := preload("res://assets/units/goblin.png")
const T_SKELLY := preload("res://assets/units/skelly.png")
const T_FIRE_SKULL := preload("res://assets/units/fire_skull.png")
const T_ORC := preload("res://assets/units/orc_champion.png")
# 法术卡肖像用的特效帧（菜单/draft；arrows/log/heal 无单帧贴图→卡面回退文字）。
const T_FX_FIRE := preload("res://assets/fx/Fire_Explosion_28x28.png")
const T_FX_LIGHT := preload("res://assets/fx/Lightning_Energy_48x48.png")
const T_FX_RED := preload("res://assets/fx/Red_Energy_48x48.png")
const SPELL_ICON := {
	"fireball": {"tex": T_FX_FIRE, "fpx": 28, "frame": 4},
	"lightning": {"tex": T_FX_LIGHT, "fpx": 48, "frame": 4},
	"zap": {"tex": T_FX_RED, "fpx": 48, "frame": 4},
}

# scale = 屏幕渲染相对 body 半径的倍率（16px 帧字符偏小 → 倍率更大）。
# 各状态：fw/fh 帧尺寸、cols 列数、row 朝下行、row_up 朝上行(可选)、n 帧数、fps、
#   sc 该状态相对 scale 的补偿倍率(可选，补不同帧画布字符占比差)。
static var DB := {
	"knight_body": {  # 骑士：nc 24×24 4列(走) + cb 32×32 4列(劈砍)
		"scale": 1.35,
		"walk":   {"tex": T_KNIGHT_NC, "fw": 24, "fh": 24, "cols": 4, "row": 0, "row_up": 16, "n": 4, "fps": 8.0},
		"attack": {"tex": T_KNIGHT_CB, "fw": 32, "fh": 32, "cols": 4, "row": 8, "n": 4, "fps": 10.0, "sc": 1.25},
	},
	"archer_body": {  # 弓箭手：nc 16×16 4列(走) + cb 32×32 4列(射击)
		"scale": 1.5,
		"walk":   {"tex": T_ARCHER_NC, "fw": 16, "fh": 16, "cols": 4, "row": 0, "row_up": 14, "n": 4, "fps": 8.0},
		"attack": {"tex": T_ARCHER_CB, "fw": 32, "fh": 32, "cols": 4, "row": 4, "n": 4, "fps": 8.0, "sc": 1.5},
	},
	"musketeer_body": {  # 女巫：mage nc 16×16 4列(走) + cb 32×32 2列(施法)
		"scale": 1.5,
		"walk":   {"tex": T_MAGE_NC, "fw": 16, "fh": 16, "cols": 4, "row": 0, "row_up": 14, "n": 4, "fps": 7.0},
		"attack": {"tex": T_MAGE_CB, "fw": 32, "fh": 32, "cols": 2, "row": 4, "n": 2, "fps": 8.0, "sc": 1.5},
	},
	"mini_pekka_body": {  # 狂战士：axe cb 32×32 4列(走 rows14-18 / 攻 rows0-13 挥斧)
		"scale": 1.3,
		"walk":   {"tex": T_AXE, "fw": 32, "fh": 32, "cols": 4, "row": 16, "row_up": 14, "n": 4, "fps": 8.0},
		"attack": {"tex": T_AXE, "fw": 32, "fh": 32, "cols": 4, "row": 0, "n": 4, "fps": 10.0},
	},
	"goblin_body": {  # 哥布林：16×16 4×14
		"scale": 1.5,
		"walk":   {"tex": T_GOBLIN, "fw": 16, "fh": 16, "cols": 4, "row": 2, "row_up": 0, "n": 4, "fps": 9.0},
		"attack": {"tex": T_GOBLIN, "fw": 16, "fh": 16, "cols": 4, "row": 9, "n": 4, "fps": 10.0},
	},
	"skeleton_body": {  # 骷髅：16×16 4×14（正面为主，朝向不分）
		"scale": 1.5,
		"walk":   {"tex": T_SKELLY, "fw": 16, "fh": 16, "cols": 4, "row": 0, "n": 4, "fps": 9.0},
		"attack": {"tex": T_SKELLY, "fw": 16, "fh": 16, "cols": 4, "row": 8, "n": 4, "fps": 10.0},
	},
	"giant_body": {  # 食人魔：orc_champion 16×16 4×14
		"scale": 1.4,
		"walk":   {"tex": T_ORC, "fw": 16, "fh": 16, "cols": 4, "row": 0, "n": 4, "fps": 7.0},
		"attack": {"tex": T_ORC, "fw": 16, "fh": 16, "cols": 4, "row": 8, "n": 4, "fps": 8.0},
	},
	"golem_body": {  # 亡灵巨像：orc_champion 放大（缺真素材，暂换皮）
		"scale": 1.6,
		"walk":   {"tex": T_ORC, "fw": 16, "fh": 16, "cols": 4, "row": 0, "n": 4, "fps": 6.0},
		"attack": {"tex": T_ORC, "fw": 16, "fh": 16, "cols": 4, "row": 8, "n": 4, "fps": 7.0},
	},
	"minion_body": {  # 怨灵：fire_skull 16×16 4×10（对称飞行，朝向不分）
		"scale": 1.5,
		"walk":   {"tex": T_FIRE_SKULL, "fw": 16, "fh": 16, "cols": 4, "row": 0, "n": 4, "fps": 8.0},
		"attack": {"tex": T_FIRE_SKULL, "fw": 16, "fh": 16, "cols": 4, "row": 4, "n": 4, "fps": 9.0},
	},
	"baby_dragon_body": {  # 余烬火颅：fire_skull（无真龙，暂替）
		"scale": 1.7,
		"walk":   {"tex": T_FIRE_SKULL, "fw": 16, "fh": 16, "cols": 4, "row": 0, "n": 4, "fps": 7.0},
		"attack": {"tex": T_FIRE_SKULL, "fw": 16, "fh": 16, "cols": 4, "row": 4, "n": 4, "fps": 8.0},
	},
}

static func has_sprite(unit_id: String) -> bool:
	return DB.has(unit_id)

# 取某单位某状态当前帧：返回 {tex, src:Rect2, scale:float}，无则空字典（调用方回退白膜）。
# owner_id==0(玩家,朝上) 且该状态有 row_up → 用背面行；否则用 row（朝下/正面）。
static func frame(unit_id: String, state: String, owner_id: int, t: float) -> Dictionary:
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
	if owner_id == 0 and s.has("row_up"):
		row = int(s["row_up"])
	var col: int = int(t * fps) % n
	var sc: float = float(u.get("scale", 1.2)) * float(s.get("sc", 1.0))
	return {"tex": s["tex"], "src": Rect2(col * fw, row * fh, fw, fh), "scale": sc}

# —— 卡片肖像（菜单/draft/组卡 用 TextureRect；7b-5b）——
static func _atlas(tex: Texture2D, col: int, row: int, fw: int, fh: int) -> AtlasTexture:
	var at := AtlasTexture.new()
	at.atlas = tex
	at.region = Rect2(col * fw, row * fh, fw, fh)
	return at

# 卡片肖像纹理：兵牌=单位正面静帧；火球/闪电/电火花=特效帧；其余(箭雨/滚石/治疗/未知)=null。
static func card_portrait_tex(card_id: String, loader) -> Texture2D:
	if loader == null or not loader.has_card(card_id):
		return null
	for sk in loader.get_card(card_id).get("skills", []):
		if typeof(sk) == TYPE_DICTIONARY and str(sk.get("type")) == "spawn_unit":
			var uid := str(sk.get("unit_id"))
			if not DB.has(uid):
				return null
			var w: Dictionary = DB[uid]["walk"]
			return _atlas(w["tex"], 0, int(w["row"]), int(w["fw"]), int(w["fh"]))   # col0,正面行
	if SPELL_ICON.has(card_id):
		var s: Dictionary = SPELL_ICON[card_id]
		return _atlas(s["tex"], int(s["frame"]), 0, int(s["fpx"]), int(s["fpx"]))
	return null

# 现成可加到 Control 的肖像 TextureRect（无肖像返 null）。
static func make_card_portrait(card_id: String, loader, pos: Vector2, size: Vector2) -> TextureRect:
	var tex := card_portrait_tex(card_id, loader)
	if tex == null:
		return null
	var t := TextureRect.new()
	t.texture = tex
	t.position = pos
	t.size = size
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return t
