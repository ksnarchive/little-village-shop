extends SceneTree
## Godot 4.3 real-scene workdays at fixed 60 Hz; no wall-clock sleeps or save files.
var _checks: int = 0
var _failures: int = 0
var _goods_ok: bool = true
var _money_ok: bool = true
var _expected_goods: int = 13
var _purchases: int = 0

func _initialize() -> void:
	_run.call_deferred()

func _check(condition: bool, description: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		push_error("FAIL: " + description)

func _shop() -> Node2D:
	var shop: Node2D = load("res://scenes/main.tscn").instantiate()
	root.add_child(shop)
	shop.customers.rng.seed = 47
	_expected_goods = 13
	_purchases = 0
	return shop

func _dispose(shop: Node2D) -> void:
	shop.queue_free()
	await process_frame

func _step(shop: Node2D) -> void:
	await physics_frame
	var goods: int = shop.storage.inventory.total_units() + shop.player_inventory.total_units()
	for shelf in shop.customers.shelves:
		goods += shelf.inventory.total_units()
	for customer in shop.customers.get_children():
		goods += customer.basket.total_units()
	_goods_ok = _goods_ok and goods + shop.economy.completed_sales == _expected_goods
	_money_ok = _money_ok and shop.economy.balance == 100 - _purchases + shop.economy.revenue

func _advance(shop: Node2D, minutes: float) -> void:
	shop.day.advance_time(minutes / ShopDay.MINUTES_PER_SECOND)

func _key(code: Key) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = true
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	await process_frame

func _run() -> void:
	await _test_clock_and_menus()
	_test_accounting()
	await _test_closing_visits()
	await _test_three_days()
	_check(_goods_ok, "Goods plus sold units conserved on every physics frame across days")
	_check(_money_ok, "Balance equals initial coins minus purchases plus sales every frame")
	print("Little Village Shop days: %d checks, %d failures" % [_checks, _failures])
	quit(0 if _failures == 0 else 1)

func _test_clock_and_menus() -> void:
	var shop := _shop()
	var day: ShopDay = shop.day
	day.set_physics_process(false)
	_check(day.day_number == 1 and day.time_text() == "08:00" and day.phase == ShopDay.Phase.PREPARATION,
		"First day begins at 08:00 in preparation")
	_check(shop.customers.spawn_customer() == null, "Manual and automatic admissions blocked before opening")
	_check(not day.start_next_day(), "Cannot skip unfinished day")
	day.advance_time(-1)
	day.advance_time(INF)
	_check(day.minute == 480, "Invalid deltas leave clock unchanged")
	_advance(shop, 59)
	_check(day.time_text() == "08:59" and not shop.customers.business_open, "08:59 still preparation")
	_advance(shop, 1)
	_check(day.phase == ShopDay.Phase.OPEN and shop.customers.business_open, "09:00 opens automatically")
	_check(shop.customers.arrival_interval == CustomerFlow.ARRIVAL_INTERVAL, "Morning has normal arrival interval")
	_advance(shop, 179)
	_check(day.time_text() == "11:59" and day.phase == ShopDay.Phase.OPEN, "Morning lasts until noon")
	_advance(shop, 1)
	_check(day.phase == ShopDay.Phase.RUSH and shop.customers.arrival_interval < CustomerFlow.ARRIVAL_INTERVAL,
		"12:00 increases visitor frequency")
	var before: float = day.minute
	var ui: InventoryMenu = shop.inventory_ui
	for view in [InventoryMenu.View.BAG, InventoryMenu.View.STORAGE, InventoryMenu.View.SUPPLIER,
		InventoryMenu.View.SHELF, InventoryMenu.View.CHECKOUT]:
		match view:
			InventoryMenu.View.BAG: ui.open_inventory()
			InventoryMenu.View.STORAGE: ui.open_storage()
			InventoryMenu.View.SUPPLIER: ui.open_supplier()
			InventoryMenu.View.SHELF: ui.open_shelf(shop.get_node("LeftShelf"))
			InventoryMenu.View.CHECKOUT: ui.open_checkout()
		day.advance_time(100)
		_check(day.paused and day.minute == before, "Every modal view pauses game time: %s" % view)
		ui.close_menu()
		_check(not day.paused, "Closing menu resumes clock: %s" % view)
	_advance(shop, 119)
	_check(day.phase == ShopDay.Phase.RUSH and day.time_text() == "13:59", "Lunch lasts to 14:00")
	_advance(shop, 1)
	_check(day.phase == ShopDay.Phase.AFTERNOON and shop.customers.arrival_interval == CustomerFlow.ARRIVAL_INTERVAL,
		"14:00 restores normal visitor frequency")
	_advance(shop, 239)
	_check(day.time_text() == "17:59" and shop.customers.business_open, "Afternoon lasts to 18:00")
	shop.customers.arrivals_enabled = false
	_advance(shop, 1)
	_check(day.phase == ShopDay.Phase.SUMMARY and not shop.customers.business_open, "Empty shop finishes exactly at 18:00")
	_check(day.report() == {"day": 1, "customers": 0, "revenue": 0, "expenses": 0, "profit": 0, "balance": 100},
		"Empty day report contains all six correct values")
	await process_frame
	_check(ui.view == InventoryMenu.View.DAY_END and not shop.player.controls_enabled, "Report locks world input")
	await _key(KEY_ESCAPE)
	await _key(KEY_I)
	ui.open_supplier()
	_check(ui.view == InventoryMenu.View.DAY_END, "Esc/I and other menu calls cannot dismiss report")
	_check(shop.economy.buy(&"apple", 1) != ShopEconomy.PurchaseResult.SUCCESS, "Summary blocks hidden transactions")
	_check(ui.panel.get_global_rect().size.y <= 360 and ui.panel.get_global_rect().end.x <= 640,
		"Report fits base viewport")
	var copy := day.report()
	copy.balance = -1
	_check(day.report().balance == 100, "Report getter returns independent snapshot")
	day.advance_time(10000)
	_check(day.time_text() == "18:00" and day.day_number == 1, "Finished clock cannot advance on its own")
	ui.next_day_button.pressed.emit()
	_check(day.day_number == 2 and day.time_text() == "08:00" and ui.view == InventoryMenu.View.CLOSED,
		"Next-day button starts morning and releases controls")
	ui.next_day_button.pressed.emit()
	_check(day.day_number == 2, "Repeated next-day clicks cannot skip another day")
	_advance(shop, 60)
	shop.customers.arrivals_enabled = true
	shop.customers._arrival_time = CustomerFlow.ARRIVAL_INTERVAL
	shop.customers._physics_process(3.1)
	_check(not is_instance_valid(shop.customers.active_customer), "Normal arrivals wait longer than three seconds")
	_advance(shop, 180)
	shop.customers._physics_process(3.1)
	_check(is_instance_valid(shop.customers.active_customer), "Lunch arrival actually spawns after shorter interval")
	await _dispose(shop)
	shop = _shop()
	day = shop.day
	day.set_physics_process(false)
	var phases: Array[int] = []
	day.clock_changed.connect(func() -> void:
		if phases.is_empty() or phases.back() != day.phase:
			phases.append(day.phase))
	_advance(shop, 600)
	_check(phases == [ShopDay.Phase.OPEN, ShopDay.Phase.RUSH, ShopDay.Phase.AFTERNOON,
		ShopDay.Phase.CLOSING, ShopDay.Phase.SUMMARY], "Long frame crosses all boundaries in order once")
	await _dispose(shop)

func _test_accounting() -> void:
	var catalog: ItemCatalog = load("res://data/item_catalog.tres")
	var storage := Inventory.new(catalog, 60)
	var economy := ShopEconomy.new(catalog, storage)
	var observed := [true]
	var on_purchase := func() -> void:
		observed[0] = observed[0] and economy.balance == 94 and economy.day_expenses == 6
	storage.changed.connect(on_purchase)
	_check(economy.buy(&"apple", 2) == ShopEconomy.PurchaseResult.SUCCESS and observed[0],
		"Purchase observers see committed daily expense and balance")
	storage.changed.disconnect(on_purchase)
	_check(economy.buy(&"milk", 99) != ShopEconomy.PurchaseResult.SUCCESS and economy.day_expenses == 6,
		"Rejected order does not count as expense")
	var basket := Inventory.new(catalog, 1)
	storage.transfer_to(basket, &"apple", 1)
	var sold := [true]
	basket.changed.connect(func() -> void:
		sold[0] = sold[0] and economy.day_sales == 1 and economy.day_revenue == 5 and economy.balance == 99)
	_check(economy.sell(basket, &"apple") and sold[0], "Sale observers see committed daily revenue/customer count")
	_check(not economy.sell(basket, &"apple") and economy.day_sales == 1, "Duplicate sale cannot inflate daily report")
	_check(economy.day_revenue - economy.day_expenses == -1, "Profit may be negative and excludes demo stock")
	var full := Inventory.new(catalog, 0)
	var no_space := ShopEconomy.new(catalog, full)
	_check(no_space.buy(&"apple", 1) == ShopEconomy.PurchaseResult.INSUFFICIENT_SPACE
		and no_space.day_expenses == 0 and no_space.balance == 100, "Capacity rejection rolls back expense and balance")
	economy.reset_day_totals()
	_check(economy.day_revenue == 0 and economy.day_sales == 0 and economy.day_expenses == 0
		and economy.balance == 99 and economy.revenue == 5 and storage.total_units() == 1,
		"Resetting day counters preserves session money and remaining stock")

func _test_closing_visits() -> void:
	for stocked in [false, true]:
		var shop := _shop()
		shop.day.set_physics_process(false)
		shop.customers.arrivals_enabled = false
		_advance(shop, 599)
		if stocked:
			shop.storage.inventory.transfer_to(shop.get_node("LeftShelf").inventory, &"apple", 3)
		var flow: CustomerFlow = shop.customers
		var first := flow.spawn_customer()
		if stocked:
			for frame in range(1800):
				if flow.can_serve(first):
					break
				await _step(shop)
			_check(flow.can_serve(first), "First customer waits before closing")
			_check(flow.spawn_customer() != null, "Second visit starts just before closing")
		_advance(shop, 1)
		_check(shop.day.phase == ShopDay.Phase.CLOSING and flow.spawn_customer() == null,
			"18:00 blocks admissions but waits for existing visits")
		flow.arrivals_enabled = true
		if stocked:
			shop.inventory_ui.open_checkout()
		for frame in range(3600):
			var customer := flow.first_customer()
			if stocked and flow.can_serve(customer):
				shop.inventory_ui.checkout_menu.serve_button.pressed.emit()
			await _step(shop)
			shop.day.advance_time(0)
			if shop.day.phase == ShopDay.Phase.SUMMARY:
				break
		_check(shop.day.phase == ShopDay.Phase.SUMMARY and flow.is_empty(),
			"Reports wait for active visits, service, queue advance and final departure")
		_check(shop.inventory_ui.view == InventoryMenu.View.DAY_END,
			"Last exit opens report even while checkout panel is open")
		_check(shop.day.report().customers == (2 if stocked else 0),
			"Only paid customers count; empty-handed exit does not count")
		if stocked:
			_check(shop.day.report().revenue == 10, "Both after-hours sales belong to closing day")
			var stock: Dictionary = shop.get_node("LeftShelf").inventory.serialize()
			shop.day.start_next_day()
			_check(shop.get_node("LeftShelf").inventory.serialize() == stock and shop.economy.balance == 110,
				"Unsold shelf goods and earned coins survive next morning")
		await _dispose(shop)

func _test_three_days() -> void:
	var shop := _shop()
	shop.storage.inventory.transfer_to(shop.player_inventory, &"bread", 1)
	var bag: Dictionary = shop.player_inventory.serialize()
	var reports: Array[Dictionary] = []
	shop.day.day_finished.connect(func(value: Dictionary) -> void: reports.append(value))
	for number in range(1, 4):
		_check(shop.economy.buy(&"apple", 2) == ShopEconomy.PurchaseResult.SUCCESS, "Morning purchasing on day %d" % number)
		_expected_goods += 2
		_purchases += 6
		shop.storage.inventory.transfer_to(shop.get_node("LeftShelf").inventory, &"apple", 4)
		shop.storage.inventory.transfer_to(shop.get_node("RightShelf").inventory, &"milk", 1)
		var seen_phases: Dictionary = {}
		var admissions_ok := true
		for frame in range(27000):
			seen_phases[shop.day.phase] = true
			if shop.day.phase == ShopDay.Phase.SUMMARY:
				break
			if shop.day.phase in [ShopDay.Phase.PREPARATION, ShopDay.Phase.CLOSING]:
				admissions_ok = admissions_ok and shop.customers.spawn_customer() == null
			var customer: ShopCustomer = shop.customers.first_customer()
			if shop.customers.can_serve(customer):
				shop.customers.serve_customer(customer)
			await _step(shop)
		_check(shop.day.phase == ShopDay.Phase.SUMMARY and seen_phases.has(ShopDay.Phase.RUSH),
			"Complete automatic clock and NPC workday %d reaches report" % number)
		_check(admissions_ok and shop.customers.is_empty(), "No early/late arrivals or leftover NPCs on day %d" % number)
		var report: Dictionary = shop.day.report()
		_check(report.day == number and report.customers == 5 and report.revenue == 32
			and report.expenses == 6 and report.profit == 26 and report.balance == 100 + 26 * number,
			"Exact five-customer daily report on day %d" % number)
		_check(reports.size() == number, "Exactly one report emitted for day %d" % number)
		_check(shop.player_inventory.serialize() == bag, "Untraded bag contents persist on day %d" % number)
		var storage: Dictionary = shop.storage.inventory.serialize()
		shop.inventory_ui.next_day_button.pressed.emit()
		_check(shop.day.day_number == number + 1 and shop.day.time_text() == "08:00"
			and shop.storage.inventory.serialize() == storage and shop.player_inventory.serialize() == bag,
			"Next morning preserves inventories without re-seeding day %d" % number)
		_check(shop.economy.day_revenue == 0 and shop.economy.day_sales == 0 and shop.economy.day_expenses == 0
			and shop.economy.balance == report.balance, "Only daily statistics reset after day %d" % number)
	await _dispose(shop)
