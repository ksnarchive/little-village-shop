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
	draw_texture(preload("res://assets/shop/storage.png"), Vector2(-32, -16))
