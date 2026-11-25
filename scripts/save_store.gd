class_name SaveStore
extends RefCounted
## One slot, validated JSON and atomic rename; .bak is the previous valid generation.
const VERSION := 3
const MAX_FILE_BYTES := 65536
const MAX_SAFE_INTEGER := 9007199254740991
const ECONOMY_KEYS := ["balance", "revenue", "completed_sales", "day_revenue", "day_sales", "day_expenses"]
var path: String
var message: String = ""
var recovered: bool = false

func _init(save_path: String = "user://village_save.json") -> void:
	path = save_path

func exists() -> bool:
	return FileAccess.file_exists(path) or FileAccess.file_exists(path + ".bak")

func capture(shop: Node2D) -> Dictionary:
	if not shop.customers.is_empty() or shop.economy._buying or shop.economy._selling:
		return {}
	var economy := {}
	for key in ECONOMY_KEYS:
		# Decimal strings retain all 64 bits across JSON parsers.
		economy[key] = str(shop.economy.get(key))
	var shelves := {}
	for shelf in shop.customers.shelves:
		shelves[String(shelf.name)] = shelf.inventory.serialize()
	return {"version": VERSION, "day": shop.day.day_number, "minute": shop.day.minute,
		"phase": int(shop.day.phase), "economy": economy, "bag": shop.player_inventory.serialize(),
		"storage": shop.storage.inventory.serialize(), "shelves": shelves,
		"character": shop.player.appearance.duplicate(true), "story": shop.story.duplicate(true)}

func validate(data: Variant, shop: Node2D) -> bool:
	if not data is Dictionary or not _whole(data.get("version"), 1, VERSION):
		return false
	if int(data.version) >= 2 and not CharacterAppearance.valid(data.get("character")):
		return false
	if int(data.version) >= 3 and not TrainStory.valid(data.get("story")):
		return false
	if not _whole(data.get("day"), 1, MAX_SAFE_INTEGER - 1):
		return false
	var minute: Variant = data.get("minute")
	if not (minute is int or minute is float) or not is_finite(float(minute)) or minute < 480 or minute > 1080:
		return false
	var expected: int = ShopDay.Phase.PREPARATION
	if minute >= 1080:
		expected = ShopDay.Phase.SUMMARY
	elif minute >= 840:
		expected = ShopDay.Phase.AFTERNOON
	elif minute >= 720:
		expected = ShopDay.Phase.RUSH
	elif minute >= 540:
		expected = ShopDay.Phase.OPEN
	# An empty closing shop is immediately a summary; no transient closing snapshots.
	if not _whole(data.get("phase"), expected, expected):
		return false
	if not data.get("economy") is Dictionary:
		return false
	var money: Dictionary = data.economy
	for key in ECONOMY_KEYS:
		if not _coin_string(money.get(key)):
			return false
	if int(money.day_revenue) > int(money.revenue) or int(money.day_sales) > int(money.completed_sales):
		return false
	if not _inventory_valid(data.get("bag"), shop.player_inventory) or not _inventory_valid(data.get("storage"), shop.storage.inventory):
		return false
	if not data.get("shelves") is Dictionary or data.shelves.size() != shop.customers.shelves.size():
		return false
	for shelf in shop.customers.shelves:
		if not _inventory_valid(data.shelves.get(String(shelf.name)), shelf.inventory):
			return false
	return true

func _inventory_valid(data: Variant, inventory: Inventory) -> bool:
	return data is Dictionary and Inventory.new(inventory._catalog, inventory.capacity).restore(data)

func _whole(value: Variant, minimum: int, maximum: int) -> bool:
	return ((value is int or value is float) and is_finite(float(value))
		and value >= minimum and value <= maximum and value == floor(float(value)))

func _coin_string(value: Variant) -> bool:
	if not value is String or value.is_empty() or value.length() > 19:
		return false
	for character in value:
		if character < "0" or character > "9":
			return false
	if value.length() == 19 and value > str(ShopEconomy.MAX_COINS):
		return false
	return str(value.to_int()) == value and value.to_int() >= 0

func _read(file_path: String) -> Variant:
	var file := FileAccess.open(file_path, FileAccess.READ)
	if file == null or file.get_length() > MAX_FILE_BYTES:
		return null
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		return null
	return json.data

