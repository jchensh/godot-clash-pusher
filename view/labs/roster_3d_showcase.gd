## D3 角色图鉴：逐个查看已登记的 3D 单位模型与塔，播放各动作、转视角、切塔阵营色（toon 画风）。
## 资产验收用实验场景：不接账号/经济/战斗，不进正式路由。
extends Node3D

const UnitModels := preload("res://view/three_d/unit_models.gd")
const ToonStyle := preload("res://view/three_d/toon_style.gd")
const ArenaPresenter := preload("res://view/three_d/arena_presenter.gd")
const BattleLighting := preload("res://view/three_d/battle_lighting.gd")

const TOWERS := ["king_tower", "arrow_tower", "tower_ruin"]
const CLIPS := ["Idle", "Walk", "Attack", "Death"]
const TEXT_COLOR := Color("244632")
const STAGE_H := 2.0             # 单位统一缩放到此身高展示（米）

var _items: Array = []           # [{asset, kind: unit|tower}]
var _index := 0
var _model: Node3D
var _player: AnimationPlayer
var _pivot := Node3D.new()
var _camera: Camera3D
var _status: Label
var _clip := "Idle"
var _spin := true
var _blue := true


func _ready() -> void:
	get_window().title = "全 3D 迁移 · D3 角色图鉴"
	for asset in UnitModels.assets():
		_items.append({"asset": asset, "kind": "unit"})
	for asset in TOWERS:
		_items.append({"asset": asset, "kind": "tower"})
	add_child(_pivot)
	BattleLighting.setup(self)
	var ground := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 2.4
	disc.bottom_radius = 2.4
	disc.height = 0.1
	ground.mesh = disc
	ground.position.y = -0.05
	ground.material_override = ArenaPresenter.material(Color("8dad69"))
	add_child(ground)
	_camera = Camera3D.new()
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camera.size = 4.2
	add_child(_camera)
	_camera.position = Vector3(0, 3.0, 6.0)
	_camera.look_at(Vector3(0, 1.0, 0))
	_camera.make_current()
	_build_ui()
	show_item(0)


func show_item(index: int) -> void:
	_index = posmod(index, _items.size())
	if _model != null:
		_model.free()
	var item: Dictionary = _items[_index]
	var path: String = UnitModels.glb_path(item.asset) if item.kind == "unit" else \
		"res://assets/models/%s/%s.glb" % [item.asset, item.asset]
	_model = (load(path) as PackedScene).instantiate()
	_pivot.add_child(_model)
	var tint := Color.WHITE
	if item.kind == "tower":
		tint = ArenaPresenter.COLOR_BLUE if _blue else ArenaPresenter.COLOR_RED
	ToonStyle.apply(_model, tint)
	var h := _height(_model)
	_model.scale = Vector3.ONE * (STAGE_H / maxf(h, 0.01)) if item.kind == "unit" else Vector3.ONE * 0.55
	_player = _model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if _player != null:
		_player.animation_finished.connect(func(_n): play_clip("Idle"))
	play_clip("Idle")


func play_clip(clip: String) -> void:
	_clip = clip
	if _player != null and _player.has_animation(clip):
		_player.play(clip, 0.1)
	_update_status()


func _process(delta: float) -> void:
	if _spin:
		_pivot.rotation.y += delta * 0.6


func _update_status() -> void:
	var item: Dictionary = _items[_index]
	var tris := 0
	var bones := 0
	for node in _model.find_children("*", "MeshInstance3D", true, false):
		var mesh := (node as MeshInstance3D).mesh
		for s in mesh.get_surface_count():
			tris += (mesh.surface_get_arrays(s)[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3
	var skel := _model.find_child("Skeleton3D", true, false) as Skeleton3D
	if skel != null:
		bones = skel.get_bone_count()
	var clips := "—" if _player == null else ", ".join(_player.get_animation_list())
	_status.text = "%d / %d  %s（%s）\n三角面 %d · 骨骼 %d · 动作：%s\n当前：%s" % [
		_index + 1, _items.size(), item.asset, "单位" if item.kind == "unit" else "塔", tris, bones, clips,
		_clip if _player != null else ("蓝方" if _blue else "红方")]


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	match (event as InputEventKey).keycode:
		KEY_RIGHT:
			show_item(_index + 1)
		KEY_LEFT:
			show_item(_index - 1)
		KEY_1, KEY_2, KEY_3, KEY_4:
			play_clip(CLIPS[(event as InputEventKey).keycode - KEY_1])
		KEY_A:
			_spin = not _spin
		KEY_T:
			_blue = not _blue
			show_item(_index)


func _height(root: Node) -> float:
	var top := -INF
	var bottom := INF
	for node in root.find_children("*", "MeshInstance3D", true, false):
		var box := (node as MeshInstance3D).get_aabb()
		top = maxf(top, box.end.y)
		bottom = minf(bottom, box.position.y)
	return top - bottom if top > bottom else 1.0


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	box.offset_top = 16
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(box)
	for text in ["D3 · 3D 角色图鉴（toon 画风）", "←/→ 切换 · 1 待机 2 移动 3 攻击 4 死亡 · A 自转 · T 塔阵营色"]:
		box.add_child(_label(text, 20))
	_status = _label("", 17)
	box.add_child(_status)
	var bar := HBoxContainer.new()
	bar.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bar.offset_top = -110
	bar.offset_bottom = -20
	bar.add_theme_constant_override("separation", 8)
	layer.add_child(bar)
	for spec in [["◀", func(): show_item(_index - 1)], ["待机", func(): play_clip("Idle")], ["移动", func(): play_clip("Walk")],
			["攻击", func(): play_clip("Attack")], ["死亡", func(): play_clip("Death")], ["▶", func(): show_item(_index + 1)]]:
		var button := Button.new()
		button.text = spec[0]
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.add_theme_font_size_override("font_size", 22)
		button.pressed.connect(spec[1])
		bar.add_child(button)


func _label(text: String, size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", TEXT_COLOR)
	return label
