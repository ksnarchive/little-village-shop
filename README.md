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
- **E** at the right front of the checkout counter opens service. The panel shows the
  first villager's product, selling price, balance and session sales totals. Select
  **Обслужить** to accept payment; **Esc**, **I** or Close returns to the room.
- Successful sales empty exactly one NPC basket, credit the product's `selling_price`,
  and show a green confirmation with a small pixel coin sparkle. The HUD tracks gross
  revenue and the number of completed sales for this session.
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
Visitors arrive automatically at the south doorway after the shop opens at 09:00
(first after 4 seconds). They walk
into the central aisle, look for stocked shelves, choose one available product and carry it
in a small basket to the checkout. Empty-handed visitors walk back out; if the player empties
a target shelf en route, they search again or leave. Stock the shelves using the existing
storage → bag → shelf flow to see a successful visit.

Three villagers have different coats, hair and headwear in the same original pixel style.
A product bubble shows the goods being carried; floor marks and a HUD counter explain the
checkout queue. One visitor browses at a time, with a 7-second gap after a completed visit.
Up to three customers wait at distinct checkout positions. Arrivals stop when all three
places are occupied. Unpaid goods stay in NPC baskets until served. The paid villager
walks out along a separate lane above the queue, then the remaining villagers walk forward.
During business hours, new arrivals resume when space is available and the arrival interval elapses.

Inventory, supplier and shelf menus pause visitors and arrival timers alongside the
shopkeeper. The checkout menu blocks player/world input and new arrivals, but allows an
already active visitor to finish their visit, paid departures and queue advances to move.
To preserve the existing one-moving-visitor routes, service briefly waits for that active
visit to finish and for the queue to settle. The status explains the wait and the service
button enables automatically; there is no need to close/reopen the panel between sales.

## Workdays and game time

- The cream clock card shows the current day, HH:MM and shop phase.
- A new game begins on **day 1 at 08:00**. Preparation lasts until **09:00**;
  buying, bag/storage transfers and shelf restocking are available immediately.
- At **09:00** the shop opens automatically. **12:00–14:00** is the lunch rush:
  the gap between visits drops from **7 to 3 seconds**, within the existing bounded
  queue and one-browsing-customer routing. Normal arrivals resume at **14:00**.
- At **18:00** admission closes. Existing visitors finish browsing or leave empty-handed;
  waiting guests still need service at the counter. No goods or guests are discarded.
- After the last guest walks out, the day report shows the day number, paid customers,
  gross revenue, supplier expenses, profit (revenue minus expenses), and current balance.
  **«Следующий день»** begins the next morning at **08:00**. Esc/I cannot skip the report.
- Time runs at **1.5 game minutes per real second**: a day takes **6 minutes 40 seconds**,
  plus time spent in menus and serving remaining guests after closing. Every menu pauses
  the clock, including checkout. Checkout retains its existing NPC movement exception so
  active visits, departures and queue advances can finish while the panel is open.
- Day transitions reuse the same economy, bag, storage and shelf inventories. Coins and
  unsold goods persist; only daily totals and the arrival delay reset. Purchases during
  preparation count toward that day's expenses. Free demo stock is not an expense.
- Reports are in-memory snapshots. Restarting still starts a fresh game; there is no disk
  save system. A quiet/empty shop also completes its day with a zero-sales report.

Previews: [clock during lunch](docs/day-clock.png) · [end-of-day report](docs/day-summary.png).

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
| `scripts/shop_economy.gd` | Balance, validated supplier purchases, atomic basket sales, session/daily totals |
| `scripts/shop_day.gd`, `scenes/ui/day_report.tscn` | Clock, shop phases, closing drain, immutable report snapshots and next morning |
| `scripts/checkout_menu.gd`, `scenes/ui/checkout_menu.tscn`, `scripts/coin_effect.gd` | First-customer service panel, sale feedback and transient pixel coins |
| `scripts/inventory_menu.gd`, `scenes/ui/inventory_menu.tscn` | Bag and storage panels, modal input, balance HUD |
| `scripts/supplier_menu.gd`, `scenes/ui/supplier_menu.tscn` | Supplier catalog, quantities, subtotals and delivery status |
| `assets/items/` | Original SVG icons composed on a 16×16 pixel grid |
| `tests/run_tests.gd`, `tests/run_customer_tests.gd`, `tests/run_checkout_tests.gd`, `tests/run_day_tests.gd`, `tests/run_checks.sh` | Logic, scene/input integration, complete customer visits and smoke checks |

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
one-unit `basket`; nothing is sold, deleted or copied merely by reaching checkout. Stock is
read again on arrival rather than reserved during route planning. NPCs use shelf interaction
positions as approach anchors without opening the player's interaction menus. The authored
`AStar2D` graph connects the doorway, foyer, central aisle, shelf fronts and checkout slots.
It is designed for this fixed room; moving furniture requires updating routes and rerunning
the physics tests. Visitors collide with walls/furniture, and do not block player movement
or E-interaction rays. Only one browsing shopper is admitted. Service waits until it joins the queue or leaves,
then one paid departure completes before the queue advances together. Arrivals stay blocked
during this transition, so walkers do not cross occupied queue slots or shelf approaches.

`CustomerFlow.serve_customer(expected_customer)` validates the displayed identity, first
queue position, settled state and basket against `ShopEconomy.can_sell()`. It stages queue
removal and departure without callbacks, then `ShopEconomy.sell()` commits basket removal,
balance, revenue and completed-sales count before any notification. The flow/economy guards
reject reentrant service, repeated clicks and stale identities. Invalid baskets, mismatched
catalogs, negative prices and integer overflows leave goods and coins untouched. Revenue
is gross selling proceeds, not profit; purchases do not increase it. The existing revenue and sales HUD remains session-wide. Separate daily counters include
only successful purchases and paid sales, committed before transaction notifications.
Daily counters reset at the next morning; session totals reset only on restart.

Checkout preview: [successful sale with the next basket](docs/checkout-sale.png).

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
change coins, consume goods or remove customers. Checkout checks run the complete
purchase → storage → bag → shelf → NPC → payment loop, verify stock plus sold-unit
conservation on every physics frame, and inspect all transaction notifications. They cover
reentrant/stale/out-of-order calls, double clicks, invalid baskets, prices/overflow, continuous
paid exits and queue advances, resumed arrivals, input guards, counter reset, feedback and
coin cleanup. Day checks cover minute boundaries, actual lunch arrival delay, all modal
clock pauses, empty and occupied closing, after-hours sales, final departures, report input
locks/snapshots, duplicate next-day clicks, negative profit and three automatic full workdays.
Every physics frame checks goods plus sold units and the balance equation across days.
A main-scene smoke run follows the tests.

Headless results do not establish visual quality or Windows compatibility. See
[`docs/validation.md`](docs/validation.md) for this milestone's actual verification and limitations.

## Next milestones

1. Versioned game saves (separate milestone).
2. Original art/audio, broader desktop testing and Windows export.

The current procedural room is preserved; village expansion remains future work.
All current graphics are original project placeholders; no commercial game assets are used.
