extends EditorExportPlatformExtension

const OPTIONS_APP_ID := "douyin/app_id"
const OPTIONS_CANVAS_RESIZE_POLICY := "douyin/canvas_resize_policy"
const OPTIONS_DEVICE_ORIENTATION := "douyin/device_device_orientation"
const OPTIONS_SUBPACKAGE_ON := "douyin/subpackage_on"
const OPTIONS_CUSTOM_GAME_JS := "douyin/custom_game_js"
const OPTIONS_ENABLE_IOS_HPP := "douyin/enable_ios_hpp"

const OPTIONS_DEVELOPER_TOOL := "douyin/douyin_developer_tool"
const OPTIONS_EXTENSIONS_SUPPORT := "douyin/extensions_support"

const OPTIONS_DEBUG_REMOTE_DEBUGGER_ON := "douyin_debug/remote_debugger_on"
const OPTIONS_DEBUG_REMOTE_DEBUGGER_URL := "douyin_debug/remote_debugger_url"
const OPTIONS_DEBUG_SETTINGS_DEBUG_ID := "douyin_debug/settings_debug_id"

const OPTIONS_OPTIMIZE_BROTLI_ON := "douyin_optimize/brotli_on"
const OPTIONS_OPTIMIZE_BROTLI_POLICY := "douyin_optimize/brotli_policy"
const OPTIONS_OPTIMIZE_EXPORT_TEMPLATE := "douyin_optimize/export_template"

const OPTIONS_CUSTOM_TEMPLATE_DEBUG := "douyin_custom_template/debug"
const OPTIONS_CUSTOM_TEMPLATE_RELEASE := "douyin_custom_template/release"

const OPTIONS_EXPRIMENTAL_AUDIO_CONTEXT := "douyin_exeprimental/audio_context"


func _get_name() -> String:
	return "tt-minigame"

func _get_logo() -> Texture2D:
	return load("res://addons/ttsdk.editor/platform-logo.png")

func _get_binary_extensions(preset: EditorExportPreset) -> PackedStringArray:
	return PackedStringArray(["config.json"])

func _has_valid_export_configuration(preset: EditorExportPreset, debug: bool) -> bool:
	if (!preset.get_or_env(OPTIONS_APP_ID, "")):
		set_config_error("app_id is missing.")
		return false;
	return true

func _has_valid_project_configuration(preset: EditorExportPreset) -> bool:
	if !ProjectSettings.get_setting("rendering/textures/vram_compression/import_etc2_astc"):
		return false
	return true


func _get_export_option_visibility(preset: EditorExportPreset, option: String) -> bool:
	var advance_options_enabled = preset.are_advanced_options_enabled()
	var advance_options := [
		OPTIONS_CUSTOM_TEMPLATE_DEBUG, 
		OPTIONS_CUSTOM_TEMPLATE_RELEASE, 
		OPTIONS_DEBUG_SETTINGS_DEBUG_ID
	]
	if advance_options.has(option):
		return advance_options_enabled
	var unavailable := [OPTIONS_DEVELOPER_TOOL, OPTIONS_EXTENSIONS_SUPPORT]
	if unavailable.has(option):
		return false
	return true
	
func _get_platform_features() -> PackedStringArray:
	return PackedStringArray(["web", "Web", "tt"])
	
func _get_preset_features(preset: EditorExportPreset) -> PackedStringArray:
	var features = ["astc", "etc2", "nothreads", "wasm32"]
	if preset.get_or_env(OPTIONS_EXTENSIONS_SUPPORT, ""):
		features.push_back("web_extensions")
	else:
		features.push_back("web_noextensions")
	return PackedStringArray(features)
	
func _get_debug_protocol() -> String:
	return "ws://"
	
