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


func _load_network() -> Dictionary:
	var f := FileAccess.open("res://config/network.json", FileAccess.READ)
	if f == null:
		return {}
	var d = JSON.parse_string(f.get_as_text())
	return d if d is Dictionary else {}
