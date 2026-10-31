extends Object
class_name ExportSettings
class RemoteConfig extends RefCounted:
	var plugin_download_enabled := false
	var plugin_download_url := ""
	var plugin_version := ""
	var engine_templates := {}
	
	func get_engine_template_names() -> Array[String]:
		var arr : Array[String] = []
		for key in engine_templates.keys():
			if typeof(key) != TYPE_STRING:
				continue
			if !engine_templates.get(key).has("release"):
				continue
			if !engine_templates.get(key).has("debug"):
				continue
			arr.push_back(key)
		return arr
	func get_template_config(name: String) -> Dictionary:
		var item = engine_templates.get(name)
		var ret = {
			"release": {
				"md5": item.get("release", {}).get("md5", ""),
				"url": item.get("release", {}).get("url", ""),
			},
			"debug": {
				"md5": item.get("debug", {}).get("md5", ""),
				"url": item.get("debug", {}).get("url", ""),
			}
		}
		
		return ret

static var _remote_config: RemoteConfig

static func get_remote_config() -> RemoteConfig:
	return _remote_config

# for internal build
static func try_get_config_from_environment() -> RemoteConfig:
	var local_settings_file = OS.get_environment("BUILD_SETTINGS_LOCAL_FILE")
	if local_settings_file.is_empty() or !FileAccess.file_exists(local_settings_file):
		return null
	var f := FileAccess.open(local_settings_file,FileAccess.READ);
	if FileAccess.get_open_error() != OK:
		printerr("failed to open file: %s", local_settings_file)
		return null
	var json := f.get_as_text();
	var data = JSON.parse_string(json) as Dictionary;
	
	return _parse_remote_config(data);

static func fetch_remote_config(debug_id: String) -> Error:
	var config_from_env = try_get_config_from_environment()
	if config_from_env != null:
		_remote_config = config_from_env;
		return Error.OK
	var recv = PackedByteArray()
	var err = ExportHelper.tls_get_sync("is.snssdk.com", "/service/settings/v3/", {
		"aid": "247",
		"caller_name": "gameplus_uge",
		"device_id": debug_id
	}, recv)
	if err != OK:
		printerr(ExportHelper.get_http_error())
		return err
	
	var text = recv.get_string_from_utf8()
	var json = JSON.new()
	if json.parse(text) != OK || typeof(json.data) != TYPE_DICTIONARY:
		printerr('body failed to parse')
		return Error.FAILED
	#config.plugin_download_enabled = true
	#config.plugin_download_url = "https://lf3-static.bytednsdoc.com/obj/eden-cn/ubqupevhn/index.js"
	var dict = json.data as Dictionary
	if !dict.has("data") || !dict["data"].has("settings") || !dict["data"]["settings"].has("godot_sdk_config"):
		printerr('body error')
		return Error.FAILED
	var godot_sdk_config = dict["data"]["settings"]["godot_sdk_config"] as Dictionary

	_remote_config = _parse_remote_config(godot_sdk_config)
	return OK

static func _parse_remote_config(settings: Dictionary) -> RemoteConfig:
	var remote_config = RemoteConfig.new()
	remote_config.plugin_download_enabled = settings.get("plugin_download_enabled", false)
	remote_config.plugin_download_url = settings.get("plugin_download_url", "")
	remote_config.plugin_version = settings.get("plugin_version", "")
	
	var version_info = Engine.get_version_info()
	var version2 = "%d.%d" % [version_info.major, version_info.minor]
	
	if settings.has("engine_templates") and settings.get("engine_templates").has(version2):
		var engine_templates = settings.get("engine_templates").get(version2)
		if typeof(engine_templates) == TYPE_DICTIONARY:
			remote_config.engine_templates = engine_templates
	return remote_config
