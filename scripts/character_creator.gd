extends Control
signal confirmed(appearance: Dictionary)
signal cancelled
var appearance := CharacterAppearance.DEFAULT.duplicate()
var rng := RandomNumberGenerator.new()
var preview: Control
var name_input: LineEdit
var confirm_button: Button
var error: Label
var choices := {}
var panel: PanelContainer
var turn_row: HBoxContainer
var back_button: Button
var random_button: Button
var scroll: ScrollContainer
var walk_button: Button

func _ready() -> void:
	theme = InventoryMenu.cozy_theme()
	rng.randomize()
	var background := TextureRect.new()
	background.texture = preload("res://assets/frontend/dressing_room.png")
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.modulate = Color("#b6ad98")
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	FrontendUI.full(background)
	preview = Control.new()
	preview.set_script(preload("res://scripts/character_preview.gd"))
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(preview)
	panel = PanelContainer.new()
	add_child(panel)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 4)
	panel.add_child(content)
	content.add_child(FrontendUI.label("Ваш новый облик", 22))
	var hint := FrontendUI.label("Варианты ниже · прокрутите список", 12)
	content.add_child(hint)
	scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	content.add_child(scroll)
	var fields := VBoxContainer.new()
	fields.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fields.add_theme_constant_override("separation", 3)
	scroll.add_child(fields)
	var name_row := HBoxContainer.new()
	fields.add_child(name_row)
	name_row.add_child(FrontendUI.label("Имя"))
	name_input = LineEdit.new()
	name_input.add_theme_stylebox_override("normal", InventoryMenu._style(Color("#F0E7D4"), Color("#A5977D"), 6))
	name_input.add_theme_stylebox_override("focus", InventoryMenu._style(Color("#F5ECD9"), Color("#80604B"), 6))
	name_input.add_theme_color_override("font_color", Color("#51483F"))
	name_input.add_theme_color_override("caret_color", Color("#80604B"))
	name_input.placeholder_text = "Как вас зовут?"
	name_input.text = appearance.name
	name_input.max_length = 24
	name_input.virtual_keyboard_enabled = true
	name_input.custom_minimum_size.y = 44
	name_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_input.text_changed.connect(_name_changed)
	name_row.add_child(name_input)
	for key in ["skin", "hairstyle", "hair_color", "eyes", "outfit"]:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 3)
		fields.add_child(row)
		var previous := FrontendUI.button("‹", _cycle.bind(key, -1))
		previous.tooltip_text = "Предыдущий вариант"
		row.add_child(previous)
		var choice := FrontendUI.button("", _cycle.bind(key, 1))
		choice.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		choice.clip_text = true
		choice.add_theme_font_size_override("font_size", 14)
		row.add_child(choice)
		choices[key] = choice
		var next := FrontendUI.button("›", _cycle.bind(key, 1))
		next.tooltip_text = "Следующий вариант"
		row.add_child(next)
	error = FrontendUI.label("", 12)
	error.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(error)
	var actions := HBoxContainer.new()
	content.add_child(actions)
	back_button = FrontendUI.button("Назад", func(): cancelled.emit())
	actions.add_child(back_button)
	random_button = FrontendUI.button("Случайно", randomize_appearance)
	random_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_child(random_button)
	confirm_button = FrontendUI.button("Всё готово — в лавку", _confirm)
	content.add_child(confirm_button)
	turn_row = HBoxContainer.new()
	turn_row.add_theme_constant_override("separation", 4)
	add_child(turn_row)
	turn_row.add_child(FrontendUI.button("‹", _turn.bind(-1)))
	walk_button = FrontendUI.button("Походка", _toggle_walk)
	turn_row.add_child(walk_button)
	turn_row.add_child(FrontendUI.button("›", _turn.bind(1)))
	resized.connect(_layout)
	_layout()
	_refresh()

func _layout() -> void:
	if panel == null:
		return
	var portrait := size.x < 540
	if portrait:
		var art_height := minf(300, size.y * 0.4)
		preview.position = Vector2(0, 0)
		preview.size = Vector2(size.x, art_height)
		turn_row.position = Vector2((size.x - 188) / 2, art_height - 44)
		panel.position = Vector2(8, art_height + 4)
		panel.size = Vector2(size.x - 16, size.y - art_height - 12)
	else:
		preview.position = Vector2(8, 4)
		preview.size = Vector2(size.x * 0.44 - 16, size.y - 8)
		turn_row.position = Vector2((size.x * 0.44 - 188) / 2, size.y - 48)
		panel.position = Vector2(size.x * 0.44, 6)
		panel.size = Vector2(size.x * 0.56 - 8, size.y - 12)

func _cycle(key: String, delta: int) -> void:
	appearance[key] = posmod(int(appearance[key]) + delta, int(CharacterAppearance.LIMITS[key]))
	_refresh()

func _name_changed(value: String) -> void:
	appearance.name = CharacterAppearance.clean_name(value)
	confirm_button.disabled = appearance.name.is_empty()
	error.text = "Введите имя, чтобы отправиться в лавку." if confirm_button.disabled else ""

func _refresh() -> void:
	var names := {"skin": "Кожа", "hairstyle": "Причёска", "hair_color": "Волосы", "eyes": "Глаза", "outfit": "Одежда"}
	for key in choices:
		var index := int(appearance[key])
		var detail := "%d / %d" % [index + 1, CharacterAppearance.LIMITS[key]]
		if key == "skin":
			detail = ["Фарфор", "Персик", "Мёд", "Карамель", "Каштан", "Какао"][index]
		elif key == "hair_color":
			detail = ["Тёмный", "Каштан", "Орех", "Пшеница", "Лён", "Медь", "Пепел", "Седина"][index]
		elif key == "eyes":
			detail = ["Карие", "Зелёные", "Голубые", "Серые", "Янтарные", "Тёмные"][index]
		if key == "hairstyle":
			detail = CharacterAppearance.HAIRSTYLES[index]
		elif key == "outfit":
			detail = CharacterAppearance.OUTFITS[index]
		choices[key].text = names[key] + ": " + detail
		choices[key].tooltip_text = choices[key].text
	preview.appearance = appearance.duplicate()
	preview.queue_redraw()

func randomize_appearance() -> void:
	appearance = CharacterAppearance.randomized(rng, appearance.name)
	_refresh()

func _turn(delta: int) -> void:
	var directions := [Vector2.DOWN, Vector2.LEFT, Vector2.UP, Vector2.RIGHT]
	preview.facing = directions[posmod(directions.find(preview.facing) + delta, 4)]
	preview.queue_redraw()

func _toggle_walk() -> void:
	preview.walking = not preview.walking
	walk_button.text = "Стоять" if preview.walking else "Походка"

func _confirm() -> void:
	_name_changed(name_input.text)
	if CharacterAppearance.valid(appearance):
		confirmed.emit(appearance.duplicate())

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		cancelled.emit()
		get_viewport().set_input_as_handled()
