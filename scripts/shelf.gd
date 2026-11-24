class_name ShopShelf
extends Interactable
## A fixture owns its Inventory; all stock movement uses Inventory.transfer_to().

enum FillState { EMPTY, PARTIAL, FULL }

@export var catalog: ItemCatalog
@export var capacity: int = 12
@export var display_name: String = "Полка"
@export_enum("shelf", "pantry") var palette: String = "shelf"
var inventory: Inventory

func _ready() -> void:
	super._ready()
	inventory = Inventory.new(catalog, capacity)
	inventory.changed.connect(queue_redraw)
	queue_redraw()

func fill_state() -> FillState:
	if inventory.total_units() == 0:
		return FillState.EMPTY
	return FillState.FULL if inventory.total_units() == inventory.capacity else FillState.PARTIAL

func _draw() -> void:
	draw_texture(preload("res://assets/shop/pantry.png") if palette == "pantry" else preload("res://assets/shop/shelf.png"), Vector2(-32, -32))
	if inventory == null:
		return
	var total := inventory.total_units()
	# Six display positions represent capacity, not a second copy of the stock.
	var visible_units := 0
	if fill_state() == FillState.FULL:
		visible_units = 6
	elif fill_state() == FillState.PARTIAL:
		visible_units = clampi(ceili(float(total) / inventory.capacity * 6), 1, 5)
	for slot in range(visible_units):
		var unit_index := slot * total / visible_units
		for item in catalog.items:
			var count := inventory.quantity(item.id)
			if unit_index < count:
				if item.icon != null:
					var position := Vector2(-24 + (slot % 3) * 16, -20 + (slot / 3) * 20)
					draw_texture_rect(item.icon, Rect2(position, Vector2(16, 16)), false)
				break
			unit_index -= count
	# A small stock meter stays legible when looking at the shop from afar.
	draw_rect(Rect2(-25, 20, 50, 2), Color("#51483F"))
	if total > 0:
		var width := maxi(1, floori(50.0 * total / inventory.capacity))
		draw_rect(Rect2(-25, 20, width, 2), Color("#BCC5AC"))
