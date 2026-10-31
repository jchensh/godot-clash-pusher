## D4 正式战斗的 3D 战场层：把 presenter（单位/塔/地形）、出牌输入（落点+ghost）、镜头与光照
## 打包给 2D 战斗页（battle_scene）用。2D 页保留 HUD/卡牌/教程/结算/录制，只把「画战场」换成本节点，
## 再借本节点的投影把 tile → 屏幕像素（伤害数字/教程高亮锚点）。D8：投射物/法术/受击/死亡/塔毁特效由子节点 fx
## （battle_fx_3d）在 3D 里画，伤害数字仍是页面的 2D 飘字、锚到 head_screen（角色头顶，跟随移动）。
## 只读 Battle：sim 由调用方推进；落点只给 tile，出牌仍由调用方走既有权威入口
## （PvE Player.try_play_card；D5 联机 BattleClient.send_deploy）。
extends Node3D

const Presenter := preload("res://view/three_d/battle_presenter.gd")
const DeployInput := preload("res://view/three_d/deploy_input_3d.gd")
const BattleCamera := preload("res://view/three_d/battle_camera.gd")
const BattleLighting := preload("res://view/three_d/battle_lighting.gd")
const FieldProjection := preload("res://view/three_d/field_projection.gd")
const Fx := preload("res://view/three_d/battle_fx_3d.gd")
const Quality := preload("res://view/three_d/quality.gd")

const TUNE_FROM := 2.0          # 首局自动调档：第 2~10 秒的帧耗时 p90（避开开场加载卡顿）
const TUNE_TO := 10.0

var presenter: Node3D
var deploy: Node3D
var camera: Camera3D
var fx: Node3D
var presenter_usec := 0         # 最近一帧 presenter / 特效层同步耗时（微秒，性能测量用）
var fx_usec := 0

var _tune_t := 0.0
var _tune_ms: Array = []
var _tuned := false
var viewport_size := Vector2.ZERO

var _arena = null


## top_h / hud_h：顶栏与手牌栏高度——场地居中在二者之间，松手在其上 = 取消（与 2D 同口径）。
## options：{lighting:bool=true, local_owner:int=0（本方=蓝、落点合法性按此方）, flipped:bool=false（联机 side2 整场 180°）,
## players:Array（双方 Player：挂法术特效钩子，串在原 play_observer 之后）}。
## 可重复调用换绑新的一局（D5 断线重连会新建 Match 再追帧）：presenter 清空旧节点重建，镜头/光照/输入复用不重复造。
func setup(battle, loader, viewport: Vector2, top_h: float, hud_h: float, options: Dictionary = {}) -> void:
	_arena = battle.arena
	if presenter == null and is_inside_tree():
		# D8b：生效画质档（上次自动调档结果）+ 渲染倍率 / LOD 阈值。只在本节点首次 setup 做：
		# D5 断线重连会对同一节点再 setup，此时若换档，光照（只建一次）与 presenter 的阴影方案会不一致。
		Quality.begin_scene(get_viewport())
	var local_owner := int(options.get("local_owner", 0))
	var flipped := bool(options.get("flipped", false))
	var names := {}
	var heights := {}
	for unit_id in loader.units:
		names[unit_id] = str(loader.units[unit_id].get("name", unit_id))
		heights[unit_id] = float(loader.units[unit_id].get("vis_height_px", 0.0))
	if presenter == null:
		presenter = Presenter.new()
		presenter.name = "BattlePresenter"
		presenter.auto_advance = false
		add_child(presenter)
		deploy = DeployInput.new()
		deploy.name = "DeployInput"
		add_child(deploy)
		if bool(options.get("lighting", true)):
			BattleLighting.setup(self, true)   # 正交俯视战斗镜头：单层正交阴影
		camera = Camera3D.new()
		camera.name = "BattleCamera"
		add_child(camera)
		if camera.is_inside_tree():
			camera.make_current()
		fx = Fx.new()
		fx.name = "BattleFx"
		add_child(fx)
	presenter.setup(battle, loader.get_arena("default"), {"local_owner": local_owner, "flipped": flipped,
		"unit_names": names, "unit_heights": heights})
	fx.setup(battle, presenter, loader, camera, options.get("players", []), {"local_owner": local_owner, "flipped": flipped})
	deploy.configure(camera, _arena, loader, local_owner, flipped, viewport)
	viewport_size = viewport
	BattleCamera.fit(camera, presenter.grid_size, viewport, Rect2(0.0, top_h, viewport.x, viewport.y - top_h - hud_h))
	presenter.batches.view_basis = camera.transform.basis   # 合批血条按镜头朝向摆放
	deploy.viewport_size = viewport
	deploy.blocked_rects = [Rect2(0.0, 0.0, viewport.x, top_h), Rect2(0.0, viewport.y - hud_h, viewport.x, hud_h)]