func _get_export_options() -> Array[Dictionary]:
	return [
		_make_export_option(OPTIONS_APP_ID, Variant.Type.TYPE_STRING, ""),
		_make_export_option(OPTIONS_CANVAS_RESIZE_POLICY, Variant.Type.TYPE_INT, 0, PropertyHint.PROPERTY_HINT_ENUM, "None,Project,Adaptive"),
		_make_export_option(OPTIONS_DEVICE_ORIENTATION, Variant.Type.TYPE_INT, 0, PropertyHint.PROPERTY_HINT_ENUM, "Portrait,Landscape"),
		_make_export_option(OPTIONS_SUBPACKAGE_ON, Variant.Type.TYPE_BOOL, false),
		_make_export_option(OPTIONS_CUSTOM_GAME_JS, Variant.Type.TYPE_BOOL, false),
		_make_export_option(OPTIONS_ENABLE_IOS_HPP, Variant.Type.TYPE_BOOL, false),
		_make_export_option(OPTIONS_DEVELOPER_TOOL, Variant.Type.TYPE_STRING, "", PropertyHint.PROPERTY_HINT_GLOBAL_FILE, "*.exe"),
		_make_export_option(OPTIONS_EXTENSIONS_SUPPORT, Variant.Type.TYPE_BOOL, false),
		# --- debug ---
		_make_export_option(OPTIONS_DEBUG_REMOTE_DEBUGGER_ON, Variant.Type.TYPE_BOOL, false),
		_make_export_option(OPTIONS_DEBUG_REMOTE_DEBUGGER_URL, Variant.Type.TYPE_STRING, _get_debugger_url()),
		_make_export_option(OPTIONS_DEBUG_SETTINGS_DEBUG_ID, Variant.Type.TYPE_STRING, ""),
		# --- optimize ---
		_make_export_option(OPTIONS_OPTIMIZE_EXPORT_TEMPLATE, Variant.Type.TYPE_STRING, "", PropertyHint.PROPERTY_HINT_NONE, ""),
		_make_export_option(OPTIONS_OPTIMIZE_BROTLI_ON, Variant.Type.TYPE_BOOL, false),
		_make_export_option(OPTIONS_OPTIMIZE_BROTLI_POLICY, Variant.Type.TYPE_INT, 0, PropertyHint.PROPERTY_HINT_ENUM, ExportHelper.BROTLI_POLICY_HIT_STRING),
		# --- custom template ---
		_make_export_option(OPTIONS_CUSTOM_TEMPLATE_DEBUG, Variant.Type.TYPE_STRING, "", PropertyHint.PROPERTY_HINT_GLOBAL_FILE, "*.zip"),
		_make_export_option(OPTIONS_CUSTOM_TEMPLATE_RELEASE, Variant.Type.TYPE_STRING, "", PropertyHint.PROPERTY_HINT_GLOBAL_FILE, "*.zip"),
		
		# --- experimental ---
		_make_export_option(OPTIONS_EXPRIMENTAL_AUDIO_CONTEXT, Variant.Type.TYPE_BOOL, true),

	]

func _make_export_option(name: String, type: Variant.Type, default_value: Variant, hint: PropertyHint = PropertyHint.PROPERTY_HINT_NONE, hint_string: String = "") -> Dictionary:
	var dict = {
		"name": name,
		"type": type,
		"default_value": default_value
	}
	if hint:
		dict["hint"] = hint
	if hint_string:
		dict["hint_string"] = hint_string
	return dict

func _get_debugger_url() -> String:
	var editor_settings = EditorInterface.get_editor_settings()
	var host = editor_settings.get_setting("network/debug/remote_host")
	var port = editor_settings.get_setting("network/debug/remote_port")
	return _get_debug_protocol() + host + ":" + str(port)
	
