class_name InventoryMenu
extends CanvasLayer
## Routes the shop's modal views and shows the world HUD.

signal menu_visibility_changed(is_open: bool)

enum View { CLOSED, BAG, STORAGE, SUPPLIER, SHELF, CHECKOUT, DAY_END, PAUSE }
var view: View = View.CLOSED
signal save_requested

var pause_content: VBoxContainer
var save_button: Button
var save_notice: Label
var report_save_status: Label
var save_status: Label
var _day: ShopDay
@onready var clock_card: PanelContainer = %ClockCard
@onready var clock_label: Label = %Clock
@onready var phase_label: Label = %DayPhase
@onready var day_report: VBoxContainer = %DayReport
@onready var next_day_button: Button = %DayReport/NextDay

var _bag: Inventory
var _storage: Inventory
var _rows: Dictionary = {}
var _prompt_text: String = ""
var _touch_mode := false

@onready var panel: PanelContainer = %Panel
@onready var inventory_content: VBoxContainer = %InventoryContent
@onready var supplier_menu: SupplierMenu = %SupplierMenu
@onready var checkout_menu: CheckoutMenu = %CheckoutMenu
@onready var sales_label: Label = %SalesStatus
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
@onready var checkout_label: Label = %CheckoutStatus

func _ready() -> void:
	_apply_theme()
	_style_hud()
	_touch_mode = OS.has_feature("web") and bool(JavaScriptBridge.eval("document.body.classList.contains('touch')"))
	controls_hint.text = "Удерживайте стрелки, чтобы идти" if _touch_mode else "WASD / стрелки — идти     I — рюкзак     Esc — меню"
	close_button.pressed.connect(close_menu)
	_build_pause_menu()
	for button in [close_button, save_button, next_day_button, checkout_menu.serve_button]:
		fit_web_button(button)

func configure(catalog: ItemCatalog, bag: Inventory, storage: Inventory) -> void:
	_bag = bag
	_storage = storage
	for item in catalog.items:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var icon := TextureRect.new()
		icon.texture = item.icon
		icon.custom_minimum_size = Vector2(16, 16)
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
		take.text = "Взять 1"
		take.pressed.connect(_transfer.bind(item.id, true))
		fit_web_button(take)
		row.add_child(take)
		var deposit := Button.new()
		deposit.text = "Убрать 1"
		deposit.pressed.connect(_transfer.bind(item.id, false))
		fit_web_button(deposit)
		row.add_child(deposit)
		rows_container.add_child(row)
		_rows[item.id] = {"quantities": quantities, "take": take, "deposit": deposit}
	_bag.changed.connect(_refresh)
	_storage.changed.connect(_refresh)
	_refresh()

func configure_day(day: ShopDay) -> void:
	_day = day
	day.clock_changed.connect(_update_clock)
	day.day_finished.connect(show_day_report)
	day.day_started.connect(_dismiss_day_report)
	next_day_button.pressed.connect(day.start_next_day)
	_update_clock()

func _update_clock() -> void:
	clock_label.text = "День %d · %s" % [_day.day_number, _day.time_text()]
	phase_label.text = ["Открытие в 09:00", "Лавка открыта", "Обеденный час", "Тихий вечер", "Закрываемся", "День завершён"][_day.phase]

func show_day_report(report: Dictionary) -> void:
	# Close any service panel before locking the modal to the finished report.
	close_menu()
	var totals: GridContainer = day_report.get_node("Totals")
	for child in totals.get_children():
		totals.remove_child(child)
		child.queue_free()
	var names := ["Завершённый день", "Обслужено покупателей", "Выручка", "Закупки", "Прибыль", "Баланс магазина"]
	var keys := ["day", "customers", "revenue", "expenses", "profit", "balance"]
	for index in range(keys.size()):
		var label := Label.new()
		label.text = names[index]
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		totals.add_child(label)
		var value := Label.new()
		value.text = str(report[keys[index]]) + (" монет" if index >= 2 else "")
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		totals.add_child(value)
	_open(View.DAY_END)
	next_day_button.grab_focus()

func _dismiss_day_report() -> void:
	# Only ShopDay.day_started can dismiss the report; Esc/I cannot skip it.
	view = View.BAG
	close_menu()

