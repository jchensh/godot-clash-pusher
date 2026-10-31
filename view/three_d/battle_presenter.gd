## D1 共用 3D 战斗 presenter：每帧只读 Battle 状态，按对象实例 ID 维护单位/塔节点的生命周期。
## PvE/PvP 共用：推进 sim 的是调用方（Match.update / advance_tick），本节点不推进、不写任何逻辑量。
## 视角：local_owner 一方显示蓝色；flipped=true（联机 side2）时整场 180° 翻转，与 FieldProjection 同口径。
extends Node3D

const ArenaPresenter := preload("res://view/three_d/arena_presenter.gd")
const UnitActor := preload("res://view/three_d/battle_unit_actor.gd")
const TowerActor := preload("res://view/three_d/battle_tower_actor.gd")
const UnitModels := preload("res://view/three_d/unit_models.gd")
const Quality := preload("res://view/three_d/quality.gd")
const FxMesh := preload("res://view/three_d/fx_mesh.gd")
const Batches := preload("res://view/three_d/battle_batches.gd")

const BLOB_CAPACITY := 160      # 贴地圆影实例上限（单位 + 塔）
const BLOB_COLOR := Color(0.1, 0.13, 0.08, 0.3)

var auto_advance := true         # true：_process 每帧自动 advance；测试置 false 手动喂 delta
var local_owner := 0
var flipped := false
var grid_size := Vector2.ZERO

var _battle = null
var _field: Node3D
var _units: Dictionary = {}      # Unit 实例 ID → UnitActor（存活）
var _dying: Array = []           # 已从逻辑层消失、正在播死亡表现的 UnitActor
var _towers: Dictionary = {}     # Tower 实例 ID → TowerActor
var _names: Dictionary = {}
var _heights: Dictionary = {}    # unit_id → vis_height_px（体型归一；缺省按体积半径近似）
var _blobs: MultiMeshInstance3D  # D8b 低档：关实时阴影后单位/塔的贴地圆影（一个 MultiMesh = 1 个 draw call）
var batches: Node3D              # D8b：阵营脚环 + 血条合批（各档通用，画面不变）


## options：{local_owner:int, flipped:bool, unit_names:{unit_id: 显示名}, unit_heights:{unit_id: vis_height_px}}。
## 重复调用会先清空旧节点（重开/重连）。
func setup(battle, arena_cfg: Dictionary, options: Dictionary = {}) -> void:
	clear()
	_battle = battle
	local_owner = int(options.get("local_owner", 0))
	flipped = bool(options.get("flipped", false))
	_names = options.get("unit_names", {})
	_heights = options.get("unit_heights", {})
	_field = ArenaPresenter.new()
	_field.name = "Field"
	add_child(_field)
	_field.build(arena_cfg, false)
	grid_size = _field.grid_size
	if batches == null:
		batches = Batches.new()
		batches.name = "Batches"
		add_child(batches)
		batches.setup()
	for tower in battle.player_towers + battle.opponent_towers:
		var actor := TowerActor.new()
		add_child(actor)
		actor.setup(tower, {"grid": grid_size, "flipped": flipped, "color": _team_color(tower.owner_id), "batched": true})
		_towers[tower.get_instance_id()] = actor
	if not Quality.real_shadows():
		_build_blobs()
	advance(0.0)


func clear() -> void:
	for actor in _units.values() + _dying + _towers.values():
		actor.free()
	_units.clear()
	_dying.clear()
	_towers.clear()
	if _field != null:
		_field.free()
		_field = null
	if _blobs != null:
		_blobs.free()
		_blobs = null
	_battle = null


func _process(delta: float) -> void:
	if auto_advance:
		advance(delta)


