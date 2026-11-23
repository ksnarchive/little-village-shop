# 🌿 Little Village Shop

A cozy pixel-art shopkeeping prototype in **Godot 4.3 / GDScript**, targeting Windows.

## Playable slice

- Existing procedural shop, shopkeeper, idle/walking poses, walls and furniture collisions.
- Physical **WASD** (including alternate keyboard layouts) or **arrow keys** to move.
- **E** near the front of the green storage chest opens its inventory. A contextual prompt
  appears within 36 pixels of the interaction point; walls/furniture block the interaction ray.
- **I** opens/closes the player's bag; **Esc** or the Close button closes a menu.
- Cream/wood panels, sage buttons, keyboard focus and original 16×16 product icons.
- Take or return one item at a time using storage buttons; quantities and enabled buttons
  update immediately. Movement and world interaction stop while a menu is open.
- **E** at the front of the wooden order desk opens the village supplier. Choose a quantity
  with **− / +** and select **Order**. Apples cost 3 coins each, bread 5, and milk 7.
- The shop starts with **100 coins**. The HUD and supplier panel show the current balance.
  Each order delivers one product directly to storage when there are enough coins and the
  full quantity fits. The panel updates the balance and storage after the delivery.
- **E** at the front of either wooden shelf opens its restocking menu. Collect goods from
  storage into your bag first, select a product row and quantity with **− / +**, then choose
  **Stock** to place goods or **Take** to return them to your bag.
- The shelf menu shows its name, fill meter, total capacity and per-product counts on both
  sides. Buttons respect available stock, shared capacity and product stack limits; no partial
  transfers occur. Esc, I or Close dismisses the menu and restores movement.
- Empty, partly stocked and full shelves look different in the room: product icons gradually
  fill the two tiers and a small stock meter tracks total occupancy. Each shelf keeps its
  own stock when the menu closes; restarting resets both shelves.

The bag starts empty (24-unit capacity). Storage holds 6 apples, 4 bread and 3 milk
(60-unit capacity) as **free demo stock**. Restarting resets inventory and balance.
Both shelves start empty, each with its own **12-unit capacity** shared across products.
Visitors arrive automatically at the south doorway (first after 4 seconds). They walk
into the central aisle, look for stocked shelves, choose one available product and carry it
in a small basket to the checkout. Empty-handed visitors walk back out; if the player empties
a target shelf en route, they search again or leave. Stock the shelves using the existing
storage → bag → shelf flow to see a successful visit.

Three villagers have different coats, hair and headwear in the same original pixel style.
A product bubble shows the goods being carried; floor marks and a HUD counter explain the
checkout queue. One visitor browses at a time, with a 7-second gap after a completed visit.
Up to three customers wait at distinct checkout positions. Arrivals stop when all three
places are occupied. **There is no payment or checkout service yet**: customers and their
unpaid goods remain at the counter until restart. Open menus pause visitors and arrival
timers alongside the shopkeeper.

## Run

Open `project.godot` in Godot **4.3** and press F5. No external assets or plugins are needed.
The base viewport is 640×360 with nearest filtering and integer canvas scaling.
This is a desktop keyboard/mouse prototype; touch controls and a Windows export are pending.

## Code map

| Files | Responsibility |
| --- | --- |
| `scripts/player.gd`, `scenes/characters/player.tscn` | Existing CharacterBody2D movement and procedural character |
| `scripts/shop.gd`, `scenes/main.tscn` | Existing room and small composition/wiring layer |
| `scripts/interactable.gd` | Group-based endpoint, prompt, interaction position and actor signal |
| `scripts/interaction_controller.gd` | Player child component: nearest target, range, obstruction ray and E input |
| `scripts/item_data.gd`, `scripts/item_catalog.gd`, `data/` | Product definitions and shared catalog |
| `scripts/inventory.gd` | UI-independent quantities, capacity, atomic transfers, notifications and serialization |
| `scripts/storage.gd`, `scenes/objects/storage.tscn` | Reusable storage, initial stock and its original collision footprint |
| `scripts/order_desk.gd`, `scenes/objects/order_desk.tscn` | Order desk appearance, collision and interaction point |
| `scripts/shelf.gd`, `scenes/objects/shelf.tscn` | Reusable shelf, independent Inventory, original collision footprint and stock-driven pixel art |
| `scripts/shelf_menu.gd`, `scenes/ui/shelf_menu.tscn` | Quantity selection and validated bag ↔ shelf transfers in the shared modal UI |
| `scripts/customer.gd`, `scenes/characters/customer.tscn` | Visitor FSM, continuous physics movement, one-unit unpaid basket and three original villager appearances |
| `scripts/customer_flow.gd` | Bounded arrivals, authored AStar2D aisle routes, shelf discovery and three checkout positions |
| `scripts/shop_economy.gd` | Balance and validated supplier purchases |
| `scripts/inventory_menu.gd`, `scenes/ui/inventory_menu.tscn` | Bag and storage panels, modal input, balance HUD |
| `scripts/supplier_menu.gd`, `scenes/ui/supplier_menu.tscn` | Supplier catalog, quantities, subtotals and delivery status |
| `assets/items/` | Original SVG icons composed on a 16×16 pixel grid |
| `tests/run_tests.gd`, `tests/run_customer_tests.gd`, `tests/run_checks.sh` | Logic, scene/input integration, complete customer visits and smoke checks |

