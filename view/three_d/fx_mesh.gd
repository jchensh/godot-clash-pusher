## D8 特效几何库：用基本体拼出卡通投射物/碎块/特效网格（顶点色 + 单材质，与 toon 色阶光 + 描边同一套着色），
## 全部脚本生成、可重跑，按名缓存（同名共用一份网格）。投射物统一朝 -Z（Basis.looking_at 口径），原点在几何中心。
## 纯表现：不读写任何逻辑量。
extends RefCounted

const WOOD := Color("b27b45")
const WOOD_D := Color("7d5230")
const STEEL := Color("c9d1d8")
const STEEL_D := Color("8b959f")
const IRON := Color("4a4f57")
const WHITE := Color("ffffff")
const BRASS := Color("d9a640")
const RED := Color("d9534f")

## 所有可按名取的网格（测试遍历用）。
const NAMES := ["arrow", "spear", "axe", "double_axe", "bullet", "cannonball", "shell", "orb", "potion", "feather",
	"rock", "log", "snowball", "ice_shard", "star", "blob", "chunk", "plus", "ring", "disk", "column", "ball"]

static var _cache: Dictionary = {}


static func get_mesh(mesh_name: String) -> ArrayMesh:
	if not _cache.has(mesh_name):
		_cache[mesh_name] = _build(mesh_name)
	return _cache[mesh_name]


## parts：[[PrimitiveMesh, Transform3D, Color], ...] → 一个带顶点色的单 surface 网格。
static func merge(parts: Array) -> ArrayMesh:
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	for part in parts:
		var arrays: Array = (part[0] as PrimitiveMesh).get_mesh_arrays()
		var xf: Transform3D = part[1]
		var color: Color = part[2]
		var base := verts.size()
		var src_v: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var src_n: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		for i in src_v.size():
			verts.append(xf * src_v[i])
			normals.append((xf.basis * src_n[i]).normalized())
			colors.append(color)
		var src_i: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		for idx in src_i:
			indices.append(base + idx)
	var out := []
	out.resize(Mesh.ARRAY_MAX)
	out[Mesh.ARRAY_VERTEX] = verts
	out[Mesh.ARRAY_NORMAL] = normals
	out[Mesh.ARRAY_COLOR] = colors
	out[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, out)
	return mesh


## 锯齿闪电：起点→终点之间按 jitter 折线，每段一根细棱柱（每次放电现生成，不缓存）。
static func bolt(from: Vector3, to: Vector3, jitter: float, segments: int, width: float) -> ArrayMesh:
	var points: Array = [from]
	var side := (to - from).cross(Vector3(0.3, 0.1, 1.0)).normalized()
	var side2 := (to - from).cross(side).normalized()
	for i in range(1, segments):
		var k := float(i) / float(segments)
		var off := side * randf_range(-jitter, jitter) + side2 * randf_range(-jitter, jitter)
		points.append(from.lerp(to, k) + off)
	points.append(to)
	var parts: Array = []
	for i in range(points.size() - 1):
		var a: Vector3 = points[i]
		var b: Vector3 = points[i + 1]
		var length := a.distance_to(b)
		if length < 0.001:
			continue
		var w := width * (1.0 - 0.5 * float(i) / float(points.size()))
		parts.append([_cyl(w, w, length, 4), _segment_xform(a, b), WHITE])
	return merge(parts)


## 让沿 +Y 的基本体从 a 指到 b。
static func _segment_xform(a: Vector3, b: Vector3) -> Transform3D:
	var dir := (b - a).normalized()
	var axis := Vector3.UP.cross(dir)
	var basis := Basis.IDENTITY
	if axis.length() > 0.0001:
		basis = Basis(axis.normalized(), Vector3.UP.angle_to(dir))
	elif dir.y < 0.0:
		basis = Basis(Vector3.RIGHT, PI)
	return Transform3D(basis, (a + b) * 0.5)


