class_name VillagerArt
extends RefCounted
## Three reusable, unnamed buyer archetypes share the player's scale and poses.
const HEADS: Texture2D = preload("res://assets/characters/npc_heads.png")
const CLOTHES: Texture2D = preload("res://assets/characters/npc_clothes.png")

static func draw_actor(canvas: CanvasItem, variant: int, facing: Vector2, walking: bool, step: float, idle: float = 0.0) -> void:
	var animated := CharacterArt.motion_enabled(canvas)
	var index := CharacterArt.cell(facing, walking, step, idle, animated)
	var x := index * CharacterArt.CELL.x
	var y := clampi(variant - 1, 0, 2) * CharacterArt.CELL.y
	var target := CharacterArt.target_rect(CharacterArt.ORIGIN, 1.0, idle, animated and not walking)
	canvas.draw_texture_rect(CharacterArt.SHADOW, Rect2(CharacterArt.ORIGIN, CharacterArt.WORLD_SIZE), false)
	canvas.draw_texture_rect_region(CLOTHES, target, Rect2(x, y, CharacterArt.CELL.x, CharacterArt.CELL.y))
	var portrait := CharacterArt.head_target(target, index % CharacterArt.POSES, 1.0)
	var head_x := int(index / CharacterArt.POSES) * CharacterArt.CELL.x
	canvas.draw_texture_rect_region(HEADS, portrait, Rect2(head_x, y, CharacterArt.CELL.x, CharacterArt.CELL.y))
