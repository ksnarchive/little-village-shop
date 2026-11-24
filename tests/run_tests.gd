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
	_test_economy()
	await _test_shop()
	await _test_supplier()
	await _test_shelf_inventory()
	await _test_shelves()
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

func _test_economy() -> void:
	var storage := Inventory.new(CATALOG, 20)
	var economy := ShopEconomy.new(CATALOG, storage)
	var notifications := [0, 0]
	var on_stock_changed := func() -> void:
		notifications[0] += 1
		_check(economy.balance == 0 and storage.quantity(&"bread") == 20,
			"Stock observer sees the completed purchase and debit")
	var on_balance_changed := func(coins: int) -> void:
		notifications[1] += 1
		_check(coins == 0 and storage.quantity(&"bread") == 20,
			"Balance observer sees the completed delivery")
	storage.changed.connect(on_stock_changed)
	economy.balance_changed.connect(on_balance_changed)

	_check(economy.balance == 100, "New shop has 100 coins")
	_check(economy.buy(&"unknown", 1) == ShopEconomy.PurchaseResult.INVALID_PRODUCT,
		"Unknown product cannot be ordered")
	for amount in [0, -1]:
		_check(economy.buy(&"apple", amount) == ShopEconomy.PurchaseResult.INVALID_QUANTITY,
			"Quantity must be positive")
	_check(economy.buy(&"milk", 15) == ShopEconomy.PurchaseResult.INSUFFICIENT_FUNDS,
		"Reject an order that fits in storage but exceeds the balance")
	_check(economy.buy(&"milk", 9223372036854775807) == ShopEconomy.PurchaseResult.INSUFFICIENT_FUNDS,
		"An oversized quantity cannot overflow the cost into a credit")
	_check(economy.buy(&"apple", 21) == ShopEconomy.PurchaseResult.INSUFFICIENT_SPACE,
		"Reject a purchase that would exceed total storage capacity")
	_check(economy.balance == 100 and storage.total_units() == 0 and notifications == [0, 0],
		"Rejected orders leave balance and stock intact and emit no signals")
	_check(economy.buy(&"bread", 20) == ShopEconomy.PurchaseResult.SUCCESS,
		"A purchase may spend the exact balance and fill the exact remaining space")
	_check(notifications == [1, 1], "Successful purchase notifies stock and balance once")
	_check(economy.buy(&"apple", 1) == ShopEconomy.PurchaseResult.INSUFFICIENT_FUNDS,
		"Subsequent orders use the updated balance")
	_check(economy.balance == 0 and storage.total_units() == 20 and notifications == [1, 1],
		"Rejected repeat order leaves the completed purchase intact")
	storage.changed.disconnect(on_stock_changed)
	economy.balance_changed.disconnect(on_balance_changed)

	var larger_storage := Inventory.new(CATALOG, 120)
	larger_storage.add(&"apple", CATALOG.find(&"apple").max_stack_size)
	var second_shop := ShopEconomy.new(CATALOG, larger_storage)
	_check(second_shop.buy(&"apple", 1) == ShopEconomy.PurchaseResult.INSUFFICIENT_SPACE,
		"Purchase respects the product's stack limit even with free storage units")
	_check(second_shop.balance == 100 and larger_storage.total_units() == 99,
		"Rejected purchase against stack limit leaves both values intact")
	_check(second_shop.buy(&"milk", 1) == ShopEconomy.PurchaseResult.SUCCESS
		and second_shop.balance == 93 and larger_storage.quantity(&"milk") == 1,
		"Another product can be ordered after a rejected purchase")

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
	var camera: Camera2D = shop.get_node("Camera2D")
	var framing := camera.get_screen_center_position()
	_check(framing == Vector2(320, 180), "Camera frames the whole original room at spawn")
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
	_check(camera.get_screen_center_position() == framing,
		"Moving the shopkeeper keeps the north wall and doorway in frame")
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
	_check(menu.prompt_label.text == "E  Открыть кладовую", "Context prompt updates")
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
	_check(quantities.text == "С собой 1 | Склад 5" and not deposit.disabled, "Inventory signals refresh labels and buttons")
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

