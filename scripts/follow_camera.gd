class_name FollowCamera
extends Camera2D
## Bounded, pixel-aligned follow camera. Keep screen UI on a CanvasLayer.
## Locations supply their target, painted world bounds and preferred zoom.

@export var target: Node2D
@export var world_bounds := Rect2(0, 0, 640, 360)
@export var target_offset := Vector2(0, -24)
@export_range(1.0, 30.0) var follow_speed: float = 12.0
var _center := Vector2.ZERO

func _ready() -> void:
	# Run after CharacterBody2D movement, on the same fixed timestep.
	process_physics_priority = 100
	process_callback = Camera2D.CAMERA2D_PROCESS_PHYSICS
	position_smoothing_enabled = false
	get_viewport().size_changed.connect(snap_to_target)
	snap_to_target()

func snap_to_target() -> void:
	if not is_instance_valid(target):
		return
	_center = bounded_center(target.global_position + target_offset)
	_apply_center()
	force_update_scroll()

func bounded_center(point: Vector2) -> Vector2:
	var half_view := get_viewport_rect().size / zoom / 2.0
	var minimum := world_bounds.position + half_view
	var maximum := world_bounds.end - half_view
	# A location smaller than the viewport is centred on that axis.
	for axis in range(2):
		if minimum[axis] > maximum[axis]:
			point[axis] = world_bounds.get_center()[axis]
		else:
			# Round inward so snapping can never reveal a strip beyond the art.
			point[axis] = clampf(point[axis], ceilf(minimum[axis] * zoom[axis]) / zoom[axis],
				floorf(maximum[axis] * zoom[axis]) / zoom[axis])
	return point

func _physics_process(delta: float) -> void:
	if not is_instance_valid(target):
		return
	var destination := bounded_center(target.global_position + target_offset)
	# Frame-rate-independent damping; retain fractional progress to avoid stalls.
	_center = _center.lerp(destination, 1.0 - exp(-follow_speed * delta))
	_apply_center()

func _apply_center() -> void:
	_center = bounded_center(_center)
	# Snap the rendered translation, not the smoothing accumulator or actor.
	global_position = (_center * zoom).round() / zoom
