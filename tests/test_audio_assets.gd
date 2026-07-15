# 音频清单一致性（2026-07-04 首批 BGM 入库时加）：
# asset_status=imported/final 的条目，资源文件必须存在且可加载为 AudioStream——
# 防"清单说有、盘上没有"的漂移；planned/sourced 允许缺文件（清单先行惯例，AudioManager 静默跳过）。
extends "res://tests/test_case.gd"

func test_imported_assets_load() -> void:
	var f := FileAccess.open("res://config/audio_assets.json", FileAccess.READ)
	assert_not_null(f, "audio_assets.json 可读")
	var data = JSON.parse_string(f.get_as_text())
	assert_true(typeof(data) == TYPE_DICTIONARY, "audio_assets.json 根为对象")
	var checked := 0
	for id in data:
		var def = data[id]
		if typeof(def) != TYPE_DICTIONARY:
			continue
		if String(def.get("asset_status", "")) in ["imported", "final"]:
			var path := String(def.get("path", ""))
			assert_true(ResourceLoader.exists(path), "%s 资源应存在: %s" % [id, path])
			if ResourceLoader.exists(path):
				var s = load(path)
				assert_true(s is AudioStream, "%s 应可加载为 AudioStream" % id)
			checked += 1
	assert_true(checked >= 2, "至少 菜单+战斗 两条 BGM 已入库 (实际=%d)" % checked)
