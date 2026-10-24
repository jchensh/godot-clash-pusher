## D8 特效目录：法术卡 → 特效、远程单位 → 投射物/放电/光束，以及各特效的程序化拼装（几何体 + 粒子）。
## 只决定「画什么」，含义对齐卡牌/单位的逻辑效果（范围 = 卡牌 radius、溅射环 = 单位 splash_radius、
## 直伤劈在实际被打的目标上、减速/眩晕/冰冻挂状态件）；不参与任何判定。
extends RefCounted

const FxMesh := preload("res://view/three_d/fx_mesh.gd")
const ToonStyle := preload("res://view/three_d/toon_style.gd")

const UP := Vector3.UP
const FIRE := Color(1.0, 0.55, 0.15)
const EMBER := Color(1.0, 0.75, 0.3)
const SMOKE := Color("d9d4ca")
const DUST := Color("d8c39a")
const FROST := Color("a6e3ff")
const SNOW := Color("f4fbff")
const ELECTRIC := Color(0.45, 0.8, 1.0)
const THUNDER := Color(1.0, 0.9, 0.25)
const HEAL := Color(0.45, 0.95, 0.45)
const STONE := Color("b9ae9c")
const SCORCH := Color(0.22, 0.16, 0.1, 0.4)

## 法术卡 → 特效类型（纯法术 + 雷法师登场电爆）；其余兵牌 = 落地尘土。
const SPELLS := {
	"fireball": "fireball", "arrows": "arrows", "zap": "zap", "lightning": "lightning", "log": "log",
	"heal": "heal", "rock_shower": "rock_shower", "giant_snowball": "snowball", "freeze": "freeze",
	"electro_wizard": "electro_burst",
}

## 单位攻击表现。type：proj=3D 投射物（mesh/速度/弧高比例/自转/落点 impact/拖尾）、bolt=瞬发电弧、
## beam=持续光束、melee=近身（可带落点 impact）。射程 ≥ 2 格的单位全部登记（单测把关）；未登记 = 普通近战。
const ATTACKS := {
	"archer_body": {"type": "proj", "mesh": "arrow", "speed": 16.0, "arc": 0.18, "scale": 1.0},
	"musketeer_body": {"type": "proj", "mesh": "bullet", "speed": 28.0, "arc": 0.02, "scale": 1.1, "impact": "spark"},
	"spear_goblin_body": {"type": "proj", "mesh": "spear", "speed": 14.0, "arc": 0.14, "scale": 0.9},
	"axe_thrower_body": {"type": "proj", "mesh": "axe", "speed": 12.0, "arc": 0.16, "scale": 0.9,
		"spin": Vector3(-16.0, 0, 0), "no_orient": true},
	"executioner_body": {"type": "proj", "mesh": "double_axe", "speed": 9.0, "arc": 0.04, "scale": 0.9,
		"spin": Vector3(0, 18.0, 0), "no_orient": true, "boomerang": true},
	"royal_giant_body": {"type": "proj", "mesh": "cannonball", "speed": 14.0, "arc": 0.18, "scale": 0.8, "impact": "blast"},
	"bomber_body": {"type": "proj", "mesh": "shell", "speed": 12.0, "arc": 0.3, "scale": 1.1, "impact": "blast",
		"spin": Vector3(-10.0, 0, 0)},
	"princess_body": {"type": "proj", "mesh": "orb", "tint": Color("4fb4ff"), "speed": 16.0, "arc": 0.22, "scale": 1.0,
		"impact": "magic", "trail": Color(0.55, 0.8, 1.0)},
	"ice_wizard_body": {"type": "proj", "mesh": "orb", "tint": FROST, "speed": 13.0, "arc": 0.14, "scale": 1.0,
		"impact": "frost", "trail": SNOW},
	"wizard_body": {"type": "proj", "mesh": "ball", "glow": true, "tint": FIRE, "speed": 13.0, "arc": 0.12, "scale": 0.55,
		"impact": "fire", "trail": EMBER},
	"baby_dragon_body": {"type": "proj", "mesh": "ball", "glow": true, "tint": FIRE, "speed": 12.0, "arc": 0.04,
		"scale": 0.55, "impact": "fire", "trail": EMBER},
	"fire_pup_body": {"type": "proj", "mesh": "ball", "glow": true, "tint": FIRE, "speed": 12.0, "arc": 0.04,
		"scale": 0.4, "impact": "fire", "trail": EMBER},
	"phoenix_body": {"type": "proj", "mesh": "ball", "glow": true, "tint": Color(1.0, 0.7, 0.2), "speed": 13.0,
		"arc": 0.0, "scale": 0.4, "impact": "fire", "trail": EMBER},
	"phoenix_reborn_body": {"type": "proj", "mesh": "ball", "glow": true, "tint": Color(1.0, 0.7, 0.2), "speed": 13.0,
		"arc": 0.0, "scale": 0.35, "impact": "fire", "trail": EMBER},
	"minion_body": {"type": "proj", "mesh": "feather", "speed": 14.0, "arc": 0.05, "scale": 1.0},
	"mega_minion_body": {"type": "proj", "mesh": "potion", "speed": 11.0, "arc": 0.28, "scale": 1.0,
		"impact": "potion", "spin": Vector3(8.0, 0, 6.0), "no_orient": true},
	"electro_wizard_body": {"type": "bolt", "tint": THUNDER},
	"electro_spirit_body": {"type": "bolt", "tint": THUNDER},
	"inferno_dragon_body": {"type": "beam", "tint": Color(1.0, 0.4, 0.15, 0.85)},
	"lava_hound_body": {"type": "melee"},   # 幺蛾子持长矛：2 格射程是矛长，近身戳刺
	"fire_spirit_body": {"type": "melee", "impact": "fire"},
	"ice_spirit_body": {"type": "melee", "impact": "frost"},
}

