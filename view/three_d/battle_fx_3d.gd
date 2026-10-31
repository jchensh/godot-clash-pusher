## D8 3D 战斗特效层：程序化卡通特效（几何体 + 粒子，与描边色阶光同一套着色）。
## 每帧只读 Battle 状态派生表现：远程开火 → 3D 投射物（带弧线、命中落点爆点）、受击星、死亡烟团、塔毁爆破、
## 减速/眩晕/冰冻状态挂件；法术经 Player.play_observer 链式钩子在落子那一刻放（双方/AI/联机同一入口）。
## 只做表现：不写任何逻辑量、不参与伤害判定、不进 sim/hash（视图侧随机数只影响画面）。
## 另记各单位/塔头顶世界坐标，供 2D 伤害数字锚定跟随（单位阵亡后保留 2 秒）。
extends Node3D

const FieldProjection := preload("res://view/three_d/field_projection.gd")
const ArenaPresenter := preload("res://view/three_d/arena_presenter.gd")
const ToonStyle := preload("res://view/three_d/toon_style.gd")
const FxMesh := preload("res://view/three_d/fx_mesh.gd")
const Catalog := preload("res://view/three_d/fx_catalog.gd")
const Quality := preload("res://view/three_d/quality.gd")

const CATCHUP_SKIP := 0.6       # 秒：一帧内逻辑时间推进超过此值 = 重连追帧，期间不放法术特效（防补放一屏）
const HEAD_KEEP := 2.0          # 秒：阵亡/消失后头顶锚点保留时长（伤害数字收尾）
const CLAIM_WINDOW := 0.15      # 秒：法术范围内的受击不再另放受击星（法术特效本身已覆盖）

var local_owner := 0
var flipped := false
var grid := Vector2.ZERO
## 测试/自检计数（纯表现统计）。
var stats := {}

var _battle = null
var _presenter = null
var _loader = null
var _camera: Camera3D
var _cam_basis := Basis.IDENTITY
var _time := 0.0
var _seen_elapsed := 0.0
var _parts: Array = []
var _hp: Dictionary = {}        # 单位/塔 实例 ID → 上帧 hp
var _cd: Dictionary = {}        # 单位/塔 实例 ID → 上帧攻击冷却（上升沿 = 刚出手）
var _last: Dictionary = {}      # 单位实例 ID → 最后存活时的 {pos(脚底世界坐标含飞行高度), h}
var _heads: Dictionary = {}     # 单位/塔实例 ID → [头顶世界坐标, 最后更新 _time]
var _pending: Dictionary = {}   # 目标实例 ID → 飞行中的投射物数（命中星改到投射物落点再放）
var _zones: Array = []          # 法术范围认领 [{c:Vector2(tile), r, until}]
var _status: Dictionary = {}    # 单位实例 ID → {kind, node}
var _beams: Dictionary = {}     # 攻击者实例 ID → {node, left, actor, target, ty}
var _destroyed: Dictionary = {} # 塔实例 ID → 已放过摧毁爆破
var _outline := true            # D8b 画质：setup 时按档位定（一局内不变）
var _shadow := true
var _particles_k := 1.0
var _fx_cap := 0

static var _dot: ImageTexture    # 粒子圆点贴图（程序生成：软边白圆，避免方块粒子）


## 一条表现动画：节点 + 时长 + 声明式轨道（缩放/弹道/弧线飞行/自转/透明度/闪烁），播完释放节点。
class Part:
	extends RefCounted
	var node: Node3D
	var t := 0.0
	var dur := 0.5
	var delay := 0.0
	var mode := ""             # 缩放曲线：""=不动 / lin / out / pop（先弹大再缩没）/ hold（保持后段缩没）
	var s0 := 1.0
	var s1 := 1.0
	var base := Vector3.ONE
	var rot := Basis.IDENTITY
	var spin := Vector3.ZERO
	var face_cam := false
	var vel := Vector3.ZERO
	var grav := 0.0
	var floor_y := -INF
	var mat: StandardMaterial3D = null
	var a0 := 1.0
	var a1 := 1.0
	var flicker := false
	var arc := false
	var from := Vector3.ZERO
	var to := Vector3.ZERO
	var arc_h := 0.0
	var target: Node3D = null
	var target_y := 0.0
	var orient := false
	var boomerang := false
	var on_end := Callable()


