extends SceneTree
## Dependency-free tests: run after the editor import populates the class cache.

const CATALOG: ItemCatalog = preload("res://data/item_catalog.tres")
var _failures: int = 0
var _checks: int = 0

func _initialize() -> void:
	_run.call_deferred()

func _check(condition: bool, description: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		push_error("FAIL: " + description)

func _run() -> void:
	_test_products()
	_test_inventory()
	_test_serialization()
	await _test_shop()
	print("Little Village Shop: %d checks, %d failures" % [_checks, _failures])
	quit(0 if _failures == 0 else 1)

func _test_products() -> void:
	_check(CATALOG.is_valid(), "Catalog has valid, unique product IDs")
	_check(CATALOG.items.size() == 3, "Three starting products")
	for specification in [[&"apple", 3, 5], [&"bread", 5, 9], [&"milk", 7, 12]]:
		var item := CATALOG.find(specification[0])
		_check(item != null, "Product exists: " + String(specification[0]))
		_check(item.purchase_price == specification[1] and item.selling_price == specification[2], "Correct integer prices")
		_check(item.icon != null, "Original product icon exists")
	_check(CATALOG.find(&"unknown") == null, "Unknown ID rejected")
	var invalid: ItemData = CATALOG.items[0].duplicate()
	invalid.id = &"bad id"
	_check(not invalid.is_valid(), "Malformed ID rejected")
	invalid.id = &"valid_id"
	invalid.max_stack_size = 0
	_check(not invalid.is_valid(), "Invalid stack limit rejected")
	invalid.max_stack_size = 2
	invalid.purchase_price = -1
	_check(not invalid.is_valid(), "Negative money rejected")
	var duplicate_catalog := ItemCatalog.new()
	duplicate_catalog.items.assign([CATALOG.items[0], CATALOG.items[0]])
	_check(not duplicate_catalog.is_valid(), "Duplicate catalog IDs rejected")
	var extra: ItemData = CATALOG.items[0].duplicate()
	extra.id = &"turnip"
	extra.display_name = "Turnip"
	extra.max_stack_size = 2
	var extended := ItemCatalog.new()
	extended.items.assign(CATALOG.items)
	extended.items.append(extra)
	var inventory := Inventory.new(extended, 10)
	_check(extended.is_valid() and inventory.add(&"turnip", 2), "New data-only product works")
	_check(not inventory.add(&"turnip", 1), "Per-product stack limit enforced")

func _test_inventory() -> void:
	var source := Inventory.new(CATALOG, 10)
	var target := Inventory.new(CATALOG, 3)
	var signals := [0, 0]
	source.changed.connect(func() -> void: signals[0] += 1)
	target.changed.connect(func() -> void: signals[1] += 1)
	_check(source.add(&"apple", 4), "Add stock")
	_check(source.quantity(&"apple") == 4 and source.total_units() == 4, "Quantities match")
	for amount in [0, -1, 11]:
		_check(not source.add(&"apple", amount), "Reject invalid add: %d" % amount)
	for amount in [0, -1, 5]:
		_check(not source.remove(&"apple", amount), "Reject invalid removal: %d" % amount)
	_check(not source.add(&"unknown", 1), "Reject unknown product")
	_check(not source.remove(&"unknown", 1), "Cannot remove an unknown product")
	_check(not source.transfer_to(target, &"apple", -1), "Cannot transfer a negative amount")
	_check(not source.transfer_to(target, &"apple", 0), "Cannot transfer zero units")
	_check(not source.transfer_to(target, &"milk", 1), "Cannot transfer unavailable stock")
	_check(not source.transfer_to(source, &"apple", 1), "Reject self-transfer")
	_check(not source.transfer_to(null, &"apple", 1), "Reject missing destination")
	_check(not source.transfer_to(target, &"apple", 4), "Reject capacity overflow atomically")
	_check(source.quantity(&"apple") == 4 and target.total_units() == 0, "Failed transfer preserves both sides")
	_check(signals == [1, 0], "Rejected changes emit no notifications")
	source.changed.connect(func() -> void:
		_check(source.quantity(&"apple") == 1 and target.quantity(&"apple") == 3,
			"Observer sees both completed sides of the transfer"))
	_check(source.transfer_to(target, &"apple", 3), "Successful transfer")
	_check(signals == [2, 1], "One notification per changed inventory")
	_check(not target.add(&"bread", 1), "Capacity shared by all products")
	_check(target.remove(&"apple", 3) and target.quantity(&"apple") == 0, "Remove entire stack")
	_check(not target.remove(&"apple", 1), "Cannot make stock negative")
	_check(not Inventory.new(CATALOG, 0).add(&"apple", 1), "Zero capacity stays empty")

func _test_serialization() -> void:
	var inventory := Inventory.new(CATALOG, 10)
	inventory.add(&"apple", 3)
	inventory.add(&"milk", 2)
	var exported := inventory.serialize()
	exported["items"]["apple"] = 99
	_check(inventory.quantity(&"apple") == 3, "Serialized dictionary is an independent copy")
	var restored := Inventory.new(CATALOG, 10)
	var decoded: Dictionary = JSON.parse_string(JSON.stringify(inventory.serialize()))
	_check(restored.restore(decoded), "JSON whole-number quantities accepted")
	_check(restored.serialize() == inventory.serialize(), "JSON round-trip preserves stock")
	for invalid in [{}, {"items": []}, {"items": {"unknown": 1}},
		{"items": {"apple": -1}}, {"items": {"apple": 0}}, {"items": {"apple": 1.5}},
		{"items": {"apple": true}}, {"items": {"apple": "2"}}, {"items": {"apple": INF}},
		{"items": {"apple": 11}}, {"items": {"apple": 6, "milk": 5}}, {"items": {1: 2}}]:
		_check(not restored.restore(invalid), "Malformed serialized inventory rejected")
		_check(restored.serialize() == inventory.serialize(), "Rejected restore preserves previous inventory")
	_check(restored.restore({"items": {}}) and restored.total_units() == 0, "Empty inventory restores")

func _key(code: Key) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = true
	Input.parse_input_event(event)
	event = event.duplicate()
	event.pressed = false
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	await _frames(2)

func _frames(count: int) -> void:
	for index in range(count):
		await physics_frame

func _test_shop() -> void:
	var scene: PackedScene = load("res://scenes/main.tscn")
	var shop := scene.instantiate()
	root.add_child(shop)
	await _frames(3)
	var player: Shopkeeper = shop.get_node("Player")
	var controller: InteractionController = player.get_node("InteractionController")
	var storage: ShopStorage = shop.get_node("Storage")
	var menu: InventoryMenu = shop.get_node("InventoryUI")
	_check(player is CharacterBody2D, "Existing player scene instantiates")
	_check(storage.inventory.total_units() == 13, "Storage has demo stock")
	controller.refresh_target()
	_check(controller.target == null, "Storage out of range from spawn")
	await _key(KEY_E)
	_check(menu.view == InventoryMenu.View.CLOSED, "E out of range does nothing")
	var start := player.position
	Input.action_press("ui_right")
	await _frames(8)
	Input.action_release("ui_right")
	_check(player.position.x > start.x, "Arrow movement remains functional")
	start = player.position
	var physical := InputEventKey.new()
	physical.physical_keycode = KEY_D
	physical.keycode = KEY_G # Deliberately different logical key (alternate layout).
	physical.pressed = true
	Input.parse_input_event(physical)
	Input.flush_buffered_events()
	await _frames(8)
	physical = physical.duplicate()
	physical.pressed = false
	Input.parse_input_event(physical)
	Input.flush_buffered_events()
	_check(player.position.x > start.x, "Physical WASD works independently of logical layout")
	player.position = Vector2(155, 180)
	Input.action_press("ui_left")
	await _frames(18)
	Input.action_release("ui_left")
	_check(player.position.x >= 148.9 and player.position.x < 155, "Wall collision blocks the player")
	player.position = Vector2(260, 224)
	Input.action_press("ui_left")
	await _frames(18)
	Input.action_release("ui_left")
	_check(player.position.x >= 244.9 and player.position.x < 260, "Storage scene preserves furniture collision")
	var unreachable := Interactable.new()
	unreachable.position = Vector2(120, 180)
	shop.add_child(unreachable)
	player.position = Vector2(152, 180)
	await _frames(2)
	controller.refresh_target()
	_check(controller.target == null, "Interaction cannot reach through walls")
	unreachable.queue_free()
	player.position = Vector2(208, 260)
	await _frames(3)
	controller.refresh_target()
	_check(controller.target == storage, "Storage reachable from front")
	_check(menu.prompt_label.text == "E  Open storage", "Context prompt updates")
	await _key(KEY_E)
	_check(menu.view == InventoryMenu.View.STORAGE and menu.panel.visible, "Physical E opens storage")
	_check(not player.controls_enabled and not controller.enabled, "Menu blocks world input")
	start = player.position
	Input.action_press("ui_right")
	await _frames(5)
	Input.action_release("ui_right")
	_check(player.position == start, "Player stays still while using menu")
	var apple_row := menu.rows_container.get_child(0)
	var take: Button = apple_row.get_child(3)
	var deposit: Button = apple_row.get_child(4)
	_check(not take.disabled and deposit.disabled, "Stock controls reflect available goods")
	take.pressed.emit()
	_check(shop.player_inventory.quantity(&"apple") == 1 and storage.inventory.quantity(&"apple") == 5, "Storage button transfers real stock")
	var quantities: Label = apple_row.get_child(2)
	_check(quantities.text == "Bag 1 | Stock 5" and not deposit.disabled, "Inventory signals refresh labels and buttons")
	deposit.pressed.emit()
	_check(shop.player_inventory.quantity(&"apple") == 0 and storage.inventory.quantity(&"apple") == 6, "Return goods without duplication")
	await _key(KEY_ESCAPE)
	_check(menu.view == InventoryMenu.View.CLOSED and player.controls_enabled, "Esc closes menu and restores controls")
	await _key(KEY_I)
	_check(menu.view == InventoryMenu.View.BAG and not take.visible, "Physical I opens bag without remote storage access")
	shop.player_inventory.add(&"milk", 1)
	var milk_quantities: Label = menu.rows_container.get_child(2).get_child(2)
	_check(milk_quantities.text == "x 1", "Bag UI reacts to inventory changes")
	await _key(KEY_I)
	_check(menu.view == InventoryMenu.View.CLOSED, "I closes bag")
	shop.queue_free()
	await process_frame