func _extract_config_from_preset(preset: EditorExportPreset, debug: bool)-> ExportConfig:
	var config := ExportConfig.new();
	config.app_id = preset.get_or_env(OPTIONS_APP_ID, "")
	config.debug_on = debug
	config.canvas_resize_policy = preset.get_or_env(OPTIONS_CANVAS_RESIZE_POLICY, "")
	config.device_orientation = preset.get_or_env(OPTIONS_DEVICE_ORIENTATION, "") as int
	config.subpackage_on = preset.get_or_env(OPTIONS_SUBPACKAGE_ON, "")
	config.enable_ios_hpp = preset.get_or_env(OPTIONS_ENABLE_IOS_HPP, "")
	config.custom_game_js = preset.get_or_env(OPTIONS_CUSTOM_GAME_JS, "")
	var export_template = preset.get_or_env(OPTIONS_OPTIMIZE_EXPORT_TEMPLATE, "")
	if export_template != null:
		config.export_template = export_template
		
	if debug:
		config.remote_debugger_on = preset.get_or_env(OPTIONS_DEBUG_REMOTE_DEBUGGER_ON, "") as bool
		if config.remote_debugger_on:
			config.remote_debugger_url = preset.get_or_env(OPTIONS_DEBUG_REMOTE_DEBUGGER_URL, "")
			if !config.remote_debugger_url:
				config.remote_debugger_url = _get_debugger_url()
	
	config.brotli_on = preset.get_or_env(OPTIONS_OPTIMIZE_BROTLI_ON, "") as bool
	config.brotli_policy = preset.get_or_env(OPTIONS_OPTIMIZE_BROTLI_POLICY, "") as int
	config.force_tt_audio_context = preset.get_or_env(OPTIONS_EXPRIMENTAL_AUDIO_CONTEXT, "") as bool
	if preset.are_advanced_options_enabled():
		var settings_debug_id = preset.get_or_env(OPTIONS_DEBUG_SETTINGS_DEBUG_ID, "")
		if settings_debug_id:
			config.settings_debug_id = settings_debug_id
	#config.ide_exe = preset.get_or_env("douyin/douyin_developer_tool", "")
	return config;
func _export_pack_patch(preset: EditorExportPreset, debug: bool, path: String, patches: PackedStringArray, flags: int) -> Error:
	return Error.ERR_UNAVAILABLE
func _export_zip_patch(preset: EditorExportPreset, debug: bool, path: String, patches: PackedStringArray, flags: int) -> Error:
	return Error.ERR_UNAVAILABLE
func _export_zip(preset: EditorExportPreset, debug: bool, path: String, flags: int) -> Error:
	return Error.ERR_UNAVAILABLE
func _export_pack(preset: EditorExportPreset, debug: bool, path: String, flags: int) -> Error:
	print("export pack: " + path)
	if !path.ends_with(".pck"):
		return Error.ERR_FILE_BAD_PATH
	
	var base_dir = path.get_base_dir()
	var base_dir_access = DirAccess.open(base_dir)
	
	var res = save_pack(preset, debug, path);
	for so in res.so_files:
		print("so_files: " + so.path + " [" + str(so.tags) + "] " + so.target_folder)
	if res.result != Error.OK:
		return res.result
	
	base_dir_access.rename(path, path.substr(0, path.length() - 4) + ".bin"); # TT IDE 不支持 .pck 文件 	

	return Error.OK


func _get_export_dir_safe(path: String) -> String:
	var export_dir = ProjectSettings.globalize_path(path).get_base_dir().simplify_path()
	if export_dir == "." || export_dir == ProjectSettings.globalize_path("res://"):
		export_dir = "tt-minigame"
		if !DirAccess.dir_exists_absolute(export_dir):
			DirAccess.make_dir_absolute(export_dir)
	return export_dir
	

