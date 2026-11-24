class_name Shopkeeper
extends CharacterBody2D
## Keyboard-controlled shopkeeper with persistent, aligned pixel appearance layers.
const SPEED: float = 95.0
var appearance := CharacterAppearance.DEFAULT.duplicate()

func set_appearance(value: Dictionary) -> void:
    if CharacterAppearance.valid(value):
        appearance = {"name": value.name}
        for key in CharacterAppearance.LIMITS:
            appearance[key] = int(value[key])
        queue_redraw()

var facing: Vector2 = Vector2.DOWN
var walking: bool = false
var step_time: float = 0.0
var controls_enabled: bool = true

func _physics_process(delta: float) -> void:
    if not controls_enabled:
        velocity = Vector2.ZERO
        walking = false
        queue_redraw()
        return
    # Physical keys work on non-English keyboard layouts, too.
    var direction := Vector2(
        float(Input.is_physical_key_pressed(KEY_D) or Input.is_action_pressed("ui_right")) -
        float(Input.is_physical_key_pressed(KEY_A) or Input.is_action_pressed("ui_left")),
        float(Input.is_physical_key_pressed(KEY_S) or Input.is_action_pressed("ui_down")) -
        float(Input.is_physical_key_pressed(KEY_W) or Input.is_action_pressed("ui_up"))
    ).normalized()
    velocity = direction * SPEED
    walking = direction.length_squared() > 0.0
    if walking:
        facing = direction
        step_time += delta * 12.0
    move_and_slide()
    queue_redraw()

func _draw() -> void:
    CharacterArt.draw_actor(self, appearance, facing, walking, step_time)
