class_name ShopCustomer
extends CharacterBody2D
## A visitor owns one unpaid item. Only Inventory.transfer_to() moves shelf goods.

enum State { ENTERING, SEARCHING, MOVING_TO_SHELF, MOVING_TO_CHECKOUT, WAITING_AT_CHECKOUT, LEAVING }
signal state_changed(next_state: State)

const SPEED: float = 46.0
const COATS: Array[Color] = [Color("#a8664e"), Color("#879bb0"), Color("#b49a58")]
const HAIR: Array[Color] = [Color("#6a4936"), Color("#d4c5aa"), Color("#49382d")]
const SKIN: Array[Color] = [Color("#e8b88f"), Color("#bd8b68"), Color("#edc8a4")]

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
	appearance = posmod(variant, COATS.size())
	basket = Inventory.new(catalog, 1)

func start_visit() -> void:
	_travel(State.ENTERING, CustomerFlow.FOYER)

func _set_state(next_state: State) -> void:
	state = next_state
	walking = false
	velocity = Vector2.ZERO
	state_changed.emit(state)
	queue_redraw()

func _travel(next_state: State, destination: Vector2) -> void:
	_route = _flow.route(position, destination)
	_waypoint = 0
	_set_state(next_state)

func _physics_process(delta: float) -> void:
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
		State.LEAVING:
			_flow.finish_empty_visit(self)

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

func _draw() -> void:
	# Same tiny, whole-pixel silhouette and warm palette as the shopkeeper.
	draw_rect(Rect2(-7, 8, 14, 3), Color(0.2, 0.15, 0.1, 0.22))
	var bob := 1 if walking and sin(_step) > 0.0 else 0
	draw_rect(Rect2(-5, 5 + bob, 4, 5), Color("#4e4139"))
	draw_rect(Rect2(1, 5 - bob, 4, 5), Color("#4e4139"))
	draw_rect(Rect2(-7, -4, 14, 11), COATS[appearance])
	draw_rect(Rect2(-4, -3, 8, 9), Color("#eddbb5"))
	draw_rect(Rect2(-8, -2, 2, 7), COATS[appearance].darkened(0.12))
	draw_rect(Rect2(6, -2, 2, 7), COATS[appearance].darkened(0.12))
	draw_rect(Rect2(-5, -12, 10, 10), SKIN[appearance])
	draw_rect(Rect2(-6, -14, 12, 5), HAIR[appearance])
	draw_rect(Rect2(-6, -11, 3, 5), HAIR[appearance])
	if appearance == 0:
		draw_rect(Rect2(-8, -13, 16, 2), Color("#c9ae70"))
		draw_rect(Rect2(-5, -17, 10, 4), Color("#d8bf86"))
	elif appearance == 1:
		draw_rect(Rect2(3, -11, 3, 7), HAIR[appearance])
	else:
		draw_rect(Rect2(-6, -15, 12, 3), COATS[appearance].darkened(0.15))
	if facing.y >= -0.3:
		draw_rect(Rect2(-3, -7, 2, 2), Color("#49382d"))
		draw_rect(Rect2(2, -7, 2, 2), Color("#49382d"))
		draw_rect(Rect2(-4, -4, 2, 1), Color("#cf947d"))
	if basket != null and basket.total_units() > 0:
		draw_rect(Rect2(5, 1, 9, 8), Color("#765238"))
		draw_rect(Rect2(6, 3, 7, 5), Color("#b78b59"))
	# A catalog icon in a cream thought bubble shows held goods / waiting clearly.
	if state == State.WAITING_AT_CHECKOUT or (basket != null and basket.total_units() > 0):
		draw_rect(Rect2(-11, -40, 22, 21), Color("#765238"))
		draw_rect(Rect2(-10, -39, 20, 19), Color("#f1deb7"))
		draw_rect(Rect2(-1, -19, 3, 3), Color("#f1deb7"))
		for item in _catalog.items:
			if basket.quantity(item.id) > 0 and item.icon != null:
				draw_texture_rect(item.icon, Rect2(-8, -38, 16, 16), false)
				break
	elif state == State.SEARCHING or state == State.LEAVING:
		draw_rect(Rect2(-6, -29, 12, 9), Color("#f1deb7"))
		for x in [-3, 0, 3]:
			draw_rect(Rect2(x, -25, 1, 1), Color("#765238"))