func _export_project(preset: EditorExportPreset, debug: bool, path: String, flags: int) -> Error:
	var base_dir = _get_export_dir_safe(path)
	print("export project to: " + base_dir)
	
	var base_dir_access = DirAccess.open(base_dir)
	if !base_dir_access.dir_exists("godot"):
		base_dir_access.make_dir("godot")
	
	var config := _extract_config_from_preset(preset, debug);
	var report := ExportReport.new()
	report.project_dir = base_dir
	
	var err = ExportSettings.fetch_remote_config(config.settings_debug_id)
	if err != OK:
		printerr("check network and try again.")
		return err
	var remote_config = ExportSettings.get_remote_config()
	if remote_config.plugin_download_enabled:
		err = ExportHelper.download_file_text(remote_config.plugin_download_url, base_dir.path_join("godot.launcher.js"))
		if err != OK:
			printerr("failed to download godot launcher, url = " + str(remote_config.plugin_download_url))
			return err
		config.embed_godot_plugin = true
	else:
		config.embed_godot_plugin = false
		if base_dir_access.file_exists("godot.launcher.js"):
			base_dir_access.remove("godot.launcher.js")
	if !remote_config.plugin_version.is_empty():
		config.godot_plugin_info.version = remote_config.plugin_version
		
	for template in remote_config.get_engine_template_names():
		var template_config = remote_config.get_template_config(template)
		var release_variant = ExportTemplates.TemplateVariant.make_remote(template_config.release.url, template_config.release.md5)
		var debug_variant = ExportTemplates.TemplateVariant.make_remote(template_config.debug.url, template_config.debug.md5)
		ExportTemplates.get_instance().add_template(template, release_variant, debug_variant)
	
	err = ExportHelper.export_pack(self, preset, debug, base_dir.path_join("godot/main.pck"), config.brotli_on, config.brotli_policy, report)
	if err != Error.OK:
		printerr('failed to export pack.')
		return err
		
	var template_file_path = _get_template_file_path(preset, debug, config.export_template)
	if !template_file_path || !FileAccess.file_exists(template_file_path):
		printerr('template file not found')
		return Error.ERR_FILE_NOT_FOUND
	print('using template: ' + template_file_path)
	var zip_reader = ZIPReader.new()
	zip_reader.open(template_file_path)
	for file_name in ["godot.js", "godot.wasm.br"]:
		if !zip_reader.file_exists(file_name):
			printerr("file not found in template: " + file_name)
			return Error.ERR_DOES_NOT_EXIST
		var fa = FileAccess.open(base_dir.path_join("godot").path_join(file_name), FileAccess.WRITE)
		fa.store_buffer(zip_reader.read_file(file_name))
		fa.close()

	zip_reader.close();
	report.wasm_file = base_dir.path_join("godot/godot.wasm.br")
	
	if config.subpackage_on:
		if !base_dir_access.file_exists("godot/game.js"):
			FileAccess.open(base_dir.path_join("godot/game.js"), FileAccess.WRITE).close()
	else:
		if base_dir_access.file_exists("godot/game.js"):
			base_dir_access.remove("godot/game.js")
			
	var files :Array[ExportFile]= [
		ExportFile.TTGameJsFile.new(), 
		ExportFile.TTGameJsonFile.new(), 
		ExportFile.TTProjectConfigFile.new(), 
		ExportFile.GameConfigFile.new()
	]
	for file in files:
		var file_path = base_dir.path_join(file.get_file_name());
		if FileAccess.file_exists(file_path) && !file.is_ignore_exist():
			var file_access_read = FileAccess.open(file_path, FileAccess.READ)
			file.read_exist(file_access_read)
			file_access_read.close()
		if file as ExportFile.TTGameJsFile != null:
			if FileAccess.file_exists(file_path) && config.custom_game_js:
				continue
		var file_access_write = FileAccess.open(file_path, FileAccess.WRITE)
		file.write(file_access_write, config, report)
		file_access_write.close()
		
	FileAccess.open(base_dir.path_join('.gdignore'), FileAccess.WRITE).close();
	
	return Error.OK

func _get_template_file_path(preset: EditorExportPreset, debug: bool, template_name: String) -> String:
	var templates := ExportTemplates.get_instance()
	if preset.are_advanced_options_enabled():
		var custom_file_path = preset.get_or_env(OPTIONS_CUSTOM_TEMPLATE_DEBUG, "") if debug else preset.get_or_env(OPTIONS_CUSTOM_TEMPLATE_RELEASE, "")
		if custom_file_path:
			return custom_file_path
	var file_path = ""
	
	if template_name.is_empty():
		template_name = templates.get_default_template()
	file_path = templates.resolve_template_local_path(template_name, debug)
	if file_path.is_empty():
		templates.download_template(template_name, debug)
		file_path = templates.resolve_template_local_path(template_name, debug)
	return file_path