func _test_supplier() -> void:
	var scene: PackedScene = load("res://scenes/main.tscn")
	var shop := scene.instantiate()
	root.add_child(shop)
	await _frames(3)
	var player: Shopkeeper = shop.get_node("Player")
	var controller: InteractionController = player.get_node("InteractionController")
	var order_desk: Interactable = shop.get_node("OrderDesk")
	var storage: ShopStorage = shop.get_node("Storage")
	var menu: InventoryMenu = shop.get_node("InventoryUI")
	var supplier := menu.supplier_menu
	_check(menu.balance_label.text == "100 монет" and menu.balance_card.is_visible_in_tree(),
		"HUD shows starting balance before ordering")
	player.position = Vector2(380, 224)
	Input.action_press("ui_right")
	await _frames(18)
	Input.action_release("ui_right")
	_check(player.position.x >= 394.9 and player.position.x < 400,
		"Order desk preserves furniture collision")
	player.position = Vector2(392, 235)
	await _frames(3)
	_check(controller.target == null, "Side approach cannot order through desk collision")
	await _key(KEY_E)
	_check(menu.view == InventoryMenu.View.CLOSED, "E cannot open an obstructed order desk")
	player.position = Vector2(424, 263)
	await _frames(3)
	_check(controller.target == order_desk and menu.prompt_label.text == "E  Заказать товары",
		"Front approach shows order prompt")
	await _key(KEY_E)
	_check(menu.view == InventoryMenu.View.SUPPLIER and supplier.is_visible_in_tree(),
		"Physical E opens supplier menu")
	_check(not player.controls_enabled and not controller.enabled and not menu.inventory_content.visible,
		"Supplier menu blocks world input and shares the modal UI")
	_check(supplier.balance_label.text == "100 монет" and supplier.storage_label.text == "Склад  13 / 60",
		"Supplier menu displays balance and shared storage capacity")
	_check(supplier.rows_container.get_child_count() == 3, "Supplier lists all three catalog items")
	for item in CATALOG.items:
		var stock: Label = supplier.rows_container.get_node(String(item.id) + "/Row/Details/Stock")
		_check(stock.text.begins_with("%d за шт." % item.purchase_price), "Supplier displays catalog unit price")

	var apple_row := supplier.rows_container.get_node("apple/Row")
	var apple_less: Button = apple_row.get_node("Quantity/Less")
	var apple_more: Button = apple_row.get_node("Quantity/More")
	var apple_amount: Label = apple_row.get_node("Quantity/Amount")
	var apple_total: Label = apple_row.get_node("Total")
	var apple_buy: Button = apple_row.get_node("Buy")
	_check(apple_amount.text == "1" and apple_less.disabled, "Order starts with a minimum of one item")
	apple_more.pressed.emit()
	apple_more.pressed.emit()
	apple_less.pressed.emit()
	_check(apple_amount.text == "2" and apple_total.text == "6 монет", "Quantity controls update the subtotal")
	apple_buy.pressed.emit()
	_check(shop.economy.balance == 94 and storage.inventory.quantity(&"apple") == 8
		and shop.player_inventory.total_units() == 0, "Order delivers to storage and charges exactly six coins")
	_check(supplier.balance_label.text == "94 монет" and supplier.storage_label.text == "Склад  15 / 60"
		and supplier.message.text == "В кладовую: Яблоко × 2.", "Purchase refreshes the open menu")

	var milk_more: Button = supplier.rows_container.get_node("milk/Row/Quantity/More")
	var milk_buy: Button = supplier.rows_container.get_node("milk/Row/Buy")
	for index in range(13):
		milk_more.pressed.emit()
	milk_buy.pressed.emit()
	_check(supplier.message.text.contains("не хватает монет") and shop.economy.balance == 94
		and storage.inventory.quantity(&"milk") == 3, "Failed order reports low funds without any changes")
	storage.inventory.add(&"apple", 45)
	var bread_buy: Button = supplier.rows_container.get_node("bread/Row/Buy")
	bread_buy.pressed.emit()
	_check(supplier.message.text.contains("не хватает места") and shop.economy.balance == 94
		and storage.inventory.quantity(&"bread") == 4, "Failed order reports a full stockroom without any changes")
	await _key(KEY_ESCAPE)
	_check(menu.view == InventoryMenu.View.CLOSED and player.controls_enabled and controller.enabled,
		"Esc closes supplier menu and restores movement and interaction")
	_check(menu.balance_label.text == "94 монет" and menu.balance_card.is_visible_in_tree(),
		"World HUD shows updated balance after closing the menu")
	await _key(KEY_E)
	_check(apple_amount.text == "1", "Reopening supplier starts a fresh selection")
	await _key(KEY_I)
	_check(menu.view == InventoryMenu.View.CLOSED, "I closes supplier without opening a second menu")
	player.position = Vector2(208, 260)
	await _frames(3)
	await _key(KEY_E)
	_check(menu.view == InventoryMenu.View.STORAGE and menu.capacity_label.text.contains("60 / 60"),
		"Existing storage menu sees stock received from supplier")
	shop.queue_free()
	await process_frame

