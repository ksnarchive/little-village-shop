class_name CustomerFlow
extends Node2D
## One browsing visitor at a time; unpaid baskets stay in a bounded checkout queue.

signal queue_changed(waiting: int)
signal sale_completed(item: ItemData, customer: ShopCustomer)

const MAX_CUSTOMERS: int = 3
const ARRIVAL_INTERVAL: float = 7.0
const RUSH_INTERVAL: float = 3.0
const ENTRANCE := Vector2(320, 328)
const FOYER := Vector2(320, 260)
const AISLE := Vector2(320, 184)
const QUEUE_POSITIONS: Array[Vector2] = [Vector2(208, 260), Vector2(236, 260), Vector2(264, 260)]

@export var arrivals_enabled: bool = true
var shelves: Array[ShopShelf] = []
var waiting: Array[ShopCustomer] = []
var active_customer: ShopCustomer
var departing_customer: ShopCustomer
var service_menu_open: bool = false
var business_open: bool = true
var arrival_interval: float = ARRIVAL_INTERVAL
var economy: ShopEconomy
var _serving: bool = false
var catalog: ItemCatalog
var rng := RandomNumberGenerator.new()
var _arrival_time: float = 4.0
var _next_appearance: int = 0
var _paths := AStar2D.new()

func configure(products: ItemCatalog, shop_shelves: Array[ShopShelf]) -> void:
	catalog = products
	shelves.assign(shop_shelves)
	rng.randomize()
	# A small authored graph follows the open central aisle around the furniture.
	# Shelf endpoints come from the existing interaction system.
	_paths.clear()
	for point in [ENTRANCE, FOYER, AISLE]:
		_paths.add_point(_paths.get_point_count(), point)
	_paths.connect_points(0, 1)
	_paths.connect_points(1, 2)
	for shelf in shelves:
		var id := _paths.get_point_count()
		_paths.add_point(id, shelf.interaction_position() + Vector2(0, 8))
		_paths.connect_points(2, id)
	for point in QUEUE_POSITIONS:
		var id := _paths.get_point_count()
		_paths.add_point(id, point)
		_paths.connect_points(1, id)
	queue_redraw()

func _physics_process(delta: float) -> void:
	if service_menu_open or checkout_busy() or not arrivals_enabled or not business_open or catalog == null or is_instance_valid(active_customer):
		return
	if waiting.size() >= MAX_CUSTOMERS:
		return
	_arrival_time -= delta
	if _arrival_time <= 0.0:
		spawn_customer()

func spawn_customer() -> ShopCustomer:
	if not business_open or service_menu_open or checkout_busy() or catalog == null or is_instance_valid(active_customer) or waiting.size() >= MAX_CUSTOMERS:
		return null
	var scene: PackedScene = load("res://scenes/characters/customer.tscn")
	var customer: ShopCustomer = scene.instantiate()
	customer.configure(self, catalog, _next_appearance % 3)
	_next_appearance += 1
	customer.position = ENTRANCE
	add_child(customer)
	active_customer = customer
	customer.start_visit()
	return customer

func set_business_hours(is_open: bool, rush: bool) -> void:
	business_open = is_open
	arrival_interval = RUSH_INTERVAL if rush else ARRIVAL_INTERVAL
	if is_open:
		_arrival_time = minf(_arrival_time, arrival_interval)

func reset_arrival_timer() -> void:
	_arrival_time = 4.0

func is_empty() -> bool:
	# Include deferred queue_free nodes: reports wait until the last exit is gone.
	return (not _serving and waiting.is_empty() and not is_instance_valid(active_customer)
		and not is_instance_valid(departing_customer) and get_child_count() == 0)

func route(from: Vector2, destination: Vector2) -> PackedVector2Array:
	return _paths.get_point_path(_paths.get_closest_point(from), _paths.get_closest_point(destination))

func stocked_shelves() -> Array[ShopShelf]:
	var available: Array[ShopShelf] = []
	for shelf in shelves:
		if is_instance_valid(shelf) and shelf.inventory.total_units() > 0:
			available.append(shelf)
	return available

func checkout_position() -> Vector2:
	return QUEUE_POSITIONS[waiting.size()]

func join_checkout(customer: ShopCustomer) -> void:
	if customer != active_customer or customer.basket.total_units() != 1:
		return
	waiting.append(customer)
	active_customer = null
	_arrival_time = arrival_interval
	queue_changed.emit(waiting.size())
	queue_redraw()

func finish_empty_visit(customer: ShopCustomer) -> void:
	if customer != active_customer or customer.basket.total_units() != 0:
		return
	active_customer = null
	_arrival_time = arrival_interval
	customer.queue_free()
	queue_changed.emit(waiting.size())

func checkout_busy() -> bool:
	if _serving or is_instance_valid(departing_customer):
		return true
	for customer in waiting:
		if customer.state == ShopCustomer.State.ADVANCING_IN_QUEUE:
			return true
	return false

func can_customer_move(customer: ShopCustomer) -> bool:
	if customer == departing_customer or customer.state == ShopCustomer.State.ADVANCING_IN_QUEUE:
		return true
	return not checkout_busy() and (not service_menu_open or customer == active_customer)

func first_customer() -> ShopCustomer:
	return waiting[0] if not waiting.is_empty() else null

func basket_item(customer: ShopCustomer) -> ItemData:
	if not is_instance_valid(customer) or customer.basket.total_units() != 1:
		return null
	for item in catalog.items:
		if customer.basket.quantity(item.id) == 1:
			return item
	return null

func can_serve(customer: ShopCustomer) -> bool:
	var item := basket_item(customer)
	# One moving visitor at a time: let an in-flight visit finish before departure.
	return (not checkout_busy() and not is_instance_valid(active_customer) and is_instance_valid(customer)
		and customer == first_customer() and customer.state == ShopCustomer.State.WAITING_AT_CHECKOUT
		and economy != null and item != null and economy.can_sell(customer.basket, item.id))

func serve_customer(customer: ShopCustomer) -> bool:
	# Identity belongs to the displayed customer: stale clicks cannot serve the next.
	if not can_serve(customer):
		return false
	_serving = true
	var item := basket_item(customer)
	waiting.pop_front()
	departing_customer = customer
	customer.prepare_paid_departure()
	# Prevalidated; staging above emits no signals and cannot invalidate the sale.
	economy.sell(customer.basket, item.id)
	customer.state_changed.emit(customer.state)
	queue_changed.emit(waiting.size())
	sale_completed.emit(item, customer)
	_serving = false
	return true

func finish_departure(customer: ShopCustomer) -> void:
	if customer != departing_customer:
		finish_empty_visit(customer)
		return
	if customer.basket.total_units() != 0:
		return
	departing_customer = null
	customer.queue_free()
	# Advance only after the paid visitor clears the lane. Distances stay constant.
	for index in range(waiting.size()):
		waiting[index].advance_in_queue(index)
	queue_changed.emit(waiting.size())

func _draw() -> void:
	# Quiet floor markers make the checkout line legible before anyone arrives.
	for point in QUEUE_POSITIONS:
		draw_rect(Rect2(point + Vector2(-7, 8), Vector2(14, 2)), Color("#b5b58b"))