## 法术钩子：串在 Player.play_observer 上（保留原观察者，如 PVE 录制器），落子成功那一刻通知特效层。
## 弱引用特效层：页面销毁后逻辑层残留的钩子调用安全无副作用。
class CastHook:
	extends RefCounted
	var prev = null
	var fx_ref: WeakRef

	func on_card_played(owner_id: int, card_id: String, pos: Vector2) -> void:
		if prev != null:
			prev.on_card_played(owner_id, card_id, pos)
		var fx = fx_ref.get_ref()
		if fx != null:
			fx.cast(card_id, owner_id, pos)


## 可重入：换绑新的一局（重开/重连）先清空在播特效与记账。players = [Player...]（挂法术钩子）。
func setup(battle, presenter, loader, camera: Camera3D, players: Array, options: Dictionary) -> void:
	clear()
	_battle = battle
	_presenter = presenter
	_loader = loader
	_camera = camera
	local_owner = int(options.get("local_owner", 0))
	flipped = bool(options.get("flipped", false))
	grid = presenter.grid_size
	_seen_elapsed = battle.elapsed
	var q := Quality.profile()
	_outline = Quality.outline("fx")
	_shadow = Quality.casts_shadow("fx")
	_particles_k = float(q["particles"])
	_fx_cap = int(q["fx_cap"])
	for p in players:
		if p == null:
			continue
		if p.play_observer is CastHook:
			(p.play_observer as CastHook).fx_ref = weakref(self)
		else:
			var hook := CastHook.new()
			hook.prev = p.play_observer
			hook.fx_ref = weakref(self)
			p.play_observer = hook


func clear() -> void:
	for p in _parts:
		if is_instance_valid(p.node):
			p.node.free()
	_parts.clear()
	for b in _beams.values():
		if is_instance_valid(b["node"]):
			b["node"].free()
	for s in _status.values():
		if is_instance_valid(s["node"]):
			s["node"].free()
	for d in [_hp, _cd, _last, _heads, _pending, _status, _beams, _destroyed]:
		d.clear()
	_zones.clear()
	stats = {"casts": {}, "projectiles": {}, "bolts": 0, "beams": 0, "melee": 0, "impacts": 0, "hits": 0,
		"heals": 0, "deaths": 0, "towers": 0, "tower_shots": 0, "status": {}, "skipped_casts": 0, "capped": 0,
		"particles": 0}


func active_parts() -> int:
	return _parts.size()


## 头顶世界坐标（单位/塔实例 ID）；未知返回 null。
func head_world(id: int) -> Variant:
	var h = _heads.get(id)
	return null if h == null else h[0]


## 每帧在 presenter.advance 之后调用（节点位置已是本帧显示位）。
func advance(delta: float) -> void:
	if _battle == null or _battle.arena == null:
		return
	_time += delta
	_seen_elapsed = _battle.elapsed
	if _camera != null:
		_cam_basis = _camera.global_transform.basis if _camera.is_inside_tree() else _camera.transform.basis
	_scan_units(delta)
	_scan_towers()
	_step_beams(delta)
	for p in _parts.duplicate():
		if not _step(p, delta):
			_parts.erase(p)
	for id in _heads.keys():
		if _time - float(_heads[id][1]) > HEAD_KEEP:
			_heads.erase(id)
	var keep: Array = []
	for z in _zones:
		if float(z["until"]) > _time:
			keep.append(z)
	_zones = keep


# —— 法术 ——

func cast(card_id: String, owner_id: int, pos: Vector2) -> void:
	if _battle == null:
		return
	if _battle.elapsed - _seen_elapsed > CATCHUP_SKIP:
		stats["skipped_casts"] += 1
		return
	var kind: String = Catalog.spell_kind(_loader, card_id)
	var radius: float = Catalog.card_radius(_loader, card_id)
	stats["casts"][kind] = int(stats["casts"].get(kind, 0)) + 1
	if kind != "spawn" and kind != "heal":
		_zones.append({"c": pos, "r": maxf(radius, 1.2), "until": _time + CLAIM_WINDOW})
	Catalog.spell(self, kind, owner_id, pos, radius)