## 塔反击：箭塔/王塔射箭。
const TOWER_SHOT := {"type": "proj", "mesh": "arrow", "speed": 18.0, "arc": 0.12, "scale": 1.0}


static func attack_spec(unit_id: String) -> Dictionary:
	return ATTACKS.get(unit_id, {})


static func spell_kind(_loader, card_id: String) -> String:
	return SPELLS.get(card_id, "spawn")


## 卡牌的作用半径（取第一个带 radius 的技能积木；无 = 0）。
static func card_radius(loader, card_id: String) -> float:
	if loader == null:
		return 0.0
	for sk in loader.get_card(card_id).get("skills", []):
		if typeof(sk) == TYPE_DICTIONARY and sk.has("radius"):
			return float(sk["radius"])
	return 0.0


## 让 +Y 对齐 dir 的旋转（光束/闪电棱柱用）。
static func align_y(dir: Vector3) -> Basis:
	var n := dir.normalized()
	var axis := UP.cross(n)
	if axis.length() > 0.0001:
		return Basis(axis.normalized(), UP.angle_to(n))
	return Basis.IDENTITY if n.y >= 0.0 else Basis(Vector3.RIGHT, PI)


# —— 法术 ——

static func spell(fx, kind: String, owner_id: int, pos: Vector2, r: float) -> void:
	var c: Vector3 = fx.world(pos)
	match kind:
		"fireball":
			_fireball(fx, owner_id, c, r)
		"arrows":
			_arrows(fx, owner_id, pos, r)
		"zap":
			var sp: Array = fx.strike_point(pos, owner_id)
			_zap(fx, sp[0], float(sp[1]))
		"lightning":
			var sp2: Array = fx.strike_point(pos, owner_id)
			_lightning(fx, sp2[0], float(sp2[1]))
		"log":
			_log(fx, owner_id, c, r)
		"heal":
			_heal(fx, c, r)
		"rock_shower":
			_rock_shower(fx, pos, r)
		"snowball":
			_snowball(fx, owner_id, c, r)
		"freeze":
			_freeze(fx, pos, r)
		"electro_burst":
			_electro_burst(fx, c, r)
			_spawn_dust(fx, c, fx.team_color(owner_id))
		_:
			_spawn_dust(fx, c, fx.team_color(owner_id))


static func _fireball(fx, owner_id: int, c: Vector3, r: float) -> void:
	var start: Vector3 = c + UP * 7.0 - fx.ahead(owner_id) * 3.0
	var ball = fx.glow(FxMesh.get_mesh("ball"), FIRE, start, 1.3)
	fx.particles(Vector3.ZERO, EMBER, {"amount": 14, "life": 0.3, "speed": 0.5, "grav": 0.0, "size": 0.45, "loop": true}, ball)
	var boom := func(_p) -> void:
		explosion(fx, c, r, FIRE, 1.0)
		ground_disk(fx, c, r * 0.8, SCORCH, 1.8)
	fx.part(ball, 0.14, {"arc": {"from": start, "to": c + UP * 0.6, "h": 0.0, "orient": false}, "on_end": boom})


