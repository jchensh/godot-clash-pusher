extends Control
class_name TTVideoStreamPlayer

signal canplay
signal played
signal paused
signal stopped
signal ended
signal error(message: String)

enum SizeMode {
	STRETCH,
	WIDTH_EXPAND,
	HEIGHT_EXPAND,
}

var playback
var _current_url := ""
var _autoplay := false
var _loop := false
var _muted := false
var _volume := 1.0

@export var autoplay := false:
	set(value):
		_autoplay = value
	get:
		return _autoplay

@export var loop := false:
	set(value):
		_loop = value
		if playback != null:
			playback.set_loop(value)
	get:
		return _loop

@export var muted := false:
	set(value):
		_muted = value
		if playback != null:
			playback.set_muted(value)
	get:
		return _muted

@export_range(0.0, 1.0, 0.01) var volume := 1.0:
	set(value):
		_volume = clampf(value, 0.0, 1.0)
		if playback != null:
			playback.set_volume(_volume)
	get:
		return _volume

@export var size_mode := SizeMode.STRETCH:
	set(value):
		size_mode = value
		queue_redraw()


func _init() -> void:
	_create_playback()


func _create_playback() -> void:
	if ClassDB.class_exists("TTVideoStreamPlayback"):
		playback = ClassDB.instantiate("TTVideoStreamPlayback")
	else:
		playback = ResourceLoader.load("res://addons/ttsdk/mock/video_playback.gd").new()
	playback.canplay.connect(_on_playback_canplay)
	playback.played.connect(_on_playback_played)
	playback.paused.connect(_on_playback_paused)
	playback.stopped.connect(_on_playback_stopped)
	playback.ended.connect(_on_playback_ended)
	playback.error.connect(_on_playback_error)


func _exit_tree() -> void:
	stop()


func _process(delta: float) -> void:
	if playback == null:
		return
	if !playback.is_playing() or playback.is_paused():
		return
	playback.update(delta)
	queue_redraw()


func _draw() -> void:
	if playback == null:
		return
	var texture: Texture2D = playback.get_texture()
	if texture == null or texture.get_width() == 0:
		return
	var draw_rect := _get_draw_rect()
	var clipped_rect := draw_rect.intersection(Rect2(Vector2.ZERO, size))
	if !clipped_rect.has_area():
		return
	if clipped_rect == draw_rect:
		draw_texture_rect(texture, draw_rect, false)
		return
	var source_scale := texture.get_size() / draw_rect.size
	var source_rect := Rect2(
		(clipped_rect.position - draw_rect.position) * source_scale,
		clipped_rect.size * source_scale
	)
	draw_texture_rect_region(texture, clipped_rect, source_rect)


func load(url: String) -> void:
	_create_playback()
	_current_url = url
	playback.set_loop(_loop)
	playback.set_muted(_muted)
	playback.set_volume(_volume)
	playback.load(url, _autoplay)
	queue_redraw()


func play() -> void:
	playback.play()


func stop() -> void:
	playback.stop()


func set_paused(value: bool) -> void:
	playback.set_paused(value)


func is_paused() -> bool:
	return playback.is_paused()


func is_playing() -> bool:
	return playback.is_playing()


func seek(position: float) -> void:
	playback.seek(position)


func get_duration() -> float:
	return playback.get_length()


func get_stream_position() -> float:
	return playback.get_playback_position()


func get_video_size() -> Vector2i:
	return playback.get_video_size()


func get_url() -> String:
	return _current_url


func set_volume(value: float) -> void:
	volume = value


func get_volume() -> float:
	return volume


func _get_draw_rect() -> Rect2:
	var video_size := get_video_size()
	if video_size.x <= 0 or video_size.y <= 0:
		return Rect2(Vector2.ZERO, size)

	var draw_size := size
	match size_mode:
		SizeMode.WIDTH_EXPAND:
			draw_size.y = size.x * float(video_size.y) / float(video_size.x)
		SizeMode.HEIGHT_EXPAND:
			draw_size.x = size.y * float(video_size.x) / float(video_size.y)
	return Rect2((size - draw_size) * 0.5, draw_size)


func _on_playback_canplay() -> void:
	queue_redraw()
	canplay.emit()


func _on_playback_played() -> void:
	played.emit()


func _on_playback_paused() -> void:
	paused.emit()


func _on_playback_stopped() -> void:
	queue_redraw()
	stopped.emit()


func _on_playback_ended() -> void:
	ended.emit()


func _on_playback_error(message: String) -> void:
	queue_redraw()
	error.emit(message)
