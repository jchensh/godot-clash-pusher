## 3D 战斗镜头构图：正交相机从 +X 侧俯视（屏幕横向 = 逻辑 y，我左敌右；屏幕纵向 = 逻辑 x），
## 场地宽度撑满视口、整体居中在「顶栏下、手牌栏上」的可视区。纯函数，不依赖节点在树上。
extends RefCounted

const PITCH_DEG := 55.0          # 俯角：兼顾立体感与竖屏下场地纵深可读
const SIDE_MARGIN := 1.5         # 场地左右各留的 tile 余量
const DEPTH_EXTRA := 5.0         # 纵向额外余量（塔高/血条/飞行单位）
const DISTANCE := 60.0


## zone：视口中给场地用的矩形（像素）；返回需要的正交 size，并写好 camera.transform。
static func fit(camera: Camera3D, grid: Vector2, viewport_size: Vector2, zone: Rect2) -> float:
	var pitch := deg_to_rad(PITCH_DEG)
	var aspect := viewport_size.x / maxf(viewport_size.y, 1.0)
	var width_size := (grid.y + SIDE_MARGIN * 2.0) / maxf(aspect, 0.01)
	var depth_world := grid.x * sin(pitch) + DEPTH_EXTRA * cos(pitch)
	var depth_size := depth_world * viewport_size.y / maxf(zone.size.y, 1.0)
	var size := maxf(width_size, depth_size)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.keep_aspect = Camera3D.KEEP_HEIGHT
	camera.size = size
	camera.near = 0.1
	camera.far = DISTANCE * 3.0
	var back := Vector3(cos(pitch), sin(pitch), 0.0)
	var basis := Basis.looking_at(-back, Vector3.UP)
	# 正交投影下沿相机 up 平移 = 画面整体上下移动：把场地中心挪到 zone 中心。
	var shift_px := (zone.get_center().y - viewport_size.y * 0.5)
	var shift_world := shift_px * size / maxf(viewport_size.y, 1.0)
	var center := Vector3(0.0, 0.0, 0.0)
	camera.transform = Transform3D(basis, center + back * DISTANCE + basis.y * shift_world)
	return size


## 正交相机（KEEP_HEIGHT）屏幕点 → 世界射线 [origin, dir]。纯数学、与 Camera3D.project_ray_* 同义，
## 不要求节点在树上（测试 runner 在主循环前执行）；一致性由 tools/check_battle_3d_preview.gd 实机比对。
static func screen_ray(xform: Transform3D, size: float, viewport: Vector2, screen: Vector2) -> Array:
	var aspect := viewport.x / maxf(viewport.y, 1.0)
	var lx := (screen.x / viewport.x - 0.5) * size * aspect
	var ly := (0.5 - screen.y / viewport.y) * size
	return [xform.origin + xform.basis.x * lx + xform.basis.y * ly, -xform.basis.z]


static func world_to_screen(xform: Transform3D, size: float, viewport: Vector2, world: Vector3) -> Vector2:
	var aspect := viewport.x / maxf(viewport.y, 1.0)
	var local := xform.affine_inverse() * world
	return Vector2((local.x / (size * aspect) + 0.5) * viewport.x, (0.5 - local.y / size) * viewport.y)