func configure_supplier(catalog: ItemCatalog, storage: Inventory, economy: ShopEconomy) -> void:
	supplier_menu.configure(catalog, storage, economy)
	economy.balance_changed.connect(_update_balance)
	_update_balance(economy.balance)

func configure_shelves(catalog: ItemCatalog, bag: Inventory) -> void:
	shelf_menu.configure(catalog, bag)

func configure_checkout(flow: CustomerFlow, economy: ShopEconomy) -> void:
	checkout_menu.configure(flow, economy)
	economy.sales_changed.connect(_update_sales)
	flow.sale_completed.connect(_sale_feedback)
	_update_sales(economy.revenue, economy.completed_sales)

func open_checkout() -> void:
	if view == View.DAY_END:
		return
	checkout_menu.open_checkout()
	_open(View.CHECKOUT)

func _update_sales(revenue: int, sales: int) -> void:
	sales_label.text = "Выручка %d · Продаж %d" % [revenue, sales]

func _sale_feedback(_item: ItemData, _customer: ShopCustomer) -> void:
	var effect: Control = Control.new()
	effect.set_script(preload("res://scripts/coin_effect.gd"))
	$Root.add_child(effect)
	effect.position = panel.position + Vector2(panel.size.x - 40, 84)

func open_shelf(shelf: ShopShelf) -> void:
	if view == View.DAY_END:
		return
	shelf_menu.open_shelf(shelf)
	_open(View.SHELF)

func open_storage() -> void:
	if view == View.DAY_END:
		return
	_open(View.STORAGE)

func open_inventory() -> void:
	if view == View.DAY_END:
		return
	_open(View.BAG)

func open_supplier() -> void:
	if view == View.DAY_END:
		return
	supplier_menu.reset_order()
	_open(View.SUPPLIER)

func _open(next_view: View) -> void:
	if view == View.DAY_END:
		return
	view = next_view
	checkout_label.hide()
	sales_label.hide()
	inventory_content.visible = view in [View.BAG, View.STORAGE]
	shelf_menu.visible = view == View.SHELF
	supplier_menu.visible = view == View.SUPPLIER
	checkout_menu.visible = view == View.CHECKOUT
	day_report.visible = view == View.DAY_END
	pause_content.visible = view == View.PAUSE
	close_button.visible = view != View.DAY_END
	clock_card.visible = view != View.DAY_END
	var has_shade := view in [View.SUPPLIER, View.SHELF, View.CHECKOUT, View.DAY_END, View.PAUSE]
	supplier_shade.visible = has_shade
	balance_card.visible = not has_shade
	controls_hint.visible = not has_shade
	panel.custom_minimum_size.x = 536 if view == View.SHELF else 462
	save_notice.hide()
	panel.show()
	if inventory_content.visible:
		message.text = "Переносите товары по одному." if view == View.STORAGE else "Товары можно взять в кладовой."
		_refresh()
	close_button.grab_focus()
	menu_visibility_changed.emit(true)
	set_prompt(_prompt_text)

func close_menu() -> void:
	if view in [View.CLOSED, View.DAY_END]:
		return
	view = View.CLOSED
	checkout_label.show()
	sales_label.show()
	shelf_menu.release_shelf()
	panel.hide()
	save_notice.show()
	day_report.hide()
	pause_content.hide()
	close_button.show()
	clock_card.show()
	supplier_shade.hide()
	balance_card.show()
	controls_hint.show()
	close_button.release_focus()
	menu_visibility_changed.emit(false)
	set_prompt(_prompt_text)

func set_prompt(text: String) -> void:
	_prompt_text = text
	prompt_label.text = (text.trim_prefix("E  ") if _touch_mode else text) if view == View.CLOSED else ""
	prompt_label.visible = not prompt_label.text.is_empty()
	if OS.has_feature("web"):
		var action := text.trim_prefix("E  ") if view == View.CLOSED else ""
		JavaScriptBridge.eval("window.setShopAction && window.setShopAction(%s)" % JSON.stringify(action))

func set_checkout_waiting(waiting: int) -> void:
	checkout_label.text = "В очереди: %d / 3" % waiting