func _test_shelf_inventory() -> void:
	var shelf_scene: PackedScene = load("res://scenes/objects/shelf.tscn")
	var shelf: ShopShelf = shelf_scene.instantiate()
	shelf.capacity = 3
	root.add_child(shelf)
	var other: ShopShelf = shelf_scene.instantiate()
	root.add_child(other)
	var bag := Inventory.new(CATALOG, 4)
	bag.add(&"apple", 4)
	var notifications := [0, 0]
	bag.changed.connect(func() -> void: notifications[0] += 1)
	shelf.inventory.changed.connect(func() -> void: notifications[1] += 1)
	_check(shelf.fill_state() == ShopShelf.FillState.EMPTY and shelf.inventory.capacity == 3,
		"Shelf starts empty with its configured Inventory capacity")
	var before := bag.serialize()
	for amount in [-1, 0, 4, 5]:
		_check(not bag.transfer_to(shelf.inventory, &"apple", amount), "Reject invalid shelf deposit: %d" % amount)
	_check(not bag.transfer_to(shelf.inventory, &"unknown", 1), "Reject unknown shelf product")
	_check(bag.serialize() == before and shelf.inventory.total_units() == 0 and notifications == [0, 0],
		"Rejected shelf transfers preserve both inventories and emit no signals")
	_check(bag.transfer_to(shelf.inventory, &"apple", 2)
		and shelf.fill_state() == ShopShelf.FillState.PARTIAL, "Partial deposit changes shelf fill state")
	_check(bag.transfer_to(shelf.inventory, &"apple", 1)
		and shelf.fill_state() == ShopShelf.FillState.FULL, "Exact-capacity deposit fills shelf")
	_check(not bag.transfer_to(shelf.inventory, &"apple", 1), "Full shelf rejects another unit")
	_check(notifications == [2, 2] and other.inventory.total_units() == 0,
		"Each shelf has independent stock; successful transfers notify once per side")
	bag.add(&"bread", 3)
	_check(not shelf.inventory.transfer_to(bag, &"apple", 1), "Full bag rejects a shelf withdrawal")
	_check(bag.total_units() == 4 and shelf.inventory.total_units() == 3,
		"Rejected withdrawal preserves shelf and bag")
	bag.remove(&"bread", 3)
	_check(shelf.inventory.transfer_to(bag, &"apple", 3)
		and shelf.fill_state() == ShopShelf.FillState.EMPTY, "Returning all stock makes shelf empty again")
	_check(bag.quantity(&"apple") == 4 and not shelf.inventory.transfer_to(bag, &"apple", 1),
		"Round trip conserves goods and empty shelf cannot supply stock")
	shelf.queue_free()
	other.queue_free()
	var zero: ShopShelf = shelf_scene.instantiate()
	zero.capacity = 0
	root.add_child(zero)
	_check(not bag.transfer_to(zero.inventory, &"apple", 1) and zero.fill_state() == ShopShelf.FillState.EMPTY,
		"Zero-capacity shelf is safely empty")
	zero.queue_free()

	var limited_item: ItemData = CATALOG.items[0].duplicate()
	limited_item.max_stack_size = 2
	var limited_catalog := ItemCatalog.new()
	limited_catalog.items.assign([limited_item])
	var limited_shelf: ShopShelf = shelf_scene.instantiate()
	limited_shelf.catalog = limited_catalog
	root.add_child(limited_shelf)
	var limited_bag := Inventory.new(limited_catalog, 24)
	limited_shelf.inventory.add(&"apple", 1)
	limited_bag.add(&"apple", 2)
	_check(not limited_bag.transfer_to(limited_shelf.inventory, &"apple", 2),
		"Shelf respects per-product stack limits even when total capacity is free")
	_check(limited_bag.transfer_to(limited_shelf.inventory, &"apple", 1)
		and limited_shelf.inventory.quantity(&"apple") == 2, "Exact stack boundary is allowed")
	limited_shelf.queue_free()
	await process_frame