func advance(delta: float) -> void:
	var t0 := Time.get_ticks_usec()
	presenter.advance(delta)
	var t1 := Time.get_ticks_usec()
	fx.advance(delta)
	presenter_usec = t1 - t0
	fx_usec = Time.get_ticks_usec() - t1


## 2D 页每帧调一次：只读同步 3D 节点 + 震屏 + 拖拽 ghost 跟随页面的拖拽状态
## （drag_index<0 = 没在拖：撤 ghost；换牌/新拖 = 重建 ghost；拖着 = 跟手）。
func sync(delta: float, shake: Vector2, drag_index: int, hand: Array, screen: Vector2) -> void:
	advance(delta)
	_tune(delta)
	set_shake(shake)
	if drag_index < 0 or drag_index >= hand.size() or hand[drag_index] == null:
		if deploy.dragging:
			deploy.cancel_drag()
		return
	if not deploy.dragging or deploy.hand_index != drag_index:
		deploy.begin_drag(drag_index, str(hand[drag_index]))
	deploy.update_drag(screen)


## D8b 首局自动调档（每次启动只调一次）：采样第 2~10 秒帧耗时，剔除切后台/追帧的异常长帧后取 p90，
## 交给 Quality 决定下次升/降一档（手动选过的档不动）。有效样本不足（大半时间在后台）本局不下结论，留给下一局。
func _tune(delta: float) -> void:
	if _tuned:
		return
	if not Quality.wants_tune():
		_tuned = true
		return
	_tune_t += delta
	if _tune_t >= TUNE_FROM:
		_tune_ms.append(delta * 1000.0)
	if _tune_t < TUNE_TO:
		return
	_tuned = true
	var p90 := Quality.frame_p90(_tune_ms)
	if p90 < 0.0:
		return
	var before := Quality.level()
	var after := Quality.auto_tune(p90)
	if after != before:
		Log.i("[3D] 画质自动调档 %s → %s（帧耗时 p90 %.1f ms，下次进战斗生效）" % [Quality.LABELS[before], Quality.LABELS[after], p90])


## tile → 屏幕像素（地面高度）；与 deploy 的拾取同一套相机数学，互为逆变换。
func tile_to_screen(tile: Vector2) -> Vector2:
	return deploy.tile_to_screen(tile)


## 单位/塔（实例 ID）头顶的屏幕像素（不含震屏）；未知返回 null。伤害数字锚点：跟随角色移动，阵亡后停在最后位置 2 秒。
func head_screen(id: int) -> Variant:
	var world: Variant = fx.head_world(id)
	return null if world == null else deploy.tile_screen_world(world)


## 一格在屏幕上的像素边长（取逻辑 y 方向 = 屏幕横向，无透视缩短），供特效/数字定尺寸。
func tile_px() -> float:
	return tile_to_screen(Vector2(0.0, 1.0)).distance_to(tile_to_screen(Vector2.ZERO))


## 屏幕点（手指位置）→ 抬手后的落点 tile；不在场地上返回 null。
func drop_tile(screen: Vector2) -> Variant:
	return deploy.pick_tile(screen)


## 本方可部署半场在屏幕上的包围矩形（教程 field 高亮）。玩家 y∈[deploy_player_y_min, h]，对手 y∈[0, deploy_enemy_y_max]。
func deploy_half_rect() -> Rect2:
	var grid := Vector2(_arena.grid_w, _arena.grid_h)
	var y0: float = _arena.deploy_player_y_min if deploy.owner_id == 0 else 0.0
	var y1: float = grid.y if deploy.owner_id == 0 else float(_arena.deploy_enemy_y_max)
	var corners := [Vector2(0.0, y0), Vector2(grid.x, y0), Vector2(0.0, y1), Vector2(grid.x, y1)]
	var rect := Rect2(tile_to_screen(corners[0]), Vector2.ZERO)
	for c in corners:
		rect = rect.expand(tile_to_screen(c))
	return rect


## 震屏：2D 层的像素抖动换算成正交相机偏移（世界单位 = 像素 × size / 视口高），画面与 2D 叠加层同步抖。
func set_shake(px: Vector2) -> void:
	var k: float = camera.size / maxf(viewport_size.y, 1.0)
	camera.h_offset = -px.x * k
	camera.v_offset = px.y * k