static func _build(mesh_name: String) -> ArrayMesh:
	match mesh_name:
		"arrow":
			return merge([
				[_cyl(0.035, 0.035, 0.8), _fwd(0.0), WOOD],
				[_cyl(0.0, 0.09, 0.24), _fwd(-0.5), STEEL],
				[_box(Vector3(0.2, 0.012, 0.2)), Transform3D(Basis.IDENTITY, Vector3(0, 0, 0.36)), WHITE],
				[_box(Vector3(0.012, 0.2, 0.2)), Transform3D(Basis.IDENTITY, Vector3(0, 0, 0.36)), RED],
			])
		"spear":
			return merge([
				[_cyl(0.04, 0.04, 1.2), _fwd(0.05), WOOD_D],
				[_cyl(0.0, 0.1, 0.32), _fwd(-0.7), STEEL],
				[_box(Vector3(0.2, 0.04, 0.05)), Transform3D(Basis.IDENTITY, Vector3(0, 0, -0.52)), STEEL_D],
			])
		"axe":   # 单刃斧：柄沿 Z，刃在 +Y 侧（飞行时绕 X 轴翻滚）
			return merge([
				[_cyl(0.045, 0.045, 0.75), _fwd(0.0), WOOD],
				[_box(Vector3(0.06, 0.36, 0.3)), Transform3D(Basis.IDENTITY, Vector3(0, 0.16, -0.28)), STEEL],
				[_box(Vector3(0.07, 0.06, 0.32)), Transform3D(Basis.IDENTITY, Vector3(0, 0.33, -0.28)), STEEL_D],
			])
		"double_axe":   # 回旋双刃斧：柄居中、两端各一刃（绕 Y 轴平转）
			return merge([
				[_cyl(0.05, 0.05, 1.0), Transform3D(Basis(Vector3.FORWARD, PI * 0.5), Vector3.ZERO), WOOD_D],
				[_box(Vector3(0.36, 0.06, 0.4)), Transform3D(Basis.IDENTITY, Vector3(0.45, 0, 0.12)), STEEL],
				[_box(Vector3(0.36, 0.06, 0.4)), Transform3D(Basis.IDENTITY, Vector3(-0.45, 0, -0.12)), STEEL],
			])
		"bullet":
			return merge([
				[_sphere(0.09, 0.22, 6, 3), Transform3D.IDENTITY, BRASS],
				[_cyl(0.0, 0.06, 0.4, 5), _fwd(0.24), Color("ffe9a8")],
			])
		"cannonball":
			return merge([
				[_sphere(0.3, 0.6, 8, 5), Transform3D.IDENTITY, IRON],
				[_sphere(0.09, 0.18, 6, 3), Transform3D(Basis.IDENTITY, Vector3(0.12, 0.17, -0.1)), Color("9aa3ad")],
			])
		"shell":   # 猫炮手炮弹：铜壳 + 红引信头
			return merge([
				[_cyl(0.11, 0.11, 0.3, 6), _fwd(0.05), BRASS],
				[_cyl(0.0, 0.11, 0.16, 6), _fwd(-0.18), RED],
			])
		"orb":   # 法球：白芯（颜色由材质 tint 给）+ 外环
			return merge([
				[_sphere(0.22, 0.44, 8, 5), Transform3D.IDENTITY, WHITE],
				[_torus(0.26, 0.32, 10), Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3.ZERO), Color("e8f4ff")],
			])
		"potion":   # 鸦王药瓶：紫色瓶身 + 软木塞
			return merge([
				[_sphere(0.17, 0.32, 8, 4), Transform3D.IDENTITY, Color("9b59d0")],
				[_cyl(0.06, 0.07, 0.14, 6), Transform3D(Basis.IDENTITY, Vector3(0, 0.2, 0)), Color("d7f0f7")],
				[_cyl(0.07, 0.07, 0.06, 6), Transform3D(Basis.IDENTITY, Vector3(0, 0.29, 0)), WOOD],
			])
		"feather":   # 乌鸦羽镖：深色羽片 + 羽轴
			return merge([
				[_box(Vector3(0.18, 0.02, 0.5)), Transform3D.IDENTITY, Color("2f3550")],
				[_cyl(0.015, 0.015, 0.6, 4), _fwd(0.0), Color("e8a33b")],
			])
		"rock":
			return merge([[_sphere(0.5, 0.85, 6, 3), Transform3D(Basis.from_euler(Vector3(0.3, 0.5, 0.2)), Vector3.ZERO), WHITE]])
		"log":   # 横放沿 X 的木桩：树皮 + 两端年轮
			return merge([
				[_cyl(0.42, 0.42, 2.4, 10), Transform3D(Basis(Vector3.FORWARD, PI * 0.5), Vector3.ZERO), WOOD],
				[_cyl(0.36, 0.36, 2.46, 10), Transform3D(Basis(Vector3.FORWARD, PI * 0.5), Vector3.ZERO), Color("e7c48c")],
				[_box(Vector3(0.3, 0.12, 0.12)), Transform3D(Basis.IDENTITY, Vector3(0.4, 0.42, 0)), WOOD_D],
				[_torus(0.4, 0.47, 10), Transform3D(Basis(Vector3.FORWARD, PI * 0.5), Vector3(-0.75, 0, 0)), WOOD_D],
				[_torus(0.4, 0.47, 10), Transform3D(Basis(Vector3.FORWARD, PI * 0.5), Vector3(0.75, 0, 0)), WOOD_D],
			])
		"snowball":
			return merge([
				[_sphere(0.5, 1.0, 10, 6), Transform3D.IDENTITY, WHITE],
				[_sphere(0.16, 0.3, 6, 3), Transform3D(Basis.IDENTITY, Vector3(0.3, 0.32, 0.18)), Color("e3f2ff")],
			])
		"ice_shard":   # 冰晶簇：三根冰锥
			return merge([
				[_cyl(0.0, 0.18, 0.9, 5), Transform3D(Basis.IDENTITY, Vector3(0, 0.45, 0)), WHITE],
				[_cyl(0.0, 0.13, 0.6, 5), Transform3D(Basis(Vector3.FORWARD, 0.45), Vector3(0.16, 0.28, 0.05)), Color("dff4ff")],
				[_cyl(0.0, 0.12, 0.55, 5), Transform3D(Basis(Vector3.RIGHT, -0.5), Vector3(-0.08, 0.25, -0.15)), Color("dff4ff")],
			])
		"star":   # 卡通受击星：两层五角星挤出
			return _star_mesh()
		"blob":   # 卡通烟团（实心圆球，缩没即消失，无透明）
			return merge([[_sphere(0.5, 1.0, 8, 5), Transform3D.IDENTITY, WHITE]])
		"chunk":   # 碎石/碎雪块（低面数圆块：方块硬边在描边下会露黑缝）
			return merge([[_sphere(0.22, 0.36, 5, 3), Transform3D(Basis.from_euler(Vector3(0.4, 0.7, 0.2)), Vector3.ZERO), WHITE]])
		"plus":   # 治疗十字
			return merge([
				[_box(Vector3(0.36, 0.1, 0.1)), Transform3D.IDENTITY, WHITE],
				[_box(Vector3(0.1, 0.36, 0.1)), Transform3D.IDENTITY, WHITE],
			])
		"ring":   # 地面冲击环（单位半径 1，平放）
			return merge([[_torus(0.9, 1.0, 24), Transform3D.IDENTITY, WHITE]])
		"disk":   # 地面圆斑（单位半径 1）
			return merge([[_cyl(1.0, 1.0, 0.02, 20), Transform3D.IDENTITY, WHITE]])
		"column":   # 光柱（单位半径 1、高 1，底面在原点）
			return merge([[_cyl(1.0, 1.0, 1.0, 16), Transform3D(Basis.IDENTITY, Vector3(0, 0.5, 0)), WHITE]])
		_:   # "ball"：发光球 / 火球芯
			return merge([[_sphere(0.5, 1.0, 10, 6), Transform3D.IDENTITY, WHITE]])


