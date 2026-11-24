extends Control
var elapsed := 0.0
var animated := true
const LANDSCAPE: Texture2D = preload("res://assets/frontend/village.png")
const CLOUD: Texture2D = preload("res://assets/frontend/cloud.png")
const LEAVES: Texture2D = preload("res://assets/frontend/leaves.png")

func _process(delta: float) -> void:
	if animated:
		elapsed += delta
		queue_redraw()

func _draw() -> void:
	var zoom := maxf(size.x / 640.0, size.y / 360.0)
	var offset := (size - Vector2(640, 360) * zoom) / 2.0
	draw_set_transform(offset, 0, Vector2.ONE * zoom)
	draw_texture(LANDSCAPE, Vector2.ZERO)
	for i in range(4):
		var x := fposmod(i * 189.0 + elapsed * (1.1 + i * 0.2), 770.0) - 110.0
		draw_texture(CLOUD, Vector2(floorf(x), 27 + i * 18), Color(1, 1, 1, 0.6))
	for i in range(16):
		var y := fposmod(i * 41.0 + elapsed * (8 + i % 4), 390.0) - 18.0
		var x := fposmod(i * 137.0 + elapsed * 5.0 + sin(y * 0.04 + i) * 15, 680.0) - 20
		draw_texture_rect_region(LEAVES, Rect2(floorf(x), floorf(y), 8, 8), Rect2(i % 3 * 8, 0, 8, 8), Color(1, 1, 1, 0.8))
	draw_set_transform(Vector2.ZERO)
