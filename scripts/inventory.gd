class_name Inventory
extends RefCounted
## Capacity counts units, with one stack per product ID in this first slice.
## All mutations either complete in full or leave both inventories unchanged.

signal changed

var capacity: int:
	get:
		return _capacity

var _catalog: ItemCatalog
var _capacity: int
var _quantities: Dictionary = {}

func _init(catalog: ItemCatalog, maximum_units: int = 24) -> void:
	_catalog = catalog
	_capacity = maxi(0, maximum_units)

func quantity(item_id: StringName) -> int:
	return int(_quantities.get(String(item_id), 0))

func total_units() -> int:
	var total: int = 0
	for amount in _quantities.values():
		total += int(amount)
	return total

func can_add(item_id: StringName, amount: int) -> bool:
	var item := _catalog.find(item_id)
	return (item != null and amount > 0
		and amount <= _capacity - total_units()
		and amount <= item.max_stack_size - quantity(item_id))

func can_remove(item_id: StringName, amount: int) -> bool:
	return _catalog.find(item_id) != null and amount > 0 and amount <= quantity(item_id)

func add(item_id: StringName, amount: int) -> bool:
	if not can_add(item_id, amount):
		return false
	_set_quantity(item_id, quantity(item_id) + amount)
	changed.emit()
	return true

func remove(item_id: StringName, amount: int) -> bool:
	if not can_remove(item_id, amount):
		return false
	_set_quantity(item_id, quantity(item_id) - amount)
	changed.emit()
	return true

func transfer_to(target: Inventory, item_id: StringName, amount: int) -> bool:
	if target == null or target == self or not can_remove(item_id, amount):
		return false
	# Both sides must agree on the product definition (including stack limits).
	if target._catalog.find(item_id) != _catalog.find(item_id) or not target.can_add(item_id, amount):
		return false
	_set_quantity(item_id, quantity(item_id) - amount)
	target._set_quantity(item_id, target.quantity(item_id) + amount)
	# Observers always see the completed transaction, never a partial transfer.
	changed.emit()
	target.changed.emit()
	return true

func serialize() -> Dictionary:
	return {"items": _quantities.duplicate()}

func restore(data: Dictionary) -> bool:
	# Validate a candidate first; malformed saves cannot partially alter stock.
	if not data.get("items") is Dictionary:
		return false
	var candidate: Dictionary = {}
	var total: int = 0
	for key in data["items"]:
		if not key is String:
			return false
		var item := _catalog.find(StringName(key))
		var raw: Variant = data["items"][key]
		if item == null or (not raw is int and not raw is float):
			return false
		# JSON numbers decode as floats. Accept only finite, positive whole units.
		if not is_finite(float(raw)) or raw <= 0 or raw > _capacity or raw != floor(float(raw)):
			return false
		var amount := int(raw)
		if amount > item.max_stack_size or amount > _capacity - total:
			return false
		candidate[key] = amount
		total += amount
	if candidate != _quantities:
		_quantities = candidate
		changed.emit()
	return true

func _set_quantity(item_id: StringName, amount: int) -> void:
	if amount == 0:
		_quantities.erase(String(item_id))
	else:
		_quantities[String(item_id)] = amount
