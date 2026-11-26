extends SceneTree
## Real physics, real entry transitions and atomic location persistence.
const PATH := "user://station_test.json"
var checks := 0
var failures := 0

class FailingStore extends SaveStore:
	func _write_file(_path: String, _content: String) -> bool:
		return false

func _initialize() -> void:
	_run.call_deferred()

func check(ok: bool, description: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL: " + description)

func _frames(count: int) -> void:
	for index in range(count):
		await physics_frame

func _walk(station: VillageStation, goal: Vector2) -> void:
	var reached := false
	for step in range(600):
		var delta := goal - station.player.position
		if delta.length() < 3:
			reached = true
			break
		for action in ["ui_left", "ui_right", "ui_up", "ui_down"]:
			Input.action_release(action)
		if absf(delta.x) > 2:
			Input.action_press("ui_right" if delta.x > 0 else "ui_left")
		if absf(delta.y) > 2:
			Input.action_press("ui_down" if delta.y > 0 else "ui_up")
		await _frames(1)
		check(LocationState.STATION_BOUNDS.grow(0.01).encloses(Rect2(
			station.camera.global_position - Vector2(200, 112.5), Vector2(400, 225))), "Follow camera stays inside painted world")
	for action in ["ui_left", "ui_right", "ui_up", "ui_down"]:
		Input.action_release(action)
	check(reached, "Walk route reaches %s" % goal)

func _entry() -> Node:
	var entry := preload("res://scenes/start.tscn").instantiate()
	entry.store = SaveStore.new(PATH)
	root.add_child(entry)
	return entry

func _run() -> void:
	for suffix in ["", ".bak", ".tmp", ".bak.tmp"]:
		DirAccess.remove_absolute(PATH + suffix)
	var entry := _entry()
	entry.confirm_new_game()
	var look := CharacterAppearance.DEFAULT.duplicate()
	look.name = "Мира"
	look.hairstyle = 7
	look.outfit = 4
	entry._create_character(look)
	check(entry.shop.journey.location == "train", "New game checkpoints train location")
	check(entry._save_train_checkpoint(TrainStory.LAST_LINE, true), "Completion saves station before fade")
	entry._train_finished()
	await create_timer(1.0).timeout
	var station: VillageStation = entry.station
	check(station != null and station.player.appearance == look, "Custom character disembarks intact")
	check(entry.shop.process_mode == Node.PROCESS_MODE_DISABLED and not entry.shop.visible, "Shop simulation and render stay disabled outdoors")
	check(station.camera.zoom == Vector2(1.6, 1.6), "Station uses shared FollowCamera at 1.6")
	station.player.position = Vector2(208, 180)
	station.player.get_node("InteractionController").refresh_target()
	check(station.player.get_node("InteractionController").target == null, "Hidden shop fixtures cannot become outdoor targets")
	station.player.position = LocationState.STATION_SPAWN
	check(station.get_tree().get_nodes_in_group("interaction_controllers").size() == 2, "Only hero controllers, no station residents")
	var minute: float = entry.shop.day.minute
	station.elapsed = 4
	station._update_arrival()
	var parked: Vector2 = station.carriage.position
	station.elapsed = 7
	station._update_arrival()
	check(station.carriage.position.x > parked.x and station.wheels.volume_db < -24, "Departing train moves and wheels fade")
	station.elapsed = 10
	station._update_arrival()
	check(not station.carriage.visible and not station.wheels.playing, "Train departs permanently")
	entry.animations = false
	station.elapsed = 7
	station._update_arrival()
	check(station.carriage.position == parked, "Reduced motion suppresses train displacement")
	station.elapsed = 10
	station._update_arrival()
	entry.animations = true
	await _walk(station, Vector2(350, 260))
	await _walk(station, Vector2(570, 260))
	await _walk(station, Vector2(570, 315))
	await _walk(station, Vector2(510, 315))
	station.player.get_node("InteractionController").refresh_target()
	var target: Interactable = station.player.get_node("InteractionController").target
	check(target != null and target.prompt.contains("расписание"), "Timetable reachable with ordinary interaction controller")
	if target != null:
		target.interact(station.player)
	check(station.ui.modal.visible and not station.player.controls_enabled and station.ui.words.text.contains("18:40"), "Schedule opens readable modal and blocks movement")
	check(Rect2(0, 0, 640, 360).encloses(station.ui.modal.get_rect()), "Outdoor modal fits unscaled screen")
	station.ui.close()
	await _walk(station, Vector2(350, 315))
	await _walk(station, Vector2(350, 422))
	await _walk(station, Vector2(467, 422))
	station.player.get_node("InteractionController").refresh_target()
	target = station.player.get_node("InteractionController").target
	check(target != null and target.prompt.contains("указатель"), "Village sign is reachable")
	if target != null:
		target.interact(station.player)
	check(station.ui.words.text.contains("лавка"), "Sign explains destination")
	station.ui.close()
	await _walk(station, Vector2(166, 405))
	station.player.get_node("InteractionController").refresh_target()
	target = station.player.get_node("InteractionController").target
	check(target != null and target.prompt.contains("вокзал"), "Building entrance is inspectable")
	if target != null:
		target.interact(station.player)
	check(station.ui.words.text.contains("заперта"), "Building inspection is optional")
	station.ui.close()
	# Solid building and rail edge, independent of decorative sprite bounds.
	station.player.position = Vector2(166, 398)
	Input.action_press("ui_up")
	await _frames(30)
	Input.action_release("ui_up")
	check(station.player.position.y >= 385, "Building footprint blocks entry")
	station.player.position = Vector2(350, 180)
	Input.action_press("ui_up")
	await _frames(30)
	Input.action_release("ui_up")
	check(station.player.position.y >= 165, "Rail barrier remains solid after departure")
	station.player.position = Vector2(350, 422)
	station.state.thought = 2
	station.elapsed = 10
	check(station.save_checkpoint(), "Station snapshot commits")
	check(entry.shop.day.minute == minute and entry.shop.economy.balance == 100, "Exploration never advances shop clock or economy")
	var saved: Dictionary = entry.store.read_save(entry.shop)
	check(saved.version == 4 and saved.journey.location == "station", "Version 4 records station checkpoint")
	var bytes := FileAccess.get_file_as_string(PATH)
	entry.shop.save_store = FailingStore.new(PATH)
	station.player.position.x += 10
	check(not station.save_checkpoint() and FileAccess.get_file_as_string(PATH) == bytes, "Failed station autosave preserves previous bytes")
	entry.free()
	await process_frame
	entry = _entry()
	entry.continue_game()
	await create_timer(0.8).timeout
	station = entry.station
	check(station != null and station.player.position == Vector2(350, 422), "Continue restores platform position without intro")
	check(station.player.appearance == look and not station.carriage.visible and int(station.state.thought) >= 2, "Continue retains hero, departed train and thought progress")
	var master_volume := AudioServer.get_bus_volume_db(0)
	AudioServer.set_bus_volume_db(0, -80)
	station._update_arrival()
	check(AudioServer.get_bus_volume_db(0) == -80, "Outdoor playback respects existing master volume")
	AudioServer.set_bus_volume_db(0, master_volume)
	for version in [1, 2, 3]:
		var old := saved.duplicate(true)
		old.version = version
		old.erase("journey")
		if version < 3:
			old.erase("story")
		if version < 2:
			old.erase("character")
		check(entry.store.apply(old, entry.shop) and entry.shop.journey.location == "shop", "Legacy v%d completed save stays in shop" % version)
	var pending := saved.duplicate(true)
	pending.version = 3
	pending.erase("journey")
	pending.story = TrainStory.fresh()
	check(entry.store.apply(pending, entry.shop) and entry.shop.journey.location == "train", "Legacy unfinished v3 journey retains its train checkpoint")
	check(entry.store.apply(saved, entry.shop), "Restore station state after migration fixtures")
	for invalid in [{}, {"location": "forest"}, {"location": "station", "position": [INF, 0]},
		{"location": "station", "position": [-1, 999], "arrival_time": 10, "thought": 0}]:
		var bad := saved.duplicate(true)
		bad.journey = invalid
		var before: Dictionary = entry.store.capture(entry.shop)
		check(not entry.store.apply(bad, entry.shop) and before == entry.store.capture(entry.shop), "Malformed location rejected atomically")
	await _walk(station, Vector2(660, 422))
	# Save failure at the fade boundary must retain a usable outdoor location.
	entry.shop.save_store = FailingStore.new(PATH)
	station.leaving = true
	station._modal_changed(true)
	entry._travel("village")
	await create_timer(1.4).timeout
	check(entry.station == station and not station.leaving and station.player.controls_enabled,
		"Failed destination checkpoint returns control on station")
	check(entry.store.read_save(entry.shop).journey.location == "station", "Failed transition never commits destination")
	entry.shop.save_store = entry.store
	Input.action_press("ui_right")
	await _frames(24)
	Input.action_release("ui_right")
	await create_timer(1.5).timeout
	check(entry.station == null and entry.shop.visible and entry.shop.process_mode == Node.PROCESS_MODE_INHERIT, "Village exit fades into temporary shop destination")
	check(entry.store.read_save(entry.shop).journey.location == "shop", "Destination saved before scene is replaced")
	check(entry.shop.player.appearance == look, "Travel preserves customized hero")
	check(not Input.is_action_pressed("ui_right"), "Travel releases held movement input")
	entry.free()
	for suffix in ["", ".bak", ".tmp", ".bak.tmp"]:
		DirAccess.remove_absolute(PATH + suffix)
	print("Little Village Shop station: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
