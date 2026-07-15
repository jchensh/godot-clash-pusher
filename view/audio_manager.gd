# Global audio playback entry for config-driven music and SFX.
# Missing files are tolerated during the catalog-first asset pipeline.
extends Node

const ConfigLoaderScript = preload("res://logic/config_loader.gd")

const DEFAULT_FADE_S := 0.35

var assets: Dictionary = {}
var _cache: Dictionary = {}
var _pools: Dictionary = {}
var _music_player: AudioStreamPlayer
var _ambience_player: AudioStreamPlayer
var _current_music_id := ""
var _current_ambience_id := ""
var _music_set: Array = []   # 轮播集（0716 战斗 BGM）：曲终随机换下一首（不重复当前）；play_music/stop_music 清空

func _ready() -> void:
	_music_player = AudioStreamPlayer.new()
	add_child(_music_player)
	_music_player.finished.connect(_on_music_finished)
	_ambience_player = AudioStreamPlayer.new()
	add_child(_ambience_player)
	_ambience_player.finished.connect(_on_ambience_finished)
	reload_config()

func reload_config() -> bool:
	var loader = ConfigLoaderScript.new()
	var ok: bool = loader.load_all()
	assets = loader.audio_assets if ok else {}
	return ok

func has_asset(asset_id: String) -> bool:
	return assets.has(asset_id)

func play(asset_id: String) -> bool:
	var def: Dictionary = assets.get(asset_id, {})
	var type := String(def.get("type", ""))
	if type == "music":
		return play_music(asset_id)
	if type == "ambience":
		return play_ambience(asset_id)
	return play_sfx(asset_id)

func play_music(asset_id: String, fade_s: float = DEFAULT_FADE_S) -> bool:
	_music_set = []   # 单曲模式：解除轮播
	return _play_music_track(asset_id, fade_s)


## 轮播集（0716 首批 BGM）：随机起播一首，曲终自动随机换下一首（不与当前重复）。
## 集内曲目 loop 应为 false（否则 finished 不触发、永远单曲循环）。已在播集内曲目时幂等不打断。
func play_music_set(asset_ids: Array, fade_s: float = DEFAULT_FADE_S) -> bool:
	var playable: Array = []
	for aid in asset_ids:
		if assets.has(String(aid)):
			playable.append(String(aid))
	if playable.is_empty():
		return false
	if _music_player.playing and playable.has(_current_music_id) and _music_set == playable:
		return true   # 场景重入（再来一局等）：同集在播不打断
	_music_set = playable
	var pick: Array = next_in_set(_music_set, _current_music_id)
	return _play_music_track(pick[randi() % pick.size()], fade_s)


## 纯函数：轮播候选 = 集内除当前曲外的曲目（仅一首时退化为其本身）。供单测锁行为。
static func next_in_set(music_set: Array, current: String) -> Array:
	var out: Array = []
	for aid in music_set:
		if String(aid) != current:
			out.append(String(aid))
	return out if not out.is_empty() else music_set.duplicate()


func _play_music_track(asset_id: String, fade_s: float = DEFAULT_FADE_S) -> bool:
	var def: Dictionary = assets.get(asset_id, {})
	if def.is_empty():
		return false
	if _current_music_id == asset_id and _music_player.playing:
		return true
	var stream: AudioStream = _load_stream(asset_id)
	if stream == null:
		return false
	_current_music_id = asset_id
	_music_player.stop()
	_music_player.stream = stream
	_music_player.bus = _resolve_bus(String(def.get("bus", "Music")))
	_music_player.pitch_scale = 1.0
	_music_player.volume_db = -80.0 if fade_s > 0.0 else float(def.get("volume_db", 0.0))
	_music_player.play()
	if fade_s > 0.0:
		var tw := create_tween()
		tw.tween_property(_music_player, "volume_db", float(def.get("volume_db", 0.0)), fade_s)
	return true

func stop_music(fade_s: float = DEFAULT_FADE_S) -> void:
	_music_set = []
	if _music_player == null or not _music_player.playing:
		_current_music_id = ""
		return
	if fade_s <= 0.0:
		_music_player.stop()
		_current_music_id = ""
		return
	var tw := create_tween()
	tw.tween_property(_music_player, "volume_db", -80.0, fade_s)
	tw.tween_callback(func() -> void:
		_music_player.stop()
		_current_music_id = ""
	)

