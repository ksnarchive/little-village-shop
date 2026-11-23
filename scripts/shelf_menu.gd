class_name ShelfMenu
extends VBoxContainer
## Catalog-driven view of the bag and the currently selected shelf.

var _bag: Inventory
var _shelf: ShopShelf
var _rows: Dictionary = {}

@onready var title: Label = %ShelfTitle
@onready var capacity_label: Label = %ShelfCapacity
@onready var fill_meter: ProgressBar = %ShelfFill
@onready var rows_container: VBoxContainer = %ShelfRows
@onready var message: Label = %ShelfMessage

func configure(catalog: ItemCatalog, bag: Inventory) -> void:
	_bag = bag
	for item in catalog.items:
		_add_row(item)
	_bag.changed.connect(_refresh)

func open_shelf(shelf: ShopShelf) -> void:
	release_shelf()
	_shelf = shelf
	_shelf.inventory.changed.connect(_refresh)
	for row in _rows.values():
		row["amount"] = 1
	message.remove_theme_color_override("font_color")
	message.text = "Choose a quantity, then stock the shelf or take goods back."
	_refresh()

func release_shelf() -> void:
	if is_instance_valid(_shelf):
		_shelf.inventory.changed.disconnect(_refresh)
	_shelf = null

func _add_row(item: ItemData) -> void:
	var card := PanelContainer.new()
	card.name = item.id
	card.theme_type_variation = &"OrderRow"
	rows_container.add_child(card)
	var row := HBoxContainer.new()
	row.name = "Row"
	row.add_theme_constant_override("separation", 8)
	card.add_child(row)
	var icon := TextureRect.new()
	icon.texture = item.icon
	icon.custom_minimum_size = Vector2(32, 32)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(icon)
	var details := VBoxContainer.new()
	details.name = "Details"
	details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	details.add_theme_constant_override("separation", 0)
	row.add_child(details)
	var product := Label.new()
	product.text = item.display_name
	product.tooltip_text = item.description
	details.add_child(product)
	var stock := Label.new()
	stock.name = "Stock"
	stock.add_theme_font_size_override("font_size", 12)
	details.add_child(stock)
	var stepper := HBoxContainer.new()
	stepper.name = "Quantity"
	stepper.add_theme_constant_override("separation", 3)
	row.add_child(stepper)
	var less := _button("Less", "−", "Select one fewer %s" % item.display_name)
	less.pressed.connect(_adjust.bind(item.id, -1))
	stepper.add_child(less)
	var quantity := Label.new()
	quantity.name = "Amount"
	quantity.custom_minimum_size.x = 24
	quantity.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stepper.add_child(quantity)
	var more := _button("More", "+", "Select one more %s" % item.display_name)
	more.pressed.connect(_adjust.bind(item.id, 1))
	stepper.add_child(more)
	var deposit := _button("Deposit", "Stock", "Move %s from bag to shelf" % item.display_name)
	deposit.theme_type_variation = &"OrderButton"
	deposit.custom_minimum_size.x = 60
	deposit.pressed.connect(_transfer.bind(item.id, false))
	row.add_child(deposit)
	var take := _button("Take", "Take", "Return %s from shelf to bag" % item.display_name)
	take.custom_minimum_size.x = 60
	take.pressed.connect(_transfer.bind(item.id, true))
	row.add_child(take)
	_rows[item.id] = {"stock": stock, "less": less, "more": more,
		"quantity": quantity, "deposit": deposit, "take": take, "amount": 1}

func _button(node_name: String, text: String, tooltip: String) -> Button:
	var button := Button.new()
	button.name = node_name
	button.text = text
	button.tooltip_text = tooltip
	button.theme_type_variation = &"QuantityButton"
	button.custom_minimum_size = Vector2(30, 30)
	return button

func _can_move(item_id: StringName, amount: int, from_shelf: bool) -> bool:
	var source := _shelf.inventory if from_shelf else _bag
	var destination := _bag if from_shelf else _shelf.inventory
	return source.can_remove(item_id, amount) and destination.can_add(item_id, amount)

func _can_select(item_id: StringName, amount: int) -> bool:
	return _can_move(item_id, amount, false) or _can_move(item_id, amount, true)

func _adjust(item_id: StringName, delta: int) -> void:
	if not is_visible_in_tree() or not is_instance_valid(_shelf):
		return
	var row: Dictionary = _rows[item_id]
	var next := int(row["amount"]) + delta
	if next >= 1 and (delta < 0 or _can_select(item_id, next)):
		row["amount"] = next
	_refresh()

func _transfer(item_id: StringName, from_shelf: bool) -> void:
	if not is_visible_in_tree() or not is_instance_valid(_shelf):
		return
	var source := _shelf.inventory if from_shelf else _bag
	var destination := _bag if from_shelf else _shelf.inventory
	var amount: int = _rows[item_id]["amount"]
	# Revalidate at the model boundary even if the button was previously enabled.
	if source.transfer_to(destination, item_id, amount):
		message.add_theme_color_override("font_color", Color("#45603c"))
		message.text = "Returned to bag: %d units." % amount if from_shelf else "Placed on shelf: %d units." % amount
	else:
		message.add_theme_color_override("font_color", Color("#8a3e2d"))
		message.text = "Not enough goods or room for this quantity."

func _refresh() -> void:
	if not is_instance_valid(_shelf):
		return
	var stock := _shelf.inventory
	title.text = _shelf.display_name
	var state: String = ["Empty", "Partly stocked", "Full"][_shelf.fill_state()]
	capacity_label.text = "%s  ·  Shelf %d / %d  ·  Bag %d / %d" % [
		state, stock.total_units(), stock.capacity, _bag.total_units(), _bag.capacity]
	fill_meter.max_value = maxi(1, stock.capacity)
	fill_meter.value = stock.total_units()
	for item_id in _rows:
		var row: Dictionary = _rows[item_id]
		# Keep selections valid after a transfer or any external stock change.
		while row["amount"] > 1 and not _can_select(item_id, row["amount"]):
			row["amount"] -= 1
		var amount: int = row["amount"]
		row["stock"].text = "Bag %d  ·  Shelf %d" % [_bag.quantity(item_id), stock.quantity(item_id)]
		row["quantity"].text = str(amount)
		row["less"].disabled = amount <= 1
		row["more"].disabled = not _can_select(item_id, amount + 1)
		row["deposit"].disabled = not _can_move(item_id, amount, false)
		row["take"].disabled = not _can_move(item_id, amount, true)