func _test_shelves() -> void:
	var scene: PackedScene = load("res://scenes/main.tscn")
	var shop := scene.instantiate()
	root.add_child(shop)
	await _frames(3)
	var player: Shopkeeper = shop.get_node("Player")
	var controller: InteractionController = player.get_node("InteractionController")
	var left: ShopShelf = shop.get_node("LeftShelf")
	var right: ShopShelf = shop.get_node("RightShelf")
	var menu: InventoryMenu = shop.get_node("InventoryUI")
	var shelf_menu := menu.shelf_menu
	var bag: Inventory = shop.player_inventory
	_check(left.inventory != right.inventory and left.inventory.total_units() == 0
		and right.inventory.total_units() == 0, "Both room shelves start empty with separate inventories")
	player.position = Vector2(208, 181)
	Input.action_press("ui_up")
	await _frames(18)
	Input.action_release("ui_up")
	_check(player.position.y >= 165.4 and player.position.y < 181,
		"Shelf preserves original furniture collision footprint")
	player.position = Vector2(208, 90)
	await _frames(3)
	await _key(KEY_E)
	_check(menu.view == InventoryMenu.View.CLOSED, "Cannot use shelf from out of interaction range")
	player.position = Vector2(170, 140)
	await _frames(3)
	_check(controller.target == null, "Side approach does not offer shelf interaction")
	player.position = Vector2(208, 180)
	await _frames(3)
	_check(controller.target == left and menu.prompt_label.text == "E  Выложить товары",
		"Front of shelf shows the interaction prompt")
	await _key(KEY_E)
	_check(menu.view == InventoryMenu.View.SHELF and shelf_menu.is_visible_in_tree()
		and not menu.inventory_content.visible and not menu.supplier_menu.visible,
		"Physical E opens only the selected shelf menu")
	_check(shelf_menu.title.text == "Яблочная полка" and shelf_menu.capacity_label.text.begins_with("Пусто"),
		"Menu names the selected shelf and shows its empty state")
	_check(not player.controls_enabled and not controller.enabled and menu.prompt_label.text.is_empty(),
		"Shelf menu blocks movement, interactions and world prompt")
	var start := player.position
	Input.action_press("ui_right")
	await _frames(5)
	Input.action_release("ui_right")
	await _key(KEY_E)
	_check(player.position == start and menu.view == InventoryMenu.View.SHELF,
		"World movement and repeated E cannot interfere with shelf menu")
	var row := shelf_menu.rows_container.get_node("apple/Row")
	var less: Button = row.get_node("Quantity/Less")
	var more: Button = row.get_node("Quantity/More")
	var amount: Label = row.get_node("Quantity/Amount")
	var deposit: Button = row.get_node("Deposit")
	var take: Button = row.get_node("Take")
	var stock_label: Label = row.get_node("Details/Stock")
	_check(shelf_menu.rows_container.get_child_count() == CATALOG.items.size(), "Shelf menu is built from catalog")
	_check(deposit.disabled and take.disabled and more.disabled and less.disabled,
		"Empty bag and shelf disable unavailable operations")
	# Simulate an external stock change while the menu is open.
	shop.storage.inventory.transfer_to(bag, &"apple", 6)
	_check(stock_label.text == "С собой 6  ·  На полке 0" and not deposit.disabled and not more.disabled,
		"Shelf UI observes the real bag rather than caching stock")
	more.pressed.emit()
	more.pressed.emit()
	less.pressed.emit()
	_check(amount.text == "2", "Shelf quantity stepper selects two units")
	deposit.pressed.emit()
	_check(bag.quantity(&"apple") == 4 and left.inventory.quantity(&"apple") == 2
		and right.inventory.total_units() == 0, "Stock button deposits selected quantity on only this shelf")
	_check(left.fill_state() == ShopShelf.FillState.PARTIAL and shelf_menu.fill_meter.value == 2
		and shelf_menu.capacity_label.text.contains("Полка 2 / 12") and stock_label.text == "С собой 4  ·  На полке 2",
		"Signals update fill meter, state, counts and capacities")
	take.pressed.emit()
	_check(bag.quantity(&"apple") == 6 and left.inventory.total_units() == 0,
		"Take button returns the selected quantity without duplication")
	for index in range(10):
		more.pressed.emit()
	_check(amount.text == "6" and more.disabled, "Quantity cannot exceed available bag stock")
	deposit.pressed.emit()
	_check(bag.total_units() == 0 and left.inventory.quantity(&"apple") == 6 and deposit.disabled,
		"Depositing whole stack empties bag and disables stock button")
	shop.storage.inventory.transfer_to(bag, &"bread", 4)
	shop.storage.inventory.transfer_to(bag, &"milk", 3)
	var bread_row := shelf_menu.rows_container.get_node("bread/Row")
	for index in range(3):
		bread_row.get_node("Quantity/More").pressed.emit()
	bread_row.get_node("Deposit").pressed.emit()
	var milk_row := shelf_menu.rows_container.get_node("milk/Row")
	milk_row.get_node("Quantity/More").pressed.emit()
	_check(milk_row.get_node("Quantity/More").disabled,
		"Quantity respects remaining shelf space shared across products")
	milk_row.get_node("Deposit").pressed.emit()
	_check(left.inventory.total_units() == 12 and left.fill_state() == ShopShelf.FillState.FULL
		and shelf_menu.capacity_label.text.begins_with("Заполнено") and shelf_menu.fill_meter.value == 12,
		"Mixed products fill the shelf and update full state")
	_check(milk_row.get_node("Deposit").disabled and bag.quantity(&"milk") == 1,
		"Full shelf disables depositing even with goods left in bag")
	milk_row.get_node("Deposit").pressed.emit()
	_check(left.inventory.total_units() == 12 and bag.quantity(&"milk") == 1
		and shelf_menu.message.text.contains("Не хватает"), "Stale or forced deposit revalidates atomically")
	bag.add(&"bread", 23)
	_check(take.disabled, "Full bag disables taking goods off shelf")
	var before := left.inventory.serialize()
	take.pressed.emit()
	_check(left.inventory.serialize() == before and bag.total_units() == 24,
		"Forced withdrawal into full bag preserves both inventories")
	bag.remove(&"bread", 23)
	_check(not take.disabled and amount.text == "1", "Freeing bag space enables withdrawal with a clamped selection")
	for index in range(5):
		more.pressed.emit()
	take.pressed.emit()
	_check(left.fill_state() == ShopShelf.FillState.PARTIAL and bag.quantity(&"apple") == 6,
		"Withdrawing from full shelf returns it to partial state")
	await _frames(3)
	_check(menu.panel.get_global_rect().end.x <= root.get_visible_rect().size.x
		and menu.panel.get_global_rect().end.y <= root.get_visible_rect().size.y
		and menu.panel.get_global_rect().position.x >= 0
		and menu.panel.get_global_rect().position.y >= 0, "Shelf panel fits the game's viewport")
	await _key(KEY_ESCAPE)
	_check(menu.view == InventoryMenu.View.CLOSED and player.controls_enabled and controller.enabled,
		"Esc closes shelf menu and restores world controls")
	deposit.pressed.emit()
	_check(bag.quantity(&"apple") == 6, "Hidden shelf controls cannot transfer goods")
	player.position = Vector2(432, 180)
	await _frames(3)
	await _key(KEY_E)
	_check(shelf_menu.title.text == "Голубая полка" and stock_label.text == "С собой 6  ·  На полке 0"
		and amount.text == "1", "Second shelf opens its own stock with reset quantities")
	_check(not left.inventory.changed.is_connected(shelf_menu._refresh)
		and right.inventory.changed.is_connected(shelf_menu._refresh), "Switching shelves releases previous stock subscription")
	deposit.pressed.emit()
	_check(right.inventory.quantity(&"apple") == 1 and left.inventory.quantity(&"apple") == 0,
		"Second shelf actions cannot alter the first shelf")
	menu.close_button.pressed.emit()
	_check(menu.view == InventoryMenu.View.CLOSED, "Close button dismisses shelf menu")
	await _key(KEY_E)
	await _key(KEY_I)
	_check(menu.view == InventoryMenu.View.CLOSED and not right.inventory.changed.is_connected(shelf_menu._refresh),
		"I closes shelf menu and detaches its inventory signal")
	await _key(KEY_I)
	_check(menu.view == InventoryMenu.View.BAG and not shelf_menu.is_visible_in_tree(), "Bag still opens independently after shelves")
	_check(shop.economy.balance == 100 and shop.storage.inventory.total_units() == 0,
		"Shelf movement conserves storage deliveries and never changes coins")
	shop.queue_free()
	await process_frame
