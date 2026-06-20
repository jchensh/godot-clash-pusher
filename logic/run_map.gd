# RunMap —— Roguelite 一条 run 的节点地图（V3-4a）。
#
# 形态 = 线性连战链（V3-4a 决策）：节点按 act 顺序展开成一条扁平链，依次连战、无分叉。
# 每个节点带 type(battle/elite/boss) 与 act 标签——供 V3-4d（boss/精英差异化）与 view 分组；
# 本步所有节点都按普通战斗处理（type 仅作标签、不改行为，elite/boss 与 battle 同跑）。
# 纯数据、确定性：由 config/run.json 的某条（如 get_run("default")）展开，可 headless 单测。
# 分叉地图 / 程序化生成留后续（届时同一 RunMap 接口承载，RunState/流转不必改）。
extends RefCounted
class_name RunMap

const TYPE_BATTLE := "battle"
const TYPE_ELITE := "elite"
const TYPE_BOSS := "boss"

# 扁平节点链：每项 = {type, level_id, act, index_in_act}。
var nodes: Array = []

# 从 run 配置展开节点链（run_cfg = run.json 的某条，含 acts → nodes）。
func build(run_cfg: Dictionary) -> void:
	nodes.clear()
	var acts_cfg: Array = run_cfg.get("acts", [])
	for a in acts_cfg.size():
		var act = acts_cfg[a]
		if typeof(act) != TYPE_DICTIONARY:
			continue
		var act_nodes: Array = act.get("nodes", [])
		for j in act_nodes.size():
			var n: Dictionary = act_nodes[j]
			nodes.append({
				"type": String(n.get("type", TYPE_BATTLE)),
				"level_id": String(n.get("level_id", "")),
				"act": a,
				"index_in_act": j,
			})

func size() -> int:
	return nodes.size()

# 越界返回空字典（调用方据此判断「无更多节点」）。
func node_at(i: int) -> Dictionary:
	if i < 0 or i >= nodes.size():
		return {}
	return nodes[i]
