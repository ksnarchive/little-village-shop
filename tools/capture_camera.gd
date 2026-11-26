extends SceneTree
## Real Godot render; no resized screenshots or modified art. No saves opened.
## godot --path . --audio-driver Dummy --fixed-fps 60 --script res://tools/capture_camera.gd
var shop: Node2D

func _initialize() -> void:
	_capture.call_deferred()

func _shot(name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png("res://docs/camera-" + name + ".png") == OK)
	print("Captured camera-", name)

func _comparison(label: String) -> void:
	var camera: FollowCamera = shop.get_node("Camera2D")
	for amount in [1.15, 1.6, 1.8]:
		camera.zoom = Vector2.ONE * amount
		if amount == 1.15:
			# Original static framing, before this change.
			camera.global_position = Vector2(320, 180)
			camera.force_update_scroll()
		else:
			camera.snap_to_target()
		await _shot("%s-%s" % [label, str(amount).replace(".", "-")])

func _capture() -> void:
	DisplayServer.window_set_size(Vector2i(1280, 720))
	shop = preload("res://scenes/main.tscn").instantiate()
	root.add_child(shop)
	shop.day.paused = true
	shop.get_node("Camera2D").set_physics_process(false)
	await physics_frame
	await physics_frame
	shop.player.set_process(false)
	shop.player.set_physics_process(false)
	shop.player.art_time = 0.0
	await _comparison("spawn")
	for purchase in [[&"apple", 2], [&"bread", 4], [&"milk", 5]]:
		assert(shop.economy.buy(purchase[0], purchase[1]) == ShopEconomy.PurchaseResult.SUCCESS)
	for shelf: ShopShelf in [shop.get_node("LeftShelf"), shop.get_node("RightShelf")]:
		for id in [&"apple", &"bread", &"milk"]:
			assert(shop.storage.inventory.transfer_to(shop.player_inventory, id, 4))
			assert(shop.player_inventory.transfer_to(shelf.inventory, id, 4))
	shop.customers.rng.seed = 8
	shop.day.restore_snapshot(1, 720.0, ShopDay.Phase.RUSH)
	shop.day.paused = true
	var frames := 0
	while shop.customers.waiting.size() < 3 and frames < 9000:
		await physics_frame
		frames += 1
	assert(shop.customers.waiting.size() == 3)
	shop.customers.process_mode = Node.PROCESS_MODE_DISABLED
	shop.player.position = Vector2(246, 260)
	shop.interactions.refresh_target()
	await _comparison("queue")
	shop.free()
	quit()
