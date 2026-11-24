class_name Interactable
extends Node2D
## Reusable interaction endpoint. Furniture owns its behavior, not the player.

signal interacted(actor: Node2D)

@export var prompt: String = "Взаимодействовать"
@export_enum("box", "book", "shelf", "coin") var sign_icon: String = "shelf"
@export var art_bounds := Rect2(-34, -26, 68, 52)
@export var interaction_offset: Vector2 = Vector2.ZERO

func _ready() -> void:
	add_to_group("interactables")
	var hint := Node2D.new()
	hint.set_script(preload("res://scripts/fixture_hint.gd"))
	hint.fixture = self
	hint.bounds = art_bounds
	hint.icon = load("res://assets/ui/%s.png" % sign_icon)
	hint.z_index = 20
	add_child(hint)

func interaction_position() -> Vector2:
	return to_global(interaction_offset)

func can_interact(_actor: Node2D) -> bool:
	return true

func interact(actor: Node2D) -> void:
	if can_interact(actor):
		interacted.emit(actor)