func read_save(shop: Node2D) -> Dictionary:
	message = ""
	recovered = false
	var data: Variant = _read(path)
	if validate(data, shop):
		return data
	# A newer/older schema must never be silently replaced with an older backup.
	if data is Dictionary and data.has("version") and data.version not in [1, 2, VERSION]:
		message = "Версия сохранения не поддерживается. Файл сохранён без изменений."
		return {}
	var backup: Variant = _read(path + ".bak")
	if validate(backup, shop):
		recovered = true
		message = "Основной файл недоступен. Загружена резервная копия."
		return backup
	message = "Сохранение повреждено или недоступно. Можно начать новую игру." if exists() else "Сохранений пока нет. Начните новую игру."
	return {}

func save_game(shop: Node2D) -> bool:
	var data := capture(shop)
	if not validate(data, shop):
		message = "Сохранение доступно в пустом магазине. Обслужите гостей и дождитесь их выхода."
		return false
	if not _write_file(path + ".tmp", JSON.stringify(data)) or not validate(_read(path + ".tmp"), shop):
		message = "Не удалось записать сохранение. Предыдущее сохранение не изменено."
		return false
	# Stage and verify backup before touching the primary; never back up corrupt bytes.
	if validate(_read(path), shop):
		if not _copy_file(path, path + ".bak.tmp") or not validate(_read(path + ".bak.tmp"), shop) or not _replace_file(path + ".bak.tmp", path + ".bak"):
			message = "Не удалось создать резервную копию. Предыдущее сохранение не изменено."
			return false
	if not _replace_file(path + ".tmp", path):
		message = "Не удалось заменить файл. Предыдущее сохранение не изменено."
		return false
	message = "Игра сохранена · день %d, %s" % [shop.day.day_number, shop.day.time_text()]
	return true

# Small I/O boundary also permits deterministic disk-failure tests.
func _write_file(file_path: String, contents: String) -> bool:
	var file := FileAccess.open(file_path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(contents)
	file.flush()
	var error := file.get_error()
	file.close()
	return error == OK

func _copy_file(source: String, target: String) -> bool:
	return DirAccess.copy_absolute(source, target) == OK

func _replace_file(source: String, target: String) -> bool:
	return DirAccess.rename_absolute(source, target) == OK

func load_game(shop: Node2D) -> bool:
	var data := read_save(shop)
	if data.is_empty():
		return false
	apply(data, shop)
	if not recovered:
		message = "Игра загружена · день %d, %s" % [shop.day.day_number, shop.day.time_text()]
	shop.last_save_message = message
	shop._refresh_save_status()
	return true

func apply(data: Dictionary, shop: Node2D) -> bool:
	if not validate(data, shop):
		return false
	# Validate everything first. Replace quantities before any notification sees the state.
	shop.player.set_appearance(data.character if int(data.version) >= 2 else CharacterAppearance.DEFAULT)
	shop.story = data.story.duplicate(true) if int(data.version) >= 3 else TrainStory.completed()
	shop.story.train_line = int(shop.story.train_line)
	shop.customers.reset_for_load()
	shop.economy.restore_snapshot(data.economy)
	var inventories: Array[Inventory] = [shop.player_inventory, shop.storage.inventory]
	var snapshots: Array = [data.bag, data.storage]
	for shelf in shop.customers.shelves:
		inventories.append(shelf.inventory)
		snapshots.append(data.shelves[String(shelf.name)])
	for index in range(inventories.size()):
		var normalized := {}
		for key in snapshots[index].items:
			normalized[key] = int(snapshots[index].items[key])
		inventories[index]._quantities = normalized
	shop.day.restore_snapshot(int(data.day), float(data.minute), int(data.phase))
	shop.player.position = Vector2(320, 222)
	shop.player.velocity = Vector2.ZERO
	shop.player.walking = false
	shop.player.facing = Vector2.DOWN
	for inventory in inventories:
		inventory.changed.emit()
	shop.economy.balance_changed.emit(shop.economy.balance)
	shop.economy.sales_changed.emit(shop.economy.revenue, shop.economy.completed_sales)
	shop.inventory_ui.restore_view()
	return true
