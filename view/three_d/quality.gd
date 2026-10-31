## D8b 画质档位（高 / 中 / 低）：本地显示偏好（存 user://settings.cfg [graphics]），不进 sim/hash、不涉服务器权威数据。
## 低档 = 微信/抖音小游戏基线（H5/WebGL2，draw call 是第一杠杆）。各 3D 页在 setup 时读一次档位并应用；
## 改档（设置页 / 首局自动调档）从下一次进 3D 页起生效，不在一局中途切换（避免半新半旧；断线重连重绑同一局也不切）。
extends RefCounted

const ToonStyle := preload("res://view/three_d/toon_style.gd")

const LOW := 0
const MID := 1
const HIGH := 2
const LABELS := ["低", "中", "高"]   # 日志/测试用；界面显示走 LABEL_KEYS + tr()
const LABEL_KEYS := ["settings_quality_low", "settings_quality_mid", "settings_quality_high"]

## shadow：all=全部实时投影 / actors=只有单位与塔投影 / blob=关实时阴影、单位与塔贴地圆影。
## outline_*：该类物体是否描边（单位恒描边，保画风辨识度）。scale3d：3D 渲染倍率。
## lod_px：网格 LOD 阈值（像素，越大越早换引擎自动生成的低模）。particles：粒子数量倍率（0=不用粒子）。
## fx_cap：同屏可选特效件上限（受击星/烟团/治疗闪光；0=不限，法术与投射物恒放）。anim_hz：骨骼动画刷新频率（0=每帧）。
const PROFILES := {
	HIGH: {"shadow": "all", "outline_tower": true, "outline_prop": true, "outline_fx": true, "scale3d": 1.0,
		"lod_px": 1.0, "particles": 1.0, "fx_cap": 0, "anim_hz": 0.0},
	MID: {"shadow": "actors", "outline_tower": true, "outline_prop": false, "outline_fx": true, "scale3d": 0.85,
		"lod_px": 2.0, "particles": 0.6, "fx_cap": 120, "anim_hz": 0.0},
	LOW: {"shadow": "blob", "outline_tower": false, "outline_prop": false, "outline_fx": false, "scale3d": 0.7,
		"lod_px": 4.0, "particles": 0.0, "fx_cap": 60, "anim_hz": 30.0},
}

const AUTO_UP_MS := 20.0     # 首局帧耗时 p90 低于此 → 下次升一档
const AUTO_DOWN_MS := 40.0   # 高于此 → 下次降一档（30 帧 = 33.3 毫秒，留余量）
const TUNE_MAX_FRAME_MS := 250.0   # 采样剔除：单帧超过此值视为切后台/暂停/追帧，不计入 p90
const TUNE_MIN_SAMPLES := 30       # 有效样本太少（大半时间在后台）→ 本局不下结论

static var settings_path := "user://settings.cfg"   # 与 GameState / I18n 同一份设置文件；单测改到临时路径
static var override_level := -1                      # 测试/测量工具强制档位（-1 = 不强制）
static var _level := -1
static var _manual := false
static var _pending := -1     # 自动调档结果：已存盘，下次 begin_scene 才生效（不在一局中途切换）
static var session_tuned := false   # 自动调档每次启动只做一次（首局），避免阈值附近的机器局间来回跳档


## 当前档位（首次读盘；没存过 = 按平台给默认档）。
static func level() -> int:
	if override_level >= 0:
		return override_level
	if _level < 0:
		var c := ConfigFile.new()
		c.load(settings_path)
		_level = int(c.get_value("graphics", "level", default_level()))
		_manual = bool(c.get_value("graphics", "manual", false))
		_level = clampi(_level, LOW, HIGH)
	return _level


static func profile() -> Dictionary:
	return PROFILES[level()]


static func is_manual() -> bool:
	level()
	return _manual


## 平台默认：网页/小游戏 = 低，手机原生 = 中，电脑 = 高。
static func default_level() -> int:
	return default_for({"web": OS.has_feature("web"), "mobile": OS.has_feature("mobile")})


static func default_for(features: Dictionary) -> int:
	if bool(features.get("web", false)):
		return LOW
	if bool(features.get("mobile", false)):
		return MID
	return HIGH


