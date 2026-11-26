extends SceneTree
## Actual Godot frames of the production location; does not touch saves.
var station: VillageStation

func _initialize() -> void:
	_capture.call_deferred()

func _shot(name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png("res://docs/station-" + name + ".png") == OK)
	print("Captured station-", name)

func _capture() -> void:
	DisplayServer.window_set_size(Vector2i(1280, 720))
	station = preload("res://scenes/locations/station.tscn").instantiate()
	station.checkpoint = func(_value: Dictionary): return true
	root.add_child(station)
	await physics_frame
	await physics_frame
	await _shot("arrival")
	station.elapsed = 10
	station.state.thought = 3
	station._show_thought()
	station._update_arrival()
	station.player.position = Vector2(506, 314)
	station.camera.snap_to_target()
	await physics_frame
	await _shot("platform")
	station.player.position = Vector2(473, 423)
	station.camera.snap_to_target()
	await physics_frame
	await _shot("village-path")
	station.camera.zoom = Vector2.ONE * 0.75
	station.camera.snap_to_target()
	station.ui.hide()
	await _shot("overview")
	station.free()
	quit()
