# I18n —— 多语言 autoload（② 多语言）。
#
# 运行时从 config/i18n.json 构建 en/zh 两套 Translation 注入 TranslationServer，
# 不依赖编辑器导入 CSV（headless 友好）。locale 存 user://settings.cfg，默认中文。
# 场景里用全局 tr("key") 取译文；切语言用 I18n.set_language("zh"/"en")。
extends Node

const I18N_PATH := "res://config/i18n.json"
const SETTINGS_PATH := "user://settings.cfg"
const DEFAULT_LOCALE := "zh"

func _ready() -> void:
	_load_translations()
	TranslationServer.set_locale(_load_saved_locale())

func _load_translations() -> void:
	var f := FileAccess.open(I18N_PATH, FileAccess.READ)
	if f == null:
		push_error("I18n: 无法读取 %s" % I18N_PATH)
		return
	var data = JSON.parse_string(f.get_as_text())
	if typeof(data) != TYPE_DICTIONARY:
		push_error("I18n: i18n.json 解析失败")
		return
	for loc in data.keys():
		var table: Dictionary = data[loc]
		var tr := Translation.new()
		tr.locale = String(loc)
		for key in table.keys():
			tr.add_message(String(key), String(table[key]))
		TranslationServer.add_translation(tr)

func _load_saved_locale() -> String:
	var c := ConfigFile.new()
	if c.load(SETTINGS_PATH) == OK:
		return String(c.get_value("i18n", "locale", DEFAULT_LOCALE))
	return DEFAULT_LOCALE

# 切换语言：即时生效 + 存盘。已建好的 Control（auto_translate）会随之刷新；
# 程序化绘制的界面（battle_scene 每帧 tr）也即时；带参文本由各场景重建时更新。
func set_language(loc: String) -> void:
	TranslationServer.set_locale(loc)
	var c := ConfigFile.new()
	c.load(SETTINGS_PATH)   # 忽略返回值：不存在则空配置
	c.set_value("i18n", "locale", loc)
	c.save(SETTINGS_PATH)

func current_locale() -> String:
	return TranslationServer.get_locale()
