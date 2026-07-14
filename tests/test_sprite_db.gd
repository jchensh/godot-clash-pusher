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

func test_make_card_portrait_size_not_inflated_by_large_frame() -> void:
	# 回归（2026-07-12）：TextureRect 默认 EXPAND_KEEP_SIZE 下先赋 texture 会把 minimum size
	# 撑到帧尺寸，后设的 size 被 clamp 顶大——100×96 三国骑士帧曾把组卡 52×40 卡池格撑爆超框。
	# make_card_portrait 必须保持 expand_mode 先于 texture/size 赋值，此测锁住该顺序。
	var port = SpriteDB.make_card_portrait("knight", _loaded(), Vector2.ZERO, Vector2(52, 40))
	assert_not_null(port, "knight 卡应有肖像")
	if port != null:
		assert_true(port.size.x <= 52.0 and port.size.y <= 40.0,
			"肖像应贴合请求尺寸而非被帧尺寸撑大: %s" % str(port.size))
		port.free()

func test_placeholder_inventory() -> void:
	# 占位盘点：31 条 ph 标记（29 新单位 + golem/baby_dragon 旧暂替）。
	# 正式三国素材替换一条就删一条 ph → 此断言同步减一（刻意的替换进度账本）。
	assert_eq(SpriteDB.placeholder_ids().size(), 31, "占位条目数应为 31（替换素材后同步更新此断言）")

# —— 0715 正式素材全家桶（knight 试点：立绘肖像 + 配套战斗特效）——

func test_portrait_override_for_knight() -> void:
	# 有 "portrait" 字段的单位卡面应直接用立绘原图（322×346），而非走帧 col0 的 AtlasTexture。
	var tex := SpriteDB.card_portrait_tex("knight", _loaded())
	assert_not_null(tex, "knight 卡应有肖像")
	if tex != null:
		assert_eq(tex.get_width(), 322, "knight 肖像应为立绘原图宽 322")
		assert_eq(tex.get_height(), 346, "knight 肖像应为立绘原图高 346")

func test_unit_fx_manifest_valid() -> void:
	# knight 三种配套特效齐全且条带边界合法；未配置单位/未知 kind 返回空字典。
	for kind in ["attack", "hit", "death"]:
		var fx: Dictionary = SpriteDB.unit_fx("knight_body", kind)
		assert_false(fx.is_empty(), "knight_body 应有 %s 特效" % kind)
		if fx.is_empty():
			continue
		var tex: Texture2D = fx["tex"]
		assert_not_null(tex, "%s 特效贴图存在" % kind)
		assert_true(int(fx["n"]) * int(fx["fw"]) <= tex.get_width(),
			"%s 条带帧数×帧宽应在贴图内: %d×%d vs %d" % [kind, fx["n"], fx["fw"], tex.get_width()])
		assert_true(int(fx["fh"]) <= tex.get_height(), "%s 帧高应在贴图内" % kind)
		assert_true(float(fx["dur"]) > 0.0 and float(fx["size"]) > 0.0, "%s dur/size 为正" % kind)
	assert_true(SpriteDB.unit_fx("goblin_body", "attack").is_empty(), "未配置单位返回空")
	assert_true(SpriteDB.unit_fx("knight_body", "nope").is_empty(), "未知 kind 返回空")

func test_knight_attack_cell_and_sc() -> void:
	# 攻击帧 152 方格 + sc 补偿（走↔攻切换脚底不跳的前提）；8 帧全部在条带边界内。
	var spr: Dictionary = SpriteDB.frame("knight_body", "attack", 0, 7.0 / 12.0 + 0.001)  # 最后一帧
	assert_false(spr.is_empty(), "knight attack 帧非空")
	if not spr.is_empty():
		var src: Rect2 = spr["src"]
		assert_eq(int(src.size.x), 152, "攻击帧宽 152")
		assert_eq(int(src.size.y), 152, "攻击帧高 152")
		var tex: Texture2D = spr["tex"]
		assert_true(src.end.x <= float(tex.get_width()), "末帧在条带内")
		# scale = 条目 1.35 × sc 1.583（浮点近似）
		assert_true(absf(float(spr["scale"]) - 1.35 * 1.583) < 0.01, "攻击态 scale 含 sc 补偿")