func _update_balance(coins: int) -> void:
	balance_label.text = "%d монет" % coins
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
	elif event.is_action_pressed("ui_cancel"):
		if view == View.CLOSED:
			open_pause()
		else:
			close_menu()
		get_viewport().set_input_as_handled()

func _transfer(item_id: StringName, from_storage: bool) -> void:
	if view != View.STORAGE:
		return
	var source := _storage if from_storage else _bag
	var destination := _bag if from_storage else _storage
	if source.transfer_to(destination, item_id, 1):
		message.text = "Товар в рюкзаке." if from_storage else "Товар в кладовой."
	else:
		message.text = "Нет товара или свободного места."

func _refresh() -> void:
	if _bag == null:
		return
	title.text = "Кладовая" if view == View.STORAGE else "Рюкзак"
	capacity_label.text = "Рюкзак: %d / %d" % [_bag.total_units(), _bag.capacity]
	if view == View.STORAGE:
		capacity_label.text += "     Склад: %d / %d" % [_storage.total_units(), _storage.capacity]
	for item_id in _rows:
		var row: Dictionary = _rows[item_id]
		var quantities: Label = row["quantities"]
		var take: Button = row["take"]
		var deposit: Button = row["deposit"]
		quantities.text = "x %d" % _bag.quantity(item_id)
		if view == View.STORAGE:
			quantities.text = "С собой %d | Склад %d" % [_bag.quantity(item_id), _storage.quantity(item_id)]
		take.visible = view == View.STORAGE
		deposit.visible = view == View.STORAGE
		take.disabled = not (_storage.can_remove(item_id, 1) and _bag.can_add(item_id, 1))
		deposit.disabled = not (_bag.can_remove(item_id, 1) and _storage.can_add(item_id, 1))

# Web controls stay large enough to tap; catalog rows already scroll vertically.
static func fit_web_button(button: Button) -> void:
	if OS.has_feature("web"):
		button.custom_minimum_size = button.custom_minimum_size.max(Vector2(44, 44))

func _style_hud() -> void:
	for label in [controls_hint, checkout_label, sales_label, prompt_label]:
		label.remove_theme_color_override("font_color")
		label.remove_theme_color_override("font_shadow_color")
		label.add_theme_font_size_override("font_size", 14)
	controls_hint.add_theme_stylebox_override("normal", _style(Color("#E9DFC8"), Color("#A8B4B1"), 4))
	prompt_label.add_theme_stylebox_override("normal", _style(Color("#E9DFC8"), Color("#B7795F"), 5))
	for label in [checkout_label, sales_label]:
		label.add_theme_stylebox_override("normal", _style(Color("#E9DFC8"), Color("#B7795F"), 3))
	prompt_label.hide()

func _apply_theme() -> void:
	$Root.theme = cozy_theme()