static func _arrows(fx, owner_id: int, pos: Vector2, r: float) -> void:
	var back: Vector3 = fx.ahead(owner_id) * 2.5
	for i in 14:
		var p := pos + _in_circle(r * 0.9)
		var to: Vector3 = fx.world(p, 0.15)
		var from: Vector3 = to + UP * 6.0 - back + Vector3(randf_range(-0.4, 0.4), 0, randf_range(-0.4, 0.4))
		var arrow = fx.solid("arrow", Color.WHITE, from, 0.9, true)
		var stick := func(pp) -> void:
			var stuck = fx.solid("arrow", Color.WHITE, pp.node.position, 0.9)
			stuck.basis = pp.node.basis
			fx.part(stuck, 0.5, {"mode": "hold", "s1": 1.0})
		fx.part(arrow, 0.18, {"delay": float(i) * 0.018, "arc": {"from": from, "to": to, "h": 0.0}, "on_end": stick})
	ring(fx, fx.world(pos), r, DUST, 0.5)
	fx.particles(fx.world(pos, 0.2), DUST, {"amount": 16, "life": 0.5, "speed": 1.5, "grav": 2.0, "size": 0.35,
		"radius": r * 0.8})


static func _zap(fx, foot: Vector3, h: float) -> void:
	var at := foot + UP * maxf(h * 0.5, 0.4)
	for i in 3:
		var off := Vector3(randf_range(-1.0, 1.0), randf_range(0.6, 1.6), randf_range(-1.0, 1.0))
		var bolt = fx.glow(FxMesh.bolt(at + off, at, 0.25, 5, 0.09), ELECTRIC, Vector3.ZERO, 1.0)
		fx.part(bolt, 0.25, {"flicker": true, "a1": 0.2})
	flash(fx, at, ELECTRIC, 1.2, 0.2)
	ring(fx, foot, 1.2, ELECTRIC, 0.3)
	fx.particles(at, ELECTRIC, {"amount": 12, "life": 0.3, "speed": 4.0, "grav": 2.0, "size": 0.18})


static func _lightning(fx, foot: Vector3, h: float) -> void:
	var at := foot + UP * maxf(h * 0.5, 0.4)
	var top := foot + UP * 14.0 + Vector3(randf_range(-1.0, 1.0), 0, randf_range(-1.0, 1.0))
	var main = fx.glow(FxMesh.bolt(top, at, 0.7, 10, 0.22), THUNDER, Vector3.ZERO, 1.0)
	fx.part(main, 0.4, {"flicker": true, "a1": 0.3})
	var branch_from := top.lerp(at, 0.45)
	var branch = fx.glow(FxMesh.bolt(branch_from, branch_from + Vector3(1.5, -3.0, 1.0), 0.4, 5, 0.1), THUNDER,
		Vector3.ZERO, 1.0)
	fx.part(branch, 0.3, {"flicker": true, "a1": 0.0})
	flash(fx, at, THUNDER, 2.4, 0.3)
	ring(fx, foot, 1.8, THUNDER, 0.45)
	ground_disk(fx, foot, 1.1, SCORCH, 1.5)
	fx.particles(at, THUNDER, {"amount": 18, "life": 0.4, "speed": 5.0, "grav": 6.0, "size": 0.2})


static func _log(fx, owner_id: int, c: Vector3, r: float) -> void:
	var fwd: Vector3 = fx.ahead(owner_id)
	var s := r * 0.75
	var lift := UP * 0.42 * s
	var log_node = fx.solid("log", Color.WHITE, c - fwd * r + lift, s, true)
	log_node.basis = Basis.looking_at(fwd, UP) * Basis.from_scale(Vector3.ONE * s)
	var roll := (2.0 * r / 0.5) / (0.42 * s)
	fx.part(log_node, 0.65, {"mode": "hold", "s1": 1.0, "spin": Vector3(-roll, 0, 0),
		"arc": {"from": c - fwd * r + lift, "to": c + fwd * r * 1.3 + lift, "h": 0.0, "orient": false}})
	ring(fx, c, r, DUST, 0.55)
	fx.particles(c + UP * 0.2, DUST, {"amount": 18, "life": 0.6, "speed": 1.5, "grav": 2.0, "size": 0.4, "radius": r})