## 下次进 3D 页将使用的档位（自动调档待生效结果优先）；设置页高亮用这个。
static func next_level() -> int:
	if override_level >= 0:
		return override_level
	return _pending if _pending >= 0 else level()


## 设置页手动选档（manual=true：之后不再自动调档）。清掉待生效的自动调档结果，手选优先。
static func set_level(value: int, manual := true) -> void:
	_level = clampi(value, LOW, HIGH)
	_manual = manual
	_pending = -1
	var c := ConfigFile.new()
	c.load(settings_path)
	c.set_value("graphics", "level", _level)
	c.set_value("graphics", "manual", _manual)
	c.save(settings_path)


## 本次启动是否还需要自动调档（手动选过 / 测试强制 / 已调过 都不再调）。
static func wants_tune() -> bool:
	level()
	return not _manual and override_level < 0 and not session_tuned


## 一段帧耗时样本（毫秒）→ 剔除异常长帧后的 p90；有效样本不足返回 -1（本局不下结论）。
static func frame_p90(samples_ms: Array) -> float:
	var kept: Array = []
	for ms in samples_ms:
		if float(ms) <= TUNE_MAX_FRAME_MS:
			kept.append(float(ms))
	if kept.size() < TUNE_MIN_SAMPLES:
		return -1.0
	kept.sort()
	return kept[mini(int(kept.size() * 0.9), kept.size() - 1)]


## 首局帧耗时 p90（毫秒）→ 自动升/降一档（下次进 3D 页生效）；玩家手动选过的不动。返回调整后的档位。
static func auto_tune(frame_p90_ms: float) -> int:
	var cur := level()
	if _manual or override_level >= 0:
		return cur
	session_tuned = true
	var next := cur
	if frame_p90_ms < AUTO_UP_MS and cur < HIGH:
		next = cur + 1
	elif frame_p90_ms > AUTO_DOWN_MS and cur > LOW:
		next = cur - 1
	if next != cur:
		var keep := _level
		set_level(next, false)
		_level = keep
		_pending = next
	return next


## 每个 3D 页 setup 开头调用：生效上次自动调档的结果，并把渲染倍率/LOD 阈值应用到该视口。
static func begin_scene(viewport: Viewport) -> void:
	if _pending >= 0:
		_level = _pending
		_pending = -1
	apply_viewport(viewport)


## 3D 页 setup 时调用：渲染倍率 + 网格 LOD 阈值（作用于该视口）。
static func apply_viewport(viewport: Viewport) -> void:
	if viewport == null:
		return
	var p := profile()
	viewport.scaling_3d_scale = float(p["scale3d"])
	viewport.mesh_lod_threshold = float(p["lod_px"])


static func real_shadows() -> bool:
	return str(profile()["shadow"]) != "blob"


## kind：unit / tower / prop / fx —— 该类物体是否投实时阴影。
static func casts_shadow(kind: String) -> bool:
	match str(profile()["shadow"]):
		"all":
			return true
		"actors":
			return kind == "unit" or kind == "tower"
	return false


static func shadow_setting(kind: String) -> GeometryInstance3D.ShadowCastingSetting:
	return GeometryInstance3D.SHADOW_CASTING_SETTING_ON if casts_shadow(kind) else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## 按物体类别统一上 toon 材质（描边按档）+ 投影开关。返回换材质的 surface 数。
static func dress(root: Node, kind: String, team := Color.WHITE, body := Color.WHITE, grade := Vector2.ONE) -> int:
	var count := ToonStyle.apply(root, team, body, grade, outline(kind))
	set_shadow(root, kind)
	return count


static func set_shadow(root: Node, kind: String) -> void:
	var setting := shadow_setting(kind)
	if root is GeometryInstance3D:
		(root as GeometryInstance3D).cast_shadow = setting
	for node in root.find_children("*", "GeometryInstance3D", true, false):
		(node as GeometryInstance3D).cast_shadow = setting


## kind：unit（画面主体：战斗单位、王国建筑）/ tower / prop / fx —— 该类物体是否描边（主体恒描边）。
static func outline(kind: String) -> bool:
	if kind == "unit":
		return true
	return bool(profile().get("outline_" + kind, true))
