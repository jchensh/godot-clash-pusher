## 单位 → 3D 模型登记表（D3）：正式模型 + 锁定单位借用池内模型；体型按 units.json vis_height_px 归一。
## 只是表现层映射，不参与逻辑/配置/服务端。未登记的单位由 presenter 显示带标注的几何代理。
extends RefCounted

const PX_PER_TILE := 25.0        # vis_height_px 的基准（与 2D sprite_db 同口径：@25px/格）
const HEIGHT_K := 1.0            # 3D 整体身高倍率（真人验收可调）

## unit_id → 资产目录名（assets/models/<id>/<id>.glb）。可玩池 21 角色 + 热门锁定 4 种（D3 自行设计）。
const MODELS := {
	"knight_body": "xiaoxiao",
	"princess_body": "princess",
	"royal_giant_body": "royal_giant",
	"phoenix_body": "phoenix",
	"archer_body": "archers",
	"musketeer_body": "musketeer",
	"axe_thrower_body": "axe_thrower",
	"valkyrie_body": "valkyrie",
	"goblin_body": "goblin",
	"spear_goblin_body": "spear_goblin",
	"bomber_body": "bomber",
	"hog_rider_body": "hog_rider",
	"ice_wizard_body": "ice_wizard",
	"golem_body": "golem",
	"mini_pekka_body": "mini_pekka",
	"barbarian_body": "barbarians",
	"fire_spirit_body": "fire_spirit",
	"electro_spirit_body": "electro_spirit",
	"lava_hound_body": "lava_hound",
	"balloon_body": "balloon",
	"mega_minion_body": "mega_minion",
	"minion_body": "minion",
	"giant_body": "giant",
	"skeleton_body": "skeleton",
	"baby_dragon_body": "baby_dragon",
}

## 其余锁定单位（无原画）借用外形最接近的池内模型 + 整体色偏；只改表现，不动配置。
const BORROW := {
	"bat_body": {"as": "minion_body", "tint": Color("b58cff")},
	"ice_spirit_body": {"as": "electro_spirit_body", "tint": Color("a6e3ff")},
	"squire_body": {"as": "axe_thrower_body", "tint": Color("dfe6ff")},
	"cave_spider_body": {"as": "goblin_body", "tint": Color("8c7aa8")},
	"bone_ram_body": {"as": "hog_rider_body", "tint": Color("efe6d2")},
	"battle_ram_body": {"as": "hog_rider_body", "tint": Color("e0b98a")},
	"wizard_body": {"as": "ice_wizard_body", "tint": Color("ffa070")},
	"executioner_body": {"as": "valkyrie_body", "tint": Color("ffb890")},
	"electro_wizard_body": {"as": "ice_wizard_body", "tint": Color("fff090")},
	"inferno_dragon_body": {"as": "baby_dragon_body", "tint": Color("ff8060")},
	"fire_pup_body": {"as": "baby_dragon_body", "tint": Color("ffbb60")},
}

## 派生形态复用父模型（体型差由 vis_height_px 表达）。
const DERIVED := {
	"phoenix_reborn_body": "phoenix_body",
	"lava_pup_body": "lava_hound_body",
	"golemite_body": "golem_body",
}

static var _scenes: Dictionary = {}
static var _heights: Dictionary = {}


## 所有登记的单位资产目录名（去重，供图鉴/测试遍历）。
static func assets() -> Array:
	var out: Array = []
	for asset in MODELS.values():
		if not out.has(asset):
			out.append(asset)
	return out


static func glb_path(asset: String) -> String:
	return "res://assets/models/%s/%s.glb" % [asset, "xiaoxiao_animated" if asset == "xiaoxiao" else asset]


static func has_model(unit_id: String) -> bool:
	return not _resolve(unit_id).is_empty()


## 单位 → 资产目录名（派生/借用已解析；无模型返回 ""）。D7 预览按需 load，不经本类的常驻缓存。
static func asset_of(unit_id: String) -> String:
	return _resolve(unit_id)


## 借用单位的整体色偏（其余白色 = 原色）。
static func tint_of(unit_id: String) -> Color:
	return BORROW[unit_id]["tint"] if BORROW.has(unit_id) else Color.WHITE


## 返回 {scene: PackedScene, native_h: 模型原始身高(米), tint: 借用单位的整体色偏}；无模型返回 {}。
static func model_for(unit_id: String) -> Dictionary:
	var asset := _resolve(unit_id)
	if asset.is_empty():
		return {}
	if not _scenes.has(asset):
		_scenes[asset] = load(glb_path(asset))
	var tint: Color = BORROW[unit_id]["tint"] if BORROW.has(unit_id) else Color.WHITE
	return {"scene": _scenes[asset], "native_h": _native_height(asset), "tint": tint}


## 目标身高（tile）：vis_height_px / 25 × HEIGHT_K；缺配置时按体积半径近似（2D 同公式反推）。
static func target_height(vis_height_px: float, body_radius: float) -> float:
	if vis_height_px > 0.0:
		return vis_height_px / PX_PER_TILE * HEIGHT_K
	return maxf(body_radius, 0.3) * 3.5 * HEIGHT_K


static func _resolve(unit_id: String) -> String:
	if MODELS.has(unit_id):
		return MODELS[unit_id]
	if DERIVED.has(unit_id):
		return _resolve(DERIVED[unit_id])
	if BORROW.has(unit_id):
		return _resolve(str(BORROW[unit_id]["as"]))
	return ""


## 模型静止姿态包围盒高度（取所有网格并集），每个资产只算一次。
static func _native_height(asset: String) -> float:
	if _heights.has(asset):
		return _heights[asset]
	var inst: Node3D = _scenes[asset].instantiate()
	var top := -INF
	var bottom := INF
	for node in inst.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		var box := mi.get_aabb()
		top = maxf(top, box.end.y)
		bottom = minf(bottom, box.position.y)
	inst.free()
	var h := top - bottom if top > bottom else 1.0
	_heights[asset] = h
	return h
