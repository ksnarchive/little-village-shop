extends SceneTree
## Real scenes/physics; --fixed-fps runs complete visits quickly in CI.
var _checks: int = 0
var _failures: int = 0
var _motion_ok: bool = true
var _stock_ok: bool = true

func _initialize() -> void:
	_run.call_deferred()

func _check(condition: bool, description: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		push_error("FAIL: " + description)

func _run() -> void:
	await _test_empty_visit()
	await _test_queue()
	await _test_stale_shelf(false)
	await _test_stale_shelf(true)
	await _test_automatic_arrivals()
	_check(_motion_ok, "All visits use continuous collision-free movement")
	_check(_stock_ok, "Goods conserved on every simulated physics frame and pickup signal")
	print("Little Village Shop customers: %d checks, %d failures" % [_checks, _failures])
	quit(0 if _failures == 0 else 1)

func _shop() -> Node2D:
	var scene: PackedScene = load("res://scenes/main.tscn")
	var shop: Node2D = scene.instantiate()
	root.add_child(shop)
	shop.day.advance_time(60.0 / ShopDay.MINUTES_PER_SECOND)
	shop.day.set_physics_process(false)
	shop.customers.arrivals_enabled = false
	shop.customers.rng.seed = 47
	return shop

func _total(shop: Node2D) -> int:
	var total: int = shop.storage.inventory.total_units() + shop.player_inventory.total_units()
	for shelf in shop.customers.shelves:
		total += shelf.inventory.total_units()
	for customer in shop.customers.get_children():
		if customer is ShopCustomer:
			total += customer.basket.total_units()
	return total

func _step(shop: Node2D, customer: ShopCustomer = null) -> void:
	var before := customer.position if is_instance_valid(customer) else Vector2.ZERO
	await physics_frame
	if is_instance_valid(customer):
		_motion_ok = _motion_ok and customer.position.distance_to(before) <= ShopCustomer.SPEED / 60.0 + 0.01
		_motion_ok = _motion_ok and customer.get_slide_collision_count() == 0
	_stock_ok = _stock_ok and _total(shop) == 13

func _until(shop: Node2D, customer: ShopCustomer, target: ShopCustomer.State) -> bool:
	for frame in range(1800):
		if not is_instance_valid(customer):
			return false
		if customer.state == target:
			return true
		await _step(shop, customer)
	return false

func _exit(shop: Node2D, customer: ShopCustomer) -> bool:
	for frame in range(1800):
		if not is_instance_valid(customer):
			return true
		await _step(shop, customer)
	return false

func _dispose(shop: Node2D) -> void:
	shop.queue_free()
	await process_frame

func _test_empty_visit() -> void:
	var shop := _shop()
	await physics_frame
	var customer: ShopCustomer = shop.customers.spawn_customer()
	var states: Array[int] = [customer.state]
	customer.state_changed.connect(func(state: int) -> void: states.append(state))
	_check(customer.position == CustomerFlow.ENTRANCE and customer.state == ShopCustomer.State.ENTERING,
		"Visitor appears outside entrance in entry state")
	_check(customer.basket.capacity == 1 and customer.basket.total_units() == 0, "Visitor owns empty one-unit basket")
	_check(customer.collision_mask == 2 and customer.collision_layer == 0,
		"Visitor respects furniture without blocking player movement or interaction rays")
	_check(shop.customers.spawn_customer() == null, "Only one visitor browses at a time")
	_check(await _exit(shop, customer), "Empty-shop visitor walks out and is removed")
	_check(states == [ShopCustomer.State.ENTERING, ShopCustomer.State.SEARCHING, ShopCustomer.State.LEAVING],
		"Empty visit follows entry, search and leaving states")
	_check(shop.customers.waiting.is_empty() and shop.economy.balance == 100, "Empty visit creates no checkout or sale")
	_check(shop.customers.spawn_customer() != null, "Leaving releases browsing slot")
	await _dispose(shop)

func _test_queue() -> void:
	var shop := _shop()
	await physics_frame
	var flow: CustomerFlow = shop.customers
	var left: ShopShelf = shop.get_node("LeftShelf")
	var right: ShopShelf = shop.get_node("RightShelf")
	_check(shop.storage.inventory.transfer_to(left.inventory, &"apple", 1), "Stock orchard through Inventory")
	_check(shop.storage.inventory.transfer_to(right.inventory, &"bread", 1), "Stock pantry through Inventory")
	_check(shop.storage.inventory.transfer_to(right.inventory, &"milk", 1), "Stock mixed products")
	var variants: Array[int] = []
	var notifications := [0]
	for shelf in flow.shelves:
		shelf.inventory.changed.connect(func() -> void:
			notifications[0] += 1
			_stock_ok = _stock_ok and _total(shop) == 13)
	for index in range(3):
		var customer := flow.spawn_customer()
		variants.append(customer.appearance)
		var states: Array[int] = [customer.state]
		customer.state_changed.connect(func(state: int) -> void: states.append(state))
		_check(await _until(shop, customer, ShopCustomer.State.MOVING_TO_SHELF), "Visitor finds stocked shelf")
		_check(customer.basket.total_units() == 0, "Planning does not remove shelf stock")
		if index == 0:
			shop.inventory_ui.open_shelf(left)
			var before := customer.position
			for frame in range(45):
				await _step(shop, customer)
			_check(customer.position == before and not shop.player.controls_enabled, "Shelf menu pauses NPC and player")
			_check(not shop.inventory_ui.checkout_label.visible, "Checkout hint hides with menus")
			shop.inventory_ui.close_menu()
		_check(await _until(shop, customer, ShopCustomer.State.WAITING_AT_CHECKOUT), "Visitor reaches checkout without getting stuck")
		_check(customer.basket.total_units() == 1 and notifications[0] == index + 1, "Exactly one atomic pickup and shelf notification")
		_check(states == [ShopCustomer.State.ENTERING, ShopCustomer.State.SEARCHING,
			ShopCustomer.State.MOVING_TO_SHELF, ShopCustomer.State.MOVING_TO_CHECKOUT, ShopCustomer.State.WAITING_AT_CHECKOUT],
			"Successful visit follows complete state machine")
		_check(customer.position.distance_to(CustomerFlow.QUEUE_POSITIONS[index]) < 0.2, "Distinct physical checkout slots")
		_check(flow.waiting.size() == index + 1 and flow.active_customer == null, "Queue arrival releases browsing slot")
	_check(variants == [0, 1, 2], "First three villagers have distinct appearances")
	_check(left.fill_state() == ShopShelf.FillState.EMPTY and right.fill_state() == ShopShelf.FillState.EMPTY, "Shelf visuals read depleted stock")
	_check(shop.inventory_ui.checkout_label.text == "В очереди: 3 / 3", "HUD shows unpaid checkout queue")
	_check(shop.inventory_ui.checkout_label.get_global_rect().end.x <= root.get_visible_rect().size.x, "Checkout hint fits viewport")
	_check(flow.spawn_customer() == null, "Full checkout prevents further visitors")
	flow.arrivals_enabled = true
	for frame in range(600):
		await _step(shop)
	_check(flow.get_child_count() == 3 and flow.waiting.size() == 3, "Full queue remains bounded over time")
	for customer in flow.waiting:
		_check(customer.state == ShopCustomer.State.WAITING_AT_CHECKOUT and customer.basket.total_units() == 1,
			"Waiting preserves customer and unpaid goods")
	_check(shop.economy.balance == 100 and _total(shop) == 13, "No payment; goods remain in tracked inventories")
	await _dispose(shop)
	shop = _shop()
	_check(shop.customers.waiting.is_empty() and shop.storage.inventory.total_units() == 13, "Restart resets queue and demo goods together")
	await _dispose(shop)

func _test_stale_shelf(with_alternative: bool) -> void:
	var shop := _shop()
	await physics_frame
	var left: ShopShelf = shop.get_node("LeftShelf")
	shop.storage.inventory.transfer_to(left.inventory, &"apple", 1)
	var customer: ShopCustomer = shop.customers.spawn_customer()
	_check(await _until(shop, customer, ShopCustomer.State.MOVING_TO_SHELF), "Visitor starts approaching stocked shelf")
	_check(left.inventory.transfer_to(shop.player_inventory, &"apple", 1), "Player can withdraw targeted item en route")
	if with_alternative:
		var right: ShopShelf = shop.get_node("RightShelf")
		shop.storage.inventory.transfer_to(right.inventory, &"milk", 1)
		_check(await _until(shop, customer, ShopCustomer.State.WAITING_AT_CHECKOUT), "Visitor searches again and visits alternate shelf")
		_check(customer.basket.quantity(&"milk") == 1 and customer.basket.quantity(&"apple") == 0, "Pickup uses live stock")
	else:
		_check(await _exit(shop, customer), "Visitor leaves when targeted shelf becomes empty")
		_check(shop.customers.waiting.is_empty(), "Failed pickup creates no checkout entry")
	_check(shop.player_inventory.quantity(&"apple") == 1 and _total(shop) == 13, "Concurrent withdrawal cannot duplicate goods")
	await _dispose(shop)

func _test_automatic_arrivals() -> void:
	var shop := _shop()
	await physics_frame
	shop.customers.arrivals_enabled = true
	shop.inventory_ui.open_inventory()
	for frame in range(300):
		await _step(shop)
	_check(shop.customers.get_child_count() == 0, "Arrival timer pauses with menu")
	shop.inventory_ui.close_menu()
	for frame in range(260):
		await _step(shop)
	_check(is_instance_valid(shop.customers.active_customer), "Gameplay automatically spawns first visitor")
	var customer: ShopCustomer = shop.customers.active_customer
	_check(await _exit(shop, customer), "Automatic empty visitor completes visit")
	for frame in range(450):
		await _step(shop)
	_check(is_instance_valid(shop.customers.active_customer), "Next visitor arrives after quiet interval")
	await _dispose(shop)
