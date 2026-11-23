extends SceneTree
## Optional graphical review runner, never loaded by the game or headless CI.
## godot --path . --audio-driver Dummy --script res://tools/capture_shop.gd
## Captures the actual rendered game window; uses production stock and NPC APIs.
var shop: Node2D

func _initialize() -> void:
	call_deferred("_capture")

func _frames(count: int) -> void:
	for index in range(count):
		await physics_frame

func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	assert(image.save_png("res://docs/" + name + ".png") == OK)
	print("Captured ", name, " ", image.get_size())

func _capture() -> void:
	# Fix the physical window at exactly 2x, independent of desktop window manager.
	DisplayServer.window_set_size(Vector2i(1280, 720))
	shop = preload("res://scenes/main.tscn").instantiate()
	root.add_child(shop)
	shop.day.paused = true
	await _frames(3)
	await _shot("stage-8-shop-overview")
	# Complete ordinary purchases and the existing storage -> bag -> shelf flow.
	assert(shop.economy.buy(&"apple", 2) == ShopEconomy.PurchaseResult.SUCCESS)
	assert(shop.economy.buy(&"bread", 4) == ShopEconomy.PurchaseResult.SUCCESS)
	assert(shop.economy.buy(&"milk", 5) == ShopEconomy.PurchaseResult.SUCCESS)
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
	assert(shop.customers.waiting.size() == 3, "Three natural visits must finish")
	await _shot("stage-8-stocked-customers")
	# Native 16px bag icons and coordinated cream/sage/wood modal controls.
	shop.inventory_ui.open_storage()
	await _frames(3)
	await _shot("stage-8-storage-menu")
	shop.free()
	quit()