## 直伤法术（电击/落雷）的实际目标：离落点最近的敌方单位（与 SkillSystem 同规则，含本 tick 刚被打死的）。
## 返回目标脚底世界坐标与身高 [Vector3, h]；无目标 = 空放在落点。
func strike_point(pos: Vector2, owner_id: int) -> Array:
	var best = null
	var best_d := INF
	for u in _battle.arena.get_units():
		if u.owner_id == owner_id:
			continue
		var d: float = u.pos.distance_to(pos)
		if d < best_d:
			best_d = d
			best = u
	if best == null:
		return [world(pos), 0.0]
	var actor = _presenter.actor_for(best)
	if actor != null:
		return [actor.position + Vector3(0, actor.air_y(), 0), actor.body_height]
	return [world(best.pos, 1.8 if best.is_flying() else 0.0), 1.0]


# —— 坐标/工具（供 Catalog 构建特效）——

func world(tile: Vector2, h := 0.0) -> Vector3:
	return FieldProjection.tile_to_world(tile, grid, flipped, h)


## 该方「朝敌方」在世界空间的水平单位向量（玩家朝 y 减小、对手朝 y 增大，经视角翻转换算）。
func ahead(owner_id: int) -> Vector3:
	var step := Vector2(0, -1) if owner_id == 0 else Vector2(0, 1)
	var d := world(Vector2(10, 10) + step) - world(Vector2(10, 10))
	return d.normalized()


func team_color(owner_id: int) -> Color:
	return ArenaPresenter.COLOR_BLUE if owner_id == local_owner else ArenaPresenter.COLOR_RED


func time_now() -> float:
	return _time


## 实心卡通件（toon 色阶光 + 描边，tint 染整体色）。
func solid(mesh_name: String, tint: Color, pos: Vector3, scale_k: float, shadow := false) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = FxMesh.get_mesh(mesh_name)
	mi.material_override = ToonStyle.material(tint, Vector2.ONE, _outline)
	var cast := shadow and _shadow
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if cast else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = pos
	mi.scale = Vector3.ONE * scale_k
	add_child(mi)
	return mi


## 发光件（无光照 + 半透明，可加色混合）；每件独立材质以便各自淡出。
func glow(mesh: Mesh, color: Color, pos: Vector3, scale_k: float, additive := false) -> MeshInstance3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.vertex_color_use_as_albedo = true
	mat.albedo_color = color
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	if additive:
		mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = pos
	mi.scale = Vector3.ONE * scale_k
	add_child(mi)
	return mi


## 一次性粒子爆发（CPUParticles3D：Compatibility 渲染器下最稳）。数量按画质档位缩放，低档不放（返回 null）。
## opts：amount, life, speed, grav, size, spread, dir, radius(发射球半径), mesh(名), local(跟随父节点)。
func particles(pos: Vector3, color: Color, opts: Dictionary, parent: Node3D = null) -> CPUParticles3D:
	var amount := int(round(float(opts.get("amount", 8)) * _particles_k))
	if amount < 1:
		return null
	stats["particles"] += 1
	var cp := CPUParticles3D.new()
	cp.amount = amount
	cp.lifetime = float(opts.get("life", 0.5))
	cp.one_shot = not bool(opts.get("loop", false))
	cp.explosiveness = 0.0 if bool(opts.get("loop", false)) else 0.9
	cp.direction = opts.get("dir", Vector3.UP)
	cp.spread = float(opts.get("spread", 180.0))
	cp.initial_velocity_min = float(opts.get("speed", 3.0)) * 0.5
	cp.initial_velocity_max = float(opts.get("speed", 3.0))
	cp.gravity = Vector3(0, -float(opts.get("grav", 6.0)), 0)
	var radius := float(opts.get("radius", 0.0))
	if radius > 0.0:
		cp.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
		cp.emission_sphere_radius = radius
	var size := float(opts.get("size", 0.2))
	cp.scale_amount_min = size * 0.6
	cp.scale_amount_max = size
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 1.0))
	curve.add_point(Vector2(1.0, 0.0))
	cp.scale_amount_curve = curve
	cp.color = color
	var mesh_name := str(opts.get("mesh", ""))
	if mesh_name.is_empty():
		var quad := QuadMesh.new()
		quad.size = Vector2.ONE
		cp.mesh = quad
	else:
		cp.mesh = FxMesh.get_mesh(mesh_name)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	if mesh_name.is_empty():
		mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.albedo_texture = _dot_texture()
	cp.material_override = mat
	cp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	cp.local_coords = bool(opts.get("local", false))
	cp.preprocess = 0.02   # 出生即预算一步：粒子颜色/变换先就位，首帧不画未初始化（黑）的实例
	cp.position = pos
	(parent if parent != null else self).add_child(cp)
	cp.emitting = true
	if parent == null:
		part(cp, cp.lifetime + 0.1, {})
	return cp


