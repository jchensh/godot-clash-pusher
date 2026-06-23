extends "res://tests/test_case.gd"

## V4-S2d 客户端 net/profile.gd 的非网络部分单测:
## 缓存读写 / 离线兜底前提 / 本地卡组 upsert / 请求编码 / 响应解码填充.
## 真 HTTP get/update 走 V4-S2e 端到端验收 (需 docker compose + api 起 server).

const Profile := preload("res://net/profile.gd")
const ProfilePb := preload("res://net/proto/profile.gd")

const _PROFILE_PATH := "user://profile.cfg"

const FULL_DECK := ["knight", "archer", "fireball", "giant", "goblins", "musketeer", "minions", "cannon"]


func _cleanup() -> void:
	if FileAccess.file_exists(_PROFILE_PATH):
		DirAccess.remove_absolute(_PROFILE_PATH)


func test_server_url_default_and_override() -> void:
	var a = Profile.new()
	assert_eq(a.server_url, "http://localhost:8080")
	var b = Profile.new("https://api.example.com")
	assert_eq(b.server_url, "https://api.example.com")


func test_cache_roundtrip() -> void:
	_cleanup()
	var a = Profile.new()
	a.account_id = 42
	a.nickname = "Alice"
	a.avatar_id = 3
	a.level = 5
	a.exp = 120
	a.trophies = 250
	a.current_season_id = 1
	a.version = 7
	a.updated_at = 1700000000
	a.decks = [
		{"id": 11, "slot": 1, "card_ids": ["a", "b"], "is_active": true},
		{"id": 12, "slot": 2, "card_ids": ["c", "d"], "is_active": false},
	]
	a.unlocked_card_ids = ["a", "b", "c", "d"]
	a._save_cache()

	var b = Profile.new()
	assert_true(b._load_cache(), "load_cache should succeed after save")
	assert_eq(b.account_id, 42)
	assert_eq(b.nickname, "Alice")
	assert_eq(b.avatar_id, 3)
	assert_eq(b.level, 5)
	assert_eq(b.exp, 120)
	assert_eq(b.trophies, 250)
	assert_eq(b.current_season_id, 1)
	assert_eq(b.version, 7)
	assert_eq(b.updated_at, 1700000000)
	assert_eq(b.decks.size(), 2)
	assert_eq(int(b.decks[0]["slot"]), 1)
	assert_eq(b.decks[0]["card_ids"], ["a", "b"])
	assert_true(b.decks[0]["is_active"])
	assert_eq(b.unlocked_card_ids, ["a", "b", "c", "d"])
	_cleanup()


func test_load_cache_missing_returns_false() -> void:
	_cleanup()
	var a = Profile.new()
	assert_false(a._load_cache(), "load_cache on missing file must return false")


func test_upsert_local_deck_append_then_update() -> void:
	var a = Profile.new()
	# 插入 slot 1 (active).
	a._upsert_local_deck(1, ["a"], true)
	assert_eq(a.decks.size(), 1)
	assert_eq(int(a.decks[0]["slot"]), 1)
	assert_true(a.decks[0]["is_active"])

	# 插入 slot 2 (非 active): slot 1 仍 active.
	a._upsert_local_deck(2, ["b"], false)
	assert_eq(a.decks.size(), 2)
	assert_true(_deck_by_slot(a, 1)["is_active"], "slot1 stays active when slot2 added inactive")
	assert_false(_deck_by_slot(a, 2)["is_active"])

	# 更新 slot 2 为 active: slot 1 应被降级, slot 2 卡组更新, 不新增行.
	a._upsert_local_deck(2, ["c", "d"], true)
	assert_eq(a.decks.size(), 2, "updating existing slot must not append")
	assert_false(_deck_by_slot(a, 1)["is_active"], "slot1 demoted when slot2 becomes active")
	assert_true(_deck_by_slot(a, 2)["is_active"])
	assert_eq(_deck_by_slot(a, 2)["card_ids"], ["c", "d"])


func test_deck_update_req_roundtrip() -> void:
	# 验证 update_deck 构造请求的方式能正确编解码 (slot/card_ids/set_active/expected_version).
	var req = ProfilePb.DeckUpdateReq.new()
	req.set_slot(2)
	for c in FULL_DECK:
		req.add_card_ids(c)
	req.set_set_active(true)
	req.set_expected_version(5)
	var bytes: PackedByteArray = req.to_bytes()

	var req2 = ProfilePb.DeckUpdateReq.new()
	assert_eq(req2.from_bytes(bytes), ProfilePb.PB_ERR.NO_ERRORS)
	assert_eq(req2.get_slot(), 2)
	assert_eq(req2.get_card_ids(), FULL_DECK)
	assert_true(req2.get_set_active())
	assert_eq(req2.get_expected_version(), 5)


func test_apply_get_resp_bytes_populates_state() -> void:
	_cleanup()
	# 造一个 ProfileGetResp (profile + 2 decks + 解锁集), 编码, 让 profile.gd 解码填充.
	var resp = ProfilePb.ProfileGetResp.new()
	var prof = resp.new_profile()
	prof.set_account_id(7)
	prof.set_nickname("Bob")
	prof.set_trophies(99)
	prof.set_version(2)
	var d1 = resp.add_decks()
	d1.set_id(1)
	d1.set_slot(1)
	d1.add_card_ids("knight")
	d1.set_is_active(true)
	var d2 = resp.add_decks()
	d2.set_id(2)
	d2.set_slot(2)
	d2.add_card_ids("archer")
	d2.set_is_active(false)
	resp.add_unlocked_card_ids("knight")
	resp.add_unlocked_card_ids("archer")
	var bytes: PackedByteArray = resp.to_bytes()

	var a = Profile.new()
	assert_true(a.apply_get_resp_bytes(bytes), "decode should succeed")
	assert_eq(a.account_id, 7)
	assert_eq(a.nickname, "Bob")
	assert_eq(a.trophies, 99)
	assert_eq(a.version, 2)
	assert_eq(a.decks.size(), 2)
	assert_eq(int(_deck_by_slot(a, 1)["slot"]), 1)
	assert_true(_deck_by_slot(a, 1)["is_active"])
	assert_eq(_deck_by_slot(a, 1)["card_ids"], ["knight"])
	assert_eq(a.unlocked_card_ids, ["knight", "archer"])
	# apply 会落盘 -> 新实例能从缓存读回.
	var b = Profile.new()
	assert_true(b._load_cache())
	assert_eq(b.account_id, 7)
	_cleanup()


func test_apply_deck_resp_bytes_updates_version() -> void:
	var resp = ProfilePb.DeckUpdateResp.new()
	resp.set_ok(true)
	resp.set_new_version(3)
	var prof = resp.new_profile()
	prof.set_account_id(7)
	prof.set_version(3)
	var bytes: PackedByteArray = resp.to_bytes()

	var a = Profile.new()
	assert_true(a.apply_deck_resp_bytes(bytes))
	assert_eq(a.version, 3)
	assert_eq(a.account_id, 7)


# ---- helper ----

func _deck_by_slot(p, slot: int) -> Dictionary:
	for d in p.decks:
		if int(d["slot"]) == slot:
			return d
	return {}
