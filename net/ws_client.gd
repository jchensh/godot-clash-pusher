extends RefCounted
##
## V4-S3 WebSocket 客户端：连接 + 轮询 + 帧编解码。
## 应用层帧格式（与服务端共享）：[2 bytes msg_id 大端][N bytes protobuf payload]。
## 由调用方（对战场景）每帧 poll()；收到的帧经 frame_received 信号抛出。
##
## 用法：
##   var ws = preload("res://net/ws_client.gd").new()
##   ws.frame_received.connect(_on_frame)
##   ws.opened.connect(_on_opened)
##   ws.connect_to("ws://localhost:8081/v4/battle/ws?token=...")
##   # 每帧： ws.poll()
##   ws.send_frame(msg_id, payload_bytes)

signal opened
signal closed
signal frame_received(msg_id: int, payload: PackedByteArray)

var _ws := WebSocketPeer.new()
var _was_open := false


func connect_to(url: String) -> int:
	_was_open = false
	# 默认入站缓冲 64KB 装不下配置下发包（V5-N2 全量配置可达几十~上百 KB）→ 调大。
	_ws.inbound_buffer_size = 1 << 21   # 2MB
	return _ws.connect_to_url(url)


func close() -> void:
	_ws.close()


func get_state() -> int:
	return _ws.get_ready_state()


func is_open() -> bool:
	return _ws.get_ready_state() == WebSocketPeer.STATE_OPEN


## 每帧调用：推进 WS 状态机 + 派发收到的帧 + 检测开/关沿。
func poll() -> void:
	_ws.poll()
	var st := _ws.get_ready_state()
	if st == WebSocketPeer.STATE_OPEN:
		if not _was_open:
			_was_open = true
			opened.emit()
		while _ws.get_available_packet_count() > 0:
			var dec := decode_frame(_ws.get_packet())
			if dec["ok"]:
				frame_received.emit(int(dec["msg_id"]), dec["payload"])
	elif st == WebSocketPeer.STATE_CLOSED:
		if _was_open:
			_was_open = false
			closed.emit()


func send_frame(msg_id: int, payload: PackedByteArray) -> void:
	if _ws.get_ready_state() != WebSocketPeer.STATE_OPEN:
		return
	_ws.send(encode_frame(msg_id, payload))


# —— 帧编解码（static，无需连接即可单测）——

## [2 bytes msg_id 大端][payload]
static func encode_frame(msg_id: int, payload: PackedByteArray) -> PackedByteArray:
	var f := PackedByteArray()
	f.resize(2)
	f[0] = (msg_id >> 8) & 0xFF   # 大端高字节
	f[1] = msg_id & 0xFF          # 低字节
	f.append_array(payload)
	return f

## 返回 {ok, msg_id, payload}。短帧（<2 字节）ok=false。
static func decode_frame(pkt: PackedByteArray) -> Dictionary:
	if pkt.size() < 2:
		return {"ok": false, "msg_id": 0, "payload": PackedByteArray()}
	var mid := (pkt[0] << 8) | pkt[1]
	return {"ok": true, "msg_id": mid, "payload": pkt.slice(2)}
