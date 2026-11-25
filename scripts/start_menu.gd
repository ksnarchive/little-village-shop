extends Node
## Entry owns transitions; the shop never advances behind the frontend.
var shop: Node2D
var store := SaveStore.new()
var menu: CanvasLayer
var content: VBoxContainer
var continue_button: Button
var new_button: Button
var settings_button: Button
var confirm_button: Button
var cancel_button: Button
var status: Label
var root: Control
var panel: PanelContainer
var backdrop: Control
var train: Control
var creator: Control
var settings_panel: PanelContainer
var settings := ConfigFile.new()
var animations := true
var volume := 0.8
var _frontend := true

func _ready() -> void:
	settings.load("user://village_settings.cfg")
	animations = bool(settings.get_value("display", "animations", true))
	volume = clampf(float(settings.get_value("sound", "volume", 0.8)), 0, 1)
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(volume, 0.0001)))
	shop = preload("res://scenes/main.tscn").instantiate()
	add_child(shop)
	shop.process_mode = Node.PROCESS_MODE_DISABLED
	shop.inventory_ui.get_node("Root").hide()
	shop.save_store = store
	_build_menu()
	_set_frontend(true)
	refresh()

func _build_menu() -> void:
	menu = CanvasLayer.new()
	menu.layer = 10
	add_child(menu)
	root = Control.new()
	root.theme = InventoryMenu.cozy_theme()
	menu.add_child(root)
	FrontendUI.full(root)
	backdrop = Control.new()
	backdrop.set_script(preload("res://scripts/village_backdrop.gd"))
	backdrop.animated = animations
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(backdrop)
	FrontendUI.full(backdrop)
	panel = PanelContainer.new()
	root.add_child(panel)
	content = VBoxContainer.new()
	content.add_theme_constant_override("separation", 6)
	panel.add_child(content)
	var edition := FrontendUI.label("ОСЕНЬ В ДЕРЕВНЕ", 12)
	content.add_child(edition)
	var title := FrontendUI.label("Little Village Shop", 22)
	content.add_child(title)
	content.add_child(FrontendUI.label("Маленькая лавка, тёплые дни", 12))
	status = FrontendUI.label("", 12)
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.max_lines_visible = 3
	content.add_child(status)
	new_button = _button("Новая игра", request_new_game)
	continue_button = _button("Продолжить", continue_game)
	settings_button = _button("Настройки", open_settings)
	confirm_button = _button("Выбрать персонажа", confirm_new_game)
	cancel_button = _button("Отмена", refresh)
	root.resized.connect(_layout)
	_layout()

func _layout() -> void:
	if panel == null:
		return
	panel.position = Vector2(24, (root.size.y - 314) / 2)
	panel.size = Vector2(268, 314)
	if root.size.x < 540:
		panel.position = Vector2((root.size.x - 300) / 2, root.size.y - 332)
		panel.size = Vector2(300, 314)
	if settings_panel != null:
		settings_panel.size = Vector2(minf(380, root.size.x - 24), minf(330, root.size.y - 16))
		settings_panel.position = (root.size - settings_panel.size) / 2

func _button(text: String, action: Callable) -> Button:
	var button := FrontendUI.button(text, action)
	content.add_child(button)
	return button

func refresh() -> void:
	var data := store.read_save(shop)
	continue_button.disabled = data.is_empty()
	status.text = store.message if data.is_empty() or store.recovered else "День %d · %s" % [int(data.day), data.get("character", CharacterAppearance.DEFAULT).get("name", "Саша")]
	continue_button.show()
	new_button.show()
	settings_button.show()
	confirm_button.hide()
	cancel_button.hide()
	panel.show()
	_layout.call_deferred()
	if continue_button.disabled:
		new_button.grab_focus()
	else:
		continue_button.grab_focus()

func continue_game() -> void:
	if not store.load_game(shop):
		refresh()
		return
	_resume_story()

func request_new_game() -> void:
	if store.exists():
		status.text = "Новый герой начнёт с первого дня. Прогресс заменится только после подтверждения облика."
		continue_button.hide()
		new_button.hide()
		settings_button.hide()
		confirm_button.show()
		cancel_button.show()
		cancel_button.grab_focus()
	else:
		confirm_new_game()

func confirm_new_game() -> void:
	if creator != null:
		return
	panel.hide()
	creator = preload("res://scenes/character_creator.tscn").instantiate()
	root.add_child(creator)
	creator.confirmed.connect(_create_character)
	creator.cancelled.connect(_cancel_creator)
	# Opening the editor must not summon the mobile keyboard.
	creator.confirm_button.grab_focus()

