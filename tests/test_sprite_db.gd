# A2.5 精灵覆盖测试（三国占位铺满，2026-07-04）：
# units.json 每个单位都必须有 SpriteDB 条目（占位或正式）——防"加了新卡忘配皮"回退白膜；
# 帧取用合法（贴图非空、src 在贴图边界内、scale>0、tint 为 Color）；占位条目数盘点（替换正式素材后递减）。
extends "res://tests/test_case.gd"

const ConfigLoaderScript = preload("res://logic/config_loader.gd")
const SpriteDB = preload("res://view/sprite_db.gd")

func _loaded():
	var loader = ConfigLoaderScript.new()
	loader.load_all()
	return loader

func test_all_units_have_sprite_entry() -> void:
	var missing: Array = []
	for uid in _loaded().units:
		if not SpriteDB.has_sprite(str(uid)):
			missing.append(uid)
	assert_true(missing.is_empty(), "所有单位应有精灵条目(占位也算)，缺: %s" % str(missing))

func test_frames_valid_for_all_units_and_states() -> void:
	for uid in _loaded().units:
		for st in ["walk", "attack"]:
			for owner in [0, 1]:
				var spr: Dictionary = SpriteDB.frame(str(uid), st, owner, 0.37)
				assert_false(spr.is_empty(), "%s/%s/owner%d frame 非空" % [uid, st, owner])
				if spr.is_empty():
					continue
				var tex: Texture2D = spr["tex"]
				assert_not_null(tex, "%s/%s 贴图存在" % [uid, st])
				var src: Rect2 = spr["src"]
				assert_true(src.position.x >= 0.0 and src.position.y >= 0.0, "%s/%s src 起点非负" % [uid, st])
				assert_true(src.end.x <= float(tex.get_width()) and src.end.y <= float(tex.get_height()),
					"%s/%s src 应在贴图边界内: src=%s tex=%dx%d" % [uid, st, str(src), tex.get_width(), tex.get_height()])
				assert_true(float(spr["scale"]) > 0.0, "%s scale>0" % uid)
				assert_true(typeof(spr["tint"]) == TYPE_COLOR, "%s tint 为 Color" % uid)

func test_card_portrait_tint_is_color() -> void:
	var loader = _loaded()
	for cid in loader.cards:
		var tint = SpriteDB.card_portrait_tint(str(cid), loader)
		assert_true(typeof(tint) == TYPE_COLOR, "card %s portrait tint 为 Color" % cid)

func test_placeholder_inventory() -> void:
	# 占位盘点：31 条 ph 标记（29 新单位 + golem/baby_dragon 旧暂替）。
	# 正式三国素材替换一条就删一条 ph → 此断言同步减一（刻意的替换进度账本）。
	assert_eq(SpriteDB.placeholder_ids().size(), 31, "占位条目数应为 31（替换素材后同步更新此断言）")
