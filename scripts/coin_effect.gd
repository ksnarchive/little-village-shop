extends Control
## Brief whole-pixel coin sparkle; UI-owned so it also plays during checkout.

var _age: float = 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(delta: float) -> void:
	_age += delta
	if _age >= 0.9:
		queue_free()
	else:
		queue_redraw()

func _draw() -> void:
	for index in range(5):
		var x := roundf((index - 2) * 12 * _age)
		var y := roundf(-50 * _age + 28 * _age * _age - (index % 2) * 7)
		var alpha := minf(1.0, (0.9 - _age) * 4)
		draw_rect(Rect2(x - 3, y - 4, 6, 8), Color(0.65, 0.40, 0.17, alpha))
		draw_rect(Rect2(x - 2, y - 3, 4, 6), Color(0.96, 0.77, 0.31, alpha))
		draw_rect(Rect2(x - 1, y - 2, 1, 3), Color(1.0, 0.94, 0.65, alpha))
