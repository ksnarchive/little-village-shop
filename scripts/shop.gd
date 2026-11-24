extends Node2D
## Composition/wiring and original pastel room art. Economy and save wiring are unchanged.
const ROOM_ART: Texture2D = preload("res://assets/shop/room.png")
const CHECKOUT_ART: Texture2D = preload("res://assets/shop/checkout.png")
const CATALOG: ItemCatalog = preload("res://data/item_catalog.tres")
var player_inventory: Inventory
var economy: ShopEconomy
var save_store: SaveStore
var last_save_message: String = ""
var day: ShopDay
@onready var player: Shopkeeper = $Player
@onready var interactions: InteractionController = $Player/InteractionController
@onready var storage: ShopStorage = $Storage
@onready var order_desk: Interactable = $OrderDesk
@onready var inventory_ui: InventoryMenu = $InventoryUI
@onready var customers: CustomerFlow = $Customers
var fixtures: Array[Rect2] = [
    Rect2(176, 272, 64, 16)
]

func _ready() -> void:
    # Solid walls, leaving a doorway on the south side.
    _solid(Rect2(128, 48, 384, 16))
    _solid(Rect2(128, 48, 16, 264))
    _solid(Rect2(496, 48, 16, 264))
    _solid(Rect2(128, 296, 176, 16))
    _solid(Rect2(336, 296, 176, 16))
    for fixture in fixtures:
        _solid(fixture)
    player_inventory = Inventory.new(CATALOG, 24)
    economy = ShopEconomy.new(CATALOG, storage.inventory)
    inventory_ui.configure(CATALOG, player_inventory, storage.inventory)
    inventory_ui.configure_supplier(CATALOG, storage.inventory, economy)
    inventory_ui.configure_shelves(CATALOG, player_inventory)
    customers.configure(CATALOG, [$LeftShelf, $RightShelf])
    customers.economy = economy
    inventory_ui.configure_checkout(customers, economy)
    $Checkout.interacted.connect(_on_checkout_interacted)
    customers.queue_changed.connect(inventory_ui.set_checkout_waiting)
    for shelf: ShopShelf in [$LeftShelf, $RightShelf]:
        shelf.interacted.connect(_on_shelf_interacted.bind(shelf))
    storage.interacted.connect(_on_storage_interacted)
    order_desk.interacted.connect(_on_order_desk_interacted)
    interactions.target_changed.connect(_on_target_changed)
    inventory_ui.menu_visibility_changed.connect(_on_menu_visibility_changed)
    day = ShopDay.new()
    add_child(day)
    day.configure(customers, economy)
    inventory_ui.configure_day(day)
    inventory_ui.save_requested.connect(save_game)
    day.day_finished.connect(_autosave_report)
    day.day_started.connect(save_game)
    queue_redraw()

func _on_checkout_interacted(actor: Node2D) -> void:
    if actor == player:
        inventory_ui.open_checkout()

func _on_shelf_interacted(actor: Node2D, shelf: ShopShelf) -> void:
    if actor == player:
        inventory_ui.open_shelf(shelf)

func _on_storage_interacted(actor: Node2D) -> void:
    if actor == player:
        inventory_ui.open_storage()

func _on_order_desk_interacted(actor: Node2D) -> void:
    if actor == player:
        inventory_ui.open_supplier()

func _on_target_changed(target: Interactable) -> void:
    inventory_ui.set_prompt(target.prompt if target != null else "")

func _on_menu_visibility_changed(is_open: bool) -> void:
    if inventory_ui.view == InventoryMenu.View.PAUSE:
        _refresh_save_status()
    if day != null:
        day.paused = is_open
    player.controls_enabled = not is_open
    interactions.enabled = not is_open
    # Checkout lets the active visit, paid departure and queue advance finish. Other menus
    # preserve the existing complete pause of NPCs and arrival timers.
    customers.service_menu_open = is_open and inventory_ui.view == InventoryMenu.View.CHECKOUT
    customers.process_mode = Node.PROCESS_MODE_DISABLED if is_open and not customers.service_menu_open else Node.PROCESS_MODE_INHERIT

func _solid(rect: Rect2) -> void:
    var body := StaticBody2D.new()
    body.collision_layer = 2
    body.collision_mask = 0
    body.position = rect.position + rect.size / 2.0
    var shape := CollisionShape2D.new()
    var box := RectangleShape2D.new()
    box.size = rect.size
    shape.shape = box
    body.add_child(shape)
    add_child(body)

func _draw() -> void:
    draw_texture(ROOM_ART, Vector2.ZERO)
    draw_texture(CHECKOUT_ART, Vector2(176, 252))

func _refresh_save_status() -> void:
    inventory_ui.save_notice.text = last_save_message
    inventory_ui.report_save_status.text = last_save_message if not last_save_message.is_empty() else "Товары и монеты останутся в магазине."
    var safe := customers.is_empty()
    inventory_ui.save_button.disabled = not safe or save_store == null
    inventory_ui.save_status.text = (last_save_message if not last_save_message.is_empty() else
        "Можно сохранить прогресс. Часы и гости на паузе.") if safe else (
        "Сначала обслужите всех гостей и дождитесь их выхода. Затем вернитесь в паузу для сохранения.")

func save_game() -> bool:
    if save_store == null:
        return false
    var success := save_store.save_game(self)
    last_save_message = save_store.message
    _refresh_save_status()
    return success

func _autosave_report(_report: Dictionary) -> void:
    save_game()