## 同步一帧：新单位建节点、存活单位读状态、消失单位转入死亡表现、播完即释放。
func advance(delta: float) -> void:
	if _battle == null or _battle.arena == null:
		return
	var seen: Dictionary = {}
	for unit in _battle.arena.get_units():
		if not unit.is_alive():
			continue
		var id: int = unit.get_instance_id()
		seen[id] = true
		var actor = _units.get(id)
		if actor == null:
			actor = _spawn_unit(unit)
			_units[id] = actor
		actor.sync(unit, delta)
	for id in _units.keys():
		if not seen.has(id):
			var gone = _units[id]
			_units.erase(id)
			gone.begin_death()
			_dying.append(gone)
	for actor in _dying.duplicate():
		if actor.step_death(delta):
			_dying.erase(actor)
			actor.free()
	for tower in _battle.player_towers + _battle.opponent_towers:
		var tower_actor = _towers.get(tower.get_instance_id())
		if tower_actor != null:
			tower_actor.sync(tower, delta)
	if _blobs != null:
		_update_blobs()
	batches.refresh(_units.values() + _dying, _towers.values())


func blob_count() -> int:
	return _blobs.multimesh.visible_instance_count if _blobs != null else 0


func _build_blobs() -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = FxMesh.get_mesh("disk")
	mm.instance_count = BLOB_CAPACITY
	mm.visible_instance_count = 0
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = BLOB_COLOR
	_blobs = MultiMeshInstance3D.new()
	_blobs.name = "BlobShadows"
	_blobs.multimesh = mm
	_blobs.material_override = mat
	_blobs.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_blobs)


## 圆影跟随单位脚下（含死亡表现中的）；空军圆影略小；塔按占地。
func _update_blobs() -> void:
	var mm := _blobs.multimesh
	var n := 0
	for actor in _units.values() + _dying:
		if n >= BLOB_CAPACITY:
			break
		var r: float = actor.foot_radius * (0.75 if actor.flying else 1.0)
		mm.set_instance_transform(n, Transform3D(Basis.from_scale(Vector3(r, 1.0, r)), actor.position + Vector3(0, 0.03, 0)))
		n += 1
	for tower in _towers.values():
		if n >= BLOB_CAPACITY or tower.destroyed:
			continue
		var tr: float = float(tower.tower_ref.fw) * 0.55
		mm.set_instance_transform(n, Transform3D(Basis.from_scale(Vector3(tr, 1.0, tr)), tower.position + Vector3(0, 0.03, 0)))
		n += 1
	mm.visible_instance_count = n


func unit_actor_count() -> int:
	return _units.size()


func dying_count() -> int:
	return _dying.size()


func actor_for(unit):
	return _units.get(unit.get_instance_id())


func tower_actor_for(tower):
	return _towers.get(tower.get_instance_id())


## 代理单位清单（D3 资产欠账口径）：返回当前场上用几何代理显示的 unit_id 去重列表。
func proxy_unit_ids() -> Array:
	var ids: Array = []
	for actor in _units.values():
		if actor.mode == UnitActor.MODE_PROXY and actor.unit_ref != null and not ids.has(actor.unit_ref.unit_id):
			ids.append(actor.unit_ref.unit_id)
	return ids


func _spawn_unit(unit) -> Node3D:
	var model: Dictionary = UnitModels.model_for(unit.unit_id)
	var scale := 1.0
	var target := UnitModels.target_height(float(_heights.get(unit.unit_id, 0.0)), float(unit.body_radius))
	if not model.is_empty():
		scale = target / maxf(float(model["native_h"]), 0.01)
	var actor := UnitActor.new()
	add_child(actor)
	actor.setup(unit, {
		"grid": grid_size,
		"flipped": flipped,
		"color": _team_color(unit.owner_id),
		"model": model.get("scene"),
		"model_scale": scale,
		"model_tint": model.get("tint", Color.WHITE),
		"name": _names.get(unit.unit_id, unit.unit_id),
		"height": target,
		"batched": true,
	})
	return actor


func _team_color(owner_id: int) -> Color:
	return ArenaPresenter.COLOR_BLUE if owner_id == local_owner else ArenaPresenter.COLOR_RED
