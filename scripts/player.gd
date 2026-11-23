extends CharacterBody2D
## Keyboard-controlled shopkeeper. No external art required.
const SPEED: float = 95.0
var facing: Vector2 = Vector2.DOWN
var walking: bool = false
var step_time: float = 0.0

func _physics_process(delta: float) -> void:
    var direction := Vector2.ZERO
    direction.x = Input.get_axis("ui_left", "ui_right")
    direction.y = Input.get_axis("ui_up", "ui_down")
    direction = direction.normalized()
    velocity = direction * SPEED
    walking = direction.length_squared() > 0.0
    if walking:
        facing = direction
        step_time += delta * 12.0
    move_and_slide()
    queue_redraw()

func _draw() -> void:
    # Shadow, boots, body, hair and face: deliberately tiny pixel-art shapes.
    draw_ellipse_shadow()
    var bob := 1.0 if walking and sin(step_time) > 0.0 else 0.0
    draw_rect(Rect2(-5, 5 + bob, 4, 5), Color("#4e4139"))
    draw_rect(Rect2(1, 5 - bob, 4, 5), Color("#4e4139"))
    draw_rect(Rect2(-7, -4, 14, 11), Color("#668568"))
    draw_rect(Rect2(-5, -12, 10, 10), Color("#e8b88f"))
    draw_rect(Rect2(-6, -14, 12, 5), Color("#513a31"))
    draw_rect(Rect2(-6, -11, 3, 5), Color("#513a31"))
    draw_rect(Rect2(3, -11, 3, 5), Color("#513a31"))
    if facing.y >= -0.3:
        draw_rect(Rect2(-3, -7, 2, 2), Color("#49382d"))
        draw_rect(Rect2(2, -7, 2, 2), Color("#49382d"))

func draw_ellipse_shadow() -> void:
    draw_circle(Vector2(0, 10), 7.0, Color(0.2, 0.15, 0.1, 0.22))
