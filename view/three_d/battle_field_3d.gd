## D4 正式战斗的 3D 战场层：把 presenter（单位/塔/地形）、出牌输入（落点+ghost）、镜头与光照
## 打包给 2D 战斗页（battle_scene）用。2D 页保留 HUD/卡牌/教程/结算/录制，只把「画战场」换成本节点，
## 再借本节点的投影把 tile → 屏幕像素（伤害数字/法术特效/教程高亮锚点）。
## 只读 Battle：sim 由调用方推进；落点只给 tile，出牌仍由调用方走 Player.try_play_card。
extends Node3D

const Presenter := preload("res://view/three_d/battle_presenter.gd")
const DeployInput := preload("res://view/three_d/deploy_input_3d.gd")
const BattleCamera := preload("res://view/three_d/battle_camera.gd")
const BattleLighting := preload("res://view/three_d/battle_lighting.gd")
const FieldProjection := preload("res://view/three_d/field_projection.gd")

var presenter: Node3D
var deploy: Node3D
var camera: Camera3D
var viewport_size := Vector2.ZERO

var _arena = null


## top_h / hud_h：顶栏与手牌栏高度——场地居中在二者之间，松手在其上 = 取消（与 2D 同口径）。
func setup(battle, loader, viewport: Vector2, top_h: float, hud_h: float, lighting := true) -> void:
	_arena = battle.arena
	var names := {}
	var heights := {}
	for unit_id in loader.units:
		names[unit_id] = str(loader.units[unit_id].get("name", unit_id))
		heights[unit_id] = float(loader.units[unit_id].get("vis_height_px", 0.0))
	presenter = Presenter.new()
	presenter.name = "BattlePresenter"
	presenter.auto_advance = false
	add_child(presenter)
	presenter.setup(battle, loader.get_arena("default"), {"unit_names": names, "unit_heights": heights})
	deploy = DeployInput.new()
	deploy.name = "DeployInput"
	add_child(deploy)
	if lighting:
		BattleLighting.setup(self)
	camera = Camera3D.new()
	camera.name = "BattleCamera"
	add_child(camera)
	if camera.is_inside_tree():
		camera.make_current()
	deploy.configure(camera, _arena, loader, 0, false, viewport)
	viewport_size = viewport
	BattleCamera.fit(camera, presenter.grid_size, viewport, Rect2(0.0, top_h, viewport.x, viewport.y - top_h - hud_h))
	deploy.viewport_size = viewport
	deploy.blocked_rects = [Rect2(0.0, 0.0, viewport.x, top_h), Rect2(0.0, viewport.y - hud_h, viewport.x, hud_h)]


func advance(delta: float) -> void:
	presenter.advance(delta)


## 2D 页每帧调一次：只读同步 3D 节点 + 震屏 + 拖拽 ghost 跟随页面的拖拽状态
## （drag_index<0 = 没在拖：撤 ghost；换牌/新拖 = 重建 ghost；拖着 = 跟手）。
func sync(delta: float, shake: Vector2, drag_index: int, hand: Array, screen: Vector2) -> void:
	advance(delta)
	set_shake(shake)
	if drag_index < 0 or drag_index >= hand.size() or hand[drag_index] == null:
		if deploy.dragging:
			deploy.cancel_drag()
		return
	if not deploy.dragging or deploy.hand_index != drag_index:
		deploy.begin_drag(drag_index, str(hand[drag_index]))
	deploy.update_drag(screen)


## tile → 屏幕像素（地面高度）；与 deploy 的拾取同一套相机数学，互为逆变换。
func tile_to_screen(tile: Vector2) -> Vector2:
	return deploy.tile_to_screen(tile)


## 一格在屏幕上的像素边长（取逻辑 y 方向 = 屏幕横向，无透视缩短），供特效/数字定尺寸。
func tile_px() -> float:
	return tile_to_screen(Vector2(0.0, 1.0)).distance_to(tile_to_screen(Vector2.ZERO))


## 屏幕点（手指位置）→ 抬手后的落点 tile；不在场地上返回 null。
func drop_tile(screen: Vector2) -> Variant:
	return deploy.pick_tile(screen)


## 本方可部署半场在屏幕上的包围矩形（教程 field 高亮）。
func deploy_half_rect() -> Rect2:
	var grid := Vector2(_arena.grid_w, _arena.grid_h)
	var y0: float = _arena.deploy_player_y_min
	var corners := [Vector2(0.0, y0), Vector2(grid.x, y0), Vector2(0.0, grid.y), Vector2(grid.x, grid.y)]
	var rect := Rect2(tile_to_screen(corners[0]), Vector2.ZERO)
	for c in corners:
		rect = rect.expand(tile_to_screen(c))
	return rect


## 震屏：2D 层的像素抖动换算成正交相机偏移（世界单位 = 像素 × size / 视口高），画面与 2D 叠加层同步抖。
func set_shake(px: Vector2) -> void:
	var k: float = camera.size / maxf(viewport_size.y, 1.0)
	camera.h_offset = -px.x * k
	camera.v_offset = px.y * k
