# pve_verify —— KAN-79：PVE 战斗重放验证 CLI（服务端 verifier 调用的 headless 入口）。
#
# 用法（Go cmd/verifier exec；本机手动验证同款）：
#   godot --headless --path . -s res://tools/pve_verify.gd -- --input=<in.json> --output=<out.json>
#
# input JSON（verifier 从 pve_battles 行组装）：
#   { "stage_id": "stage_1_1", "deck": ["knight", ...8],
#     "progress": {"knight": {"level":4, "rank":2}, ...},     // 开战时服务器权威快照
#     "cmds":   [{"t":30,"ph":0,"s":1,"c":"knight","x":4500,"y":17000}, ...],
#     "hashes": [{"t":10,"h":"<sha256 hex>"}, ...] }
# output JSON（verdict，见 logic/pve_replay.gd）：
#   { "status":"pass|mismatch|error", "reason":"", "mismatch_tick":-1,
#     "win":true, "ticks":995, "king_hp_permille":740 }
#
# exit code 恒 0（verdict 在输出文件里；进程级失败才非 0）——让 verifier 区分
# 「重放判假」与「基建故障」。这是测量工具、不参与 CI。
extends SceneTree

const ConfigLoaderScript = preload("res://logic/config_loader.gd")
const PveReplayScript = preload("res://logic/pve_replay.gd")

func _initialize() -> void:
	var args := _parse_args()
	var in_path := String(args.get("input", ""))
	var out_path := String(args.get("output", ""))
	if in_path == "" or out_path == "":
		printerr("pve_verify: usage --input=<in.json> --output=<out.json>")
		quit(2)
		return

	var verdict := _run(in_path)
	var f := FileAccess.open(out_path, FileAccess.WRITE)
	if f == null:
		printerr("pve_verify: cannot write %s" % out_path)
		quit(2)
		return
	f.store_string(JSON.stringify(verdict))
	f.close()
	print("pve_verify: %s (%s)" % [String(verdict.get("status", "?")), String(verdict.get("reason", ""))])
	quit(0)

func _run(in_path: String) -> Dictionary:
	var f := FileAccess.open(in_path, FileAccess.READ)
	if f == null:
		return {"status": "error", "reason": "cannot read input %s" % in_path}
	var parsed = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		return {"status": "error", "reason": "input is not a JSON object"}

	var config = ConfigLoaderScript.new()
	if not config.load_all():
		return {"status": "error", "reason": "config load_all failed"}

	var progress = parsed.get("progress", {})
	var cmds = parsed.get("cmds", [])
	var hashes = parsed.get("hashes", [])
	return PveReplayScript.replay(
		config,
		String(parsed.get("stage_id", "")),
		parsed.get("deck", []),
		progress if typeof(progress) == TYPE_DICTIONARY else {},
		cmds if typeof(cmds) == TYPE_ARRAY else [],
		hashes if typeof(hashes) == TYPE_ARRAY else [])

# 解析 `--` 之后的用户参数（--key=value）。
func _parse_args() -> Dictionary:
	var out := {}
	for a in OS.get_cmdline_user_args():
		var s := String(a)
		if s.begins_with("--") and s.contains("="):
			var eq := s.find("=")
			out[s.substr(2, eq - 2)] = s.substr(eq + 1)
	return out
