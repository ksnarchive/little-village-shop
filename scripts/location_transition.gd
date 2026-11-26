class_name LocationTransition
extends CanvasLayer
## One fade boundary for outdoor/interior travel; destinations are stable IDs.
const DESTINATIONS := {"village": "shop"} # Replace with the village street when built.
var busy := false
var shade: ColorRect

static func release_movement() -> void:
	# Godot 4.3: clear both action state and physical WASD/arrow state.
	for code in [KEY_W, KEY_A, KEY_S, KEY_D, KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT]:
		var event := InputEventKey.new()
		event.physical_keycode = code
		event.keycode = code
		event.pressed = false
		Input.parse_input_event(event)
	Input.flush_buffered_events()
	for action in ["ui_left", "ui_right", "ui_up", "ui_down"]:
		Input.action_release(action)

func _ready() -> void:
	layer = 30
	shade = ColorRect.new()
	shade.color = Color("#282c29")
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.modulate.a = 0

func cover() -> Signal:
	busy = true
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	var tween := create_tween()
	tween.tween_property(shade, "modulate:a", 1.0, 0.55)
	return tween.finished

func reveal() -> Signal:
	busy = true
	shade.modulate.a = 1
	var tween := create_tween()
	tween.tween_property(shade, "modulate:a", 0.0, 0.7)
	tween.finished.connect(_revealed)
	return tween.finished

func _revealed() -> void:
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	busy = false
