extends Control
signal finished
## Entry supplies an atomic checkpoint callback; failed writes never advance UI.
var appearance := CharacterAppearance.DEFAULT.duplicate()
var line := 0
var animated := true
var checkpoint: Callable
var view: Control
var dialogue: PanelContainer
var words: Label
var heading: Label
var counter: Label
var next_button: Button
var skip_button: Button
var modal: ColorRect
var confirm_button: Button
var cancel_button: Button
var fade: ColorRect
var error: Label
var sound: AudioStreamPlayer
var _letters := 0.0
var _braking := 0.0
var _ending := false
var _transitioning := false

func _ready() -> void:
	theme = InventoryMenu.cozy_theme()
	mouse_filter = Control.MOUSE_FILTER_STOP
	view = Control.new()
	view.set_script(preload("res://scripts/train_view.gd"))
	view.appearance = appearance.duplicate()
	view.animated = animated
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(view)
	skip_button = FrontendUI.button("Пропустить…", request_skip)
	skip_button.add_theme_font_size_override("font_size", 12)
	add_child(skip_button)
	dialogue = PanelContainer.new()
	dialogue.add_theme_stylebox_override("panel", InventoryMenu._style(Color("#e9dfc8"), Color("#80604b"), 10))
	dialogue.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(dialogue)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 3)
	dialogue.add_child(box)
	var row := HBoxContainer.new()
	box.add_child(row)
	heading = FrontendUI.label("", 12)
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(heading)
	counter = FrontendUI.label("", 12)
	row.add_child(counter)
	words = FrontendUI.label("", 14)
	words.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	words.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(words)
	var foot := HBoxContainer.new()
	box.add_child(foot)
	error = FrontendUI.label("", 12)
	error.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	error.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	foot.add_child(error)
	next_button = FrontendUI.button("Далее  ›", advance)
	next_button.add_theme_font_size_override("font_size", 14)
	foot.add_child(next_button)
	_build_modal()
	fade = ColorRect.new()
	fade.color = Color("#282c29")
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fade)
	FrontendUI.full(fade)
	fade.modulate.a = 1
	create_tween().tween_property(fade, "modulate:a", 0.0, 0.8)
	sound = AudioStreamPlayer.new()
	var loop: AudioStreamWAV = preload("res://assets/train/rails.wav").duplicate()
	loop.loop_mode = AudioStreamWAV.LOOP_FORWARD
	loop.loop_begin = 0
	loop.loop_end = int(loop.get_length() * loop.mix_rate)
	sound.stream = loop
	sound.volume_db = -12
	add_child(sound)
	sound.play()
	dialogue.minimum_size_changed.connect(_layout.call_deferred)
	resized.connect(_layout)
	_layout()
	_show_line()
	# Mouse, keyboard and screen touch all share one advance path. Only GUI
	# controls handle their own presses, preventing a skip click from advancing.
	next_button.grab_focus()

func _build_modal() -> void:
	modal = ColorRect.new()
	modal.color = Color(0.12, 0.15, 0.12, 0.78)
	add_child(modal)
	FrontendUI.full(modal)
	var panel := PanelContainer.new()
	panel.name = "Confirmation"
	modal.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)
	box.add_child(FrontendUI.label("Пропустить поездку?", 20))
	var hint := FrontendUI.label("История продолжится в лавке.\nК поездке можно вернуться в новой игре.", 14)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.custom_minimum_size.x = 290
	box.add_child(hint)
	cancel_button = FrontendUI.button("Остаться в поезде", cancel_skip)
	box.add_child(cancel_button)
	confirm_button = FrontendUI.button("Пропустить вступление", _finish)
	box.add_child(confirm_button)
	modal.hide()

