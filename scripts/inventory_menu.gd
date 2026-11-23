class_name InventoryMenu
extends CanvasLayer
## Routes the shop's modal views and shows the world HUD.

signal menu_visibility_changed(is_open: bool)

enum View { CLOSED, BAG, STORAGE, SUPPLIER, SHELF }
var view: View = View.CLOSED
var _bag: Inventory
var _storage: Inventory
var _rows: Dictionary = {}
var _prompt_text: String = ""

@onready var panel: PanelContainer = %Panel
@onready var inventory_content: VBoxContainer = %InventoryContent
@onready var supplier_menu: SupplierMenu = %SupplierMenu
@onready var shelf_menu: ShelfMenu = %ShelfMenu
@onready var supplier_shade: ColorRect = %SupplierShade
@onready var balance_card: PanelContainer = %BalanceCard
@onready var balance_label: Label = %Balance
@onready var controls_hint: Label = %Hint
@onready var title: Label = %Title
@onready var capacity_label: Label = %Capacity
@onready var rows_container: VBoxContainer = %Rows
@onready var message: Label = %Message
@onready var prompt_label: Label = %Prompt
@onready var close_button: Button = %Close

func _ready() -> void:
	_apply_theme()
	close_button.pressed.connect(close_menu)

func configure(catalog: ItemCatalog, bag: Inventory, storage: Inventory) -> void:
	_bag = bag
	_storage = storage
	for item in catalog.items:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var icon := TextureRect.new()
		icon.texture = item.icon
		icon.custom_minimum_size = Vector2(20, 20)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		row.add_child(icon)
		var product := Label.new()
		product.text = item.display_name
		product.tooltip_text = item.description
		product.custom_minimum_size.x = 55
		row.add_child(product)
		var quantities := Label.new()
		quantities.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(quantities)
		var take := Button.new()
		take.text = "Take 1"
		take.pressed.connect(_transfer.bind(item.id, true))
		row.add_child(take)
		var deposit := Button.new()
		deposit.text = "Store 1"
		deposit.pressed.connect(_transfer.bind(item.id, false))
		row.add_child(deposit)
		rows_container.add_child(row)
		_rows[item.id] = {"quantities": quantities, "take": take, "deposit": deposit}
	_bag.changed.connect(_refresh)
	_storage.changed.connect(_refresh)
	_refresh()

func configure_supplier(catalog: ItemCatalog, storage: Inventory, economy: ShopEconomy) -> void:
	supplier_menu.configure(catalog, storage, economy)
	economy.balance_changed.connect(_update_balance)
	_update_balance(economy.balance)

func configure_shelves(catalog: ItemCatalog, bag: Inventory) -> void:
	shelf_menu.configure(catalog, bag)

func open_shelf(shelf: ShopShelf) -> void:
	shelf_menu.open_shelf(shelf)
	_open(View.SHELF)

func open_storage() -> void:
	_open(View.STORAGE)

func open_inventory() -> void:
	_open(View.BAG)

func open_supplier() -> void:
	supplier_menu.reset_order()
	_open(View.SUPPLIER)

func _open(next_view: View) -> void:
	view = next_view
	inventory_content.visible = view in [View.BAG, View.STORAGE]
	shelf_menu.visible = view == View.SHELF
	supplier_menu.visible = view == View.SUPPLIER
	var has_shade := view in [View.SUPPLIER, View.SHELF]
	supplier_shade.visible = has_shade
	balance_card.visible = not has_shade
	controls_hint.visible = not has_shade
	panel.custom_minimum_size.x = 536 if view == View.SHELF else 462
	panel.show()
	if inventory_content.visible:
		message.text = "Move one item at a time." if view == View.STORAGE else "Visit storage to collect or return goods."
		_refresh()
	close_button.grab_focus()
	menu_visibility_changed.emit(true)
	set_prompt(_prompt_text)

func close_menu() -> void:
	if view == View.CLOSED:
		return
	view = View.CLOSED
	shelf_menu.release_shelf()
	panel.hide()
	supplier_shade.hide()
	balance_card.show()
	controls_hint.show()
	close_button.release_focus()
	menu_visibility_changed.emit(false)
	set_prompt(_prompt_text)

func set_prompt(text: String) -> void:
	_prompt_text = text
	prompt_label.text = text if view == View.CLOSED else ""

func _update_balance(coins: int) -> void:
	balance_label.text = "%d coins" % coins
	supplier_menu.balance_label.text = balance_label.text

