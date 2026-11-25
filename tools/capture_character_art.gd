extends SceneTree
## Optional real-render review; separate temporary save, production UI/API paths.
var entry: Node
const PATH := "user://character_art_review.json"

func _initialize() -> void:
	call_deferred("_capture")

func frames(count: int) -> void:
	for index in range(count):
		await physics_frame

func shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png("res://docs/character-art-" + name + ".png") == OK)
	print("Captured character-art-", name)

func look(value: Dictionary) -> void:
	entry.creator.appearance = value.duplicate()
	entry.creator.name_input.text = value.name
	entry.creator._refresh()
	entry.creator._name_changed(value.name)

func _capture() -> void:
	DisplayServer.window_set_size(Vector2i(1280, 720))
	for suffix in ["", ".bak", ".tmp", ".bak.tmp"]:
		DirAccess.remove_absolute(PATH + suffix)
	entry = preload("res://scenes/start.tscn").instantiate()
	entry.store = SaveStore.new(PATH)
	root.add_child(entry)
	entry.confirm_new_game()
	await frames(4)
	await shot("editor-default")
	for index in range(3):
		look({"name": "Мира", "skin": [5, 1, 3][index], "hairstyle": [4, 7, 6][index], "hair_color": [4, 5, 0][index], "eyes": [4, 1, 2][index], "outfit": [4, 5, 1][index]})
		await frames(4)
		await shot("variant-" + str(index + 1))
	var chosen := {"name": "Мира", "skin": 2, "hairstyle": 1, "hair_color": 5, "eyes": 2, "outfit": 2}
	look(chosen)
	await frames(4)
	await shot("same-hero-editor")
	entry.creator.confirm_button.pressed.emit()
	await create_timer(1.2).timeout
	assert(entry.train.appearance == chosen and entry.train.view.appearance == chosen)
	entry.train.words.visible_characters = -1
	await shot("same-hero-train")
	entry.train.request_skip()
	entry.train.confirm_button.pressed.emit()
	await create_timer(1.5).timeout
	var shop: Node2D = entry.shop
	shop.day.paused = true
	assert(shop.player.appearance == chosen)
	assert(entry.store.read_save(shop).character == JSON.parse_string(JSON.stringify(chosen)))
	await frames(3)
	await shot("same-hero-shop")
	# Existing buying and stocking APIs; wait for three natural visits.
	for purchase in [[&"apple", 2], [&"bread", 4], [&"milk", 5]]:
		assert(shop.economy.buy(purchase[0], purchase[1]) == ShopEconomy.PurchaseResult.SUCCESS)
	for shelf: ShopShelf in [shop.get_node("LeftShelf"), shop.get_node("RightShelf")]:
		for id in [&"apple", &"bread", &"milk"]:
			assert(shop.storage.inventory.transfer_to(shop.player_inventory, id, 4))
			assert(shop.player_inventory.transfer_to(shelf.inventory, id, 4))
	shop.customers.rng.seed = 8
	shop.day.restore_snapshot(1, 720.0, ShopDay.Phase.RUSH)
	shop.day.paused = true
	var elapsed := 0
	while shop.customers.waiting.size() < 3 and elapsed < 9000:
		await physics_frame
		elapsed += 1
	assert(shop.customers.waiting.size() == 3)
	await shot("buyers")
	entry.free()
	for suffix in ["", ".bak", ".tmp", ".bak.tmp"]:
		DirAccess.remove_absolute(PATH + suffix)
	quit()
