extends "res://tests/test_case.gd"

## V4-S1d 客户端 net/auth.gd 的 storage 部分单测.
## 真 HTTP login/refresh 走 V4-S1e 端到端验收 (需要 docker compose 起 server).

const Auth := preload("res://net/auth.gd")

const _DEVICE_PATH := "user://device.cfg"
const _AUTH_PATH := "user://auth.cfg"


func _cleanup() -> void:
	if FileAccess.file_exists(_DEVICE_PATH):
		DirAccess.remove_absolute(_DEVICE_PATH)
	if FileAccess.file_exists(_AUTH_PATH):
		DirAccess.remove_absolute(_AUTH_PATH)


func test_device_id_generated_in_uuid4_format() -> void:
	_cleanup()
	var auth = Auth.new()
	assert_ne(auth.device_id, "")
	# RFC 4122 UUID v4: xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx (36 chars, dashes at 8/13/18/23, version '4' at 14, variant 8/9/a/b at 19)
	assert_eq(auth.device_id.length(), 36)
	assert_eq(auth.device_id[8], "-")
	assert_eq(auth.device_id[13], "-")
	assert_eq(auth.device_id[14], "4", "UUID version digit should be 4")
	assert_eq(auth.device_id[18], "-")
	assert_eq(auth.device_id[23], "-")
	var variant_char: String = auth.device_id[19]
	assert_true(variant_char in ["8", "9", "a", "b"], "UUID variant char should be 8/9/a/b, got %s" % variant_char)
	_cleanup()


func test_device_id_persists_across_instances() -> void:
	_cleanup()
	var first = Auth.new()
	var first_id = first.device_id
	# 第二个实例没清 file → 必须读到同一个 device_id.
	var second = Auth.new()
	assert_eq(second.device_id, first_id, "device_id should persist via user://device.cfg")
	_cleanup()


func test_two_fresh_devices_get_different_ids() -> void:
	_cleanup()
	var a = Auth.new()
	var id_a = a.device_id
	_cleanup()  # 删除存档让下一个实例重新生成.
	var b = Auth.new()
	assert_ne(b.device_id, id_a, "two regenerated UUID4s collided (improbable)")
	_cleanup()


func test_tokens_save_and_load() -> void:
	_cleanup()
	var a = Auth.new()
	a.access_token = "ACCESS-TOKEN-XYZ"
	a.refresh_token = "REFRESH-TOKEN-ABC"
	a._save_tokens()

	var b = Auth.new()
	assert_eq(b.access_token, "ACCESS-TOKEN-XYZ")
	assert_eq(b.refresh_token, "REFRESH-TOKEN-ABC")
	_cleanup()


func test_logout_clears_tokens_in_memory_and_on_disk() -> void:
	_cleanup()
	var a = Auth.new()
	a.access_token = "X"
	a.refresh_token = "Y"
	a._save_tokens()
	assert_true(FileAccess.file_exists(_AUTH_PATH))

	a.logout()
	assert_eq(a.access_token, "")
	assert_eq(a.refresh_token, "")
	assert_false(FileAccess.file_exists(_AUTH_PATH), "auth.cfg should be deleted after logout")

	# 新实例也读不出 token.
	var b = Auth.new()
	assert_eq(b.access_token, "")
	assert_eq(b.refresh_token, "")
	_cleanup()


func test_logout_preserves_device_id() -> void:
	# logout 只清 token,不动 device_id (重登仍是同一账号).
	_cleanup()
	var a = Auth.new()
	var original_device = a.device_id
	a.access_token = "X"
	a._save_tokens()
	a.logout()
	# 重新加载,device_id 不变.
	var b = Auth.new()
	assert_eq(b.device_id, original_device, "device_id must survive logout")
	_cleanup()


func test_server_url_default_and_override() -> void:
	_cleanup()
	var a = Auth.new()
	assert_eq(a.server_url, "http://localhost:8080")
	var b = Auth.new("https://api.example.com")
	assert_eq(b.server_url, "https://api.example.com")
	_cleanup()


# —— KAN-109 username 裸登录：凭据存储与登录门 ——

const Session := preload("res://net/session.gd")


func test_username_persists_and_has_credentials() -> void:
	_cleanup()
	var a = Auth.new()
	assert_false(a.has_credentials(), "全新实例不应有登录凭据")
	a.username = "陈到叔至"
	a.access_token = "tokA"
	a.refresh_token = "tokR"
	a._save_tokens()
	var b = Auth.new()
	assert_eq(b.username, "陈到叔至", "username 应随 auth.cfg 持久化（记住我）")
	assert_true(b.has_credentials(), "有记住的 username → 有凭据")
	_cleanup()


func test_logout_clears_username() -> void:
	_cleanup()
	var a = Auth.new()
	a.username = "老将"
	a.access_token = "X"
	a._save_tokens()
	a.logout()
	assert_eq(a.username, "", "logout 应清 username（内存）")
	var b = Auth.new()
	assert_false(b.has_credentials(), "logout 后新实例不应有凭据 → 弹登录页")
	_cleanup()


func test_session_needs_login_gate() -> void:
	# 无凭据 → needs_login=true（主菜单据此跳登录页，不再本地生造账号）。
	_cleanup()
	var s = Session.new()
	assert_true(s.needs_login(), "无 auth.cfg 时应要求登录")
	# 存了 username → 门放行（静默重登路径）。
	s.auth.username = "老将"
	s.auth.access_token = "X"
	s.auth._save_tokens()
	var s2 = Session.new()
	assert_false(s2.needs_login(), "有记住的 username 时不应弹登录页")
	# sign_out → 门重新关上。
	s2.sign_out()
	assert_true(s2.needs_login(), "登出后应回到需登录态")
	assert_false(s2.logged_in, "登出后 logged_in 应复位")
	_cleanup()
