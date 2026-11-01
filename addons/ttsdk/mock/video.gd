extends VideoStream


func _instantiate_playback() -> VideoStreamPlayback:
	var playback: VideoStreamPlayback = load("res://addons/ttsdk/mock/video_playback.gd").new()
	playback.load(file)
	return playback


func instantiate_playback() -> VideoStreamPlayback:
	return _instantiate_playback()
