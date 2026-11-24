class_name VillagerArt
extends RefCounted
## Shared original 24x32 atlas. Only rendering is quantized; physics stays continuous.
const ATLAS: Texture2D = preload("res://assets/characters/villagers.png")

static func draw_actor(canvas: CanvasItem, variant: int, facing: Vector2, walking: bool, step: float) -> void:
	var direction := 0
	if absf(facing.x) > absf(facing.y):
		direction = 2 if facing.x < 0 else 3
	elif facing.y < -0.3:
		direction = 1
	var frame := (1 if sin(step) > 0.0 else 2) if walking else 0
	canvas.draw_texture_rect_region(ATLAS, Rect2(-12, -20, 24, 32),
		Rect2((direction * 3 + frame) * 24, variant * 32, 24, 32))
