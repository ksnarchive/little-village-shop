class_name VillageStation
extends Node2D
## A compact, uninhabited first outdoor location. No shop time passes here.
signal travel_requested(destination: String)
const OUT := "res://assets/outdoors/"
const THOUGHTS := [
	"Никого. Даже таблички «Добро пожаловать, новый лавочник». Что ж, торжественную речь можно не репетировать.",
	"Воздух пахнет листьями и дымом. А вдруг эта затея всё-таки была хорошей идеей?",
	"Лавка где-то в деревне. Начнём с указателя — у него, кажется, план надёжнее моего."
]
var appearance := CharacterAppearance.DEFAULT.duplicate()
var state := LocationState.fresh("station")
var bag: Inventory
var checkpoint: Callable
var player: Shopkeeper
var camera: FollowCamera
var ui: ExplorationUI
var carriage: Sprite2D
var nature: AudioStreamPlayer
var wheels: AudioStreamPlayer
var elapsed := 0.0
var _save_elapsed := 0.0
var _thought_elapsed := 0.0
var _wind_time := 0.0
var _leaves: Array[Sprite2D] = []
var leaving := false
var _saved_state := {}

func _ready() -> void:
	_build_ground()
	_build_props()
	player = preload("res://scenes/characters/player.tscn").instantiate()
	player.z_index = 0 # Outdoor props and actor share ground-point Y sorting.
	player.position = Vector2(state.position[0], state.position[1])
	player.set_appearance(appearance)
	add_child(player)
	player.controls_enabled = float(state.arrival_time) >= 0.8
	camera = FollowCamera.new()
	camera.zoom = Vector2(1.6, 1.6)
	camera.world_bounds = LocationState.STATION_BOUNDS
	camera.target = player
	add_child(camera)
	ui = ExplorationUI.new()
	add_child(ui)
	ui.modal_changed.connect(_modal_changed)
	ui.save_requested.connect(save_checkpoint)
	player.get_node("InteractionController").target_changed.connect(func(target: Interactable):
		ui.set_prompt(target.prompt if target != null else ""))
	elapsed = float(state.arrival_time)
	_saved_state = state.duplicate(true)
	_sound()
	_update_arrival()
	_show_thought()

func _texture(name: String) -> Texture2D:
	return load(OUT + name + ".png")

func _tile(name: String, rect: Rect2) -> void:
	var sprite := Sprite2D.new()
	sprite.texture = _texture(name)
	sprite.centered = false
	sprite.position = rect.position
	sprite.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	sprite.region_enabled = true
	sprite.region_rect = Rect2(Vector2.ZERO, rect.size)
	sprite.z_index = -20
	add_child(sprite)

func _solid(rect: Rect2) -> void:
	var body := StaticBody2D.new()
	body.collision_layer = 2
	body.collision_mask = 0
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = rect.size
	shape.shape = box
	shape.position = rect.get_center()
	body.add_child(shape)
	add_child(body)

func _build_ground() -> void:
	_tile("grass", LocationState.STATION_BOUNDS)
	_tile("track", Rect2(0, 80, 720, 80))
	_tile("platform", Rect2(40, 160, 640, 146))
	_tile("path", Rect2(310, 290, 84, 132))
	_tile("path", Rect2(354, 370, 366, 64))
	_solid(Rect2(0, 148, 720, 12)) # Never walk onto rails, even after departure.
	_solid(Rect2(0, 0, 8, 480))
	_solid(Rect2(712, 0, 8, 480))
	_solid(Rect2(0, 472, 720, 8))
	# This exit is a destination ID. It does not know the temporary target scene.
	var exit := Area2D.new()
	exit.name = "VillageExit"
	exit.collision_layer = 0
	exit.collision_mask = 1
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = Vector2(28, 64)
	shape.shape = box
	shape.position = Vector2(690, 402)
	exit.add_child(shape)
	exit.body_entered.connect(func(body: Node2D):
		if body == player and not leaving:
			leaving = true
			_modal_changed(true)
			travel_requested.emit("village"))
	add_child(exit)