static func cozy_theme() -> Theme:
	var cozy := Theme.new()
	cozy.default_font_size = 16
	var pixel_font := preload("res://assets/fonts/VillagePixel-Regular.ttf")
	cozy.default_font = pixel_font
	cozy.set_color("font_color", "Label", Color("#51483F"))
	# Bound ledger paper: margins keep text clear of the binding.
	var frame := StyleBoxTexture.new()
	frame.texture = preload("res://assets/ui/panel.png")
	frame.texture_margin_left = 8
	frame.texture_margin_right = 8
	frame.texture_margin_top = 8
	frame.texture_margin_bottom = 8
	frame.content_margin_left = 18
	frame.content_margin_right = 14
	frame.content_margin_top = 12
	frame.content_margin_bottom = 12
	cozy.set_stylebox("panel", "PanelContainer", frame)
	cozy.set_stylebox("normal", "Button", _style(Color("#BCC5AC"), Color("#879575"), 6))
	cozy.set_stylebox("hover", "Button", _style(Color("#CDD3BE"), Color("#879575"), 6))
	cozy.set_stylebox("pressed", "Button", _style(Color("#A8B4B1"), Color("#80604B"), 6))
	cozy.set_stylebox("disabled", "Button", _style(Color("#D8D2C3"), Color("#BAB5A7"), 6))
	var focus := _style(Color(0, 0, 0, 0), Color("#80604B"), 6)
	focus.shadow_size = 0
	focus.shadow_color = Color(0, 0, 0, 0)
	cozy.set_stylebox("focus", "Button", focus)
	cozy.set_color("font_color", "Button", Color("#51483F"))
	cozy.set_color("font_hover_color", "Button", Color("#51483F"))
	cozy.set_color("font_pressed_color", "Button", Color("#51483F"))
	cozy.set_color("font_focus_color", "Button", Color("#51483F"))
	cozy.set_color("font_disabled_color", "Button", Color("#918B7D"))
	for variation in [&"BalanceCard", &"ClockCard", &"OrderHeader", &"OrderRow"]:
		cozy.set_type_variation(variation, &"PanelContainer")
	cozy.set_stylebox("panel", &"ClockCard", _style(Color("#E9DFC8"), Color("#80604B"), 0))
	cozy.set_stylebox("panel", &"BalanceCard", _style(Color("#E9DFC8"), Color("#80604B"), 5))
	cozy.set_stylebox("panel", &"OrderHeader", _style(Color("#D8DDCF"), Color("#A8B4B1"), 8))
	cozy.set_stylebox("panel", &"OrderRow", _style(Color("#F0E7D4"), Color("#C5B494"), 6))
	cozy.set_type_variation(&"QuantityButton", &"Button")
	cozy.set_stylebox("normal", &"QuantityButton", _style(Color("#D8DDCF"), Color("#A8B4B1"), 4))
	cozy.set_color("font_color", &"QuantityButton", Color("#51483F"))
	cozy.set_type_variation(&"OrderButton", &"Button")
	cozy.set_stylebox("normal", &"OrderButton", _style(Color("#BCC5AC"), Color("#879575"), 4))
	cozy.set_stylebox("background", "ProgressBar", _style(Color("#D3C8AE"), Color("#A5977D"), 0))
	cozy.set_stylebox("fill", "ProgressBar", _style(Color("#BCC5AC"), Color("#879575"), 0))
	return cozy

static func _style(fill: Color, border: Color, padding: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(1)
	style.corner_radius_top_left = 1
	style.corner_radius_top_right = 1
	style.corner_radius_bottom_left = 1
	style.corner_radius_bottom_right = 1
	style.corner_detail = 1
	style.anti_aliasing = false
	style.shadow_color = Color("#493e3038")
	style.shadow_size = 2
	style.shadow_offset = Vector2(0, 2)
	style.content_margin_left = padding
	style.content_margin_right = padding
	style.content_margin_top = padding
	style.content_margin_bottom = padding
	return style

func _build_pause_menu() -> void:
	pause_content = VBoxContainer.new()
	pause_content.add_theme_constant_override("separation", 12)
	panel.get_node("Content").add_child(pause_content)
	panel.get_node("Content").move_child(pause_content, 0)
	var heading := Label.new()
	heading.text = "Тихая пауза"
	heading.add_theme_font_size_override("font_size", 22)
	pause_content.add_child(heading)
	save_status = Label.new()
	save_status.custom_minimum_size.x = 420
	save_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	pause_content.add_child(save_status)
	save_button = Button.new()
	save_button.text = "Сохранить игру"
	save_button.pressed.connect(func(): save_requested.emit())
	pause_content.add_child(save_button)
	pause_content.hide()
	report_save_status = day_report.get_node("Footer")
	report_save_status.custom_minimum_size.x = 420
	report_save_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	save_notice = Label.new()
	save_notice.position = Vector2(12, 295)
	save_notice.size.x = 230
	save_notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	save_notice.add_theme_font_size_override("font_size", 11)
	save_notice.add_theme_color_override("font_color", Color("#51483F"))
	save_notice.add_theme_stylebox_override("normal", _style(Color("#E9DFC8"), Color("#A8B4B1"), 3))
	$Root.add_child(save_notice)

func open_pause() -> void:
	_open(View.PAUSE)
	if view == View.PAUSE:
		save_button.grab_focus()

func restore_view() -> void:
	# Discard transient menus/subscriptions/effects and reconstruct the report if needed.
	view = View.BAG
	close_menu()
	for child in $Root.get_children():
		if child.get_script() == preload("res://scripts/coin_effect.gd"):
			child.free()
	_update_clock()
	if _day.phase == ShopDay.Phase.SUMMARY:
		show_day_report(_day.report())