static func _heal(fx, c: Vector3, r: float) -> void:
	ground_disk(fx, c, r, Color(HEAL, 0.35), 0.9)
	ring(fx, c, r, HEAL, 0.6)
	var col = fx.glow(FxMesh.get_mesh("column"), Color(HEAL, 0.25), c, 1.0)
	col.scale = Vector3(r * 0.9, 3.0, r * 0.9)
	fx.part(col, 0.8, {"mode": "out", "s0": 0.3, "s1": 1.0, "a1": 0.0})
	fx.particles(c + UP * 0.4, HEAL, {"amount": 14, "life": 0.9, "speed": 2.5, "grav": -1.0, "size": 0.5,
		"spread": 15.0, "radius": r * 0.8, "mesh": "plus"})


static func _rock_shower(fx, pos: Vector2, r: float) -> void:
	for i in 7:
		var p := pos + _in_circle(r * 0.85)
		var s := randf_range(0.45, 0.75)
		var to: Vector3 = fx.world(p, s * 0.35)
		var from := to + UP * 8.0 + Vector3(randf_range(-0.5, 0.5), 0, randf_range(-0.5, 0.5))
		var rock = fx.solid("rock", STONE, from, s, true)
		var land := func(pp) -> void:
			var rest = fx.solid("rock", STONE, pp.node.position, s, true)
			rest.basis = pp.node.basis
			fx.part(rest, 0.6, {"mode": "hold", "s1": 1.0})
			puff(fx, pp.node.position, DUST, 2, 0.5)
			fx.particles(pp.node.position, STONE, {"amount": 6, "life": 0.4, "speed": 3.0, "grav": 10.0, "size": 0.18,
				"mesh": "chunk"})
		fx.part(rock, 0.16, {"delay": float(i) * 0.04, "spin": Vector3(randf(), randf(), randf()) * 8.0,
			"arc": {"from": from, "to": to, "h": 0.0, "orient": false}, "on_end": land})
	ring(fx, fx.world(pos), r, DUST, 0.55)


static func _snowball(fx, owner_id: int, c: Vector3, r: float) -> void:
	var s := r * 0.7
	var start: Vector3 = c + UP * 6.0 - fx.ahead(owner_id) * 2.0
	var ball = fx.solid("snowball", Color.WHITE, start, s, true)
	var burst := func(_p) -> void:
		for i in 10:
			var a := TAU * float(i) / 10.0
			var out := Vector3(cos(a), 0, sin(a)) * randf_range(3.0, 6.0) + UP * randf_range(3.0, 5.0)
			var chunk = fx.solid("chunk", SNOW, c + UP * s * 0.4, randf_range(0.5, 0.8))
			fx.part(chunk, 0.8, {"mode": "hold", "s1": 1.0, "vel": out, "grav": 18.0, "floor": 0.12,
				"spin": Vector3(randf(), randf(), randf()) * 6.0})
		ring(fx, c, r, FROST, 0.6)
		ground_disk(fx, c, r * 0.8, Color(SNOW, 0.6), 1.2)
		fx.particles(c + UP * 0.5, SNOW, {"amount": 20, "life": 0.6, "speed": 3.0, "grav": 3.0, "size": 0.25})
	fx.part(ball, 0.15, {"spin": Vector3(-12.0, 0, 0), "arc": {"from": start, "to": c + UP * s * 0.45, "h": 0.0,
		"orient": false}, "on_end": burst})


static func _freeze(fx, pos: Vector2, r: float) -> void:
	var c: Vector3 = fx.world(pos)
	ground_disk(fx, c, r, Color(FROST, 0.45), 1.4)
	ring(fx, c, r, FROST, 0.6)
	for i in 9:
		var a := float(i) * 2.39996
		var d := r * 0.85 * sqrt((float(i) + 0.5) / 9.0)
		var at: Vector3 = fx.world(pos + Vector2(cos(a), sin(a)) * d)
		var shard = fx.solid("ice_shard", FROST, at, randf_range(0.6, 0.9), true)
		shard.rotation.y = randf() * TAU
		fx.part(shard, 1.1, {"delay": float(i) * 0.03, "mode": "hold", "s1": 1.0})
	fx.particles(c + UP * 0.3, SNOW, {"amount": 20, "life": 0.9, "speed": 1.2, "grav": -0.5, "size": 0.22,
		"radius": r * 0.8})


