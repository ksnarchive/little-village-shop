extends Control
## Raster paintings and baked animation plates. Nothing here mutates game state.
const ROOMS = [preload("res://assets/train/carriage.png"), preload("res://assets/train/carriage_1.png"), preload("res://assets/train/carriage_2.png")]
const PORTRAITS = [preload("res://assets/train/carriage_portrait.png"), preload("res://assets/train/carriage_portrait_1.png"), preload("res://assets/train/carriage_portrait_2.png")]
const LIGHTS = [preload("res://assets/train/carriage_light.png"), preload("res://assets/train/carriage_portrait_light.png")]
const LAYERS = [preload("res://assets/train/sky.png"), preload("res://assets/train/hills.png"), preload("res://assets/train/fields.png"), preload("res://assets/train/trees.png")]
const HEAD = preload("res://assets/train/seated_head.png")
const HANDS = preload("res://assets/train/seated_hands.png")
const CLOTHES = preload("res://assets/train/seated_clothes.png")
const HAIR = preload("res://assets/train/seated_hair.png")
const EYES = preload("res://assets/train/seated_eyes.png")
const LIDS = preload("res://assets/train/seated_lids.png")
const FACE = preload("res://assets/train/seated_face.png")
const STEAM = preload("res://assets/train/steam.png")
var appearance := CharacterAppearance.DEFAULT.duplicate()
var animated := true
var speed := 1.0
var distance := 0.0
var elapsed := 0.0

func _process(delta: float) -> void:
	if animated:
		distance = fmod(distance + delta * speed * 20.0, 15360.0)
		elapsed += delta
		queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("#25191f"))
	var portrait := size.x < 540
	var art_size := Vector2(400, 600) if portrait else Vector2(640, 360)
	var zoom := minf(size.x / art_size.x, (size.y - 108) / 600.0) if portrait else minf(size.x / 640.0, size.y / 360.0)
	zoom = maxf(0.1, zoom)
	var offset := Vector2((size.x - art_size.x * zoom) / 2, 0 if portrait else -8 * zoom).floor()
	var sway := sin(elapsed * 1.7) * 0.35 * speed if animated else 0.0
	draw_set_transform(offset + Vector2(0, sway), 0, Vector2.ONE * zoom)
	var window := Rect2(4, 72, 200, 224) if portrait else Rect2(15, 20, 371, 180)
	# Moving terrain is hidden by the painted window aperture. The curtains
	# and bevel retain their own alpha edge, including each cloth animation frame.
	_strip(0, window, 0.0)
	_strip(1, Rect2(window.position + Vector2(0, window.size.y * 0.10), window.size * Vector2(1, 0.90)), 0.16)
	_strip(2, Rect2(window.position + Vector2(0, window.size.y * 0.27), window.size * Vector2(1, 0.73)), 0.58)
	_strip(3, Rect2(window.position + Vector2(0, window.size.y * 0.57), window.size * Vector2(1, 0.43)), 1.5)
	var frame := 0
	if animated:
		var cloth := sin(elapsed * 0.65)
		frame = 1 if cloth < -0.45 else (2 if cloth > 0.45 else 0)
	draw_texture(PORTRAITS[frame] if portrait else ROOMS[frame], Vector2.ZERO)
	var actor := Vector2(240, 243) if portrait else Vector2(430, 110)
	_draw_seated(actor)
	if animated:
		draw_texture(LIGHTS[1 if portrait else 0], Vector2(sin(elapsed * 0.23) * 2.0, cos(elapsed * 0.19)), Color(1, 0.9, 0.7, 0.34))
	# A passing tree's broad shadow affects the painting and hero, never the UI.
	var phase := fmod(elapsed, 17.0)
	if animated and phase > 12.0 and phase < 14.5:
		var shade := sin((phase - 12.0) / 2.5 * PI) * 0.20 * speed
		draw_rect(Rect2(Vector2.ZERO, art_size), Color(0.06, 0.09, 0.11, shade))
	var tea := Vector2(103, 289) if portrait else Vector2(174, 171)
	var steam_frame := int(elapsed * 3) % 12 if animated else 0
	draw_texture_rect_region(STEAM, Rect2(tea, Vector2(48, 64)), Rect2(steam_frame * 48, 0, 48, 64))
	draw_set_transform(Vector2.ZERO)

func _strip(index: int, destination: Rect2, rate: float) -> void:
	var travel := fmod(floorf(distance * rate), 1536.0)
	# Preserve pixel scale across all terrain layers; each panorama has a
	# mirrored continuation so the wrap cannot expose a vertical seam.
	var width := destination.size.x
	var first := minf(width, 1536.0 - travel)
	draw_texture_rect_region(LAYERS[index], Rect2(destination.position, Vector2(first, destination.size.y)), Rect2(travel, 0, first, 128))
	if first < width:
		draw_texture_rect_region(LAYERS[index], Rect2(destination.position + Vector2(first, 0), Vector2(width - first, destination.size.y)), Rect2(0, 0, width - first, 128))

func _draw_seated(origin: Vector2) -> void:
	var breath := sin(elapsed * 1.35) * 0.65 if animated else 0.0
	# Breathing expands the torso/head by less than a source pixel while the
	# soles stay planted. Full garments contain the lap, knees, sleeves and shoes.
	var target := Rect2(origin - Vector2(0, breath), Vector2(96, 144 + breath))
	var source := Rect2(0, int(appearance.hairstyle) * 144, 96, 144)
	draw_texture_rect_region(HEAD, target, source, Color(CharacterAppearance.SKIN[int(appearance.skin)]))
	source.position.y = int(appearance.outfit) * 144
	draw_texture_rect_region(CLOTHES, target, source)
	source.position.y = int(appearance.outfit) * 144
	draw_texture_rect_region(HANDS, target, source, Color(CharacterAppearance.SKIN[int(appearance.skin)]))
	source.position.y = int(appearance.hairstyle) * 144
	draw_texture_rect_region(HAIR, target, source, Color(CharacterAppearance.HAIR[int(appearance.hair_color)]))
	draw_texture_rect_region(FACE, target, source)
	var blink := animated and fmod(elapsed + 2.4, 6.7) > 6.54
	if blink:
		draw_texture_rect_region(LIDS, target, source, Color(CharacterAppearance.SKIN[int(appearance.skin)]))
	source.position.y = int(appearance.hairstyle) * 288 + (144 if blink else 0)
	draw_texture_rect_region(EYES, target, source, Color(CharacterAppearance.EYES[int(appearance.eyes)]))