static func _star_mesh() -> ArrayMesh:
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	for face in [1.0, -1.0]:
		var base := verts.size()
		verts.append(Vector3(0, 0, 0.06 * face))
		normals.append(Vector3(0, 0, face))
		colors.append(WHITE)
		for i in 10:
			var r := 0.5 if i % 2 == 0 else 0.22
			var a := PI * 0.5 + TAU * float(i) / 10.0
			verts.append(Vector3(cos(a) * r, sin(a) * r, 0.0))
			normals.append(Vector3(0, 0, face))
			colors.append(WHITE)
		for i in 10:
			var p := base + 1 + i
			var q := base + 1 + (i + 1) % 10
			if face > 0.0:
				indices.append_array([base, q, p])
			else:
				indices.append_array([base, p, q])
	var out := []
	out.resize(Mesh.ARRAY_MAX)
	out[Mesh.ARRAY_VERTEX] = verts
	out[Mesh.ARRAY_NORMAL] = normals
	out[Mesh.ARRAY_COLOR] = colors
	out[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, out)
	return mesh


## 沿 -Z 放置（基本体默认沿 +Y）。z = 中心在 Z 轴上的位置。
static func _fwd(z: float) -> Transform3D:
	return Transform3D(Basis(Vector3.RIGHT, -PI * 0.5), Vector3(0, 0, z))


static func _cyl(top: float, bottom: float, height: float, segments: int = 6) -> CylinderMesh:
	var m := CylinderMesh.new()
	m.top_radius = top
	m.bottom_radius = bottom
	m.height = height
	m.radial_segments = segments
	m.rings = 1
	return m


static func _sphere(radius: float, height: float, segments: int, rings: int) -> SphereMesh:
	var m := SphereMesh.new()
	m.radius = radius
	m.height = height
	m.radial_segments = segments
	m.rings = rings
	return m


static func _box(size: Vector3) -> BoxMesh:
	var m := BoxMesh.new()
	m.size = size
	return m


static func _torus(inner: float, outer: float, rings: int) -> TorusMesh:
	var m := TorusMesh.new()
	m.inner_radius = inner
	m.outer_radius = outer
	m.rings = rings
	m.ring_segments = 6
	return m