static func _electro_burst(fx, c: Vector3, r: float) -> void:
	for i in 6:
		var a := TAU * float(i) / 6.0 + randf() * 0.4
		var tip := c + Vector3(cos(a), 0, sin(a)) * r + UP * 0.25
		var bolt = fx.glow(FxMesh.bolt(c + UP * 0.6, tip, 0.25, 5, 0.09), THUNDER, Vector3.ZERO, 1.0)
		fx.part(bolt, 0.3, {"flicker": true, "a1": 0.1})
	ring(fx, c, r, THUNDER, 0.4)
	flash(fx, c + UP * 0.6, THUNDER, 1.5, 0.25)


static func _spawn_dust(fx, c: Vector3, team: Color) -> void:
	puff(fx, c + UP * 0.15, DUST, 5, 0.75)
	ring(fx, c, 1.1, team, 0.45)


# —— 命中 / 受击 / 死亡 / 塔毁 ——

## 投射物落点。splash > 0 时地面画溅射范围环（= 单位 splash_radius）。
static func impact(fx, kind: String, at: Vector3, splash: float) -> void:
	var ground := Vector3(at.x, 0.0, at.z)
	match kind:
		"blast":
			explosion(fx, at, maxf(splash, 0.8), FIRE, 0.6)
		"fire":
			flash(fx, at, FIRE, 1.0, 0.25)
			fx.particles(at, EMBER, {"amount": 10, "life": 0.4, "speed": 2.5, "grav": -1.0, "size": 0.25})
		"frost":
			flash(fx, at, FROST, 1.0, 0.25)
			fx.particles(at, SNOW, {"amount": 10, "life": 0.5, "speed": 2.0, "grav": 1.0, "size": 0.22})
		"magic":
			flash(fx, at, Color(0.55, 0.8, 1.0), 0.9, 0.22)
			fx.particles(at, Color(0.8, 0.9, 1.0), {"amount": 8, "life": 0.4, "speed": 2.5, "grav": 0.0, "size": 0.2})
		"potion":
			puff(fx, at, Color("b07ee0"), 4, 0.6)
			fx.particles(at, Color("c9a0f0"), {"amount": 10, "life": 0.4, "speed": 2.5, "grav": 4.0, "size": 0.2})
		_:
			hit_star(fx, at, false)
	if splash > 0.0:
		ring(fx, ground, splash, _impact_tint(kind), 0.4)


static func melee_impact(fx, kind: String, at: Vector3, splash: float, ring_center: Vector3) -> void:
	if kind == "fire" or kind == "frost":
		impact(fx, kind, at, 0.0)
	if splash > 0.0:
		ring(fx, Vector3(ring_center.x, 0.0, ring_center.z), splash, _impact_tint(kind), 0.35)


static func _impact_tint(kind: String) -> Color:
	match kind:
		"blast", "fire":
			return FIRE
		"frost":
			return FROST
		"magic":
			return Color(0.55, 0.8, 1.0)
		"potion":
			return Color("b07ee0")
	return Color(1, 1, 1, 0.8)


## 受击星：面朝镜头弹出即缩没的卡通星 + 几颗火花；重击更大更橙。
static func hit_star(fx, at: Vector3, big: bool) -> void:
	var star = fx.solid("star", Color(1.0, 0.72, 0.25) if big else Color(1.0, 0.97, 0.7), at, 1.0)
	fx.part(star, 0.22 if big else 0.18, {"mode": "pop", "s1": 0.8 if big else 0.45, "face_cam": true,
		"spin": Vector3(0, 0, randf_range(-6.0, 6.0))})
	fx.particles(at, Color(1, 1, 0.8), {"amount": 7 if big else 4, "life": 0.25, "speed": 4.0 if big else 3.0,
		"grav": 4.0, "size": 0.14})


