extends SceneTree
## Isolated real files under user://, real shop scenes, deterministic I/O failure boundary.
var checks: int = 0
var failures: int = 0
const TEST_PATH := "user://save_tests/slot.json"

class FailingStore extends SaveStore:
	var failure: String = ""
	func _write_file(target: String, contents: String) -> bool:
		if failure == "write":
			super._write_file(target, contents.left(20))
			return false
		if failure == "verify":
			return super._write_file(target, "{broken")
		return super._write_file(target, contents)
	func _copy_file(source: String, target: String) -> bool:
		if failure == "copy":
			return false
		return super._copy_file(source, target)
	func _replace_file(source: String, target: String) -> bool:
		if failure == "backup" and target.ends_with(".bak"):
			return false
		if failure == "replace" and not target.ends_with(".bak"):
			return false
		return super._replace_file(source, target)

func _initialize() -> void:
	_run.call_deferred()

func check(ok: bool, description: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL: " + description)

func shop_scene() -> Node2D:
	var shop: Node2D = load("res://scenes/main.tscn").instantiate()
	root.add_child(shop)
	shop.day.set_physics_process(false)
	shop.customers.arrivals_enabled = false
	return shop

func clean() -> void:
	for suffix in ["", ".bak", ".tmp", ".bak.tmp"]:
		if FileAccess.file_exists(TEST_PATH + suffix):
			DirAccess.remove_absolute(TEST_PATH + suffix)

func write_text(path: String, contents: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(contents)
	file.close()

func _run() -> void:
	DirAccess.make_dir_recursive_absolute("user://save_tests")
	clean()
	var store := SaveStore.new(TEST_PATH)
	var shop := shop_scene()
	var initial := store.capture(shop)
	check(not store.load_game(shop) and store.message.contains("пока нет"), "Missing save is explained")
	check(store.capture(shop) == initial, "Missing save changes nothing")
	check(store.save_game(shop), "Initial save writes real user file")
	check(FileAccess.file_exists(TEST_PATH), "Primary file exists")
	check(not FileAccess.file_exists(TEST_PATH + ".tmp"), "Temporary file promoted after success")
	check(store.load_game(shop), "Initial JSON save loads")
	check(store.capture(shop) == initial, "JSON round trip restores whole snapshot")
	await _days(store, shop)
	_failure_cases(store, shop)
	_invalid_data(store, shop)
	await _npcs_and_ui(store, shop)
	shop.free()
	await _entry_menu()
	clean()
	print("Little Village Shop saves: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

func _days(store: SaveStore, shop: Node2D) -> void:
	shop.save_store = store
	for number in range(1, 4):
		check(shop.economy.buy(&"apple", 2) == ShopEconomy.PurchaseResult.SUCCESS, "Day %d purchase" % number)
		shop.storage.inventory.transfer_to(shop.player_inventory, &"apple", 2)
		shop.player_inventory.transfer_to(shop.customers.shelves[0].inventory, &"apple", 1)
		var basket := Inventory.new(shop.CATALOG, 1)
		shop.customers.shelves[0].inventory.transfer_to(basket, &"apple", 1)
		check(shop.economy.sell(basket, &"apple"), "Day %d paid basket" % number)
		shop.storage.inventory.transfer_to(shop.customers.shelves[1].inventory, &"bread", 1)
		shop.day.advance_time(400)
		check(shop.day.phase == ShopDay.Phase.SUMMARY, "Day %d finished" % number)
		var summary := store.capture(shop)
		check(store.read_save(shop) == json_form(summary), "End-of-day autosave captures totals")
		shop.economy._balance = 0
		shop.player_inventory.remove(&"apple", 1)
		check(store.load_game(shop) and store.capture(shop) == summary, "Restore all money, goods and totals on day %d" % number)
		check(shop.inventory_ui.view == InventoryMenu.View.DAY_END and not shop.economy.transactions_enabled, "Loaded report is locked and transactions disabled")
		check(shop.day.report().revenue == 5 and shop.day.report().expenses == 6 and shop.day.report().profit == -1, "Daily report restored from saved accounting")
		check(shop.economy.balance == 100 - number and shop.economy.revenue == 5 * number and shop.economy.completed_sales == number, "Session money and sales survive multiple days")
		check(shop.day.start_next_day(), "Next morning starts once")
		var morning := store.capture(shop)
		check(store.read_save(shop) == json_form(morning) and shop.day.minute == 480 and shop.economy.day_expenses == 0, "Morning autosave resets only daily totals")
		check(store.load_game(shop) and store.capture(shop) == morning and shop.inventory_ui.view == InventoryMenu.View.CLOSED, "Morning restore refreshes menus")
		check(shop.inventory_ui.balance_label.text == "%d монет" % (100 - number) and shop.inventory_ui.clock_label.text.contains("08:00"), "Loaded HUD refreshes")
		check(not shop.day.paused and shop.player.controls_enabled, "Morning load resumes clock and controls")

func _failure_cases(store: SaveStore, shop: Node2D) -> void:
	var good := store.capture(shop)
	var primary := FileAccess.get_file_as_string(TEST_PATH)
	var failing := FailingStore.new(TEST_PATH)
	shop.economy.buy(&"milk", 1)
	for failure in ["write", "verify", "copy", "backup", "replace"]:
		failing.failure = failure
		check(not failing.save_game(shop), "Injected %s failure rejects save" % failure)
		check(FileAccess.get_file_as_string(TEST_PATH) == primary, "Failure %s preserves primary bytes" % failure)
		check(store.read_save(shop) == json_form(good), "Previous save still readable after %s failure" % failure)
	failing.failure = ""
	check(failing.save_game(shop), "Next successful save recovers from stale temporary files")
	var newer := store.capture(shop)
	check(store.read_save(shop) == json_form(newer), "Successful overwrite contains new state")
	write_text(TEST_PATH, "{broken")
	check(store.load_game(shop) and store.recovered and store.capture(shop) == good, "Corrupt primary falls back to validated previous generation")
	check(store.save_game(shop), "Can save after backup recovery")
	check(JSON.parse_string(FileAccess.get_file_as_string(TEST_PATH + ".bak")) == json_form(good), "Recovery never overwrites good backup with corrupt primary")
	DirAccess.remove_absolute(TEST_PATH)
	check(store.load_game(shop) and store.recovered, "Missing primary recovers backup after interrupted write")
	write_text(TEST_PATH + ".tmp", JSON.stringify(newer))
	check(store.read_save(shop) == json_form(good), "Uncommitted temporary file is never loaded")
	store.save_game(shop)

func _invalid_data(store: SaveStore, shop: Node2D) -> void:
	var good := store.capture(shop)
	clean()
	write_text(TEST_PATH, "{bad json")
	check(not store.load_game(shop) and store.message.contains("повреждено"), "Corrupt save without backup is explained")
	check(store.capture(shop) == good, "Corrupt load changes nothing")
	for version in [0, 2]:
		var data := good.duplicate(true)
		data.version = version
		write_text(TEST_PATH, JSON.stringify(data))
		write_text(TEST_PATH + ".bak", JSON.stringify(good))
		check(not store.load_game(shop) and store.message.contains("Версия"), "Unsupported version %d is rejected even with backup" % version)
		check(FileAccess.get_file_as_string(TEST_PATH) == JSON.stringify(data), "Unsupported save is not rewritten")
	for field in ["day", "minute", "phase", "economy", "bag", "storage", "shelves", "version"]:
		var data := good.duplicate(true)
		data.erase(field)
		check(not store.apply(data, shop) and store.capture(shop) == good, "Missing %s rejected atomically" % field)
	var invalid := good.duplicate(true)
	invalid.bag.items = {"apple": 999}
	check(not store.apply(invalid, shop), "Over-capacity inventory rejected")
	invalid = good.duplicate(true)
	invalid.shelves["UnknownShelf"] = invalid.shelves["LeftShelf"]
	invalid.shelves.erase("LeftShelf")
	check(not store.apply(invalid, shop), "Unknown shelf rejected without lost goods")
	for value in ["-1", "9223372036854775808", "1.5", "00", 100]:
		invalid = good.duplicate(true)
		invalid.economy.balance = value
		check(not store.apply(invalid, shop), "Invalid coin value rejected: %s" % str(value))
	invalid = good.duplicate(true)
	invalid.economy.balance = str(ShopEconomy.MAX_COINS)
	check(store.apply(invalid, shop) and store.save_game(shop) and store.load_game(shop) and shop.economy.balance == ShopEconomy.MAX_COINS, "64-bit coins survive JSON exactly")
	store.apply(good, shop)
	store.save_game(shop)

func _npcs_and_ui(store: SaveStore, shop: Node2D) -> void:
	shop.save_store = store
	shop.day.minute = 735.25
	shop.day._apply_phase()
	check(store.save_game(shop), "Fractional time saved during lunch")
	var good := store.capture(shop)
	var primary := FileAccess.get_file_as_string(TEST_PATH)
	var npc: ShopCustomer = shop.customers.spawn_customer()
	check(npc != null, "Real customer spawned")
	check(not store.save_game(shop) and FileAccess.get_file_as_string(TEST_PATH) == primary, "Active customer prevents save and preserves disk")
	shop.inventory_ui.open_pause()
	check(shop.inventory_ui.save_button.disabled and shop.inventory_ui.save_status.text.contains("гостей"), "Pause explains unsafe save and disables button")
	check(shop.day.paused and not shop.player.controls_enabled and shop.customers.process_mode == Node.PROCESS_MODE_DISABLED, "Pause stops clock, player and visitors")
	shop.inventory_ui.close_menu()
	# Construct a waiting customer with a real unpaid one-unit basket.
	npc.basket.add(&"apple", 1)
	shop.customers.join_checkout(npc)
	check(not store.save_game(shop), "Queue and unpaid goods prevent saving")
	for index in range(3):
		check(store.load_game(shop), "Repeated load %d succeeds" % index)
		check(shop.customers.is_empty() and shop.customers.get_child_count() == 0, "Repeated load leaves no duplicate NPCs")
		check(store.capture(shop) == good, "Repeated load replaces rather than adds goods, money and totals")
	check(shop.day.phase == ShopDay.Phase.RUSH and shop.day.minute == 735.25 and shop.customers.business_open and shop.customers.arrival_interval == 3, "Loaded time restores rush admission policy")
	shop.inventory_ui.open_pause()
	check(not shop.inventory_ui.save_button.disabled, "Empty shop allows manual save")
	shop.inventory_ui.save_button.pressed.emit()
	check(shop.inventory_ui.save_status.text.contains("Игра сохранена"), "Manual button writes save and confirms success")
	await process_frame
	check(shop.inventory_ui.panel.size.x <= 640 and shop.inventory_ui.panel.size.y <= 360, "Pause panel fits base viewport")
	shop.inventory_ui.close_menu()
	await key(KEY_ESCAPE)
	check(shop.inventory_ui.view == InventoryMenu.View.PAUSE, "Physical Esc opens pause from world")
	await key(KEY_ESCAPE)
	check(shop.inventory_ui.view == InventoryMenu.View.CLOSED, "Physical Esc closes pause")
	await key(KEY_I)
	check(shop.inventory_ui.view == InventoryMenu.View.BAG, "Existing I opens bag")
	await key(KEY_ESCAPE)
	check(shop.inventory_ui.view == InventoryMenu.View.CLOSED, "Esc preserves existing bag close behavior")
	var failing := FailingStore.new(TEST_PATH)
	failing.failure = "write"
	shop.save_store = failing
	var last_good := FileAccess.get_file_as_string(TEST_PATH)
	shop.day.advance_time(400)
	check(shop.day.phase == ShopDay.Phase.SUMMARY and shop.inventory_ui.report_save_status.text.contains("Не удалось"), "Autosave failure is visible on report")
	check(FileAccess.get_file_as_string(TEST_PATH) == last_good, "Failed end-of-day autosave preserves last valid save")
	await process_frame
	check(shop.inventory_ui.panel.size.y <= 360, "Report with autosave failure fits viewport")
	shop.day.start_next_day()
	check(shop.inventory_ui.save_notice.text.contains("Не удалось"), "Failed morning autosave is visible on HUD")
	check(FileAccess.get_file_as_string(TEST_PATH) == last_good, "Failed morning autosave preserves last valid save")
	shop.save_store = store

func key(code: Key) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = true
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	await process_frame
	event = event.duplicate()
	event.pressed = false
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	await process_frame

func _entry_menu() -> void:
	var entry: Node = load("res://scenes/start.tscn").instantiate()
	# Inject before ready: never read or write the player's real slot in tests.
	entry.store = SaveStore.new(TEST_PATH)
	root.add_child(entry)
	entry.shop.save_store = entry.store
	entry.refresh()
	await process_frame
	check(not entry.continue_button.disabled and entry.menu.visible, "Start menu enables Continue for valid save")
	check(entry.shop.process_mode == Node.PROCESS_MODE_DISABLED, "Preview cannot advance simulation behind menu")
	var bytes := FileAccess.get_file_as_string(TEST_PATH)
	entry.request_new_game()
	check(entry.confirm_button.visible and entry.cancel_button.has_focus(), "Existing save requires confirmation with Cancel focused")
	check(FileAccess.get_file_as_string(TEST_PATH) == bytes, "New game request does not delete save")
	entry.cancel_button.pressed.emit()
	check(entry.continue_button.visible and FileAccess.get_file_as_string(TEST_PATH) == bytes, "Cancel preserves existing save")
	entry.continue_button.pressed.emit()
	check(not entry.menu.visible and entry.shop.day.phase == ShopDay.Phase.RUSH, "Continue restores game and hides title")
	entry.free()
	entry = load("res://scenes/start.tscn").instantiate()
	entry.store = SaveStore.new(TEST_PATH)
	root.add_child(entry)
	entry.shop.save_store = entry.store
	entry.refresh()
	entry.request_new_game()
	entry.confirm_button.pressed.emit()
	check(entry.shop.day.day_number == 1 and entry.shop.day.minute == 480 and entry.shop.economy.balance == 100, "Confirmed new game starts fresh")
	check(entry.shop.player_inventory.total_units() == 0 and entry.shop.storage.inventory.total_units() == 13 and entry.shop.customers.is_empty(), "New game has demo goods and no duplicate objects")
	check(entry.store.read_save(entry.shop).day == 1, "Confirmed new game replaces slot")
	entry.free()

func json_form(data: Dictionary) -> Dictionary:
	# Godot dictionary equality distinguishes integer and JSON floating-point variants.
	return JSON.parse_string(JSON.stringify(data))
