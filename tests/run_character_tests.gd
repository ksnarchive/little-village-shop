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
		look.outfit = index % 6
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
	for atlas in [CharacterArt.BODY, CharacterArt.EYES, CharacterArt.FACE, CharacterArt.CLOTHES, CharacterArt.HAIR]:
		check(atlas.get_width() == 288, "Aligned atlas has all 12 direction/animation cells")
	check(CharacterArt.CLOTHES.get_height() == 6 * 32 and CharacterArt.HAIR.get_height() == 8 * 32, "Six garments and eight hairstyles are actual pixel sprites")
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
