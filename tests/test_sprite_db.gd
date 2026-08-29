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
	# 占位盘点：0704 铺满时 31 条；0721 批次正式素材替换 bat/royal_giant/inferno_dragon 三条 → 28。
	# 正式三国素材替换一条就删一条 ph → 此断言同步减一（刻意的替换进度账本）。
	assert_eq(SpriteDB.placeholder_ids().size(), 28, "占位条目数应为 28（替换素材后同步更新此断言）")

# —— 0715 正式素材全家桶（knight 试点：立绘肖像 + 配套战斗特效）——

func test_portrait_override_for_knight() -> void:
	# 有 "portrait" 字段的单位卡面应直接用立绘原图（322×346），而非走帧 col0 的 AtlasTexture。
	var tex := SpriteDB.card_portrait_tex("knight", _loaded())
	assert_not_null(tex, "knight 卡应有肖像")
	if tex != null:
		assert_eq(tex.get_width(), 322, "knight 肖像应为立绘原图宽 322")
		assert_eq(tex.get_height(), 346, "knight 肖像应为立绘原图高 346")

func test_unit_fx_manifest_valid() -> void:
	# 决策 49：knight_body 被卡通层接管（无 fx）→ 用仍走旧 DB 的 giant_body（0721 素材）验 manifest；
	# 特效条带边界合法；未配置单位/未知 kind 返回空字典。
	assert_true(SpriteDB.unit_fx("knight_body", "attack").is_empty(), "卡通层接管的 knight 无旧 fx")
	for kind in ["attack", "hit"]:
		var fx: Dictionary = SpriteDB.unit_fx("giant_body", kind)
		assert_false(fx.is_empty(), "giant_body 应有 %s 特效" % kind)
		if fx.is_empty():
			continue
		var tex: Texture2D = fx["tex"]
		assert_not_null(tex, "%s 特效贴图存在" % kind)
		assert_true(int(fx["n"]) * int(fx["fw"]) <= tex.get_width(),
			"%s 条带帧数×帧宽应在贴图内: %d×%d vs %d" % [kind, fx["n"], fx["fw"], tex.get_width()])
		assert_true(int(fx["fh"]) <= tex.get_height(), "%s 帧高应在贴图内" % kind)
		assert_true(float(fx["dur"]) > 0.0 and float(fx["size"]) > 0.0, "%s dur/size 为正" % kind)
	assert_true(SpriteDB.unit_fx("goblin_body", "attack").is_empty(), "未配置单位返回空")
	assert_true(SpriteDB.unit_fx("giant_body", "nope").is_empty(), "未知 kind 返回空")

func test_knight_attack_cell_and_sc() -> void:
	# 决策 49：knight_body=卡通层（小小）。帧尺寸以 cartoon_frames.json 为真相源对比（美术重切自动跟随）；
	# px 直画标记 + mirror（正面微朝左单行帧）+ scale=1.0（交付即所得）。
	var meta = JSON.parse_string(FileAccess.get_file_as_string("res://assets/units_cartoon/cartoon_frames.json"))
	assert_true(typeof(meta) == TYPE_DICTIONARY and (meta as Dictionary).has("knight"), "帧元数据含 knight")
	var am: Dictionary = (meta as Dictionary).get("knight", {}).get("attack", {})
	var spr: Dictionary = SpriteDB.frame("knight_body", "attack", 0, 0.001)
	assert_false(spr.is_empty(), "knight attack 帧非空")
	if not spr.is_empty() and not am.is_empty():
		var src: Rect2 = spr["src"]
		assert_eq(int(src.size.x), int(am["fw"]), "攻击帧宽=元数据 fw")
		assert_eq(int(src.size.y), int(am["fh"]), "攻击帧高=元数据 fh")
		var tex: Texture2D = spr["tex"]
		assert_true(src.end.x <= float(tex.get_width()), "帧在条带内")
		assert_true(bool(spr["px"]), "卡通层标 px 直画")
		assert_true(bool(spr["mirror"]), "卡通层标 mirror")
		assert_true(absf(float(spr["scale"]) - 1.0) < 0.001, "卡通主体 scale=1（交付即所得）")


func test_cartoon_layer_covers_21_cards() -> void:
	# 决策 49 P1-6：21 张可玩卡的 spawn 单位 + 派生形态（凤凰重生/幼蛾）全被卡通层接管；
	# walk/attack 双态可取帧、px 标记、立绘就位。
	for card in SpriteDB.CARTOON_UNIT_OF_CARD:
		var uid: String = SpriteDB.CARTOON_UNIT_OF_CARD[card]
		for st in ["walk", "attack"]:
			var spr: Dictionary = SpriteDB.frame(uid, st, 0, 0.0)
			assert_false(spr.is_empty(), "%s(%s) %s 帧非空" % [card, uid, st])
			if not spr.is_empty():
				assert_true(bool(spr["px"]), "%s %s 走 px 直画" % [uid, st])
				var src: Rect2 = spr["src"]
				var tex: Texture2D = spr["tex"]
				assert_true(src.end.x <= float(tex.get_width()) + 0.001, "%s %s 帧在条带内" % [uid, st])
	for uid in SpriteDB.CARTOON_DERIVED:
		var spr: Dictionary = SpriteDB.frame(uid, "walk", 0, 0.0)
		assert_false(spr.is_empty(), "派生形态 %s 有帧（复用父贴图）" % uid)
		if not spr.is_empty():
			assert_true(float(spr["scale"]) < 1.0, "派生形态 %s 缩小号" % uid)
