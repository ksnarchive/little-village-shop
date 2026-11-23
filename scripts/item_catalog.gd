class_name ItemCatalog
extends Resource
## Add a product resource to data/item_catalog.tres; consumers need no changes.

@export var items: Array[ItemData] = []

func is_valid() -> bool:
	var seen: Dictionary = {}
	for item in items:
		if item == null or not item.is_valid() or seen.has(item.id):
			return false
		seen[item.id] = true
	return not items.is_empty()

func find(item_id: StringName) -> ItemData:
	for item in items:
		if item != null and item.id == item_id:
			return item
	return null
