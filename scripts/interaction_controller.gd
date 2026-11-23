class_name InteractionController
extends Node
## Selects the nearest reachable endpoint within range and handles the E action.

signal target_changed(target: Interactable)

@export var interaction_range: float = 36.0
var enabled: bool = true
var target: Interactable
@onready var actor: Node2D = get_parent() as Node2D

func _physics_process(_delta: float) -> void:
	refresh_target()

func refresh_target() -> void:
	var nearest: Interactable
	var distance_squared := interaction_range * interaction_range
	if enabled:
		for node in get_tree().get_nodes_in_group("interactables"):
			var candidate := node as Interactable
			if candidate == null or not candidate.can_interact(actor):
				continue
			var distance := actor.global_position.distance_squared_to(candidate.interaction_position())
			if distance <= distance_squared and _has_clear_path(candidate):
				nearest = candidate
				distance_squared = distance
	if target != nearest:
		target = nearest
		target_changed.emit(target)

func _has_clear_path(candidate: Interactable) -> bool:
	var query := PhysicsRayQueryParameters2D.create(
		actor.global_position, candidate.interaction_position(), 2)
	return actor.get_world_2d().direct_space_state.intersect_ray(query).is_empty()

func _unhandled_input(event: InputEvent) -> void:
	if not enabled or not event.is_action_pressed("interact") or event.is_echo():
		return
	refresh_target()
	if is_instance_valid(target):
		get_viewport().set_input_as_handled()
		target.interact(actor)
