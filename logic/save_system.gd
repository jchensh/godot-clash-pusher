# SaveSystem —— 存档落盘（V3-4d）。user:// 下 JSON 存读 MetaProgress（持久）+ RunState（可续跑）。
#
# RunState 的节点地图不存盘——由 config 重建后 from_dict 恢复 cursor/deck/status 等（地图是确定性派生）。
# 全 static、路径可注入（默认 user://，单测传临时路径并清理），存读档往返一致。
extends RefCounted
class_name SaveSystem

const MetaScript = preload("res://logic/meta_progress.gd")
const RunStateScript = preload("res://logic/run_state.gd")
const RunMapScript = preload("res://logic/run_map.gd")
const PlayerDataScript = preload("res://logic/player_data.gd")

const META_PATH := "user://meta_save.json"
const RUN_PATH := "user://run_save.json"
const PLAYER_PATH := "user://player_save.json"   # V5：单机闯关养成存档（钱包/卡牌/关卡/挂机）

# —— Meta（持久统计） ——
static func save_meta(meta, path: String = META_PATH) -> void:
	_write(path, meta.to_dict())

# 无存档 → 返回全 0 的 fresh MetaProgress（首次游玩）。
static func load_meta(path: String = META_PATH):
	var m = MetaScript.new()
	m.load_dict(_read(path))
	return m

# —— Run（可续跑的当前 run） ——
static func save_run(run, path: String = RUN_PATH) -> void:
	_write(path, run.to_dict())

# 读 run 存档并重建 RunState（地图由 run_cfg 重建）。无存档返回 null。
static func load_run(run_cfg: Dictionary, path: String = RUN_PATH):
	var d := _read(path)
	if d.is_empty():
		return null
	var map = RunMapScript.new()
	map.build(run_cfg)
	var r = RunStateScript.new(map)
	r.load_dict(d)
	return r

static func has_run_save(path: String = RUN_PATH) -> bool:
	return FileAccess.file_exists(path)

static func clear_run_save(path: String = RUN_PATH) -> void:
	if FileAccess.file_exists(path):
		var dir := DirAccess.open(path.get_base_dir())
		if dir != null:
			dir.remove(path.get_file())

# —— Player（V5 闯关养成存档：钱包/卡牌养成/关卡进度/挂机） ——
static func save_player(player_data, path: String = PLAYER_PATH) -> void:
	_write(path, player_data.to_dict())

# 读玩家档；无档 → init_new（全卡建条目、starter 8 张解锁）。
# 有档 → load_dict 后 ensure_cards 补齐缺失卡（卡池后续新增时不丢档）。
static func load_player(all_card_ids: Array, path: String = PLAYER_PATH):
	var p = PlayerDataScript.new()
	var d := _read(path)
	if d.is_empty():
		p.init_new(all_card_ids)
	else:
		p.load_dict(d)
		p.ensure_cards(all_card_ids)
	return p

static func has_player_save(path: String = PLAYER_PATH) -> bool:
	return FileAccess.file_exists(path)

static func clear_player_save(path: String = PLAYER_PATH) -> void:
	if FileAccess.file_exists(path):
		var dir := DirAccess.open(path.get_base_dir())
		if dir != null:
			dir.remove(path.get_file())

# —— 私有 IO ——
static func _write(path: String, data: Dictionary) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(data))
		f.close()

static func _read(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var data = JSON.parse_string(FileAccess.get_file_as_string(path))
	return data if typeof(data) == TYPE_DICTIONARY else {}
