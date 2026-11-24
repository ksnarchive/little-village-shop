extends Node2D
## Pixel corners and an object-specific sign track the real reachable interaction target.
var fixture: Interactable
var bounds := Rect2(-34, -26, 68, 52)
var icon: Texture2D
var selected := false

func _process(_delta: float) -> void:
	var active := false
	for controller in get_tree().get_nodes_in_group("interaction_controllers"):
		if controller.enabled and controller.target == fixture:
			active = true
	if active != selected:
		selected = active
		queue_redraw()

func _draw() -> void:
	if not selected:
		return
	var color := Color("#E9DFC8")
	for point in [bounds.position, Vector2(bounds.end.x, bounds.position.y), bounds.end, Vector2(bounds.position.x, bounds.end.y)]:
		var sx := 1 if point.x == bounds.position.x else -1
		var sy := 1 if point.y == bounds.position.y else -1
		draw_line(point, point + Vector2(7 * sx, 0), Color("#51483F"), 4)
		draw_line(point, point + Vector2(0, 7 * sy), Color("#51483F"), 4)
		draw_line(point, point + Vector2(6 * sx, 0), color, 2)
		draw_line(point, point + Vector2(0, 6 * sy), color, 2)
	if icon != null:
		draw_texture(icon, Vector2(-8, bounds.position.y - 18))
