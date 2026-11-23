class_name Interactable
extends Node2D
## Reusable interaction endpoint. Furniture owns its behavior, not the player.

signal interacted(actor: Node2D)

@export var prompt: String = "Interact"
@export var interaction_offset: Vector2 = Vector2.ZERO

func _ready() -> void:
	add_to_group("interactables")

func interaction_position() -> Vector2:
	return to_global(interaction_offset)

func can_interact(_actor: Node2D) -> bool:
	return true

func interact(actor: Node2D) -> void:
	if can_interact(actor):
		interacted.emit(actor)
