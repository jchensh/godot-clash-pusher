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
## KAN-109：无记住的 username → 直接失败（调用方引导去登录页）；有则静默重登。
## V4-S1 匿名 device 登录保留注释（正式上线"新设备直进引导"体验时恢复）：
##     var lr = await auth.login(http)   # device_id 匿名登录（服务端 /v4/auth/login 仍挂载）
func ensure(http: HTTPRequest) -> bool:
	if not logged_in:
		if not auth.has_credentials():
			return false   # 需要登录页（needs_login()），不再本地生造账号
		var lr = await auth.login_name(http, auth.username)
		if not lr.ok:
			# 服务器明确拒绝（4xx=账号不存在/凭据无效，非网络故障）→ 清本地记住的
			# username，让 needs_login() 路由去登录页重注册；否则会永远卡在重试门
			# （2026-07-19 测试清库事故实锤的死角）。5xx/超时保留凭据只重试。
			if lr.status_code >= 400 and lr.status_code < 500:
				Log.w("[V5][session] login-name 被服务器拒绝(status=%d) → 清凭据回登录页" % lr.status_code)
				sign_out()
			return false
		logged_in = true
	var profile_result = await profile.get_profile(http, auth.access_token)
	# 决策48/E1：离线 profile cache 只可只读展示，不算在线登录成功。
	return profile_result.ok and not profile_result.offline


# —— KAN-109 username 裸登录门面 ——

## 是否需要弹登录页（本地无记住的 username）。
func needs_login() -> bool:
	return auth == null or not auth.has_credentials()


## 查 username 是否已注册（服务器权威）。返回 {ok, valid, registered, error}。
func check_name(http: HTTPRequest, p_username: String) -> Dictionary:
	return await auth.check_name(http, p_username)


## 老玩家登录（成功记住 username）。
func login_name(http: HTTPRequest, p_username: String) -> bool:
	var r = await auth.login_name(http, p_username)
	logged_in = r.ok
	return r.ok


## 新玩家注册（username+头像；服务器建号，昵称=username）。
func register_name(http: HTTPRequest, p_username: String, avatar: String) -> bool:
	var r = await auth.register_name(http, p_username, avatar)
	logged_in = r.ok
	return r.ok


## 登出：清 token+username（device_id 保留），回登录页由调用方跳转。
func sign_out() -> void:
	logged_in = false
	if auth != null:
		auth.logout()


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
	if f == null:
		return {}
	var d = JSON.parse_string(f.get_as_text())
	return d if d is Dictionary else {}
