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
