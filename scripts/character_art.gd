class_name CharacterArt
extends RefCounted
## Registered painted materials. World feet stay at the original collision anchor.
const CELL := Vector2i(64, 96)
const POSES := 8 # neutral, blink, six walking phases
const HEAD_POSES := 2
const HAIR_POSES := 3 # neutral, tips lagging left / right
const WORLD_SIZE := Vector2(40, 60)
const ORIGIN := Vector2(-20, -50) # Preserve the original bottom/ground anchor at y=10.
const BODY: Texture2D = preload("res://assets/characters/body.png")
const CLOTHES: Texture2D = preload("res://assets/characters/clothes.png")
const HANDS: Texture2D = preload("res://assets/characters/hands.png")
const FACE: Texture2D = preload("res://assets/characters/face.png")
const EYES: Texture2D = preload("res://assets/characters/eyes.png")
const HAIR: Texture2D = preload("res://assets/characters/hair.png")
const SHADOW: Texture2D = preload("res://assets/characters/actor_shadow.png")

static func motion_enabled(canvas: CanvasItem) -> bool:
	# Read the existing entry preference without changing settings, saves or shell.
	var ancestor: Node = canvas
	while ancestor != null:
		if "animations" in ancestor:
			return bool(ancestor.get("animations"))
		ancestor = ancestor.get_parent()
	return true

static func cell(facing: Vector2, walking: bool, step: float, idle: float = 0.0, animated: bool = true) -> int:
	var direction := 0
	if absf(facing.x) > absf(facing.y):
		direction = 2 if facing.x < 0 else 3
	elif facing.y < -0.3:
		direction = 1
	var pose := 0
	if animated:
		pose = 2 + int(fposmod(step, TAU) / TAU * 6.0) if walking else (1 if fposmod(idle, 4.8) > 4.66 else 0)
	return direction * POSES + pose

static func target_rect(origin: Vector2, zoom: float, idle: float, animated: bool) -> Rect2:
	var breath := sin(idle * 1.5) * 0.22 * zoom if animated else 0.0
	return Rect2(origin - Vector2(0, breath), WORLD_SIZE * zoom + Vector2(0, breath))

static func head_target(body: Rect2, pose: int, zoom: float) -> Rect2:
	if pose >= 2:
		body.position.y += roundf(absf(sin((pose - 2) * TAU / 6.0))) * WORLD_SIZE.y / CELL.y * zoom
	return body

static func draw_actor(canvas: CanvasItem, appearance: Dictionary, facing: Vector2, walking: bool, step: float, origin: Vector2 = ORIGIN, zoom: float = 1.0, idle: float = 0.0, shadow: bool = true) -> void:
	var animated := motion_enabled(canvas)
	var index := cell(facing, walking, step, idle, animated)
	var direction := int(index / POSES)
	var pose := index % POSES
	var x := index * CELL.x
	var target := target_rect(origin, zoom, idle, animated and not walking)
	var portrait := head_target(target, pose, zoom)
	var head_x := (direction * HEAD_POSES + (1 if pose == 1 else 0)) * CELL.x
	var lag := sin((pose - 2) * TAU / 6.0) if pose >= 2 else 0.0
	var hair_pose := (1 if lag > 0 else 2) if absf(lag) > 0.25 else 0
	var hair_x := (direction * HAIR_POSES + hair_pose) * CELL.x
	var head := int(appearance.hairstyle) * CELL.y
	var garment := int(appearance.outfit) * CELL.y
	if shadow:
		canvas.draw_texture_rect(SHADOW, Rect2(origin, WORLD_SIZE * zoom), false)
	canvas.draw_texture_rect_region(CLOTHES, target, Rect2(x, garment, CELL.x, CELL.y))
	canvas.draw_texture_rect_region(HANDS, target, Rect2(x, garment, CELL.x, CELL.y), Color(CharacterAppearance.SKIN[int(appearance.skin)]))
	canvas.draw_texture_rect_region(BODY, portrait, Rect2(head_x, head, CELL.x, CELL.y), Color(CharacterAppearance.SKIN[int(appearance.skin)]))
	canvas.draw_texture_rect_region(HAIR, portrait, Rect2(hair_x, head, CELL.x, CELL.y), Color(CharacterAppearance.HAIR[int(appearance.hair_color)]))
	canvas.draw_texture_rect_region(FACE, portrait, Rect2(head_x, head, CELL.x, CELL.y))
	canvas.draw_texture_rect_region(EYES, portrait, Rect2(head_x, head, CELL.x, CELL.y), Color(CharacterAppearance.EYES[int(appearance.eyes)]))