func _prop(name: String, at: Vector2, footprint: Rect2, wind: bool = false) -> OutdoorProp:
	var prop := OutdoorProp.new()
	prop.name = name.to_pascal_case()
	prop.texture = _texture(name)
	prop.position = at
	prop.footprint = footprint
	prop.wind = wind
	if name.ends_with("tree"):
		prop.shadow = _texture(name + "_shadow")
	add_child(prop)
	return prop

func _endpoint(at: Vector2, prompt: String, title: String, text: String, bounds: Rect2) -> void:
	var point := Interactable.new()
	point.position = at
	point.prompt = prompt
	point.sign_icon = "book"
	point.art_bounds = bounds
	point.interacted.connect(func(_actor: Node2D): ui.show_message(title, text))
	add_child(point)

func _build_props() -> void:
	_prop("station", Vector2(166, 380), Rect2(-100, -74, 200, 74))
	_prop("bench", Vector2(410, 292), Rect2(-40, -13, 80, 13))
	_prop("bench", Vector2(594, 220), Rect2(-40, -13, 80, 13))
	_prop("timetable", Vector2(510, 282), Rect2(-30, -10, 60, 10))
	var sign := _prop("sign", Vector2(466, 397), Rect2(-5, -8, 10, 8))
	var direction := Label.new()
	direction.theme = InventoryMenu.cozy_theme()
	direction.text = "Деревня"
	direction.add_theme_font_size_override("font_size", 8)
	direction.position = Vector2(-22, -63)
	sign.add_child(direction)
	for at: Vector2 in [Vector2(302, 302), Vector2(652, 292), Vector2(86, 188)]:
		_prop("lamp", at, Rect2(-5, -8, 10, 8))
	for at: Vector2 in [Vector2(284, 300), Vector2(78, 392), Vector2(540, 281)]:
		_prop("pots", at, Rect2(-14, -9, 28, 9))
	for at: Vector2 in [Vector2(64, 126), Vector2(696, 142), Vector2(52, 468)]:
		_prop("gold_tree", at, Rect2(-12, -12, 24, 16), true)
	for at: Vector2 in [Vector2(638, 474), Vector2(604, 352), Vector2(232, 105)]:
		_prop("red_tree", at, Rect2(-12, -12, 24, 16), true)
	for at: Vector2 in [Vector2(130, 464), Vector2(246, 460), Vector2(565, 358), Vector2(695, 347), Vector2(352, 80)]:
		_prop("shrub", at, Rect2(-23, -16, 46, 16), true)
	for at: Vector2 in [Vector2(113, 450), Vector2(210, 450), Vector2(518, 455)]:
		_prop("fence", at, Rect2(-46, -10, 92, 10))
	for at: Vector2 in [Vector2(310, 280), Vector2(566, 280), Vector2(350, 362), Vector2(527, 416)]:
		_prop("leaves", at, Rect2())
	_endpoint(Vector2(166, 401), "E  Осмотреть вокзал", "Старый вокзал", "Дверь заперта. За стеклом — билетный компостер и кружка с засохшим чаем.\nПохоже, здесь умеют никуда не спешить.", Rect2(-112, -201, 224, 180))
	_endpoint(Vector2(510, 306), "E  Прочитать расписание", "Расписание", "Деревенская линия · платформа 1\nУтренний поезд — 08:00. Вечерний — 18:40.\nМежду ними вполне поместится новая жизнь.", Rect2(-38, -128, 76, 104))
	_endpoint(Vector2(467, 422), "E  Прочитать указатель", "В деревню >", "По дорожке направо — деревня и старая лавка у площади.\nПора взглянуть, на что ушли все мои сбережения.", Rect2(-26, -111, 52, 86))
	carriage = Sprite2D.new()
	carriage.texture = _texture("carriage")
	carriage.position = Vector2(360, 102)
	carriage.scale.y = 112.0 / 166.0
	carriage.z_index = -3
	add_child(carriage)
	for index in range(10):
		var leaf := Sprite2D.new()
		leaf.texture = _texture("leaf")
		leaf.z_index = 3
		add_child(leaf)
		_leaves.append(leaf)

