extends SceneTree
## Real entry + atomic I/O + interrupted journeys, without touching the player's slot.
const PATH := "user://train_test.json"
var checks := 0
var failures := 0
class FailingStore extends SaveStore:
	var fail := true
	func _write_file(target: String, contents: String) -> bool:
		return false if fail else super._write_file(target, contents)

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

func entry_scene() -> Node:
	var entry := preload("res://scenes/start.tscn").instantiate()
	entry.store = SaveStore.new(PATH)
	root.add_child(entry)
	return entry

func _run() -> void:
	clean()
	check(TrainStory.THOUGHTS.size() == TrainStory.LAST_LINE, "Stable arrival checkpoint follows all thoughts")
	var entry := entry_scene()
	entry.confirm_new_game()
	var look := {"name": "Мира", "skin": 5, "hairstyle": 7, "hair_color": 5, "eyes": 2, "outfit": 4}
	entry._create_character(look)
	var train: Control = entry.train
	check(train != null and entry.menu.visible and entry.creator == null, "New character boards a separate scene")
	var before_view: Dictionary = entry.store.capture(entry.shop)
	train.scenery_button.pressed.emit()
	check(not train.dialogue.visible and not train.skip_button.visible, "Scenery view hides UI without changing story")
	train.advance()
	check(train.dialogue.visible and train.line == 0 and entry.store.capture(entry.shop) == before_view, "Returning from illustration never skips a thought or saves progress")
	check(train.view.CLOTHES.get_height() == 6 * 144 and train.view.HANDS.get_height() == 6 * 144, "All six complete seated outfits retain their own hands and poses")
	check(train.view.HEAD.get_height() == 8 * 144 and train.view.HAIR.get_height() == 8 * 144, "All eight selected hairstyles have complete painted portraits")
	check(train.view.EYES.get_height() == 16 * 144, "Each portrait supports independent iris tint and blink")
	check(train.appearance == look and entry.shop.player.appearance == look, "Chosen name and all appearance layers board intact")
	check(entry.shop.process_mode == Node.PROCESS_MODE_DISABLED and not entry.shop.inventory_ui.get_node("Root").visible, "Shop and its UI stay disabled during intro")
	var snapshot: Dictionary = entry.store.capture(entry.shop)
	await create_timer(0.1).timeout
	check(entry.store.capture(entry.shop) == snapshot and entry.shop.customers.is_empty(), "No clock, NPC or economy advancement behind train")
	check(entry.store.read_save(entry.shop).story.train_line == 0 and not entry.store.read_save(entry.shop).story.train_complete, "First atomic save contains pending intro")
	train.advance()
	check(train.line == 0 and train.words.visible_characters == -1, "First action reveals unfinished text without skipping")
	train.advance()
	check(train.line == 1 and entry.store.read_save(entry.shop).story.train_line == 1, "Second action checkpoints before showing next thought")
	var bytes := FileAccess.get_file_as_string(PATH)
	var failing := FailingStore.new(PATH)
	entry.shop.save_store = failing
	train.words.visible_characters = -1
	train.advance()
	check(train.line == 1 and entry.shop.story.train_line == 1 and FileAccess.get_file_as_string(PATH) == bytes, "Write failure rolls back story and preserves save + displayed line")
	check(train.error.text.contains("Не удалось"), "Checkpoint failure offers retry")
	train.request_skip()
	train.confirm_button.pressed.emit()
	check(not train._ending and entry.shop.story.train_complete == false and FileAccess.get_file_as_string(PATH) == bytes, "Failed skip cannot enter shop or mark intro complete")
	entry.free()
	await process_frame
	entry = entry_scene()
	entry.continue_game()
	train = entry.train
	check(train != null and train.line == 1 and train.appearance == look, "Continue resumes last committed thought with chosen hero")
	train.request_skip()
	check(train.modal.visible and train.cancel_button.has_focus(), "Skip requires confirmation, safe choice focused")
	train.cancel_button.pressed.emit()
	check(not train.modal.visible and train.line == 1 and FileAccess.get_file_as_string(PATH) == bytes, "Cancel skip leaves progress unchanged")
	train.words.visible_characters = -1
	var touch := InputEventScreenTouch.new()
	touch.position = Vector2(100, 130)
	touch.pressed = true
	Input.parse_input_event(touch)
	Input.flush_buffered_events()
	await process_frame
	check(train.line == 2, "A screen touch advances exactly one checkpoint")
	var mouse_twin := InputEventMouseButton.new()
	mouse_twin.device = -1
	mouse_twin.position = touch.position
	mouse_twin.button_index = MOUSE_BUTTON_LEFT
	mouse_twin.pressed = true
	Input.parse_input_event(mouse_twin)
	Input.flush_buffered_events()
	await process_frame
	check(train.line == 2 and train.words.visible_characters >= 0, "Emulated mouse twin cannot advance or reveal text again")
	for dimensions in [Vector2(640, 360), Vector2(400, 740), Vector2(400, 660), Vector2(740, 400)]:
		train.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
		train.size = dimensions
		await process_frame
		await process_frame
		for control in [train.dialogue, train.next_button, train.skip_button]:
			check(Rect2(Vector2.ZERO, dimensions).encloses(control.get_global_rect()), "Dialogue and controls fit %s" % dimensions)
		check(train.next_button.size.y >= 44 and train.skip_button.size.y >= 44, "Touch targets remain 44 pixels")
		train.heading.text = "WWWWWWWWWWWWWWWWWWWWWWWW · ПРО СЕБЯ"
		await process_frame
		await process_frame
		check(Rect2(Vector2.ZERO, dimensions).encloses(train.dialogue.get_rect()), "Long saved name cannot widen the compact panel at %s" % dimensions)
		for text in TrainStory.THOUGHTS + [TrainStory.ARRIVAL]:
			train.words.text = text
			await process_frame
			await process_frame
			check(Rect2(Vector2.ZERO, dimensions).encloses(train.dialogue.get_rect()), "Every full monologue paragraph fits %s" % dimensions)
		train._show_line()
		train.request_skip()
		check(Rect2(Vector2.ZERO, dimensions).encloses(train.modal.get_node("Confirmation").get_rect()), "Confirmation fits %s" % dimensions)
		train.cancel_skip()
	for index in range(3, TrainStory.LAST_LINE + 1):
		train.words.visible_characters = -1
		train.advance()
		check(train.line == index and entry.store.read_save(entry.shop).story.train_line == index, "Thought %d saves without changing trading progress" % index)
	check(train.heading.text == "ОБЪЯВЛЕНИЕ В ВАГОНЕ", "Arrival is announced after the monologue")
	train.words.visible_characters = -1
	train.advance()
	check(not train._ending, "Arrival waits for braking before departure")
	train._process(4)
	check(train.view.speed == 0, "Parallax eases down to a halt")
	train.advance()
	check(entry.shop.story.train_complete and train._ending and entry.menu.visible, "Completion is committed before fade or shop activation")
	await create_timer(1.4).timeout
	check(entry.train == null and not entry.menu.visible and entry.shop.process_mode == Node.PROCESS_MODE_INHERIT, "Fade ends in existing shop")
	check(entry.shop.player.appearance == look and entry.shop.economy.balance == 100, "Shop retains hero and starting economy")
	entry.free()
	await process_frame
	entry = entry_scene()
	entry.continue_game()
	check(entry.train == null and not entry.menu.visible, "Completed intro never repeats on Continue")
	entry.shop.process_mode = Node.PROCESS_MODE_DISABLED
	var good: Dictionary = entry.store.capture(entry.shop)
	for version in [1, 2]:
		var old := good.duplicate(true)
		old.version = version
		old.erase("story")
		if version == 1:
			old.erase("character")
		check(entry.store.apply(old, entry.shop) and entry.shop.story.train_complete, "Legacy v%d save starts after intro" % version)
		check(entry.shop.economy.balance == 100 and entry.shop.storage.inventory.total_units() == 13, "Legacy migration keeps goods and economy")
	for bad in [null, {}, {"train_line": -1, "train_complete": false}, {"train_line": 0.5, "train_complete": false}, {"train_line": 11, "train_complete": false}, {"train_line": 0, "train_complete": true}, {"train_line": 1, "train_complete": "false"}]:
		var invalid := good.duplicate(true)
		invalid.story = bad
		var before: Dictionary = entry.store.capture(entry.shop)
		check(not entry.store.apply(invalid, entry.shop) and entry.store.capture(entry.shop) == before, "Malformed checkpoint rejected before any state mutation")
	# Backup recovery resumes a valid pending line instead of starting from zero.
	entry.shop.story = {"train_line": 3, "train_complete": false}
	entry.store.save_game(entry.shop)
	entry.shop.story.train_line = 4
	entry.store.save_game(entry.shop)
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	file.store_string("{broken")
	file.close()
	check(entry.store.load_game(entry.shop) and entry.store.recovered and entry.shop.story.train_line == 3, "Corrupt primary recovers prior intro checkpoint")
	entry.free()
	await process_frame
	entry = entry_scene()
	entry.animations = false
	entry.continue_game()
	train = entry.train
	check(train.words.visible_characters == -1 and not train.view.animated, "Reduced motion disables typewriter and scene animation")
	var distance: float = train.view.distance
	train.view._process(1.0)
	check(train.view.distance == distance, "Reduced motion keeps scenery completely still")
	train.request_skip()
	train.confirm_button.pressed.emit()
	await create_timer(1.4).timeout
	check(entry.train == null and entry.shop.story.train_complete, "Confirmed skip safely completes intro")
	entry.free()
	clean()
	print("Little Village Shop train: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