static func heal_sparkle(fx, foot: Vector3, h: float) -> void:
	fx.particles(foot + UP * h * 0.6, HEAL, {"amount": 4, "life": 0.6, "speed": 1.5, "grav": -1.5, "size": 0.35,
		"spread": 25.0, "mesh": "plus"})


## 阵亡烟团（实心卡通烟球弹出缩没）+ 小星。
static func poof(fx, pos: Vector3, h: float) -> void:
	puff(fx, pos + UP * h * 0.4, SMOKE, 6, maxf(h, 0.8) * 0.8)
	for i in 3:
		var star = fx.solid("star", Color(1.0, 0.97, 0.7), pos + UP * h * 0.6, 1.0)
		var a := TAU * float(i) / 3.0
		fx.part(star, 0.45, {"mode": "pop", "s1": 0.25, "face_cam": true,
			"vel": Vector3(cos(a), 1.5, sin(a)) * 1.6, "grav": 3.0})


## 塔被摧毁：闪光 + 冲击环 + 石块碎片抛射 + 阵营色碎旗 + 浓烟上升。
static func tower_blast(fx, base: Vector3, fw: float, king: bool, team: Color) -> void:
	var k := 1.4 if king else 1.0
	var mid := base + UP * 2.0 * k
	flash(fx, mid, Color(1.0, 0.9, 0.5), fw * 1.1 * k, 0.4)
	ring(fx, base, fw * 1.3 * k, DUST, 0.7)
	for i in 14:
		var a := TAU * float(i) / 14.0 + randf() * 0.3
		var out := Vector3(cos(a), 0, sin(a)) * randf_range(2.5, 5.0) + UP * randf_range(5.0, 9.0)
		var tint := team if i % 5 == 0 else STONE
		var chunk = fx.solid("chunk", tint, mid, randf_range(0.6, 1.1) * k, true)
		fx.part(chunk, 1.2, {"mode": "hold", "s1": 1.0, "vel": out, "grav": 20.0, "floor": 0.15,
			"spin": Vector3(randf(), randf(), randf()) * 8.0})
	for i in 8:
		var blob = fx.solid("blob", Color("8f8a82") if i % 2 == 0 else SMOKE,
			base + Vector3(randf_range(-1.0, 1.0), 1.0 + randf() * 2.0, randf_range(-1.0, 1.0)) * k, 1.0)
		fx.part(blob, 1.4, {"delay": float(i) * 0.05, "mode": "pop", "s1": randf_range(1.2, 1.8) * k,
			"vel": UP * randf_range(1.0, 2.0)})
	fx.particles(base + UP * 0.5, DUST, {"amount": 24, "life": 0.8, "speed": 4.0, "grav": 6.0, "size": 0.4,
		"radius": fw * 0.5})


## 瞬发电弧（雷法师/雷精灵出手）：手 → 目标的锯齿电光 + 落点闪。
static func zap_bolt(fx, from: Vector3, to: Vector3, tint: Color) -> void:
	var bolt = fx.glow(FxMesh.bolt(from, to, 0.18, 6, 0.08), tint, Vector3.ZERO, 1.0)
	fx.part(bolt, 0.16, {"flicker": true, "a1": 0.2})
	flash(fx, to, tint, 0.7, 0.15)


# —— 状态挂件 ——