func _sound() -> void:
	nature = AudioStreamPlayer.new()
	var loop: AudioStreamWAV = preload("res://assets/station/nature.wav").duplicate()
	loop.loop_mode = AudioStreamWAV.LOOP_FORWARD
	loop.loop_end = int(loop.get_length() * loop.mix_rate)
	nature.stream = loop
	nature.volume_db = -12
	add_child(nature)
	nature.play()
	wheels = AudioStreamPlayer.new()
	var rails: AudioStreamWAV = preload("res://assets/train/rails.wav").duplicate()
	rails.loop_mode = AudioStreamWAV.LOOP_FORWARD
	rails.loop_end = int(rails.get_length() * rails.mix_rate)
	wheels.stream = rails
	add_child(wheels)
	if elapsed < 10:
		wheels.play()

func _show_thought() -> void:
	ui.thought.visible = int(state.thought) < THOUGHTS.size()
	if ui.thought.visible:
		ui.thought.text = THOUGHTS[int(state.thought)]

func _update_arrival() -> void:
	var departure := clampf((elapsed - 4.0) / 6.0, 0, 1)
	carriage.visible = departure < 1
	carriage.position.x = 360 + (departure * departure * 800 if CharacterArt.motion_enabled(self) else 0.0)
	carriage.modulate.a = 1.0 if CharacterArt.motion_enabled(self) else 1.0 - departure
	wheels.volume_db = -24 - departure * 40
	wheels.pitch_scale = 0.7 + departure * 0.3
	if elapsed >= 10 and wheels.playing:
		wheels.stop()

func _process(delta: float) -> void:
	if leaving or ui.modal.visible:
		return
	elapsed = minf(10, elapsed + delta)
	_update_arrival()
	if elapsed >= 0.8:
		player.controls_enabled = true
	_thought_elapsed += delta
	if int(state.thought) < 3 and _thought_elapsed >= 6:
		state.thought = int(state.thought) + 1
		_thought_elapsed = 0
		_show_thought()
	var animated := CharacterArt.motion_enabled(self)
	if animated:
		_wind_time += delta
	for index in range(_leaves.size()):
		var leaf := _leaves[index]
		leaf.visible = animated
		if leaf.visible:
			leaf.position = Vector2(fposmod(index * 71 + _wind_time * 7, 710), 165 + fposmod(index * 43 + _wind_time * 11, 305))
	_save_elapsed += delta
	if _save_elapsed >= 1:
		_save_elapsed = 0
		save_checkpoint()

func snapshot() -> Dictionary:
	return {"location": "station", "position": [player.position.x, player.position.y],
		"arrival_time": elapsed, "thought": int(state.thought)}

func save_checkpoint() -> bool:
	var next := snapshot()
	if next == _saved_state:
		return true
	if checkpoint.is_valid() and checkpoint.call(next):
		_saved_state = next
		ui.notice.text = "Путь сохранён · станция"
		return true
	ui.notice.text = "Не удалось сохранить. Повторите через меню (Esc)."
	return false

func _modal_changed(open: bool) -> void:
	player.controls_enabled = not open and not leaving and elapsed >= 0.8
	player.get_node("InteractionController").enabled = player.controls_enabled
	ui.thought.visible = not open and int(state.thought) < THOUGHTS.size()

func _unhandled_input(event: InputEvent) -> void:
	if leaving or event.is_echo():
		return
	if event.is_action_pressed("ui_cancel"):
		if ui.modal.visible:
			ui.close()
		else:
			save_checkpoint()
			ui.show_message("Пауза · станция", "Найти купленную лавку.\nДорожка направо ведёт в деревню.\nПрогресс на станции сохраняется автоматически.", "pause")
	elif event.is_action_pressed("inventory"):
		if ui.modal.visible:
			ui.close()
		else:
			var text := "В кармане — ключ от лавки и смятое объявление."
			if bag != null:
				for item in bag._catalog.items:
					if bag.quantity(item.id) > 0:
						text += "\n%s: %d" % [item.display_name, bag.quantity(item.id)]
			ui.show_message("Рюкзак", text, "bag")
	else:
		return
	get_viewport().set_input_as_handled()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and is_instance_valid(player) and is_instance_valid(ui) and not leaving:
		save_checkpoint()
