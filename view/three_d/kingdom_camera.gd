## D6 王国镜头：正交斜俯视（自南向北看，屏幕上方 = 城北），拖动平移 + 以指点为中心缩放，焦点钳在城内。
## 纯函数（状态由调用方持有：target 地面焦点 + size 正交高度），投影复用 BattleCamera 的纯数学，不要求节点在树上。
extends RefCounted

const BattleCamera := preload("res://view/three_d/battle_camera.gd")

const PITCH_DEG := 45.0          # 俯角：看得到建筑正立面（贴近 2D 原画的 3/4 视角），又不至于把纵深压扁
const DISTANCE := 90.0
const SIZE_MIN := 20.0           # 正交竖向视野（米）：最近（竖屏约 11 米宽）
const SIZE_MAX := 64.0           # 最远（竖屏约 36 米宽 ≈ 整城宽）
const SIZE_DEFAULT := 38.0
const EDGE_MARGIN := 3.0         # 画面最多露出城墙外多少米（再往外拖就停）


## 焦点 target（地面点）+ 正交 size → 相机变换（相机在焦点南侧上空，朝北俯视）。
static func xform(target: Vector3, _size: float) -> Transform3D:
	var pitch := deg_to_rad(PITCH_DEG)
	var back := Vector3(0.0, sin(pitch), cos(pitch))
	var basis := Basis.looking_at(-back, Vector3.UP)
	return Transform3D(basis, target + back * DISTANCE)


static func apply(camera: Camera3D, target: Vector3, size: float) -> void:
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.keep_aspect = Camera3D.KEEP_HEIGHT
	camera.size = size
	camera.near = 0.1
	camera.far = DISTANCE * 3.0
	camera.transform = xform(target, size)


static func world_to_screen(target: Vector3, size: float, viewport: Vector2, world: Vector3) -> Vector2:
	return BattleCamera.world_to_screen(xform(target, size), size, viewport, world)


## 屏幕点 → 地面（y=0）交点；正交斜视下恒有解。
static func screen_to_ground(target: Vector3, size: float, viewport: Vector2, screen: Vector2) -> Vector3:
	var ray := BattleCamera.screen_ray(xform(target, size), size, viewport, screen)
	var hit: Variant = Plane(Vector3.UP, 0.0).intersects_ray(ray[0], ray[1])
	return hit if hit != null else target


## 拖动：手指移动 delta 像素 → 焦点反向移动，使手指下的地面点跟手。
static func pan(target: Vector3, size: float, viewport: Vector2, delta: Vector2, bounds: Rect2) -> Vector3:
	var a := screen_to_ground(target, size, viewport, Vector2.ZERO)
	var b := screen_to_ground(target, size, viewport, delta)
	return clamp_target(target - (b - a), bounds, size, viewport)


## 以屏幕点 at 为中心缩放：缩放前后 at 下的地面点不动。返回 [新焦点, 新 size]。
static func zoom_at(target: Vector3, size: float, viewport: Vector2, at: Vector2, factor: float, bounds: Rect2) -> Array:
	var new_size := clampf(size * factor, SIZE_MIN, SIZE_MAX)
	var before := screen_to_ground(target, size, viewport, at)
	var after := screen_to_ground(target, new_size, viewport, at)
	return [clamp_target(target + (before - after), bounds, new_size, viewport), new_size]


## bounds：城墙围出的地面矩形（x, z）。焦点按当前视野收紧，使画面最多露出墙外 EDGE_MARGIN 米；
## 视野比城还大的方向直接居中。
static func clamp_target(target: Vector3, bounds: Rect2, size: float, viewport: Vector2) -> Vector3:
	var half_w := size * viewport.x / maxf(viewport.y, 1.0) * 0.5
	var half_d := size * 0.5 / sin(deg_to_rad(PITCH_DEG))
	return Vector3(_clamp_axis(target.x, bounds.position.x, bounds.end.x, half_w), 0.0,
		_clamp_axis(target.z, bounds.position.y, bounds.end.y, half_d))


static func _clamp_axis(v: float, lo: float, hi: float, half: float) -> float:
	var a := lo - EDGE_MARGIN + half
	var b := hi + EDGE_MARGIN - half
	return (lo + hi) * 0.5 if a > b else clampf(v, a, b)
