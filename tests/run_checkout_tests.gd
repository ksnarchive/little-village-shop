extends SceneTree
## Full stock-to-money cycle, adversarial sale calls, real routes and modal input.
const CATALOG: ItemCatalog = preload("res://data/item_catalog.tres")
var _checks: int = 0
var _failures: int = 0
var _motion_ok: bool = true
var _conservation_ok: bool = true
var _separation_ok: bool = true
var _expected_goods: int = 13

func _initialize() -> void:
	_run.call_deferred()

func _check(condition: bool, description: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		push_error("FAIL: " + description)

func _run() -> void:
	_test_sale_model()
	await _test_cycle_and_queue()
	await _test_incoming_customer()
	_check(_motion_ok, "Every customer moves continuously without furniture collisions")
	_check(_conservation_ok, "Every frame conserves purchased/demo goods plus completed sales")
	_check(_separation_ok, "Paid departure and queue advance keep NPC bodies apart")
	print("Little Village Shop checkout: %d checks, %d failures" % [_checks, _failures])
	quit(0 if _failures == 0 else 1)

func _copy_catalog() -> ItemCatalog:
	var copy := ItemCatalog.new()
	for item in CATALOG.items:
		copy.items.append(item.duplicate())
	return copy

func _test_sale_model() -> void:
	var storage := Inventory.new(CATALOG, 60)
	var economy := ShopEconomy.new(CATALOG, storage)
	var basket := Inventory.new(CATALOG, 1)
	var notifications := [0, 0, 0]
	basket.changed.connect(func() -> void: notifications[0] += 1)
	economy.balance_changed.connect(func(_value: int) -> void: notifications[1] += 1)
	economy.sales_changed.connect(func(_revenue: int, _count: int) -> void: notifications[2] += 1)
	_check(economy.revenue == 0 and economy.completed_sales == 0, "Sales counters start at zero")
	_check(not economy.sell(null, &"apple") and not economy.sell(basket, &"apple"), "Missing or empty basket rejected")
	basket.add(&"apple", 1)
	notifications[0] = 0
	_check(not economy.sell(basket, &"unknown") and not economy.sell(basket, &"bread"), "Unknown/mismatched goods rejected")
	_check(notifications == [0, 0, 0] and basket.quantity(&"apple") == 1 and economy.balance == 100,
		"Rejected sales emit nothing and preserve all state")
	var foreign_catalog := _copy_catalog()
	var foreign_basket := Inventory.new(foreign_catalog, 1)
	foreign_basket.add(&"apple", 1)
	_check(not economy.sell(foreign_basket, &"apple"), "Mismatched catalog rejected")
	var large_basket := Inventory.new(CATALOG, 3)
	large_basket.add(&"apple", 2)
	_check(not economy.sell(large_basket, &"apple"), "Ambiguous multi-unit baskets rejected")
	var observed := [true]
	var on_basket := func() -> void:
		observed[0] = (basket.total_units() == 0 and economy.balance == 105
			and economy.revenue == 5 and economy.completed_sales == 1)
	basket.changed.connect(on_basket)
	_check(economy.sell(basket, &"apple"), "Sale succeeds using selling price")
	_check(observed[0] and notifications == [1, 1, 1], "Basket observer sees complete money, stock and counters")
	_check(not economy.sell(basket, &"apple") and economy.balance == 105, "Same basket cannot pay twice")
	basket.changed.disconnect(on_basket)

	var local_catalog := _copy_catalog()
	var item := local_catalog.find(&"apple")
	var local_basket := Inventory.new(local_catalog, 1)
	var local_economy := ShopEconomy.new(local_catalog, Inventory.new(local_catalog, 60))
	local_basket.add(&"apple", 1)
	item.selling_price = -1
	_check(not local_economy.sell(local_basket, item.id), "Negative selling price rejected")
	item.selling_price = ShopEconomy.MAX_COINS
	_check(not local_economy.sell(local_basket, item.id), "Balance overflow rejected without losing goods")
	item.selling_price = 5
	local_economy._revenue = ShopEconomy.MAX_COINS
	_check(not local_economy.sell(local_basket, item.id), "Revenue overflow rejected")
	local_economy._revenue = 0
	local_economy._completed_sales = ShopEconomy.MAX_COINS
	_check(not local_economy.sell(local_basket, item.id), "Sale counter overflow rejected")
	local_economy._completed_sales = 0
	item.selling_price = 0
	_check(local_economy.sell(local_basket, item.id) and local_economy.completed_sales == 1
		and local_economy.revenue == 0 and local_economy.balance == 100, "Zero-price sale completes without invented coins")

	var extra := Inventory.new(CATALOG, 1)
	extra.add(&"milk", 1)
	var reentrant := [true]
	var on_reentrant := func(_value: int) -> void: reentrant[0] = economy.sell(extra, &"milk")
	economy.balance_changed.connect(on_reentrant)
	# Previous observer intentionally described only the first sale; use a fresh basket.
	var second := Inventory.new(CATALOG, 1)
	second.add(&"bread", 1)
	_check(economy.sell(second, &"bread") and not reentrant[0] and extra.total_units() == 1,
		"Reentrant sale of another basket is rejected during notifications")
	economy.balance_changed.disconnect(on_reentrant)
	_check(economy.revenue == 14 and economy.completed_sales == 2, "Revenue is gross proceeds, not purchase profit")

func _shop() -> Node2D:
	var scene: PackedScene = load("res://scenes/main.tscn")
	var shop: Node2D = scene.instantiate()
	root.add_child(shop)
	shop.day.advance_time(60.0 / ShopDay.MINUTES_PER_SECOND)
	shop.day.set_physics_process(false)
	shop.customers.arrivals_enabled = false
	shop.customers.rng.seed = 47
	_expected_goods = 13
	return shop

func _step(shop: Node2D) -> void:
	var before: Dictionary = {}
	for customer in shop.customers.get_children():
		before[customer] = customer.position
	await physics_frame
	var goods: int = shop.storage.inventory.total_units() + shop.player_inventory.total_units()
	for shelf in shop.customers.shelves:
		goods += shelf.inventory.total_units()
	var customers: Array[Node] = shop.customers.get_children()
	for customer in customers:
		goods += customer.basket.total_units()
		if before.has(customer):
			_motion_ok = _motion_ok and customer.position.distance_to(before[customer]) <= ShopCustomer.SPEED / 60.0 + 0.01
		_motion_ok = _motion_ok and customer.get_slide_collision_count() == 0
		for other in customers:
			if other != customer:
				_separation_ok = _separation_ok and customer.position.distance_to(other.position) >= 12.9
	_conservation_ok = _conservation_ok and goods + shop.economy.completed_sales == _expected_goods

func _until_waiting(shop: Node2D, customer: ShopCustomer) -> bool:
	for frame in range(2000):
		if customer.state == ShopCustomer.State.WAITING_AT_CHECKOUT:
			return true
		await _step(shop)
	return false

func _settle(shop: Node2D) -> bool:
	for frame in range(2000):
		if not shop.customers.checkout_busy():
			return true
		await _step(shop)
	return false

func _key(code: Key) -> void:
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

func _coin_effects(ui: InventoryMenu) -> Array[Node]:
	return ui.get_node("Root").get_children().filter(func(node: Node) -> bool:
		return node.get_script() == preload("res://scripts/coin_effect.gd"))

func _test_cycle_and_queue() -> void:
	var shop := _shop()
	await physics_frame
	var flow: CustomerFlow = shop.customers
	var ui: InventoryMenu = shop.inventory_ui
	var menu := ui.checkout_menu
	var shelf: ShopShelf = shop.get_node("LeftShelf")
	_check(shop.economy.buy(&"apple", 4) == ShopEconomy.PurchaseResult.SUCCESS, "Buy four apples into storage")
	_expected_goods += 4
	_check(shop.economy.balance == 88 and shop.storage.inventory.quantity(&"apple") == 10,
		"Purchase deducts 12 coins and delivers stock")
	_check(shop.storage.inventory.transfer_to(shop.player_inventory, &"apple", 4), "Storage to bag")
	_check(shop.player_inventory.transfer_to(shelf.inventory, &"apple", 4), "Bag to shelf")
	var original: Array[ShopCustomer] = []
	for index in range(3):
		var customer := flow.spawn_customer()
		original.append(customer)
		_check(await _until_waiting(shop, customer), "Shelf to NPC basket to checkout")
	_check(flow.spawn_customer() == null, "Full queue prevents new arrivals")
	_check(not flow.serve_customer(original[1]) and not flow.serve_customer(null), "Only queue head can be served")
	_check(shop.economy.balance == 88 and shop.economy.completed_sales == 0, "Waiting/out-of-order calls never credit money")

	shop.player.position = Vector2(320, 260)
	shop.interactions.refresh_target()
	await _key(KEY_E)
	_check(ui.view == InventoryMenu.View.CLOSED, "Checkout E is range limited")
	shop.player.position = Vector2(208, 290)
	await physics_frame
	shop.interactions.refresh_target()
	_check(shop.interactions.target == null, "Counter blocks interaction ray from back")
	shop.player.position = Vector2(246, 260)
	await physics_frame
	shop.interactions.refresh_target()
	_check(shop.interactions.target == shop.get_node("Checkout"), "Right counter front selects checkout beside storage")
	await _key(KEY_E)
	_check(ui.view == InventoryMenu.View.CHECKOUT and not shop.player.controls_enabled
		and not shop.interactions.enabled, "Physical E opens checkout and blocks world/player input")
	_check(menu._customer == original[0] and menu.product_label.text.contains("Яблоко")
		and menu.product_label.text.contains("5 монет") and not menu.serve_button.disabled,
		"Panel shows queue head, catalog icon, selling price and enabled service")
	await process_frame
	var rect := ui.panel.get_global_rect()
	_check(rect.position.x >= 0 and rect.position.y >= 0 and rect.end.x <= 640 and rect.end.y <= 360,
		"Checkout panel fits 640x360")
	var before: Vector2 = shop.player.position
	Input.action_press("ui_right")
	for frame in range(10):
		await _step(shop)
	Input.action_release("ui_right")
	_check(shop.player.position == before, "Checkout blocks player movement")
	var timer: float = flow._arrival_time
	flow.arrivals_enabled = true
	for frame in range(20):
		await _step(shop)
	_check(flow._arrival_time == timer, "Checkout pauses automatic arrival timer")

	var atomic := [true, 0, 0]
	var observe := func() -> void:
		atomic[1] += 1
		atomic[0] = atomic[0] and original[0].basket.total_units() == 0 and original[0].state == ShopCustomer.State.LEAVING
		atomic[0] = atomic[0] and flow.first_customer() == original[1] and shop.economy.balance == 93
		atomic[0] = atomic[0] and shop.economy.revenue == 5 and shop.economy.completed_sales == 1
		if flow.serve_customer(original[0]) or flow.serve_customer(original[1]):
			atomic[2] += 1
	original[0].basket.changed.connect(observe)
	var on_balance := func(_value: int) -> void: observe.call()
	var on_sales := func(_revenue: int, _count: int) -> void: observe.call()
	var on_queue := func(_count: int) -> void: observe.call()
	shop.economy.balance_changed.connect(on_balance)
	shop.economy.sales_changed.connect(on_sales)
	flow.queue_changed.connect(on_queue)
	menu.serve_button.pressed.emit()
	_check(atomic[0] and atomic[1] == 4 and atomic[2] == 0,
		"All stock/money/stat/queue observers see committed sale and cannot reenter")
	shop.economy.balance_changed.disconnect(on_balance)
	shop.economy.sales_changed.disconnect(on_sales)
	flow.queue_changed.disconnect(on_queue)
	_check(menu.message.text.contains("Продано: Яблоко!") and menu.message.text.contains("+5"), "Success feedback names product and coins")
	_check(ui.balance_label.text == "93 монет" and menu.balance_label.text.contains("93")
		and ui.sales_label.text.contains("Продаж 1"), "All balance/counter views update from signals")
	_check(_coin_effects(ui).size() == 1 and _coin_effects(ui)[0].mouse_filter == Control.MOUSE_FILTER_IGNORE,
		"One nonblocking coin effect plays for a successful sale")
	var balance: int = shop.economy.balance
	menu.serve_button.pressed.emit()
	_check(shop.economy.balance == balance and not flow.serve_customer(original[0]), "Double click and stale identity cannot create extra sales")
	_check(await _settle(shop), "Paid visitor exits and next queue positions settle while checkout stays open")
	_check(_coin_effects(ui).is_empty(), "Coin effect cleans itself up after its short animation")
	_check(not is_instance_valid(original[0]), "Paid NPC removed only after walking to exit")
	for index in range(flow.waiting.size()):
		_check(flow.waiting[index].position.distance_to(CustomerFlow.QUEUE_POSITIONS[index]) < 0.2,
			"Remaining queue advances continuously to freed slot")
	_check(menu._customer == original[1] and not menu.serve_button.disabled, "Next settled customer becomes serviceable in same menu")
	menu.serve_button.pressed.emit()
	_check(await _settle(shop), "Second paid customer exits")
	menu.serve_button.pressed.emit()
	_check(await _settle(shop), "Third paid customer exits")
	_check(flow.waiting.is_empty() and menu.serve_button.disabled and menu._customer == null,
		"Empty queue has clear disabled service state")
	_check(shop.economy.balance == 103 and shop.economy.revenue == 15 and shop.economy.completed_sales == 3,
		"Full cycle: 100 - 4*3 purchase + 3*5 selling, gross revenue 15")
	_check(shelf.inventory.quantity(&"apple") == 1 and shop.player_inventory.total_units() == 0,
		"Only sold units consumed; remaining stock intact")
	await _key(KEY_ESCAPE)
	_check(ui.view == InventoryMenu.View.CLOSED and shop.player.controls_enabled and not flow.service_menu_open,
		"Esc restores world movement and customer arrivals")
	for frame in range(450):
		await _step(shop)
	_check(is_instance_valid(flow.active_customer), "Automatic arrivals resume after queue places free")
	var newcomer: ShopCustomer = flow.active_customer
	_check(await _until_waiting(shop, newcomer), "New visitor uses the freed first checkout slot")
	await _key(KEY_E)
	await _key(KEY_I)
	_check(ui.view == InventoryMenu.View.CLOSED, "I closes checkout")
	ui.open_checkout()
	ui.close_button.pressed.emit()
	_check(ui.view == InventoryMenu.View.CLOSED, "Close button dismisses checkout")
	balance = shop.economy.balance
	menu.serve_button.pressed.emit()
	_check(shop.economy.balance == balance and newcomer.basket.total_units() == 1, "Closed menu ignores stale button signal")
	shop.queue_free()
	await process_frame
	shop = _shop()
	_check(shop.economy.revenue == 0 and shop.economy.completed_sales == 0 and shop.economy.balance == 100,
		"Restart resets session sales counters and economy")
	shop.queue_free()
	await process_frame

func _test_incoming_customer() -> void:
	var shop := _shop()
	await physics_frame
	var flow: CustomerFlow = shop.customers
	var shelf: ShopShelf = shop.get_node("RightShelf")
	shop.storage.inventory.transfer_to(shelf.inventory, &"milk", 3)
	var first := flow.spawn_customer()
	_check(await _until_waiting(shop, first), "Milk customer reaches checkout")
	var incoming := flow.spawn_customer()
	for frame in range(1500):
		if incoming.state == ShopCustomer.State.MOVING_TO_CHECKOUT and incoming.position.x < 310:
			break
		await _step(shop)
	_check(incoming.state == ShopCustomer.State.MOVING_TO_CHECKOUT, "Another basket is already en route when sale begins")
	shop.inventory_ui.open_checkout()
	_check(not flow.serve_customer(first), "Incoming visit cannot cross a paid departure")
	_check(await _until_waiting(shop, incoming), "Incoming visitor finishes approaching while checkout is open")
	_check(flow.serve_customer(first), "Service resumes as soon as incoming visit joins queue")
	_check(await _settle(shop), "Departure finishes and next visitor advances")
	_check(incoming.state == ShopCustomer.State.WAITING_AT_CHECKOUT, "Next visitor settles during checkout modal")
	_check(shop.economy.balance == 112 and shop.economy.revenue == 12 and shop.economy.completed_sales == 1,
		"Milk sale uses catalog selling price 12")
	shop.inventory_ui.close_menu()
	_check(await _until_waiting(shop, incoming), "Incoming visitor remains at the advanced queue position")
	_check(incoming.position.distance_to(CustomerFlow.QUEUE_POSITIONS[0]) < 0.2 and flow.waiting.size() == 1,
		"No stale checkout slot or duplicate queue admission")
	_check(flow.serve_customer(incoming), "Incoming visitor can also complete a sale")
	_check(await _settle(shop), "Second milk departure completes without menu")
	shop.queue_free()
	await process_frame
