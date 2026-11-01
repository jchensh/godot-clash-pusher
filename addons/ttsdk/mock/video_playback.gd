extends VideoStreamPlayback

signal canplay
signal played
signal paused
signal stopped
signal ended
signal error(message: String)

var _url := ""
var _loop := false
var _muted := false
var _volume := 1.0


func load(value: String, _autoplay: bool = false) -> void:
	_url = value


func get_url() -> String:
	return _url


func set_loop(value: bool) -> void:
	_loop = value


func is_loop() -> bool:
	return _loop


func set_muted(value: bool) -> void:
	_muted = value


func is_muted() -> bool:
	return _muted


func set_volume(value: float) -> void:
	_volume = clampf(value, 0.0, 1.0)


func get_volume() -> float:
	return _volume


func play() -> void:
	_play()


func _play() -> void:
	error.emit("TTVideoStreamPlayback class is unavailable")


func stop() -> void:
	_stop()


func _stop() -> void:
	stopped.emit()


func is_playing() -> bool:
	return _is_playing()


func _is_playing() -> bool:
	return false


func set_paused(value: bool) -> void:
	_set_paused(value)


func _set_paused(value: bool) -> void:
	if value:
		paused.emit()


func is_paused() -> bool:
	return _is_paused()


func _is_paused() -> bool:
	return false


func get_length() -> float:
	return _get_length()


func _get_length() -> float:
	return 0.0


func get_playback_position() -> float:
	return _get_playback_position()


func _get_playback_position() -> float:
	return 0.0


func seek(time: float) -> void:
	_seek(time)


func _seek(_time: float) -> void:
	pass


func get_texture() -> Texture2D:
	return _get_texture()


func _get_texture() -> Texture2D:
	return null


func update(delta: float) -> void:
	_update(delta)


func _update(_delta: float) -> void:
	pass


func get_video_size() -> Vector2i:
	return Vector2i.ZERO


func _get_channels() -> int:
	return 0


func _get_mix_rate() -> int:
	return 0
