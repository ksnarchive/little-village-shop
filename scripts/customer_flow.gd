class_name CustomerFlow
extends Node2D
## One browsing visitor at a time; unpaid baskets stay in a bounded checkout queue.

signal queue_changed(waiting: int)

const MAX_CUSTOMERS: int = 3
const ARRIVAL_INTERVAL: float = 7.0
const ENTRANCE := Vector2(320, 328)
const FOYER := Vector2(320, 260)
const AISLE := Vector2(320, 184)
const QUEUE_POSITIONS: Array[Vector2] = [Vector2(208, 260), Vector2(236, 260), Vector2(264, 260)]

@export var arrivals_enabled: bool = true
var shelves: Array[ShopShelf] = []
var waiting: Array[ShopCustomer] = []
var active_customer: ShopCustomer
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
	if not arrivals_enabled or catalog == null or is_instance_valid(active_customer):
		return
	if waiting.size() >= MAX_CUSTOMERS:
		return
	_arrival_time -= delta
	if _arrival_time <= 0.0:
		spawn_customer()

func spawn_customer() -> ShopCustomer:
	if catalog == null or is_instance_valid(active_customer) or waiting.size() >= MAX_CUSTOMERS:
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
	_arrival_time = ARRIVAL_INTERVAL
	queue_changed.emit(waiting.size())
	queue_redraw()

func finish_empty_visit(customer: ShopCustomer) -> void:
	# There is deliberately no removal/service path for a customer holding goods.
	if customer != active_customer or customer.basket.total_units() != 0:
		return
	active_customer = null
	_arrival_time = ARRIVAL_INTERVAL
	customer.queue_free()

func _draw() -> void:
	# Quiet floor markers make the checkout line legible before anyone arrives.
	for point in QUEUE_POSITIONS:
		draw_rect(Rect2(point + Vector2(-7, 8), Vector2(14, 2)), Color("#b5b58b"))
