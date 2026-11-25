extends SceneTree
## Persistent appearance, v1 migration, all atlas poses and real frontend interactions.
var checks := 0
var failures := 0
class WriteFailure extends SaveStore:
	func _write_file(_target: String, _contents: String) -> bool:
		return false

const PATH := "user://character_test.json"

func _initialize() -> void:
	_run.call_deferred()

func check(ok: bool, description: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL: " + description)

func clean() -> void:
	for suffix in ["", ".bak", ".tmp", ".bak.tmp"]:
		DirAccess.remove_absolute(PATH + suffix)

func _run() -> void:
	clean()
	var shop := preload("res://scenes/main.tscn").instantiate()
	root.add_child(shop)
	shop.process_mode = Node.PROCESS_MODE_DISABLED
	var store := SaveStore.new(PATH)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1971
	for index in range(48):
		var look := CharacterAppearance.randomized(rng, "Женя Ёлкина")
		look.hairstyle = index % 8
		look.outfit = int(index / 8) # All 8 x 6 pairs, rather than a 24-pair LCM loop.
		shop.player.set_appearance(look)
		check(store.save_game(shop), "Appearance %d writes atomically" % index)
		shop.player.set_appearance(CharacterAppearance.DEFAULT)
		check(store.load_game(shop) and shop.player.appearance == look, "Name and every appearance layer round-trip %d" % index)
		for direction in [Vector2.DOWN, Vector2.UP, Vector2.LEFT, Vector2.RIGHT]:
			shop.player.facing = direction
			shop.player.walking = true
			check(shop.player.appearance == look, "Walking and facing preserve appearance")
	var snapshot := store.capture(shop)
	var old := snapshot.duplicate(true)
	old.version = 1
	old.erase("character")
	check(store.apply(old, shop), "Original v1 save is accepted")
	check(shop.player.appearance == CharacterAppearance.DEFAULT, "Old save gets deterministic default character")
	check(store.capture(shop).economy == old.economy and store.capture(shop).storage == old.storage, "Migration preserves progress")
	check(store.save_game(shop) and store.read_save(shop).version == SaveStore.VERSION, "Next explicit save upgrades v1 to current schema")
	for bad in [null, {}, {"name": ""}, {"name": "A\nB"}]:
		var invalid := snapshot.duplicate(true)
		invalid.character = bad
		check(not store.apply(invalid, shop), "Malformed appearance rejected before progress changes")
	for key in CharacterAppearance.LIMITS:
		for bad in [-1, CharacterAppearance.LIMITS[key], 0.5, "1", null]:
			var invalid := snapshot.duplicate(true)
			invalid.character[key] = bad
			var before := store.capture(shop)
			check(not store.apply(invalid, shop) and store.capture(shop) == before, "Invalid %s rejected atomically" % key)
	for atlas in [CharacterArt.BODY, CharacterArt.EYES, CharacterArt.FACE, CharacterArt.CLOTHES, CharacterArt.HAIR, CharacterArt.HANDS]:
		check(atlas.get_width() <= 2048 and atlas.get_width() % 256 == 0, "Aligned material atlas fits mobile 2048px textures and four complete views")
	check(CharacterArt.BODY.get_width() == 512 and CharacterArt.HAIR.get_width() == 768 and VillagerArt.HEADS.get_width() == 256, "Static head materials are shared across walk poses to bound mobile memory")
	check(CharacterArt.CLOTHES.get_height() == 6 * 96 and CharacterArt.HAIR.get_height() == 8 * 96, "Six garments and eight hairstyles retain actual painted resources")
	_check_art()
	shop.free()
	var entry := preload("res://scenes/start.tscn").instantiate()
	entry.store = store
	root.add_child(entry)
	await process_frame
	await process_frame
	check(Rect2(0, 0, 640, 360).encloses(entry.panel.get_rect()), "Main menu fits after hidden confirmation buttons settle")
	entry.open_settings()
	await process_frame
	await process_frame
	check(Rect2(0, 0, 640, 360).encloses(entry.settings_panel.get_rect()), "Settings fit initial layout without offscreen content")
	entry._close_settings()
	entry.request_new_game()
	entry.confirm_new_game()
	var wardrobe: Control = entry.creator
	check(not wardrobe.name_input.has_focus() and wardrobe.confirm_button.has_focus(), "Opening wardrobe focuses a non-text action, never the name/keyboard")
	entry.animations = false
	check(not CharacterArt.motion_enabled(wardrobe.preview) and not CharacterArt.motion_enabled(entry.shop.player), "Existing reduced-motion preference reaches both preview and world actors")
	entry.animations = true
	var bytes := FileAccess.get_file_as_string(PATH)
	wardrobe.name_input.text = " "
	wardrobe.name_input.text_changed.emit(" ")
	check(wardrobe.confirm_button.disabled, "Blank name cannot be confirmed")
	wardrobe.name_input.text = "  Лёва  "
	wardrobe.name_input.text_changed.emit("  Лёва  ")
	check(not wardrobe.confirm_button.disabled and wardrobe.appearance.name == "Лёва", "Russian name is trimmed and validated")
	for key in wardrobe.choices:
		var previous: int = wardrobe.appearance[key]
		wardrobe.choices[key].pressed.emit()
		check(wardrobe.preview.appearance[key] == (previous + 1) % CharacterAppearance.LIMITS[key], "Click %s immediately updates preview" % key)
	wardrobe.random_button.pressed.emit()
	check(wardrobe.appearance.name == "Лёва" and wardrobe.preview.appearance == wardrobe.appearance, "Random changes all layers and retains name")
	for viewport_size in [Vector2(640, 360), Vector2(400, 740)]:
		wardrobe.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
		wardrobe.size = viewport_size
		await process_frame
		await process_frame
		check(Rect2(Vector2.ZERO, viewport_size).encloses(wardrobe.panel.get_rect()), "Editor panel fits %s" % viewport_size)
		check(Rect2(Vector2.ZERO, viewport_size).encloses(wardrobe.confirm_button.get_global_rect()), "Confirmation stays visible at %s" % viewport_size)
		check(wardrobe.confirm_button.size.y >= 44 and wardrobe.random_button.size.y >= 44, "Touch actions have 44 logical pixel targets")
	wardrobe.back_button.pressed.emit()
	check(entry.creator == null and entry.panel.visible and FileAccess.get_file_as_string(PATH) == bytes, "Cancelling wardrobe preserves save bytes")
	entry.confirm_new_game()
	entry.creator.appearance = {"name": "Мира", "skin": 5, "hairstyle": 4, "hair_color": 5, "eyes": 3, "outfit": 2}
	entry.creator.name_input.text = "Мира"
	var previous_shop: Node2D = entry.shop
	entry.store = WriteFailure.new(PATH)
	entry.creator.confirm_button.pressed.emit()
	check(entry.creator != null and entry.shop == previous_shop and FileAccess.get_file_as_string(PATH) == bytes, "Failed new-game write preserves editor, prior shop and save")
	check(entry.creator.error.text.contains("Не удалось"), "Write failure is visible in wardrobe")
	entry.store = store
	entry.creator.confirm_button.pressed.emit()
	check(entry.creator == null and entry.train != null and entry.menu.visible and entry.shop.player.appearance.name == "Мира", "Confirm enters train with chosen character")
	check(store.read_save(entry.shop).character == JSON.parse_string(JSON.stringify(entry.shop.player.appearance)), "First morning saves character with progress")
	entry.free()
	await process_frame # Release pending scene tweens before shutting down the test tree.
	clean()
	print("Little Village Shop character: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

func _check_art() -> void:
	# Stable IDs must select different art in every direction, not one universal sprite.
	for texture in [CharacterArt.HAIR, CharacterArt.CLOTHES, VillagerArt.HEADS]:
		var image: Image = texture.get_image()
		for direction in range(4):
			var seen := {}
			for variant in range(image.get_height() / 96):
				var part := image.get_region(Rect2i(direction * int(image.get_width() / 4), variant * 96, 64, 96))
				check(not part.is_invisible(), "Every selectable material has pixels in every direction")
				seen[part.get_data().hex_encode().sha256_text()] = true
			check(seen.size() == image.get_height() / 96, "All hairstyle/outfit/buyer IDs select distinct painted views")
	for texture in [CharacterArt.BODY, CharacterArt.HANDS, CharacterArt.HAIR, CharacterArt.EYES]:
		var bytes: PackedByteArray = texture.get_image().get_data()
		var neutral := true
		for offset in range(0, bytes.size(), 4):
			if bytes[offset + 3] > 0 and (bytes[offset] != bytes[offset + 1] or bytes[offset] != bytes[offset + 2]):
				neutral = false
				break
		check(neutral, "Tintable skin/hair/iris plates contain neutral material values, no false-color leakage")
	for texture in [CharacterArt.CLOTHES, VillagerArt.CLOTHES]:
		var image: Image = texture.get_image()
		for variant in range(image.get_height() / 96):
			for direction in range(4):
				var drawings := {}
				for pose in range(2, 8):
					var part := image.get_region(Rect2i((direction * 8 + pose) * 64, variant * 96, 64, 96))
					drawings[part.get_data().hex_encode().sha256_text()] = true
				check(drawings.size() == 6, "Each outfit and NPC has six genuinely different walk drawings")
	for facing in [Vector2.DOWN, Vector2.UP, Vector2.LEFT, Vector2.RIGHT]:
		var phases := {}
		for index in range(6):
			phases[CharacterArt.cell(facing, true, index * TAU / 6.0 + 0.01)] = true
		check(phases.size() == 6, "Walking uses six phases for every direction")
		check(CharacterArt.cell(facing, true, 0) == CharacterArt.cell(facing, true, TAU), "Walk cycle wraps without a pose discontinuity")
		check(CharacterArt.cell(facing, false, 0, 4.7) != CharacterArt.cell(facing, false, 0, 1), "Quiet idle includes a separate blink pose")
		check(CharacterArt.cell(facing, true, 1, 4.7, false) == CharacterArt.cell(facing, false, 0, 0, false), "Reduced motion holds the neutral directional pose")
	var a := CharacterArt.target_rect(CharacterArt.ORIGIN, 1.0, 0, true)
	var b := CharacterArt.target_rect(CharacterArt.ORIGIN, 1.0, 1, true)
	check(is_equal_approx(a.end.y, b.end.y), "Breathing keeps the feet anchored")
