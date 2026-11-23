class_name SupplierMenu
extends VBoxContainer

var _storage: Inventory
var _economy: ShopEconomy
var _rows: Dictionary = {}

@onready var storage_label: Label = %OrderStorage
@onready var balance_label: Label = %OrderBalance
@onready var rows_container: VBoxContainer = %OrderRows
@onready var message: Label = %OrderMessage

func configure(catalog: ItemCatalog, storage: Inventory, economy: ShopEconomy) -> void:
	_storage = storage
	_economy = economy
	for item in catalog.items:
		_add_row(item)
	_storage.changed.connect(_refresh)
	_refresh()

func reset_order() -> void:
	for row in _rows.values():
		row["amount"] = 1
	message.remove_theme_color_override("font_color")
	message.text = "Orders go straight to the stockroom."
	_refresh()

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
	var less := _button("Less", "−", "Order one fewer %s" % item.display_name)
	less.pressed.connect(_adjust.bind(item.id, -1))
	stepper.add_child(less)
	var quantity := Label.new()
	quantity.name = "Amount"
	quantity.custom_minimum_size.x = 24
	quantity.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stepper.add_child(quantity)
	var more := _button("More", "+", "Order one more %s" % item.display_name)
	more.pressed.connect(_adjust.bind(item.id, 1))
	stepper.add_child(more)
	var total := Label.new()
	total.name = "Total"
	total.custom_minimum_size.x = 70
	total.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(total)
	var buy := _button("Buy", "Order", "Order %s" % item.display_name)
	buy.theme_type_variation = &"OrderButton"
	buy.custom_minimum_size.x = 62
	buy.pressed.connect(_buy.bind(item.id))
	row.add_child(buy)
	_rows[item.id] = {
		"item": item, "stock": stock, "less": less, "more": more,
		"quantity": quantity, "total": total, "amount": 1,
		"limit": mini(_storage.capacity, item.max_stack_size)
	}

func _button(node_name: String, text: String, tooltip: String) -> Button:
	var button := Button.new()
	button.name = node_name
	button.text = text
	button.tooltip_text = tooltip
	button.theme_type_variation = &"QuantityButton"
	button.custom_minimum_size = Vector2(30, 30)
	InventoryMenu.fit_web_button(button)
	return button

func _adjust(item_id: StringName, delta: int) -> void:
	var row: Dictionary = _rows[item_id]
	row["amount"] = clampi(int(row["amount"]) + delta, 1, maxi(1, row["limit"]))
	_refresh()

func _buy(item_id: StringName) -> void:
	if not is_visible_in_tree():
		return
	var row: Dictionary = _rows[item_id]
	var item: ItemData = row["item"]
	var amount: int = row["amount"]
	message.add_theme_color_override("font_color", Color("#8a3e2d"))
	match _economy.buy(item_id, amount):
		ShopEconomy.PurchaseResult.SUCCESS:
			message.add_theme_color_override("font_color", Color("#45603c"))
			message.text = "Delivered to storage: %s × %d." % [item.display_name, amount]
		ShopEconomy.PurchaseResult.INSUFFICIENT_FUNDS:
			message.text = "You don't have enough coins for this order."
		ShopEconomy.PurchaseResult.INSUFFICIENT_SPACE:
			message.text = "There isn't enough room in storage for this order."
		_:
			message.text = "This order couldn't be placed."

func _refresh() -> void:
	storage_label.text = "Storage  %d / %d units" % [_storage.total_units(), _storage.capacity]
	for item_id in _rows:
		var row: Dictionary = _rows[item_id]
		var item: ItemData = row["item"]
		var amount: int = row["amount"]
		var cost := _economy.order_cost(item, amount)
		row["stock"].text = "%d / unit  ·  %d in stock" % [item.purchase_price, _storage.quantity(item_id)]
		row["quantity"].text = str(amount)
		row["total"].text = "%d coins" % cost if cost >= 0 else "Over budget"
		row["less"].disabled = amount <= 1
		row["more"].disabled = amount >= row["limit"]