static func status_node(kind: String, actor) -> Node3D:
	var root := Node3D.new()
	root.name = "Status_" + kind
	var h: float = actor.body_height
	var air: float = actor.air_y()
	var w := clampf(h * 0.45, 0.4, 1.0)
	match kind:
		"stun":
			for i in 3:
				var star := MeshInstance3D.new()
				star.mesh = FxMesh.get_mesh("star")
				star.material_override = ToonStyle.material(Color(1.0, 0.85, 0.2))
				var a := TAU * float(i) / 3.0
				star.position = Vector3(cos(a) * 0.45, air + h + 0.25, sin(a) * 0.45)
				star.rotation.y = -a
				star.scale = Vector3.ONE * 0.5
				root.add_child(star)
		"freeze":
			var block := MeshInstance3D.new()
			block.mesh = FxMesh.get_mesh("column")
			var mat := StandardMaterial3D.new()
			mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			mat.vertex_color_use_as_albedo = true
			mat.albedo_color = Color(FROST, 0.5)
			block.material_override = mat
			block.scale = Vector3(w * 1.2, h * 1.1, w * 1.2)
			block.position.y = air
			block.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			root.add_child(block)
			var cap := MeshInstance3D.new()
			cap.mesh = FxMesh.get_mesh("ice_shard")
			cap.material_override = ToonStyle.material(FROST)
			cap.position.y = air + h * 1.1
			cap.scale = Vector3.ONE * 0.5
			root.add_child(cap)
		_:   # slow：脚下霜环 + 飘落雪花
			var halo := MeshInstance3D.new()
			halo.mesh = FxMesh.get_mesh("ring")
			var m2 := StandardMaterial3D.new()
			m2.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			m2.vertex_color_use_as_albedo = true
			m2.albedo_color = FROST
			halo.material_override = m2
			halo.scale = Vector3(w * 1.3, 1.0, w * 1.3)
			halo.position.y = air + 0.08
			halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			root.add_child(halo)
			for i in 3:   # 头顶绕圈的小雪花（实心件；状态挂件不用粒子，省每帧粒子模拟）
				var flake := MeshInstance3D.new()
				flake.mesh = FxMesh.get_mesh("star")
				flake.material_override = ToonStyle.material(FROST)
				var a := TAU * float(i) / 3.0
				flake.position = Vector3(cos(a) * w * 0.8, air + h + 0.15, sin(a) * w * 0.8)
				flake.rotation.y = -a
				flake.scale = Vector3.ONE * 0.3
				root.add_child(flake)
	return root


# —— 积木 ——

## 爆炸：发光球膨胀淡出 + 火团/烟团 + 火星 + 地面冲击环。
static func explosion(fx, c: Vector3, r: float, color: Color, k: float) -> void:
	var at := c + UP * 0.6 * k
	flash(fx, at, Color(1.0, 0.9, 0.45), r * 1.6, 0.35)
	puff(fx, at, color, int(4 + 2 * k), r * 0.7)
	puff(fx, at + UP * 0.4, SMOKE, int(2 + 2 * k), r * 0.6)
	ring(fx, Vector3(c.x, 0.0, c.z), r, color, 0.45)
	fx.particles(at, EMBER, {"amount": int(8 + 10 * k), "life": 0.45, "speed": 5.0 * k, "grav": 5.0, "size": 0.22})


## 发光球：瞬间膨胀到 size（直径）并淡出。
static func flash(fx, at: Vector3, color: Color, size: float, dur: float) -> void:
	var ball = fx.glow(FxMesh.get_mesh("ball"), Color(color, 0.9), at, 1.0, true)
	fx.part(ball, dur, {"mode": "out", "s0": size * 0.2, "s1": size, "a1": 0.0})


## 地面范围环：从 30% 半径扩到 r 并淡出（= 法术/溅射实际范围）。
static func ring(fx, center: Vector3, r: float, color: Color, dur: float) -> void:
	var node = fx.glow(FxMesh.get_mesh("ring"), Color(color, 0.85), Vector3(center.x, 0.06, center.z), 1.0)
	node.scale = Vector3(r, 1.0, r)
	fx.part(node, dur, {"mode": "out", "s0": 0.3, "s1": 1.0, "a1": 0.0})


static func ground_disk(fx, center: Vector3, r: float, color: Color, dur: float) -> void:
	var node = fx.glow(FxMesh.get_mesh("disk"), color, Vector3(center.x, 0.04, center.z), 1.0)
	node.scale = Vector3(r, 1.0, r)
	fx.part(node, dur, {"a1": 0.0})


## 卡通烟团：n 个实心球向外弹出再缩没（不透明，省排序）。
static func puff(fx, at: Vector3, tint: Color, n: int, size: float) -> void:
	for i in n:
		var a := TAU * float(i) / float(n) + randf() * 0.5
		var dir := Vector3(cos(a), randf_range(0.2, 0.8), sin(a))
		var blob = fx.solid("blob", tint, at + dir * size * 0.2, 1.0)
		fx.part(blob, randf_range(0.4, 0.6), {"mode": "pop", "s1": size * randf_range(0.5, 0.8), "vel": dir * size * 1.6})


static func _in_circle(r: float) -> Vector2:
	var a := randf() * TAU
	return Vector2(cos(a), sin(a)) * r * sqrt(randf())