Inventory capacity counts **total units**, not slots. Each product has one stack limited by
`max_stack_size`. Rejected operations change nothing and emit no change notification.
A transfer validates both inventories and updates both before emitting signals.
Inventories share catalog product resources; UI code does not store a second copy of stock.
`serialize()` returns an independent dictionary, and `restore()` validates a complete candidate
before replacing stock, accepting JSON whole numbers and rejecting invalid IDs/quantities.
These are inventory serialization primitives, **not a game save/load system**.

To add a product, create an `ItemData` resource and add it to `data/item_catalog.tres`.
The bag and storage menus build rows from this catalog without product-specific logic.
The supplier builds its rows from the same catalog and uses each product's purchase price.
Shelf menus and world icons also use this catalog. A shelf owns an `Inventory`; the UI calls
`transfer_to()` in either direction, and stock signals refresh the menu and redraw the fixture.
Configure `capacity` and `display_name` on each instance of `scenes/objects/shelf.tscn`.
Shelf capacity is shared across all products, with no extra product/category restriction.
The six visible product positions represent occupancy, rather than a one-icon-per-unit count.

Customer goods move with the existing atomic `Inventory.transfer_to()` into each NPC's
one-unit `basket`; nothing is sold, deleted or copied when they reach checkout. Stock is
read again on arrival rather than reserved during route planning. NPCs use shelf interaction
positions as approach anchors without opening the player's interaction menus. The authored
`AStar2D` graph connects the doorway, foyer, central aisle, shelf fronts and checkout slots.
It is designed for this fixed room; moving furniture requires updating routes and rerunning
the physics tests. Visitors collide with walls/furniture, and do not block player movement
or E-interaction rays. Only one moving shopper is admitted, so checkout arrivals do not
cross occupied queue slots or compete for narrow shelf approaches.

Customer preview: [three villagers waiting at checkout](docs/customers-checkout.png).

Shelf previews: [restocking menu](docs/shelf-menu.png) · [stocked shelf in the room](docs/shelf-stock.png).

## Automated validation

GitHub Actions imports and tests with **Godot 4.3**, on main pushes and pull requests.
It also supports manual runs from the Actions tab. For development environments:

```sh
bash tests/run_checks.sh
# Or: GODOT_BIN=/path/to/godot bash tests/run_checks.sh
```

The runner fails on logged engine/script errors as well as nonzero exit codes. It checks
product data, negative/unknown quantities, capacity and stack limits, atomic transfers,
notifications, JSON round-trips, malformed restores, real scene instantiation, movement,
wall/furniture collisions, range/obstruction, physical E/I/Esc input, movement blocking,
successful and rejected supplier orders, balance and stock updates, and shelf deposits and
withdrawals, mixed-product capacity, independent shelf inventories, fill-state transitions,
full-bag rejection, quantity clamping, modal controls and viewport fit.
Customer checks additionally cover empty visits, all FSM transitions, both stocked shelves,
mixed products, stale stock and alternate-shelf recovery, automatic arrivals, bounded queues,
modal pause/resume, distinct villager appearances, HUD fit and restart. They simulate whole
visits with real physics, checking collision-free continuous motion and conservation of all
goods on every physics frame, including atomic transfer notifications. Waiting does not
change coins, consume goods or remove customers. A main-scene smoke run follows the tests.

Headless results do not establish visual quality or Windows compatibility. See
[`docs/validation.md`](docs/validation.md) for this milestone's actual verification and limitations.

## Next milestones

1. Checkout service/payment (separate future milestone).
2. Day cycle, reports and versioned game saves.
3. Original art/audio, broader desktop testing and Windows export.

The current procedural room is preserved; village expansion, checkout service and day systems remain future work.
All current graphics are original project placeholders; no commercial game assets are used.
