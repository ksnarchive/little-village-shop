extends SceneTree
## Optional real-render capture, not a game entry point. Run on a graphical display:
## godot --path . --audio-driver Dummy --script res://tools/capture_illustrated_shop.gd
## Uses production purchasing, transfers and natural customers; no save slot is opened.
var shop: Node2D

func _initialize() -> void:
	call_deferred("_capture")

func _frames(count: int) -> void:
	for index in range(count):
		await physics_frame

func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	assert(image.save_png("res://docs/illustrated-shop-" + name + ".png") == OK)
	print("Captured ", name, " ", image.get_size())

func _capture() -> void:
	DisplayServer.window_set_size(Vector2i(1280, 720))
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	shop = preload("res://scenes/main.tscn").instantiate()
	root.add_child(shop)
	shop.day.paused = true
	await _frames(3)
	await _shot("overview")
	# Buy missing stock, then use the same storage -> bag -> shelf path as play.
	for purchase in [[&"apple", 2], [&"bread", 4], [&"milk", 5]]:
		assert(shop.economy.buy(purchase[0], purchase[1]) == ShopEconomy.PurchaseResult.SUCCESS)
	for shelf: ShopShelf in [shop.get_node("LeftShelf"), shop.get_node("RightShelf")]:
		for id in [&"apple", &"bread", &"milk"]:
			assert(shop.storage.inventory.transfer_to(shop.player_inventory, id, 4))
			assert(shop.player_inventory.transfer_to(shelf.inventory, id, 4))
	# Give the bag a small visible assortment as well.
	for id in [&"apple", &"bread", &"milk"]:
		assert(shop.economy.buy(id, 1) == ShopEconomy.PurchaseResult.SUCCESS)
		assert(shop.storage.inventory.transfer_to(shop.player_inventory, id, 1))
	shop.customers.rng.seed = 8
	shop.day.restore_snapshot(1, 720.0, ShopDay.Phase.RUSH)
	shop.day.paused = true
	var frames := 0
	while shop.customers.waiting.size() < 3 and frames < 9000:
		await physics_frame
		frames += 1
	assert(shop.customers.waiting.size() == 3, "Three natural visits must reach checkout")
	await _shot("stocked-customers")
	shop.inventory_ui.open_inventory()
	await _frames(3)
	await _shot("inventory")
	shop.free()
	quit()