static func _dot_texture() -> ImageTexture:
	if _dot == null:
		var img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
		for y in 32:
			for x in 32:
				var d := Vector2(x - 15.5, y - 15.5).length() / 15.5
				img.set_pixel(x, y, Color(1, 1, 1, clampf((1.0 - d) * 4.0, 0.0, 1.0)))
		_dot = ImageTexture.create_from_image(img)
	return _dot


## 登记一条动画。opts 键见 Part 字段：delay, mode, s0, s1, spin, face_cam, vel, grav, floor, a0, a1, flicker,
## arc:{from,to,h,target,ty,orient,boomerang}, on_end。
func part(node: Node3D, dur: float, opts: Dictionary) -> Part:
	var p := Part.new()
	p.node = node
	p.dur = maxf(dur, 0.01)
	p.delay = float(opts.get("delay", 0.0))
	p.mode = str(opts.get("mode", ""))
	p.s0 = float(opts.get("s0", 1.0))
	p.s1 = float(opts.get("s1", 1.0))
	p.base = node.scale
	p.rot = node.basis.orthonormalized()
	p.spin = opts.get("spin", Vector3.ZERO)
	p.face_cam = bool(opts.get("face_cam", false))
	p.vel = opts.get("vel", Vector3.ZERO)
	p.grav = float(opts.get("grav", 0.0))
	p.floor_y = float(opts.get("floor", -INF))
	p.flicker = bool(opts.get("flicker", false))
	p.on_end = opts.get("on_end", Callable())
	if node is GeometryInstance3D and (node as GeometryInstance3D).material_override is StandardMaterial3D:
		p.mat = (node as GeometryInstance3D).material_override
		p.a0 = float(opts.get("a0", p.mat.albedo_color.a))
		p.a1 = float(opts.get("a1", p.a0))
	var arc: Dictionary = opts.get("arc", {})
	if not arc.is_empty():
		p.arc = true
		p.from = arc["from"]
		p.to = arc["to"]
		p.arc_h = float(arc.get("h", 0.0))
		p.target = arc.get("target")
		p.target_y = float(arc.get("ty", 0.0))
		p.orient = bool(arc.get("orient", true))
		p.boomerang = bool(arc.get("boomerang", false))
		node.position = p.from
	if p.delay > 0.0:
		node.visible = false
	_parts.append(p)
	_step(p, 0.0)
	return p


