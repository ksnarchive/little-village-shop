class_name CharacterArt
extends RefCounted
## Aligned independent pixel layers: skin, garment, face, eyes and hair.
const BODY: Texture2D = preload("res://assets/characters/body.png")
const CLOTHES: Texture2D = preload("res://assets/characters/clothes.png")
const FACE: Texture2D = preload("res://assets/characters/face.png")
const EYES: Texture2D = preload("res://assets/characters/eyes.png")
const HAIR: Texture2D = preload("res://assets/characters/hair.png")

static func cell(facing: Vector2, walking: bool, step: float) -> int:
	var direction := 0
	if absf(facing.x) > absf(facing.y):
		direction = 2 if facing.x < 0 else 3
	elif facing.y < -0.3:
		direction = 1
	return direction * 3 + ((1 if sin(step) > 0.0 else 2) if walking else 0)

static func draw_actor(canvas: CanvasItem, appearance: Dictionary, facing: Vector2, walking: bool, step: float, origin: Vector2 = Vector2(-12, -20), zoom: float = 1.0) -> void:
	var x := cell(facing, walking, step) * 24
	var target := Rect2(origin, Vector2(24, 32) * zoom)
	canvas.draw_texture_rect_region(BODY, target, Rect2(x, 0, 24, 32), Color(CharacterAppearance.SKIN[int(appearance.skin)]))
	canvas.draw_texture_rect_region(CLOTHES, target, Rect2(x, int(appearance.outfit) * 32, 24, 32))
	canvas.draw_texture_rect_region(FACE, target, Rect2(x, 0, 24, 32))
	canvas.draw_texture_rect_region(EYES, target, Rect2(x, 0, 24, 32), Color(CharacterAppearance.EYES[int(appearance.eyes)]))
	canvas.draw_texture_rect_region(HAIR, target, Rect2(x, int(appearance.hairstyle) * 32, 24, 32), Color(CharacterAppearance.HAIR[int(appearance.hair_color)]))
