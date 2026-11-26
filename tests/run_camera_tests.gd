extends SceneTree
## Fixed-step movement, bounded framing and independent HUD integration.
var checks := 0
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL: " + message)

func _frames(count: int) -> void:
	for index in range(count):
		await physics_frame

func _run() -> void:
	var shop := preload("res://scenes/main.tscn").instantiate()
	root.add_child(shop)
	shop.day.paused = true
	shop.customers.arrivals_enabled = false
	await _frames(3)
	var camera: FollowCamera = shop.get_node("Camera2D")
	var player: Shopkeeper = shop.player
	check(camera.zoom == Vector2(1.6, 1.6), "Chosen shop zoom is 1.6")
	var hud_rect: Rect2 = shop.inventory_ui.balance_card.get_global_rect()
	var hud_transform: Transform2D = shop.inventory_ui.balance_card.get_global_transform_with_canvas()
	# Walk the perimeter and both central aisles using actual player physics.
	for waypoint: Vector2 in [Vector2(320, 270), Vector2(470, 270), Vector2(470, 160),
		Vector2(470, 80), Vector2(320, 80), Vector2(160, 80), Vector2(160, 180),
		Vector2(160, 250), Vector2(160, 260), Vector2(246, 260), Vector2(320, 260),
		Vector2(320, 180), Vector2(208, 180), Vector2(320, 180), Vector2(432, 164)]:
		var reached := false
		for step in range(180):
			var difference := waypoint - player.position
			if difference.length() < 3:
				reached = true
				break
			for action in ["ui_left", "ui_right", "ui_up", "ui_down"]:
				Input.action_release(action)
			if absf(difference.x) > 2:
				Input.action_press("ui_right" if difference.x > 0 else "ui_left")
			if absf(difference.y) > 2:
				Input.action_press("ui_down" if difference.y > 0 else "ui_up")
			var before := camera.global_position
			await _frames(1)
			var half_view := camera.get_viewport_rect().size / camera.zoom / 2
			var view := Rect2(camera.global_position - half_view, half_view * 2)
			check(camera.world_bounds.grow(0.001).encloses(view), "Moving camera never exposes outside room art")
			check(camera.global_position.distance_to(before) <= 3, "Normal movement has no camera jumps")
			var pixels := camera.global_position * camera.zoom
			check(pixels.distance_to(pixels.round()) < 0.001, "Camera translation stays on render pixel grid")
		for action in ["ui_left", "ui_right", "ui_up", "ui_down"]:
			Input.action_release(action)
		check(reached, "Can walk to %s" % waypoint)
		await _frames(30)
		check(camera.global_position.distance_to(camera.bounded_center(player.position + camera.target_offset)) < 1,
			"Camera settles promptly after stopping")
		var settled := camera.global_position
		await _frames(12)
		check(camera.global_position == settled, "Stationary camera does not jitter")
	check(shop.inventory_ui.balance_card.get_global_rect() == hud_rect
		and shop.inventory_ui.balance_card.get_global_transform_with_canvas() == hud_transform, "HUD size and screen position stay fixed")
	shop.inventory_ui.open_inventory()
	await _frames(3)
	check(Rect2(0, 0, 640, 360).encloses(shop.inventory_ui.panel.get_global_rect()), "Menu remains in screen coordinates")
	shop.inventory_ui.close_menu()
	# Future locations can be larger, offset or smaller than the viewport.
	camera.world_bounds = Rect2(-1000, -600, 2400, 1600)
	player.position = Vector2(-800, -400)
	camera.snap_to_target()
	check(camera.global_position.distance_to(player.position + camera.target_offset) < 1, "Reusable target and nonzero world origin")
	camera.world_bounds = Rect2(100, 50, 80, 60)
	camera.snap_to_target()
	check(camera.global_position == Vector2(140, 80), "Small location centres without inverted clamp")
	shop.free()
	print("Little Village Shop camera: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