func _unhandled_input(event: InputEvent) -> void:
	if event.is_echo():
		return
	if event.is_action_pressed("inventory"):
		if view == View.CLOSED:
			open_inventory()
		else:
			close_menu()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel") and view != View.CLOSED:
		close_menu()
		get_viewport().set_input_as_handled()

func _transfer(item_id: StringName, from_storage: bool) -> void:
	if view != View.STORAGE:
		return
	var source := _storage if from_storage else _bag
	var destination := _bag if from_storage else _storage
	if source.transfer_to(destination, item_id, 1):
		message.text = "Moved to bag." if from_storage else "Returned to storage."
	else:
		message.text = "No stock or destination is full."

func _refresh() -> void:
	if _bag == null:
		return
	title.text = "Village stockroom" if view == View.STORAGE else "Your bag"
	capacity_label.text = "Bag: %d / %d units" % [_bag.total_units(), _bag.capacity]
	if view == View.STORAGE:
		capacity_label.text += "     Storage: %d / %d" % [_storage.total_units(), _storage.capacity]
	for item_id in _rows:
		var row: Dictionary = _rows[item_id]
		var quantities: Label = row["quantities"]
		var take: Button = row["take"]
		var deposit: Button = row["deposit"]
		quantities.text = "x %d" % _bag.quantity(item_id)
		if view == View.STORAGE:
			quantities.text = "Bag %d | Stock %d" % [_bag.quantity(item_id), _storage.quantity(item_id)]
		take.visible = view == View.STORAGE
		deposit.visible = view == View.STORAGE
		take.disabled = not (_storage.can_remove(item_id, 1) and _bag.can_add(item_id, 1))
		deposit.disabled = not (_bag.can_remove(item_id, 1) and _storage.can_add(item_id, 1))

func _apply_theme() -> void:
	var cozy := Theme.new()
	cozy.default_font_size = 14
	cozy.set_color("font_color", "Label", Color("#513a31"))
	var frame := _style(Color("#f1deb7"), Color("#765238"), 12)
	cozy.set_stylebox("panel", "PanelContainer", frame)
	cozy.set_stylebox("normal", "Button", _style(Color("#82936b"), Color("#61734f"), 6))
	cozy.set_stylebox("hover", "Button", _style(Color("#9daf84"), Color("#61734f"), 6))
	cozy.set_stylebox("pressed", "Button", _style(Color("#a8664e"), Color("#765238"), 6))
	cozy.set_stylebox("disabled", "Button", _style(Color("#d6c6a9"), Color("#b8a88c"), 6))
	var focus := _style(Color(0, 0, 0, 0), Color("#a8664e"), 6)
	cozy.set_stylebox("focus", "Button", focus)
	cozy.set_color("font_color", "Button", Color("#fff2d7"))
	cozy.set_color("font_hover_color", "Button", Color("#513a31"))
	cozy.set_color("font_disabled_color", "Button", Color("#847764"))
	for variation in [&"BalanceCard", &"OrderHeader", &"OrderRow"]:
		cozy.set_type_variation(variation, &"PanelContainer")
	cozy.set_stylebox("panel", &"BalanceCard", _style(Color("#f5e4bd"), Color("#765238"), 5))
	cozy.set_stylebox("panel", &"OrderHeader", _style(Color("#d9dfbc"), Color("#9aa779"), 8))
	cozy.set_stylebox("panel", &"OrderRow", _style(Color("#fff0cf"), Color("#dcc39a"), 6))
	cozy.set_type_variation(&"QuantityButton", &"Button")
	cozy.set_stylebox("normal", &"QuantityButton", _style(Color("#d9dfbc"), Color("#9aa779"), 4))
	cozy.set_color("font_color", &"QuantityButton", Color("#3d4933"))
	cozy.set_type_variation(&"OrderButton", &"Button")
	cozy.set_stylebox("normal", &"OrderButton", _style(Color("#5e704c"), Color("#4a5e3f"), 4))
	cozy.set_stylebox("background", "ProgressBar", _style(Color("#c6b18a"), Color("#9d7455"), 0))
	cozy.set_stylebox("fill", "ProgressBar", _style(Color("#82936b"), Color("#61734f"), 0))
	$Root.theme = cozy

func _style(fill: Color, border: Color, padding: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(2)
	style.content_margin_left = padding
	style.content_margin_right = padding
	style.content_margin_top = padding
	style.content_margin_bottom = padding
	return style
