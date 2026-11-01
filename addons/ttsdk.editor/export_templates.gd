extends RefCounted
class_name ExportTemplates

static var _instance: ExportTemplates;

class TemplateVariant:
	var download_url: String;
	var local_path: String;
	var md5: String;
	static func make_remote(url: String, md5: String) -> TemplateVariant:
		var item = new()
		item.download_url = url
		item.md5 = md5
		return item
		
class TemplateInfo:
	var name: String;
	var release: TemplateVariant;
	var debug: TemplateVariant
	var local_only: bool = false
	static func make_local(name: String, release_local_path: String, debug_local_path: String) -> TemplateInfo:
		var info = new()
		info.name = name;
		info.release = TemplateVariant.new()
		info.release.local_path = release_local_path
		info.debug = TemplateVariant.new()
		info.debug.local_path = debug_local_path
		return info
	static func make(name: String, release: TemplateVariant, debug: TemplateVariant) -> TemplateInfo:
		var info = new()
		info.name = name
		info.release = release
		info.debug = debug
		return info


var _templates: Dictionary
var _download_dir: String


func _init() -> void:
	#var release_local = _get_sdk_dir().path_join("web_release.zip")
	#var debug_local = _get_sdk_dir().path_join("web_debug.zip")
	#var web_template = TemplateInfo.make_local("web", release_local, debug_local)
	#web_template.local_only = true
	#_templates.set("web", web_template)
	pass # always use remote template

func get_default_template() -> String:
	return "web"

func resolve_template_local_path(name: String, debug: bool) -> String:
	var info = _templates.get(name)
	if info == null:
		return ""
	var variant :TemplateVariant = info.debug if debug else info.release
	
	var local_path := variant.local_path
	if !local_path.is_empty():
		return local_path
	elif info.local_only:
		return ""
		
	## search for cached download
	local_path = _get_download_path(name, debug)
	if !FileAccess.file_exists(local_path):
		return ""

	var is_validated = false

	if !variant.md5.is_empty():
		var md5: String = FileAccess.get_md5(local_path)
		if md5.to_lower() == variant.md5.to_lower():
			is_validated = true
		else:
			print("template's md5 mis matched: expected %s, got %s. %s" % [variant.md5, md5, local_path])
			is_validated = false

	if is_validated:
		variant.local_path = local_path
		return local_path
	else:
		DirAccess.remove_absolute(local_path)
		return ""
		
func _get_download_path(name: String, debug: bool) -> String:
	return _get_download_dir().path_join("%s_%s.zip" % [name, "debug" if debug else "release"])

func add_template(name: String, release: TemplateVariant, debug: TemplateVariant):
	if _templates.has(name):
		var info = _templates.get(name)
		info.release = release
		info.debug = debug
	else:
		var info = TemplateInfo.make(name, release, debug)
		_templates.set(name, info);

func get_available_templates() -> Array[String]:
	return _templates.keys()
	

# 从 cdn 下载 template
func download_template(name: String, debug: bool) -> Error:
	if !_templates.has(name):
		printerr("template info not found: " + name)
		return Error.ERR_INVALID_PARAMETER
	
	var resolved_local_path = resolve_template_local_path(name, debug);
	if !resolved_local_path.is_empty():
		return resolved_local_path;
	
	var info: TemplateInfo = _templates.get(name)
	var variant : TemplateVariant = info.debug if debug else info.release

	if variant.download_url.is_empty():
		printerr("template download url unknown")
		return Error.FAILED
		
	var local_path = _get_download_path(name, debug)
	
	var download_path = local_path + ".tmp"
	if FileAccess.file_exists(download_path):
		DirAccess.remove_absolute(download_path)
		
	var url = variant.download_url
	print("begin download: %s" % [url])
	
	var err := ExportHelper.download_file(url, download_path);
	if err != OK:
		return err
		
	err = DirAccess.rename_absolute(download_path, local_path)
	if err != OK:
		return err
	print("downloaded: %s" % [local_path])
	variant.local_path = local_path
	
	return OK

func _get_download_dir() -> String:
	if _download_dir.is_empty():
		var version_info := Engine.get_version_info()
		var cache_dir := EditorInterface.get_editor_paths().get_cache_dir()
		_download_dir = cache_dir.path_join("tt-templates").path_join("%d.%d" % [version_info.major, version_info.minor])
		if !DirAccess.dir_exists_absolute(_download_dir):
			DirAccess.make_dir_recursive_absolute(_download_dir);
			
	return _download_dir
	
func _get_sdk_dir() -> String:
	return ProjectSettings.globalize_path("./addons/ttsdk.editor/templates")
	
static func get_instance()-> ExportTemplates:
	if _instance == null:
		_instance = new();
	return _instance;
	
static func delete_instance():
	_instance = null;