func _step(p: Part, delta: float) -> bool:
	if not is_instance_valid(p.node):
		return false
	p.t += delta
	if p.t < p.delay:
		p.node.visible = false
		return true
	p.node.visible = not p.flicker or int(p.t * 30.0) % 3 != 0
	var lt := p.t - p.delay
	var k := clampf(lt / p.dur, 0.0, 1.0)
	var rot := p.rot
	if p.arc:
		if p.target != null and is_instance_valid(p.target):
			p.to = p.target.position + Vector3(0, p.target_y, 0)
		var kk := sin(k * PI) if p.boomerang else k
		var prev := p.node.position
		var pos := p.from.lerp(p.to, kk) + Vector3.UP * p.arc_h * 4.0 * kk * (1.0 - kk)
		p.node.position = pos
		var dir := pos - prev
		if p.orient and dir.length() > 0.0001:
			var up := Vector3.UP if absf(dir.normalized().y) < 0.98 else Vector3.FORWARD
			p.rot = Basis.looking_at(dir, up)
			rot = p.rot
	elif p.vel != Vector3.ZERO or p.grav != 0.0:
		p.vel.y -= p.grav * delta
		var pos2 := p.node.position + p.vel * delta
		if pos2.y < p.floor_y:
			pos2.y = p.floor_y
			p.vel = Vector3.ZERO
			p.grav = 0.0
			p.spin = Vector3.ZERO
		p.node.position = pos2
	if p.face_cam:
		rot = _cam_basis
	if p.spin != Vector3.ZERO:
		rot = rot * Basis.from_euler(p.spin * lt)
	var s := 1.0
	match p.mode:
		"lin":
			s = lerpf(p.s0, p.s1, k)
		"out":
			s = lerpf(p.s0, p.s1, 1.0 - pow(1.0 - k, 3.0))
		"pop":
			s = p.s1 * (k / 0.25 if k < 0.25 else 1.0 - pow((k - 0.25) / 0.75, 2.0))
		"hold":
			s = p.s1 if k < 0.7 else p.s1 * (1.0 - (k - 0.7) / 0.3)
	p.node.basis = rot * Basis.from_scale(p.base * maxf(s, 0.001))
	if p.mat != null:
		p.mat.albedo_color.a = lerpf(p.a0, p.a1, k)
	if lt >= p.dur:
		if p.on_end.is_valid():
			p.on_end.call(p)
		_drop(p.node)
		return false
	return true


# —— 每帧扫描逻辑状态（只读）——

func _scan_units(delta: float) -> void:
	var alive: Dictionary = {}
	for u in _battle.arena.get_units():
		if not u.is_alive():
			continue
		var id: int = u.get_instance_id()
		var actor = _presenter.actor_for(u)
		if actor == null:
			continue
		alive[id] = true
		var foot: Vector3 = actor.position + Vector3(0, actor.air_y(), 0)
		_heads[id] = [foot + Vector3(0, actor.body_height, 0), _time]
		_last[id] = {"pos": foot, "h": actor.body_height}
		var cd: float = u._attack_cooldown
		if _cd.has(id) and cd > float(_cd[id]) + 0.01:
			_on_unit_attack(u, actor)
		_cd[id] = cd
		if _hp.has(id):
			var d: float = float(_hp[id]) - u.hp
			if d > 0.5:
				_on_hit(id, u.pos, foot + Vector3(0, actor.body_height * 0.55, 0), d, u.max_hp)
			elif d < -0.5:
				stats["heals"] += 1
				if _optional_ok():
					Catalog.heal_sparkle(self, foot, actor.body_height)
		_hp[id] = u.hp
		_sync_status(u, actor, id, delta)
	for id in _last.keys():
		if not alive.has(id):
			stats["deaths"] += 1
			if _optional_ok():
				Catalog.poof(self, _last[id]["pos"], float(_last[id]["h"]))
			for book in [_last, _hp, _cd, _pending]:
				book.erase(id)
			if _status.has(id) and is_instance_valid(_status[id]["node"]):
				_drop(_status[id]["node"])
			_status.erase(id)


func _scan_towers() -> void:
	for t in _battle.player_towers + _battle.opponent_towers:
		var id: int = t.get_instance_id()
		var actor = _presenter.tower_actor_for(t)
		if actor == null:
			continue
		var base: Vector3 = actor.position
		_heads[id] = [base + Vector3(0, actor.top_height, 0), _time]
		if _hp.has(id):
			var d: float = float(_hp[id]) - t.hp
			if d > 0.5:
				var side := Vector3(randf_range(-0.6, 0.6), 0, randf_range(-0.6, 0.6))
				_on_hit(id, t.pos, base + side + Vector3(0, actor.top_height * 0.55, 0), d, t.max_hp)
		_hp[id] = t.hp
		if t.is_destroyed() and not _destroyed.has(id):
			_destroyed[id] = true
			stats["towers"] += 1
			Catalog.tower_blast(self, base, float(t.fw), t.is_king(), team_color(t.owner_id))
		var cd: float = t._attack_cooldown
		if _cd.has(id) and cd > float(_cd[id]) + 0.01 and not t.is_destroyed():
			var victim = tower_target(_battle, t)
			var victim_actor = _presenter.actor_for(victim) if victim != null else null
			if victim_actor != null:
				stats["tower_shots"] += 1
				var muzzle: Vector3 = base + Vector3(0, actor.top_height * 0.85, 0)
				_launch(Catalog.TOWER_SHOT, muzzle, victim, victim_actor, 0.0)
		_cd[id] = cd


