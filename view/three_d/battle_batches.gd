## D8b 合批：全场单位的阵营脚环 + 单位/塔血条用 MultiMesh 一起画（脚环 1 个 + 血条底框 1 个 + 填充 1 个 draw call），
## 取代每个单位各自 3~4 个小网格。只读 actor 上的数据（位置/颜色/半径/血条比例与显隐），画面与逐个节点版一致。
## 镜头固定（正交俯视），血条按镜头朝向摆放即可正对屏幕，不需要逐实例公告板。
## 实例颜色是 sRGB 值（与原 albedo_color 同口径），材质开 vertex_color_is_srgb 让引擎转线性，否则偏亮偏淡。
## 容量按需翻倍（大批召唤不丢环/丢塔血条）。
extends Node3D

const CAPACITY := 160   # 初始容量；超出时 _ensure 翻倍扩容
const BAR_BACK := Color(0.12, 0.12, 0.14, 0.85)
const RING_HEIGHT := 0.15
const RING_Y := 0.04

var view_basis := Basis.IDENTITY   # 镜头朝向（battle_field_3d 定好镜头后写入）

var _rings: MultiMeshInstance3D
var _backs: MultiMeshInstance3D
var _fills: MultiMeshInstance3D


func _ready_batches() -> void:
	var torus := TorusMesh.new()
	torus.inner_radius = 0.85
	torus.outer_radius = 1.05
	var ring_mat := StandardMaterial3D.new()
	ring_mat.vertex_color_use_as_albedo = true
	ring_mat.vertex_color_is_srgb = true
	ring_mat.roughness = 0.85
	_rings = _batch("TeamRings", torus, ring_mat)
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	_backs = _batch("HpBarBacks", quad, _bar_mat(0))
	_fills = _batch("HpBarFills", quad, _bar_mat(1))


func setup() -> void:
	if _rings == null:
		_ready_batches()


## 每帧由 presenter 调：units = 存活 + 死亡表现中的 UnitActor；towers = TowerActor。
func refresh(units: Array, towers: Array) -> void:
	var rings := _rings.multimesh
	_ensure(rings, units.size())
	var n := 0
	for actor in units:
		var r: float = actor.ring_radius
		rings.set_instance_transform(n, Transform3D(Basis.from_scale(Vector3(r, RING_HEIGHT, r)),
			actor.position + Vector3(0, RING_Y, 0)))
		rings.set_instance_color(n, actor.team_color)
		n += 1
	rings.visible_instance_count = n
	var bars: Array = []
	for actor in units + towers:
		var bar = actor.hp_bar
		if bar != null and bar.visible and actor.visible:
			bars.append(bar)
	var backs := _backs.multimesh
	var fills := _fills.multimesh
	_ensure(backs, bars.size())
	_ensure(fills, bars.size())
	var right := view_basis.x.normalized()
	var up := view_basis.y.normalized()
	var back := view_basis.z.normalized()
	var m := 0
	for bar in bars:
		var w: float = bar.width()
		var center: Vector3 = bar.get_parent().position + bar.position   # actor 只绕 Y 转、血条在其正上方
		backs.set_instance_transform(m, Transform3D(Basis(right * (w + 0.08), up * 0.2, back), center))
		backs.set_instance_color(m, BAR_BACK)
		var fw := maxf(w * float(bar.ratio), 0.001)
		var fill_center := center - right * (w - fw) * 0.5
		fills.set_instance_transform(m, Transform3D(Basis(right * fw, up * 0.12, back), fill_center))
		fills.set_instance_color(m, bar.bar_color)
		m += 1
	backs.visible_instance_count = m
	fills.visible_instance_count = m


func ring_count() -> int:
	return _rings.multimesh.visible_instance_count


func bar_count() -> int:
	return _fills.multimesh.visible_instance_count


## 实例数不够时翻倍扩容（改 instance_count 会清空缓冲；调用方每帧整批重写变换与颜色）。
static func _ensure(mm: MultiMesh, need: int) -> void:
	if need <= mm.instance_count:
		return
	var count := mm.instance_count
	while count < need:
		count *= 2
	mm.instance_count = count


func _batch(label: String, mesh: Mesh, mat: Material) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mesh
	mm.instance_count = CAPACITY
	mm.visible_instance_count = 0
	var inst := MultiMeshInstance3D.new()
	inst.name = label
	inst.multimesh = mm
	inst.material_override = mat
	inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(inst)
	return inst


func _bar_mat(priority: int) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.vertex_color_is_srgb = true
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.no_depth_test = true
	mat.render_priority = priority
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	return mat
