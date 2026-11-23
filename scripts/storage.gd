class_name ShopStorage
extends Interactable
## One reusable storage object with the same Inventory model as the player's bag.

@export var catalog: ItemCatalog
@export var capacity: int = 60
@export var initial_stock: Dictionary = {}
var inventory: Inventory

func _ready() -> void:
	super._ready()
	inventory = Inventory.new(catalog, capacity)
	if not inventory.restore({"items": initial_stock}):
		push_error("Storage initial stock is invalid; inventory left empty.")

func _draw() -> void:
	# Preserve the existing green storage fixture's footprint and palette.
	draw_rect(Rect2(-32, -16, 64, 32), Color("#765238"))
	draw_rect(Rect2(-29, -13, 58, 26), Color("#8dab78"))