func _on_hit(id: int, tile: Vector2, at: Vector3, amount: float, max_hp: float) -> void:
	if int(_pending.get(id, 0)) > 0:   # 投射物还在飞：受击星改到落点再放
		_pending[id] = int(_pending[id]) - 1
		return
	for z in _zones:
		if tile.distance_to(z["c"]) <= float(z["r"]) + 0.5:
			return
	stats["hits"] += 1
	if _optional_ok():
		Catalog.hit_star(self, at, amount >= maxf(150.0, max_hp * 0.25))


## 可选特效（受击星/阵亡烟团/治疗闪光）受同屏上限约束；法术与投射物恒放（含义必须看得到）。
func _optional_ok() -> bool:
	if _fx_cap <= 0 or _parts.size() < _fx_cap:
		return true
	stats["capped"] += 1
	return false


# —— 攻击表现 ——

func _on_unit_attack(u, actor) -> void:
	var target = u.current_target
	if target == null or not is_instance_valid(target):
		return
	var spec: Dictionary = Catalog.attack_spec(u.unit_id)
	var type := str(spec.get("type", "melee"))
	var is_unit: bool = target.get("unit_id") != null
	var tgt_node = _presenter.actor_for(target) if is_unit else _presenter.tower_actor_for(target)
	if tgt_node == null:
		return
	var ty: float = (tgt_node.air_y() + tgt_node.body_height * 0.5) if is_unit else tgt_node.top_height * 0.5
	var facing := Vector3(sin(actor.rotation.y), 0, cos(actor.rotation.y))
	var hand: Vector3 = actor.position + facing * 0.35 + Vector3(0, actor.air_y() + actor.body_height * 0.6, 0)
	var target_at: Vector3 = tgt_node.position + Vector3(0, ty, 0)
	match type:
		"proj":
			_launch(spec, hand, target, tgt_node, u.splash_radius)
		"bolt":
			stats["bolts"] += 1
			Catalog.zap_bolt(self, hand, target_at, spec.get("tint", Color.WHITE))
		"beam":
			stats["beams"] += 1
			_beam(u, actor, tgt_node, ty, maxf(float(u.attack_speed), 0.2), spec.get("tint", Color.WHITE))
		_:
			stats["melee"] += 1
			Catalog.melee_impact(self, str(spec.get("impact", "")), target_at, u.splash_radius,
				actor.position if u.unit_id == "valkyrie_body" else target_at)


## 发射一枚 3D 投射物：弧线飞向目标（目标移动则追随其显示位），到点放落点特效（含溅射范围环）。
func _launch(spec: Dictionary, from: Vector3, target, tgt_node: Node3D, splash: float) -> void:
	var kind := str(spec.get("mesh", "arrow"))
	stats["projectiles"][kind] = int(stats["projectiles"].get(kind, 0)) + 1
	var is_unit: bool = target.get("unit_id") != null
	var ty: float = (tgt_node.air_y() + tgt_node.body_height * 0.5) if is_unit else tgt_node.top_height * 0.5
	var to := tgt_node.position + Vector3(0, ty, 0)
	var dist := from.distance_to(to)
	var dur := clampf(dist / float(spec.get("speed", 16.0)), 0.12, 0.7)
	var node: MeshInstance3D
	if bool(spec.get("glow", false)):
		node = glow(FxMesh.get_mesh(kind), spec.get("tint", Color.WHITE), from, float(spec.get("scale", 1.0)))
	else:
		node = solid(kind, spec.get("tint", Color.WHITE), from, float(spec.get("scale", 1.0)), true)
	var tid: int = target.get_instance_id()
	_pending[tid] = int(_pending.get(tid, 0)) + 1
	var impact := str(spec.get("impact", "spark"))
	var end := func(p) -> void:
		stats["impacts"] += 1
		Catalog.impact(self, impact, p.node.position, splash)
	var trail = spec.get("trail")
	if trail != null:
		particles(Vector3.ZERO, trail, {"amount": 10, "life": 0.25, "speed": 0.4, "grav": 0.0, "size": 0.22,
			"loop": true}, node)
	part(node, dur, {"spin": spec.get("spin", Vector3.ZERO), "on_end": end, "arc": {"from": from, "to": to,
		"h": dist * float(spec.get("arc", 0.15)), "target": tgt_node, "ty": ty,
		"orient": not bool(spec.get("no_orient", false)), "boomerang": bool(spec.get("boomerang", false))}})


