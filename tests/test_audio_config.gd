# V3-8 音频资源表测试：AudioConfig.xlsx -> audio_assets.json，Godot 运行时读 JSON。
extends "res://tests/test_case.gd"

const ConfigLoaderScript = preload("res://logic/config_loader.gd")

var loader

func setup() -> void:
	loader = ConfigLoaderScript.new()
	assert_true(loader.load_all(), "配置应能完整加载: %s" % ", ".join(loader.errors))

func test_audio_assets_loaded() -> void:
	assert_true(loader.audio_assets.size() >= 70, "音频资源表应覆盖 BGM/UI/战斗/法术/roguelite 资源")
	assert_true(loader.has_audio_asset("music_main_menu"), "应包含主菜单音乐")
	assert_true(loader.has_audio_asset("spell_fireball_impact"), "应包含火球爆炸音效")
	assert_true(loader.has_audio_asset("relic_pick"), "应包含 relic 选择音效")

func test_audio_assets_have_required_runtime_fields() -> void:
	for asset_id in loader.audio_assets:
		var a: Dictionary = loader.get_audio_asset(asset_id)
		for f in ["display_name_zh", "type", "bus", "path", "asset_status", "loop", "volume_db", "pitch_min", "pitch_max", "max_polyphony"]:
			assert_true(a.has(f), "audio asset %s missing %s" % [asset_id, f])

func test_audio_assets_have_chinese_planning_notes() -> void:
	for asset_id in loader.audio_assets:
		var a: Dictionary = loader.get_audio_asset(asset_id)
		assert_true(String(a.get("display_name_zh", "")).length() > 0, "audio asset %s should have Chinese display name" % asset_id)
		assert_true(["planned", "sourced", "imported", "final"].has(String(a.get("asset_status", ""))),
				"audio asset %s should have valid status" % asset_id)
		assert_true(String(a.get("effect_notes", "")).length() > 0, "audio asset %s should have Chinese effect notes" % asset_id)

func test_audio_paths_are_under_sound_folder() -> void:
	for asset_id in loader.audio_assets:
		var path := String(loader.get_audio_asset(asset_id).get("path", ""))
		assert_true(path.begins_with("res://sound/"), "audio asset %s path should live under res://sound/: %s" % [asset_id, path])

func test_p0_core_audio_plan_exists() -> void:
	var required := [
		"music_main_menu",
		"music_battle_normal",
		"music_battle_boss",
		"stinger_victory",
		"stinger_defeat",
		"ui_card_pickup",
		"ui_card_drop_valid",
		"ui_card_drop_invalid",
		"deploy_medium",
		"hit_heavy",
		"tower_destroy_king",
		"spell_fireball_impact",
		"spell_arrows_impact",
		"spell_lightning_impact",
		"spell_heal_cast",
		"reward_card_pick",
		"relic_pick",
	]
	for asset_id in required:
		assert_true(loader.has_audio_asset(asset_id), "P0 音频资源缺失: %s" % asset_id)
