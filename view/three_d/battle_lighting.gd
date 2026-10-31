## 3D 战斗/图鉴共用光照：天空色背景 + 柔和环境光 + 一盏投影太阳光 + 一盏补光。
## D3 调整：原 环境 0.65 + 太阳 1.1 叠加约 1.5 倍过曝（草地发白、蓝色发青）。toon 亮面 = 太阳能量 × 底色，
## 再叠环境光，故 太阳 0.7 + 环境 0.3 ≈ 1.0 倍，浅色（石头/米色）也不再顶白。
extends RefCounted

const Quality := preload("res://view/three_d/quality.gd")

const SKY := Color("d8ecfa")
const AMBIENT := Color("e1ead6")
const AMBIENT_ENERGY := 0.3
const SUN_ENERGY := 0.7
const FILL_ENERGY := 0.12


static func setup(parent: Node) -> void:
	var env := WorldEnvironment.new()
	env.name = "BattleEnvironment"
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = SKY
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = AMBIENT
	env.environment.ambient_light_energy = AMBIENT_ENERGY
	parent.add_child(env)
	parent.add_child(_light("Sun", Vector3(-55, -25, 0), SUN_ENERGY, Quality.real_shadows()))   # D8b：低档关实时阴影
	parent.add_child(_light("Fill", Vector3(-35, 145, 0), FILL_ENERGY, false))


static func _light(label: String, degrees: Vector3, energy: float, shadow: bool) -> DirectionalLight3D:
	var light := DirectionalLight3D.new()
	light.name = label
	light.rotation_degrees = degrees
	light.light_energy = energy
	light.shadow_enabled = shadow
	light.directional_shadow_max_distance = 100
	light.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL   # D8b：正交俯视镜头单层足够，省 3 遍阴影绘制
	return light
