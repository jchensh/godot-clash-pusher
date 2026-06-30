extends RefCounted
##
## V4-S4 联机会话:把"匿名登录 + 拉档案"集中一处,跨场景复用(由 GameState 静态持有)。
## 主菜单进来调 ensure() 登录+拉档显示杯数;联机对战页复用 token() 不再重复登录;
## 打完一局回菜单前 refresh_profile() 刷新杯数。HTTPRequest 由 caller 传入(须在 SceneTree)。

const AuthScript := preload("res://net/auth.gd")
const ProfileScript := preload("res://net/profile.gd")

var auth                    # net/auth.gd
var profile                 # net/profile.gd
var api_url := "http://localhost:8080"
var ws_url := "ws://localhost:8081/v4/battle/ws"
var logged_in := false


func _init() -> void:
	var net := _load_network()
	api_url = net.get("api_url", api_url)
	ws_url = net.get("ws_url", ws_url)
	auth = AuthScript.new(api_url)
	profile = ProfileScript.new(api_url)


## 登录(若尚未)+拉档案。幂等。http 须已 add_child 到 SceneTree。返回是否成功。
func ensure(http: HTTPRequest) -> bool:
	if not logged_in:
		var lr = await auth.login(http)
		if not lr.ok:
			return false
		logged_in = true
	await profile.get_profile(http, auth.access_token)
	return true


## 重新拉档案(对局后刷新杯数等)。
func refresh_profile(http: HTTPRequest) -> void:
	if logged_in:
		await profile.get_profile(http, auth.access_token)


func trophies() -> int:
	return profile.trophies if profile != null else 0


func token() -> String:
	return auth.access_token if auth != null else ""


# —— V5-S9 账号身份（昵称/头像/引导）——

func is_new() -> bool:
	return auth != null and auth.is_new


func nickname() -> String:
	return profile.nickname if profile != null else ""


func avatar_card_id() -> String:
	return profile.avatar_card_id if profile != null else ""


func tutorial_done() -> bool:
	return profile != null and profile.tutorial_done


## 是否还没创号（服务器权威：头像为空 = 没走过创号流程，扛"创号中途退出"）。
func needs_account_setup() -> bool:
	return profile != null and profile.avatar_card_id == ""


## 推昵称+头像到服务器（创号/改身份）。返回是否成功。http 须在 SceneTree。
func update_identity(http: HTTPRequest, p_nickname: String, p_avatar_card_id: String) -> bool:
	if auth == null or profile == null:
		return false
	var res = await profile.update_identity(http, auth.access_token, p_nickname, p_avatar_card_id)
	return res.ok


## 标记新手引导已完成（服务器权威）。返回是否成功。
func mark_tutorial_done(http: HTTPRequest) -> bool:
	if auth == null or profile == null:
		return false
	var res = await profile.mark_tutorial_done(http, auth.access_token)
	return res.ok


## V5-S9 天梯：把选好的卡组存到指定槽（服务器权威，set_active）。返回是否成功。
## 服务端匹配时按槽取卡组建房（lobby.lookupDeck），故必须先存槽再入队。
func save_deck(http: HTTPRequest, slot: int, cards: Array) -> bool:
	if auth == null or profile == null:
		return false
	var res = await profile.update_deck(http, auth.access_token, slot, cards, true, profile.version)
	if res.conflict:   # 版本冲突已自动重取最新档 → 用新版本重试一次
		res = await profile.update_deck(http, auth.access_token, slot, cards, true, profile.version)
	return res.ok


func _load_network() -> Dictionary:
	var f := FileAccess.open("res://config/network.json", FileAccess.READ)
	var d = {}
	if f != null:
		var parsed = JSON.parse_string(f.get_as_text())
		if parsed is Dictionary:
			d = parsed
	
	# Web 平台动态 URL 注入支持 (环境无关性)
	if OS.has_feature("web"):
		var js_api = JavaScriptBridge.eval("window.GAME_API_URL")
		var js_ws = JavaScriptBridge.eval("window.GAME_WS_URL")
		if js_api != null and str(js_api) != "":
			d["api_url"] = str(js_api)
		if js_ws != null and str(js_ws) != "":
			var ws_str = str(js_ws)
			if not ws_str.contains("/v4/"):
				if ws_str.ends_with("/"):
					ws_str = ws_str + "v4/battle/ws"
				else:
					ws_str = ws_str + "/v4/battle/ws"
			d["ws_url"] = ws_str
			
	return d
