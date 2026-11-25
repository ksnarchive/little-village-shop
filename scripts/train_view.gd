extends Control
## All scene geometry is in a 640 x 300 pixel canvas. Cover-crop keeps the
## window, seated hero and suitcase together when rotating a phone.
const ROOM = preload("res://assets/train/carriage.png")
const LAYERS = [preload("res://assets/train/sky.png"), preload("res://assets/train/hills.png"), preload("res://assets/train/fields.png"), preload("res://assets/train/trees.png")]
var appearance := CharacterAppearance.DEFAULT.duplicate()
var animated := true
var speed := 1.0
var distance := 0.0
var elapsed := 0.0

func _process(delta: float) -> void:
	if animated:
		distance = fmod(distance + delta * speed * 34.0, 7680.0)
		elapsed += delta * speed
		queue_redraw()

func _draw() -> void:
	var zoom := maxf(size.x / 640.0, size.y / 300.0)
	var offset := ((size - Vector2(640, 300) * zoom) / 2).floor()
	offset.y = minf(0, size.y - 248.0 * zoom)
	# At most one source pixel of carriage movement, never move the UI.
	var sway := floorf(sin(elapsed * 2.0) * 0.65) if animated else 0.0
	draw_set_transform(offset + Vector2(0, sway) * zoom, 0, Vector2.ONE * zoom)
	for index in range(LAYERS.size()):
		var travel := floorf(distance * [0.0, 0.16, 0.50, 1.6][index])
		# Draw only the visible window region, sampling a seamless repeated strip.
		var start := fmod(travel, 768.0)
		var first := minf(330.0, 768.0 - start)
		draw_texture_rect_region(LAYERS[index], Rect2(155, 59, first, 110), Rect2(start, 0, first, 110))
		if first < 330:
			draw_texture_rect_region(LAYERS[index], Rect2(155 + first, 59, 330 - first, 110), Rect2(0, 0, 330 - first, 110))
	draw_texture(ROOM, Vector2.ZERO)
	# Seated pose reuses the actual chosen layers above the knees. Bent legs
	# replace the walking feet; the name and appearance never get copied back.
	var origin := Vector2(289, 169)
	var source := Rect2(216, 0, 24, 25)
	var target := Rect2(origin, Vector2(48, 50))
	draw_texture_rect_region(CharacterArt.BODY, target, source, Color(CharacterAppearance.SKIN[int(appearance.skin)]))
	source.position.y = int(appearance.outfit) * 32
	draw_texture_rect_region(CharacterArt.CLOTHES, target, source)
	source.position.y = 0
	draw_texture_rect_region(CharacterArt.FACE, target, source)
	draw_texture_rect_region(CharacterArt.EYES, target, source, Color(CharacterAppearance.EYES[int(appearance.eyes)]))
	source.position.y = int(appearance.hairstyle) * 32
	draw_texture_rect_region(CharacterArt.HAIR, target, source, Color(CharacterAppearance.HAIR[int(appearance.hair_color)]))
	draw_rect(Rect2(307, 215, 23, 8), Color("#575b53"))
	draw_rect(Rect2(321, 219, 9, 17), Color("#575b53"))
	draw_rect(Rect2(310, 215, 18, 2), Color("#737367"))
	draw_rect(Rect2(320, 235, 15, 5), Color("#48453c"))
	# Glass glints and a gentle lamp flicker, quantized to pixel shapes.
	draw_colored_polygon(PackedVector2Array([Vector2(172,62), Vector2(181,62), Vector2(236,167), Vector2(227,167)]), Color(0.95,0.88,0.70,0.08))
	var glow := 0.035 + (sin(elapsed * 0.7) * 0.008 if animated else 0.0)
	draw_rect(Rect2(273, 32, 96, 16), Color(1.0,0.86,0.58,glow))
	draw_set_transform(Vector2.ZERO)
