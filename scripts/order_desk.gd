extends Interactable
## Pixel-grid details mark the front of the existing order desk.

func _draw() -> void:
	draw_rect(Rect2(-24, -16, 48, 32), Color("#765238"))
	draw_rect(Rect2(-21, -13, 42, 24), Color("#d8a15f"))
	draw_rect(Rect2(-21, 11, 42, 3), Color("#b78455"))
	draw_rect(Rect2(-18, -7, 36, 1), Color("#c28b54"))
	draw_rect(Rect2(-18, 7, 36, 1), Color("#c28b54"))
	# Open order book and pencil.
	draw_rect(Rect2(-15, -7, 25, 15), Color("#61734f"))
	draw_rect(Rect2(-14, -8, 11, 13), Color("#fff0cf"))
	draw_rect(Rect2(-2, -8, 11, 13), Color("#f1deb7"))
	for y in [-5, -2, 1]:
		draw_rect(Rect2(-12, y, 7, 1), Color("#c7aa80"))
		draw_rect(Rect2(0, y, 7, 1), Color("#c7aa80"))
	draw_rect(Rect2(2, 8, 10, 2), Color("#a8664e"))
	draw_rect(Rect2(11, 8, 2, 2), Color("#513a31"))
	# A flowerpot sits at the corner of the desk.
	draw_rect(Rect2(13, 1, 6, 5), Color("#a8664e"))
	draw_rect(Rect2(12, 0, 8, 2), Color("#bd7956"))
	draw_rect(Rect2(15, -7, 2, 7), Color("#61734f"))
	draw_rect(Rect2(17, -4, 3, 2), Color("#8dab78"))
	draw_rect(Rect2(13, -9, 6, 3), Color("#fff0cf"))
	draw_rect(Rect2(15, -8, 2, 2), Color("#d8a15f"))
