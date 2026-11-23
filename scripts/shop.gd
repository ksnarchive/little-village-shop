extends Node2D
## Self-contained prototype room drawn in code until original tiles are ready.
const WALL := Color("#8c654b")
const FLOOR := Color("#e7cda4")
const FLOOR_ALT := Color("#dfc39a")
const SHELF_DARK := Color("#765238")
const COUNTER := Color("#9d7455")
const WINDOW := Color("#a7c4cb")
const ROOM := Rect2(128, 48, 384, 264)
const TILE: int = 16
const CATALOG: ItemCatalog = preload("res://data/item_catalog.tres")
var player_inventory: Inventory
var economy: ShopEconomy
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
    customers.queue_changed.connect(inventory_ui.set_checkout_waiting)
    for shelf: ShopShelf in [$LeftShelf, $RightShelf]:
        shelf.interacted.connect(_on_shelf_interacted.bind(shelf))
    storage.interacted.connect(_on_storage_interacted)
    order_desk.interacted.connect(_on_order_desk_interacted)
    interactions.target_changed.connect(_on_target_changed)
    inventory_ui.menu_visibility_changed.connect(_on_menu_visibility_changed)
    queue_redraw()

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
    player.controls_enabled = not is_open
    interactions.enabled = not is_open
    customers.process_mode = Node.PROCESS_MODE_DISABLED if is_open else Node.PROCESS_MODE_INHERIT

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
    draw_rect(Rect2(Vector2.ZERO, Vector2(640, 360)), Color("#819c70"))
    draw_rect(ROOM, FLOOR)
    for x in range(8, 32):
        for y in range(3, 20):
            if (x + y) % 2 == 0:
                draw_rect(Rect2(x * TILE, y * TILE, TILE, TILE), FLOOR_ALT)
    # Wall border, with a walkable doorway at the bottom.
    draw_rect(Rect2(128, 48, 384, 16), WALL)
    draw_rect(Rect2(128, 48, 16, 264), WALL)
    draw_rect(Rect2(496, 48, 16, 264), WALL)
    draw_rect(Rect2(128, 296, 176, 16), WALL)
    draw_rect(Rect2(336, 296, 176, 16), WALL)
    draw_rect(Rect2(304, 296, 32, 6), Color("#77926b"))
    for wx in [208, 416]:
        draw_rect(Rect2(wx, 48, 32, 12), WINDOW)
        draw_line(Vector2(wx + 16, 48), Vector2(wx + 16, 60), WALL, 2)
    _fixture(fixtures[0], COUNTER, SHELF_DARK)
    # Small flowers outside.
    for p in [Vector2(96, 80), Vector2(544, 110), Vector2(110, 275), Vector2(540, 275)]:
        draw_circle(p, 5, Color("#f1deb7"))
        draw_circle(p, 2, Color("#d8a15f"))

func _fixture(rect: Rect2, color: Color, edge: Color) -> void:
    draw_rect(rect, edge)
    draw_rect(Rect2(rect.position + Vector2(3, 3), rect.size - Vector2(6, 6)), color)
