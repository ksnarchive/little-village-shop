extends SceneTree
## Layout and font regressions caused by the Russian art/UI overhaul.
var checks := 0
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAIL: " + description)

func _run() -> void:
	var font := preload("res://assets/fonts/VillagePixel-Regular.ttf")
	var russian := "АБВГДЕЁЖЗИЙКЛМНОПРСТУФХЦЧШЩЪЫЬЭЮЯабвгдеёжзийклмнопрстуфхцчшщъыьэюя"
	var covered := true
	for letter in russian:
		covered = covered and font.has_char(letter.unicode_at(0))
	check(covered, "Bundled pixel font covers every Russian letter without system fallback")
	var shop := preload("res://scenes/main.tscn").instantiate()
	root.add_child(shop)
	shop.day.paused = true
	shop.customers.arrivals_enabled = false
	var ui: InventoryMenu = shop.inventory_ui
	await process_frame
	await process_frame
	check(not ui.clock_card.get_global_rect().intersects(ui.balance_card.get_global_rect()), "Clock and money cards do not overlap")
	for open in [ui.open_inventory, ui.open_storage, ui.open_supplier, ui.open_shelf.bind(shop.get_node("RightShelf")), ui.open_checkout, ui.open_pause]:
		open.call()
		await process_frame
		await process_frame
		var rect := ui.panel.get_global_rect()
		check(Rect2(0, 0, 640, 360).encloses(rect), "Russian menu fits the base viewport: %s" % ui.view)
		check(not ui.prompt_label.visible, "Context action hides while a modal is open")
		ui.close_menu()
	shop.player.position = Vector2(208, 255)
	await physics_frame
	await physics_frame
	check(shop.interactions.target == shop.storage and ui.prompt_label.visible, "Reachable storage shows the Russian action after closing a modal")
	shop.player.position = Vector2(320, 222)
	await physics_frame
	await physics_frame
	check(not ui.prompt_label.visible, "Context action hides after leaving interaction range")
	shop.free()
	print("Little Village Shop visuals: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