func play_ambience(asset_id: String, fade_s: float = DEFAULT_FADE_S) -> bool:
	var def: Dictionary = assets.get(asset_id, {})
	if def.is_empty():
		return false
	if _current_ambience_id == asset_id and _ambience_player.playing:
		return true
	var stream: AudioStream = _load_stream(asset_id)
	if stream == null:
		return false
	_current_ambience_id = asset_id
	_ambience_player.stop()
	_ambience_player.stream = stream
	_ambience_player.bus = _resolve_bus(String(def.get("bus", "Ambience")))
	_ambience_player.pitch_scale = 1.0
	_ambience_player.volume_db = -80.0 if fade_s > 0.0 else float(def.get("volume_db", 0.0))
	_ambience_player.play()
	if fade_s > 0.0:
		var tw := create_tween()
		tw.tween_property(_ambience_player, "volume_db", float(def.get("volume_db", 0.0)), fade_s)
	return true

func stop_ambience(fade_s: float = DEFAULT_FADE_S) -> void:
	if _ambience_player == null or not _ambience_player.playing:
		_current_ambience_id = ""
		return
	if fade_s <= 0.0:
		_ambience_player.stop()
		_current_ambience_id = ""
		return
	var tw := create_tween()
	tw.tween_property(_ambience_player, "volume_db", -80.0, fade_s)
	tw.tween_callback(func() -> void:
		_ambience_player.stop()
		_current_ambience_id = ""
	)

func play_sfx(asset_id: String) -> bool:
	var def: Dictionary = assets.get(asset_id, {})
	if def.is_empty():
		return false
	var stream: AudioStream = _load_stream(asset_id)
	if stream == null:
		return false
	var player: AudioStreamPlayer = _claim_player(asset_id, def)
	if player == null:
		return false
	player.stream = stream
	player.bus = _resolve_bus(String(def.get("bus", "SFX")))
	player.volume_db = float(def.get("volume_db", 0.0))
	player.pitch_scale = _pitch_for(def)
	player.play()
	return true

func current_music_id() -> String:
	return _current_music_id

func current_ambience_id() -> String:
	return _current_ambience_id

func _load_stream(asset_id: String) -> AudioStream:
	if _cache.has(asset_id):
		return _cache[asset_id] as AudioStream
	var def: Dictionary = assets.get(asset_id, {})
	var path := String(def.get("path", ""))
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	var loaded: Resource = load(path)
	if loaded == null or not (loaded is AudioStream):
		return null
	var stream := loaded as AudioStream
	# 清单 loop 声明落到资源上（导入默认不循环；music/ambience 循环靠这里生效，2026-07-04 接首批 BGM 时补）。
	if bool(def.get("loop", false)):
		if stream is AudioStreamOggVorbis:
			(stream as AudioStreamOggVorbis).loop = true
		elif stream is AudioStreamMP3:
			(stream as AudioStreamMP3).loop = true
		elif stream is AudioStreamWAV:
			var w := stream as AudioStreamWAV
			w.loop_mode = AudioStreamWAV.LOOP_FORWARD
			var bytes_per_frame: int = (2 if w.format == AudioStreamWAV.FORMAT_16_BITS else 1) * (2 if w.stereo else 1)
			w.loop_begin = 0
			w.loop_end = w.data.size() / maxi(1, bytes_per_frame)
	_cache[asset_id] = stream
	return stream

func _claim_player(asset_id: String, def: Dictionary) -> AudioStreamPlayer:
	var pool: Array = _pools.get(asset_id, [])
	for p in pool:
		if not p.playing:
			return p
	var max_polyphony := maxi(1, int(def.get("max_polyphony", 1)))
	if pool.size() >= max_polyphony:
		return null
	var p := AudioStreamPlayer.new()
	add_child(p)
	pool.append(p)
	_pools[asset_id] = pool
	return p

func _pitch_for(def: Dictionary) -> float:
	var lo := float(def.get("pitch_min", 1.0))
	var hi := float(def.get("pitch_max", 1.0))
	if hi <= lo:
		return lo
	return randf_range(lo, hi)

func _resolve_bus(bus_name: String) -> String:
	return bus_name if AudioServer.get_bus_index(bus_name) >= 0 else "Master"

func _on_music_finished() -> void:
	if _current_music_id.is_empty():
		return
	if _music_set.size() > 1:   # 轮播集：曲终随机换下一首（不重复当前）
		var pick: Array = next_in_set(_music_set, _current_music_id)
		_play_music_track(pick[randi() % pick.size()], 0.0)
		return
	var def: Dictionary = assets.get(_current_music_id, {})
	if bool(def.get("loop", false)) and _music_player.stream != null:
		_music_player.play()

func _on_ambience_finished() -> void:
	if _current_ambience_id.is_empty():
		return
	var def: Dictionary = assets.get(_current_ambience_id, {})
	if bool(def.get("loop", false)) and _ambience_player.stream != null:
		_ambience_player.play()
