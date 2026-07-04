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
	var def: Dictionary = assets.get(_current_music_id, {})
	if bool(def.get("loop", false)) and _music_player.stream != null:
		_music_player.play()

func _on_ambience_finished() -> void:
	if _current_ambience_id.is_empty():
		return
	var def: Dictionary = assets.get(_current_ambience_id, {})
	if bool(def.get("loop", false)) and _ambience_player.stream != null:
		_ambience_player.play()