func _layout() -> void:
	if dialogue == null:
		return
	var portrait := size.x < 540
	var font_size := 16 if portrait else 14
	if words.get_theme_font_size("font_size") != font_size:
		words.add_theme_font_size_override("font_size", font_size)
	words.custom_minimum_size.x = maxf(100, size.x - 40)
	error.custom_minimum_size.x = maxf(80, size.x - 150)
	var height := 236.0 if portrait else 138.0
	view.position = Vector2.ZERO
	view.size = Vector2(size.x, size.y - height + 8)
	dialogue.position = Vector2(10, size.y - height - 8)
	dialogue.size = Vector2(size.x - 20, height)
	skip_button.position = Vector2(size.x - 130, 8)
	skip_button.size = Vector2(120, 44)
	var panel := modal.get_node("Confirmation") as PanelContainer
	panel.size = Vector2(minf(352, size.x - 24), 236)
	panel.position = (size - panel.size) / 2

func _show_line() -> void:
	heading.text = "ОБЪЯВЛЕНИЕ В ВАГОНЕ" if line == TrainStory.LAST_LINE else "%s · ПРО СЕБЯ" % appearance.name
	counter.text = "%02d / %02d" % [line + 1, TrainStory.LAST_LINE + 1]
	words.text = TrainStory.ARRIVAL if line == TrainStory.LAST_LINE else TrainStory.THOUGHTS[line]
	_letters = 0
	words.visible_characters = 0 if animated else -1
	error.text = "Коснитесь экрана · Enter / Пробел" if size.x >= 540 else "Коснитесь экрана"
	next_button.text = "В лавку  ›" if line == TrainStory.LAST_LINE else "Далее  ›"
	_layout.call_deferred()
	if line == TrainStory.LAST_LINE:
		_braking = 0.001

func _process(delta: float) -> void:
	if _ending or modal.visible:
		return
	if words.visible_characters >= 0:
		_letters += delta * 52.0
		words.visible_characters = int(_letters)
		if words.visible_characters >= words.get_total_character_count():
			words.visible_characters = -1
	if _braking > 0:
		_braking += delta
		view.speed = maxf(0, 1.0 - _braking / 3.5)
		sound.pitch_scale = 0.75 + view.speed * 0.25
		sound.volume_db = -12 - (1.0 - view.speed) * 12

func advance() -> void:
	if _ending or _transitioning or modal.visible:
		return
	if words.visible_characters >= 0:
		words.visible_characters = -1
		return
	if line == TrainStory.LAST_LINE:
		if _braking < 3.5:
			error.text = "Поезд замедляется…"
			return
		_finish()
		return
	_transitioning = true
	if checkpoint.call(line + 1, false):
		line += 1
		_show_line()
	else:
		error.text = "Не удалось сохранить. Нажмите «Далее», чтобы повторить."
	_transitioning = false

func request_skip() -> void:
	if _ending:
		return
	modal.show()
	cancel_button.grab_focus()

func cancel_skip() -> void:
	modal.hide()
	next_button.grab_focus()

func _finish() -> void:
	if _ending or _transitioning:
		return
	_transitioning = true
	if not checkpoint.call(TrainStory.LAST_LINE, true):
		modal.hide()
		error.text = "Не удалось сохранить. Попробуйте ещё раз."
		_transitioning = false
		return
	_ending = true
	modal.hide()
	skip_button.disabled = true
	next_button.disabled = true
	var tween := create_tween().set_parallel(true)
	tween.tween_property(fade, "modulate:a", 1.0, 1.2)
	tween.tween_property(sound, "volume_db", -60.0, 1.2)
	await tween.finished
	finished.emit()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if modal.visible:
			cancel_skip()
		else:
			request_skip()
	elif not modal.visible and ((event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_ENTER, KEY_SPACE, KEY_E]) or (event is InputEventMouseButton and event.device != -1 and event.pressed and event.button_index == MOUSE_BUTTON_LEFT) or (event is InputEventScreenTouch and event.pressed)):
		advance()
	else:
		return
	get_viewport().set_input_as_handled()

# Touch already advances on press. Ignore its synthesized mouse twin (device -1).
func _gui_input(event: InputEvent) -> void:
	if (event is InputEventMouseButton and event.device != -1 and event.pressed and event.button_index == MOUSE_BUTTON_LEFT) or (event is InputEventScreenTouch and event.pressed):
		advance()
		accept_event()