func _cancel_creator() -> void:
	creator.hide()
	creator.queue_free()
	creator = null
	refresh()

func _create_character(appearance: Dictionary) -> void:
	if not CharacterAppearance.valid(appearance):
		return
	# Commit only after a successful atomic write. Failed I/O leaves the editor and old shop intact.
	var candidate := preload("res://scenes/main.tscn").instantiate()
	add_child(candidate)
	candidate.process_mode = Node.PROCESS_MODE_DISABLED
	candidate.inventory_ui.get_node("Root").hide()
	candidate.save_store = store
	candidate.player.set_appearance(appearance)
	candidate.story = TrainStory.fresh()
	if not candidate.save_game():
		creator.error.text = store.message
		candidate.free()
		return
	shop.free()
	shop = candidate
	creator.hide()
	creator.queue_free()
	creator = null
	_resume_story()

func _resume_story() -> void:
	if shop.story.train_complete:
		_start()
		return
	panel.hide()
	backdrop.hide()
	train = preload("res://scenes/train_intro.tscn").instantiate()
	train.appearance = shop.player.appearance.duplicate()
	train.line = int(shop.story.train_line)
	train.animated = animations
	train.checkpoint = _save_train_checkpoint
	root.add_child(train)
	train.finished.connect(_train_finished)

func _save_train_checkpoint(line: int, complete: bool) -> bool:
	var previous: Dictionary = shop.story.duplicate(true)
	shop.story = {"train_line": line, "train_complete": complete}
	if not shop.save_game():
		shop.story = previous
		return false
	return true

func _train_finished() -> void:
	train.hide()
	train.queue_free()
	train = null
	_start()

func _start() -> void:
	_set_frontend(false)
	shop.process_mode = Node.PROCESS_MODE_INHERIT
	shop.inventory_ui.get_node("Root").show()
	menu.hide()
	root.process_mode = Node.PROCESS_MODE_DISABLED
	shop._on_menu_visibility_changed(shop.inventory_ui.view != InventoryMenu.View.CLOSED)

func open_settings() -> void:
	panel.hide()
	settings_panel = PanelContainer.new()
	root.add_child(settings_panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	settings_panel.add_child(box)
	box.add_child(FrontendUI.label("Настройки", 24))
	var check := CheckButton.new()
	check.text = "Анимации пейзажа и поезда"
	check.custom_minimum_size.y = 44
	check.button_pressed = animations
	check.toggled.connect(func(value: bool):
		animations = value
		backdrop.animated = value
		_save_settings())
	box.add_child(check)
	box.add_child(FrontendUI.label("Громкость звука"))
	var slider := HSlider.new()
	slider.min_value = 0
	slider.max_value = 1
	slider.step = 0.05
	slider.value = volume
	slider.custom_minimum_size.y = 44
	slider.value_changed.connect(func(value: float):
		volume = value
		AudioServer.set_bus_volume_db(0, linear_to_db(maxf(value, 0.0001)))
		_save_settings())
	box.add_child(slider)
	var hint := FrontendUI.label("ПК: WASD или стрелки, E — действие.\nНа телефоне: экранные кнопки.", 14)
	hint.custom_minimum_size.x = 280
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(hint)
	box.add_child(FrontendUI.button("Готово", _close_settings))
	_layout()
	check.grab_focus()

func _close_settings() -> void:
	settings_panel.hide()
	settings_panel.queue_free()
	settings_panel = null
	refresh()

func _save_settings() -> void:
	settings.set_value("display", "animations", animations)
	settings.set_value("sound", "volume", volume)
	settings.save("user://village_settings.cfg")

func _set_frontend(active: bool) -> void:
	_frontend = active
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.setFrontend && window.setFrontend(%s)" % ("true" if active else "false"))
	_update_viewport()

func _process(_delta: float) -> void:
	if OS.has_feature("web"):
		_update_viewport()

func _update_viewport() -> void:
	if not OS.has_feature("web"):
		return
	var portrait := _frontend and bool(JavaScriptBridge.eval("window.isGamePortrait ? window.isGamePortrait() : window.innerHeight > window.innerWidth"))
	var target := Vector2i(400, 740) if portrait else Vector2i(640, 360)
	if get_viewport().content_scale_size != target:
		get_viewport().content_scale_size = target
		JavaScriptBridge.eval("window.resizeGame && window.resizeGame()")

func _unhandled_input(event: InputEvent) -> void:
	if _frontend and train == null and event.is_action_pressed("ui_cancel"):
		if settings_panel != null:
			_close_settings()
		elif creator == null:
			refresh()
		get_viewport().set_input_as_handled()
