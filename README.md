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

The bag starts empty (24-unit capacity). Storage holds 6 apples, 4 bread and 3 milk
(60-unit capacity) as **free demo stock**. Restarting resets inventory and balance.
Shelves and checkout remain decorative collision objects.

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
| `scripts/shop_economy.gd` | Balance and validated supplier purchases |
| `scripts/inventory_menu.gd`, `scenes/ui/inventory_menu.tscn` | Bag and storage panels, modal input, balance HUD |
| `scripts/supplier_menu.gd`, `scenes/ui/supplier_menu.tscn` | Supplier catalog, quantities, subtotals and delivery status |
| `assets/items/` | Original SVG icons composed on a 16×16 pixel grid |
| `tests/run_tests.gd`, `tests/run_checks.sh` | Logic, scene/input integration and smoke checks |

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
successful and rejected supplier orders, and balance and stock updates.
A main-scene smoke run follows the tests.

Headless results do not establish visual quality or Windows compatibility. See
[`docs/validation.md`](docs/validation.md) for this milestone's actual verification and limitations.

## Next milestones

1. Shelf restocking.
2. Customer navigation/FSM and checkout queue.
3. Day cycle, reports and versioned game saves.
4. Original art/audio, broader desktop testing and Windows export.

The current procedural room is preserved; no village, customer or checkout systems have been added.
All current graphics are original project placeholders; no commercial game assets are used.
