extends Node
## Application entry. Gameplay scenes remain reusable and have no implicit disk access.
var shop: Node2D
var store := SaveStore.new()
var menu: CanvasLayer
var content: VBoxContainer
var continue_button: Button
var new_button: Button
var confirm_button: Button
var cancel_button: Button
var status: Label

func _ready() -> void:
	shop = preload("res://scenes/main.tscn").instantiate()
	add_child(shop)
	shop.process_mode = Node.PROCESS_MODE_DISABLED
	shop.inventory_ui.get_node("Root").hide()
	shop.save_store = store
	_build_menu()
	refresh()

func _build_menu() -> void:
	menu = CanvasLayer.new()
	menu.layer = 10
	add_child(menu)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.theme = InventoryMenu.cozy_theme()
	menu.add_child(root)
	var shade := ColorRect.new()
	shade.color = Color("#253528b8")
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = 420
	center.add_child(panel)
	content = VBoxContainer.new()
	content.add_theme_constant_override("separation", 10)
	panel.add_child(content)
	var title := Label.new()
	title.text = "Little Village Shop"
	title.add_theme_font_size_override("font_size", 27)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(title)
	var subtitle := Label.new()
	subtitle.text = "Ваш маленький магазин ждёт вас"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(subtitle)
	status = Label.new()
	status.custom_minimum_size.x = 396
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(status)
	continue_button = _button("Продолжить", continue_game)
	new_button = _button("Новая игра", request_new_game)
	confirm_button = _button("Начать заново", confirm_new_game)
	cancel_button = _button("Отмена", refresh)

func _button(text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.pressed.connect(action)
	content.add_child(button)
	return button

func refresh() -> void:
	var data := store.read_save(shop)
	continue_button.disabled = data.is_empty()
	status.text = store.message if data.is_empty() or store.recovered else "День %d · сохранение готово" % int(data.day)
	continue_button.show()
	new_button.show()
	confirm_button.hide()
	cancel_button.hide()
	if continue_button.disabled:
		new_button.grab_focus()
	else:
		continue_button.grab_focus()

func continue_game() -> void:
	if not store.load_game(shop):
		refresh()
		return
	_start()

func request_new_game() -> void:
	if store.exists():
		status.text = "Начать с первого утра? Прежний прогресс будет заменён новым сохранением."
		continue_button.hide()
		new_button.hide()
		confirm_button.show()
		cancel_button.show()
		cancel_button.grab_focus()
	else:
		confirm_new_game()

func confirm_new_game() -> void:
	# Fresh scene, same room and systems. Existing save is only replaced after confirmation.
	shop.free()
	shop = preload("res://scenes/main.tscn").instantiate()
	add_child(shop)
	shop.save_store = store
	shop.save_game()
	_start()

func _start() -> void:
	shop.process_mode = Node.PROCESS_MODE_INHERIT
	shop.inventory_ui.get_node("Root").show()
	menu.hide()
	# Report restoration may have paused the simulation; ordinary loads restore controls.
	shop._on_menu_visibility_changed(shop.inventory_ui.view != InventoryMenu.View.CLOSED)