## 持续光束（熔岩龙）：每次出手续命，期间每帧跟随攻击者与目标。
func _beam(u, actor, tgt_node: Node3D, ty: float, interval: float, color: Color) -> void:
	var id: int = u.get_instance_id()
	var b = _beams.get(id)
	if b == null or not is_instance_valid(b["node"]):
		var node := glow(FxMesh.get_mesh("column"), color, Vector3.ZERO, 1.0)
		b = {"node": node}
		_beams[id] = b
	b["left"] = interval * 0.9
	b["actor"] = actor
	b["target"] = tgt_node
	b["ty"] = ty


func _step_beams(delta: float) -> void:
	for id in _beams.keys():
		var b: Dictionary = _beams[id]
		b["left"] = float(b["left"]) - delta
		var node: MeshInstance3D = b["node"]
		if b["left"] <= 0.0 or not is_instance_valid(b["actor"]) or not is_instance_valid(b["target"]) \
				or not is_instance_valid(node):
			if is_instance_valid(node):
				_drop(node)
			_beams.erase(id)
			continue
		var actor = b["actor"]
		var facing := Vector3(sin(actor.rotation.y), 0, cos(actor.rotation.y))
		var a: Vector3 = actor.position + facing * 0.4 + Vector3(0, actor.air_y() + actor.body_height * 0.5, 0)
		var t: Vector3 = (b["target"] as Node3D).position + Vector3(0, float(b["ty"]), 0)
		var dir := t - a
		var width := 0.09 + 0.03 * sin(_time * 40.0)
		node.transform = Transform3D(Catalog.align_y(dir) * Basis.from_scale(Vector3(width, dir.length(), width)), a)


# —— 状态挂件（减速/眩晕/冰冻）：挂在单位节点下随之移动，状态结束即撤 ——

func _sync_status(u, actor, id: int, delta: float) -> void:
	var kind: String = u._status_kind if u._status_timer > 0.0 else ""
	var cur = _status.get(id)
	if cur != null and (not is_instance_valid(cur["node"]) or cur["kind"] != kind):
		if is_instance_valid(cur["node"]):
			_drop(cur["node"])
		_status.erase(id)
		cur = null
	if kind != "" and cur == null:
		var node: Node3D = Catalog.status_node(kind, actor)
		actor.add_child(node)
		_status[id] = {"kind": kind, "node": node}
		stats["status"][kind] = int(stats["status"].get(kind, 0)) + 1
	elif cur != null:
		(cur["node"] as Node3D).rotation.y += delta * (6.0 if kind == "stun" else 2.0)


## 在树上 = 帧末释放；不在树上（单测裸实例）= 立即释放。
static func _drop(node: Node) -> void:
	if node.is_inside_tree():
		node.queue_free()
	else:
		node.free()


## 塔射程内最近的存活敌方单位（view 侧复刻 arena 选择；PvE/PvP 页与本层共用）。
static func tower_target(battle, t):
	var best = null
	var best_d := INF
	var r: float = float(t.attack_range) + 0.001
	for u in battle.arena.get_units():
		if not u.is_alive() or u.owner_id == t.owner_id:
			continue
		var d: float = (t.pos as Vector2).distance_to(u.pos as Vector2)
		if d <= r and d < best_d:
			best_d = d
			best = u
	return best
