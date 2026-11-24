extends Control
## The preview and moving player share the exact same atlas renderer.
var appearance := CharacterAppearance.DEFAULT.duplicate()
var facing := Vector2.DOWN
var walking := false
var elapsed := 0.0

func _process(delta: float) -> void:
	elapsed += delta * 8.0
	queue_redraw()

func _draw() -> void:
	var zoom := minf(size.x / 288.0, size.y / 320.0)
	var offset := (size - Vector2(288, 320) * zoom) / 2.0
	draw_texture_rect(preload("res://assets/frontend/dressing_room.png"), Rect2(offset, Vector2(288, 320) * zoom), false)
	# Reflection is a mirrored aligned actor, tinted by the old glass.
	draw_set_transform(offset + Vector2(117, 176) * zoom, 0.0, Vector2(-1, 1))
	CharacterArt.draw_actor(self, appearance, facing, walking, elapsed, Vector2(-24, -40) * zoom, 2.0 * zoom)
	draw_set_transform(Vector2.ZERO)
	CharacterArt.draw_actor(self, appearance, facing, walking, elapsed, offset + Vector2(94, 203) * zoom, 2.0 * zoom)
