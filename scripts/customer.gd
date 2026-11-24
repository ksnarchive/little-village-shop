class_name ShopCustomer
extends CharacterBody2D
## A visitor owns one unpaid item; checkout consumes it only after a validated sale.

enum State { ENTERING, SEARCHING, MOVING_TO_SHELF, MOVING_TO_CHECKOUT, WAITING_AT_CHECKOUT, LEAVING, ADVANCING_IN_QUEUE }
signal state_changed(next_state: State)

const SPEED: float = 46.0
const APPEARANCE_COUNT: int = 3

var state: State = State.ENTERING
var basket: Inventory
var appearance: int = 0
var facing := Vector2.UP
var walking: bool = false
var _flow: CustomerFlow
var _catalog: ItemCatalog
var _shelf: ShopShelf
var _route := PackedVector2Array()
var _waypoint: int = 0
var _pause: float = 0.0
var _step: float = 0.0

func configure(flow: CustomerFlow, catalog: ItemCatalog, variant: int) -> void:
	_flow = flow
	_catalog = catalog
	appearance = posmod(variant, APPEARANCE_COUNT)
	basket = Inventory.new(catalog, 1)

func start_visit() -> void:
	_travel(State.ENTERING, CustomerFlow.FOYER)

func _set_state(next_state: State, notify: bool = true) -> void:
	state = next_state
	walking = false
	velocity = Vector2.ZERO
	if notify:
		state_changed.emit(state)
	queue_redraw()

func _travel(next_state: State, destination: Vector2) -> void:
	_route = _flow.route(position, destination)
	_waypoint = 0
	_set_state(next_state)

func _physics_process(delta: float) -> void:
	if not _flow.can_customer_move(self):
		walking = false
		velocity = Vector2.ZERO
		return
	walking = false
	velocity = Vector2.ZERO
	if _pause > 0.0:
		_pause = maxf(0.0, _pause - delta)
	elif state == State.SEARCHING:
		_search()
	elif state != State.WAITING_AT_CHECKOUT:
		_walk(delta)
	queue_redraw()

func _walk(delta: float) -> void:
	if _waypoint >= _route.size():
		_arrive()
		return
	var offset := _route[_waypoint] - position
	if offset.length() <= 0.1:
		_waypoint += 1
		return
	# Clamp velocity to the remaining distance: no snapping, overshoot or teleport.
	velocity = offset.normalized() * minf(SPEED, offset.length() / delta)
	facing = offset.normalized()
	move_and_slide()
	walking = get_position_delta().length_squared() > 0.001
	if walking:
		_step += delta * 10.0

func _arrive() -> void:
	match state:
		State.ENTERING:
			_set_state(State.SEARCHING)
			_pause = 0.8
		State.MOVING_TO_SHELF:
			_take_item()
		State.MOVING_TO_CHECKOUT:
			_set_state(State.WAITING_AT_CHECKOUT)
			facing = Vector2.DOWN
			_flow.join_checkout(self)
		State.ADVANCING_IN_QUEUE:
			_set_state(State.WAITING_AT_CHECKOUT)
			facing = Vector2.DOWN
			_flow.queue_changed.emit(_flow.waiting.size())
		State.LEAVING:
			_flow.finish_departure(self)

func _search() -> void:
	var available := _flow.stocked_shelves()
	if available.is_empty():
		_travel(State.LEAVING, CustomerFlow.ENTRANCE)
		return
	_shelf = available[_flow.rng.randi_range(0, available.size() - 1)]
	_travel(State.MOVING_TO_SHELF, _shelf.interaction_position() + Vector2(0, 8))

func _take_item() -> void:
	# Re-read stock on arrival: the player may have emptied the shelf en route.
	var available: Array[StringName] = []
	if is_instance_valid(_shelf):
		for item in _catalog.items:
			if _shelf.inventory.quantity(item.id) > 0:
				available.append(item.id)
	if not available.is_empty():
		var item_id := available[_flow.rng.randi_range(0, available.size() - 1)]
		if _shelf.inventory.transfer_to(basket, item_id, 1):
			_travel(State.MOVING_TO_CHECKOUT, _flow.checkout_position())
			_pause = 0.6
			return
	_set_state(State.SEARCHING)
	_pause = 0.5

func prepare_paid_departure() -> void:
	# A separate lane above the queue clears the waiting villagers and storage.
	# Stage silently so basket/economy observers also see the completed NPC state.
	_route = PackedVector2Array([Vector2(208, 247), Vector2(288, 247),
		CustomerFlow.FOYER, CustomerFlow.ENTRANCE])
	_waypoint = 0
	_pause = 0.0
	_set_state(State.LEAVING, false)

func advance_in_queue(slot: int) -> void:
	_route = PackedVector2Array([CustomerFlow.QUEUE_POSITIONS[slot]])
	_waypoint = 0
	_set_state(State.ADVANCING_IN_QUEUE)

func _draw() -> void:
	VillagerArt.draw_actor(self, appearance + 1, facing, walking, _step)
	if basket != null and basket.total_units() > 0:
		draw_rect(Rect2(5, 1, 9, 8), Color("#685569"))
		draw_rect(Rect2(6, 3, 7, 5), Color("#E4BC98"))
		draw_rect(Rect2(7, 4, 5, 1), Color("#F2D18F"))
		draw_rect(Rect2(8, 3, 1, 5), Color("#A58491"))
		draw_rect(Rect2(11, 3, 1, 5), Color("#A58491"))
	# A catalog icon in a cream thought bubble shows held goods / waiting clearly.
	if state == State.WAITING_AT_CHECKOUT or (basket != null and basket.total_units() > 0):
		draw_rect(Rect2(-11, -40, 22, 21), Color("#685569"))
		draw_rect(Rect2(-10, -39, 20, 19), Color("#FFF2DF"))
		draw_rect(Rect2(-1, -19, 3, 3), Color("#FFF2DF"))
		for item in _catalog.items:
			if basket.quantity(item.id) > 0 and item.icon != null:
				draw_texture_rect(item.icon, Rect2(-8, -38, 16, 16), false)
				break
	elif state == State.SEARCHING or state == State.LEAVING:
		draw_rect(Rect2(-6, -29, 12, 9), Color("#FFF2DF"))
		for x in [-3, 0, 3]:
			draw_rect(Rect2(x, -25, 1, 1), Color("#685569"))
