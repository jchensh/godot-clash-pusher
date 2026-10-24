## 3D 卡通画风统一入口：把模型所有网格面换成 toon 色阶光 + 描边（D3 用户决策）。
## 资产约定：顶点色作底色；材质名为 M_Team 的面按 team_tint 染色（塔的旗帜/屋顶），其余面乘 body_tint
## （借用模型的锁定单位整体色偏；缺省白色 = 原色）。
extends RefCounted

const TOON := preload("res://view/three_d/toon.gdshader")
const OUTLINE := preload("res://view/three_d/toon_outline.gdshader")
const TEAM_MATERIAL := "M_Team"

static var _cache: Dictionary = {}   # tint.to_html() → ShaderMaterial（同色共用，减少材质实例）


static func material(tint: Color = Color.WHITE) -> ShaderMaterial:
	var key := tint.to_html()
	if _cache.has(key):
		return _cache[key]
	var outline := ShaderMaterial.new()
	outline.shader = OUTLINE
	var mat := ShaderMaterial.new()
	mat.shader = TOON
	mat.set_shader_parameter("tint", tint)
	mat.next_pass = outline
	_cache[key] = mat
	return mat


## 返回被换材质的 surface 数（测试/自检用）。
static func apply(root: Node, team_tint: Color = Color.WHITE, body_tint: Color = Color.WHITE) -> int:
	var count := 0
	for node in root.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		if mi.mesh == null:
			continue
		for s in mi.mesh.get_surface_count():
			var src := mi.mesh.surface_get_material(s)
			var team := src != null and src.resource_name == TEAM_MATERIAL
			mi.set_surface_override_material(s, material(team_tint if team else body_tint))
			count += 1
	return count
