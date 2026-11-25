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
	# The exact same registered actor appears in the glass and on the rug.
	draw_set_transform(offset + Vector2(89, 0) * zoom, 0.0, Vector2(-1, 1))
	CharacterArt.draw_actor(self, appearance, facing, walking, elapsed, Vector2(-44, 44) * zoom, 2.184 * zoom, elapsed / 8.0, false)
	draw_set_transform(Vector2.ZERO)
	# The portrait editor has a shallow art panel above its 44px turn controls.
	var compact := size.x > size.y
	# Compensate for the larger world scale: previews grow 30%, with fixed feet.
	var hero := Vector2(122, 105 if compact else 127)
	CharacterArt.draw_actor(self, appearance, facing, walking, elapsed, offset + hero * zoom, (2.73 if compact else 2.912) * zoom, elapsed / 8.0)
