# Foundation / storage inventory milestone

## Baseline

- Inspected main at `7f6c9e6f3c8606b34f88cbabe968199f8bb37289` before editing.
- Its GitHub Actions run [45155522119](https://github.com/ksnarchive/little-village-shop/actions/runs/45155522119)
  completed successfully, independently confirmed through the GitHub API.
- Imported and smoke-tested the unmodified project locally with official Godot
  **4.3.stable.official.77dcf97d8**, matching CI. Both completed without engine/script errors.

## This slice

- Same Godot 4.3 build: editor import, **93 checks with zero failures**, and a
  60-frame main-scene smoke run. `bash tests/run_checks.sh` completes successfully.
- Checks cover product resources/prices, data-only product extension, stack/capacity
  boundaries, nonnegative stock, atomic transfers and notifications, JSON restore validation,
  existing scene instantiation, arrow/physical WASD movement, wall/storage collisions,
  interaction range and walls, physical E/I/Esc events, menu input blocking, button transfers
  and signal-driven UI labels.
- Tests synthesize engine input and exercise real scenes, not OS keyboard hardware.
- CI now uses the same runner and also fails on logged engine/script errors, even when
  Godot's process returns zero. Existing Godot version and workflow triggers are preserved.
- Full CI-log inspection found that the hosted runner lacks `rg`; the log guard now uses
  standard `grep`. A local fake-engine probe returning zero while logging a script error
  was correctly rejected. Genuine Godot checks were rerun after the guard fix.
- [PR #1](https://github.com/ksnarchive/little-village-shop/pull/1) implementation commit
  `6caea4ec50c9d9d0834f9f59f4e0c3efb0767334` passed GitHub Actions
  [45158321661](https://github.com/ksnarchive/little-village-shop/actions/runs/45158321661).

## Graphical desktop check

The published implementation commit above was cloned to the cloud Linux desktop and
opened with **Godot 4.7.2.stable.official.ed1daf0bf** (Compatibility renderer).
This is a separate graphical check, not the Godot 4.3 headless run.

- Moved down/left using real desktop arrow-key events and observed the storage prompt.
- Pressed E and inspected the rendered storage panel, item icons, labels and buttons.
  The menu fit within the base 640×360 canvas, displayed inside a larger desktop window.
- Clicked Take 1 for apple and milk: bag became 2 units and storage became 11 units,
  with both product counts updated visibly.
- Returned the apple, pressed Esc, then I: the bag showed apple 0, bread 0, milk 1.
- Text and controls were readable without clipping in the inspected window. This was
  a short desktop smoke check, not an exhaustive resolution or gameplay test.

## Foundation limitations (at that milestone)

- Graphical Godot 4.3 testing and a broader resolution sweep remain pending.
- Windows export, hardware keyboard-layout testing, gamepad/touch input and audio testing
  have not been performed. No Windows build is claimed.
- Inventory dictionaries can round-trip through JSON, but no game save file or save/load
  menu exists. Stock resets on restart.
- Storage is seeded with free demonstration goods. Economy, purchasing, shelf stock,
  customers, checkout, time and day reports are deliberately outside this milestone.

## Supplier purchasing milestone

- Branched from PR #1 at `73e4bb8255c3468d6cd79b9cfee5dad829a9279d`.
- Official Godot **4.3.stable.official.77dcf97d8** completed the editor import,
  **133 checks with zero failures**, and the 60-frame main-scene smoke run.
- Added coverage for the starting balance, catalog prices, invalid orders, insufficient
  funds, total capacity and stack limits, exact-balance purchases, and stock and balance
  notifications. The scene test opens the desk with physical E, changes the quantity,
  orders into storage, checks both failure messages, and verifies the HUD and storage view.
- In graphical Linux/Godot 4.3, walked to the order desk, opened the menu with E, and
  used the + and Order buttons to buy two apples. The balance changed from 100 to 94,
  the apple count from 6 to 8, and storage from 13 to 15 units. Esc closed the panel
  and the world HUD showed 94 coins. [Screenshot of the completed order](supplier-menu.png).

## Shelf restocking milestone

- Started from `feat/supplier-purchasing` at
  `e99941f14efff79c5ec634f60d154f3cbe7bf8a5`; PRs #1 and #2 remain unmerged.
  The shelf PR targets that supplier branch so its diff contains only this milestone.
- Rechecked the unchanged supplier baseline: **133 checks, zero failures**.
- Official **Godot 4.3.stable.official.77dcf97d8** now passes editor import,
  **187 checks with zero failures**, and the 60-frame main-scene smoke run using
  `bash tests/run_checks.sh`. The existing CI error-log guard remains active.
- The 54 new checks exercise real shelf instances, configured and zero capacity,
  invalid amounts/IDs, stack limits, atomic rejection with no notifications, exact fills,
  round trips, mixed goods, independent inventories, all three fill states, full-bag
  withdrawal rejection, live stock labels, quantity limits/clamping and forced stale actions.
- Scene/input checks cover the original shelf collision footprint, front approach and
  out-of-range use, physical E, movement/world-input blocking, Esc/I/Close, switching
  shelf subscriptions, closed-menu guards, viewport fit, and bag use afterwards.
- Graphical Linux check with the same official Godot **4.3**: walked to storage, took
  6 apples, 4 bread and 2 milk into the bag, walked to the orchard shelf and pressed E.
  Used quantity buttons to place all 12 units in batches, saw partial and full world art,
  then returned all goods to the bag. The final panel showed shelf 0/12 and bag 12/24.
  Menu labels and buttons fit inside the 640×360 base canvas without clipping in the
  inspected window. The adjacent pantry shelf stayed visibly empty; coins stayed at 100.
- Captured only the game window: [full shelf menu](shelf-menu.png) and
  [stocked shelf beside the empty pantry shelf](shelf-stock.png).
- This is a short Linux desktop check, not a Windows build or a full resolution sweep.
  Touch/gamepad controls and persistent game saves remain pending. Shelf stock resets
  on restart; no customers, selling/checkout behavior, day cycle or other large systems
  were added.

## First customers milestone

- Started from `feat/shelf-restocking` at
  `9fd68c7cabe9567d0ceb59d65e830e8dd10dc0ad`. PR #3 is still open; the customer
  PR targets that branch and contains only this milestone. No merges to main.
- Rechecked the baseline with official **Godot 4.3.stable.official.77dcf97d8**:
  editor import, **187 checks, zero failures**, and main-scene smoke run.
- The same Godot 4.3 now passes editor import, all **187 existing checks**,
  **61 additional customer checks**, and the 60-frame main-scene smoke run through
  `bash tests/run_checks.sh`. The runner still rejects logged engine/script errors.
- The dedicated customer suite instantiates the real main scene and simulates complete
  visits at fixed 60 Hz. It covers entry, delayed search, both shelf approaches,
  mixed-product pickup, movement to distinct checkout slots, permanent unpaid waiting,
  and empty-handed departure. Every simulated physics frame checks conservation of
  the original 13 demo goods; movement checks reject jumps and furniture collisions.
- Coverage includes player withdrawal while an NPC approaches a shelf, retrying another
  shelf, leaving when none remains, atomic pickup signal observations, empty one-unit
  baskets, queue admission limits, repeated automatic arrivals, timer/movement pause
  during menus, HUD fit, three appearance variants and resetting the scene.
- Graphical check on Linux with the same official **Godot 4.3**, Compatibility renderer
  (software Mesa): used actual arrow/E input to visit storage, took one apple, bread and
  milk, then walked around the storage to the orchard shelf and stocked all three using
  the existing buttons. Open menus paused visitor movement. After closing the menu,
  observed visitors carrying goods through the central aisle to the counter. The final
  view showed three distinct villagers, three product bubbles, an empty orchard shelf,
  queue 3/3 and an unchanged 100-coin balance. The pantry remained empty.
- Captured the [game canvas with the completed checkout queue](customers-checkout.png),
  cropped from the game window and enlarged 2× with nearest-neighbor scaling. No
  gameplay state or visual elements were added to the image.
- The graph is authored for the existing fixed furniture layout. One visitor browses
  while up to three wait, so moving visitors never cross occupied queue slots. NPCs
  collide with static furniture, but intentionally do not block the player or E rays.
  Changing the room layout requires revisiting route anchors and physical validation.
- Checkout service, payment, impatience, day cycles and persistent saves are not part
  of this milestone. Unpaid goods remain in NPC inventories until the scene resets;
  full queues stop arrivals. This short Linux graphical check is not a Windows build,
  touch-input check, or exhaustive resolution sweep. The environment has no audio
  device; Godot used its dummy-audio fallback during the graphical check.


## Checkout and sales milestone

- Started from `feat/first-customers` at
  `63993cf18da4b5569697ec9098f1e9c64d6c5e66`. PR #4 is still open, so this PR
  targets that branch and contains only checkout changes. No merges to main.
- Official **Godot 4.3.stable.official.77dcf97d8** passes editor import,
  **187 inventory/scene/input checks**, **61 customer checks** and **72 checkout checks**
  (**320 total, zero failures**), followed by the 60-frame main-scene smoke run via
  `tests/run_checks.sh`. No logged engine/script errors or leaked-resource warnings.
- New tests purchase four apples (100 → 88 coins), move them through storage → bag →
  shelf → NPC baskets, serve three villagers at 5 coins each, and verify balance 103,
  revenue 15, sales 3 and one apple remaining on the shelf. Every physics frame checks
  tracked goods plus completed sales against demo stock plus purchased units. Milk
  sales separately verify the catalog selling price of 12 coins.
- Sale tests cover empty/foreign/multi-unit baskets, unknown or mismatched products,
  negative and zero prices, balance/revenue/counter overflow, out-of-order customers,
  stale identities, forced double clicks, and reentrant calls from basket, balance,
  statistics and queue notifications. Observers see the complete committed transaction;
  rejected calls preserve money/goods/counters and emit no change notifications.
- Scene tests use physical E/I/Esc, test counter range/obstruction and the preserved
  storage approach, modal movement/world-input guards, empty/full queues, session reset,
  automatically resumed arrivals, and service while another visitor is approaching.
  They check continuous collision-free paid exits, NPC separation and queue advances,
  disabled service during transitions, 640×360 panel fit, signal-driven labels, success
  text and the nonblocking coin effect's cleanup.
- Checkout deliberately permits the already active visitor, paid exit and queue advance
  to finish while its panel is open. New arrivals pause. This preserves the bounded
  one-moving-visitor architecture and prevents a frozen queue or crossing routes; the
  button becomes ready automatically once movement settles. Other menus keep their
  existing complete NPC/timer pause behavior.
- Graphical Linux check with official **Godot 4.3**, Compatibility renderer: used real
  arrow/E input to take one apple, bread and milk from storage, stock the orchard shelf,
  and open checkout. Observed the active visitor finish and the service button enable.
  Clicked **Обслужить** for milk: balance **100 → 112**, revenue **12**, sales **1**,
  green sale confirmation and pixel coin sparkle; panel advanced to the next apple
  basket and showed the queue-moving status.
- [Checkout screenshot](checkout-sale.png) is the real 640×360 game canvas, cropped
  from the desktop capture and enlarged 2× using nearest-neighbor scaling. No game
  state or visual elements were added to the image.
- This is a short Linux graphical check, not a Windows build or exhaustive resolution
  sweep. No day cycle, game saves or new large systems were added. Balance, goods,
  customers and sales totals reset on restart. Routes remain authored for this room.

## Stage 6 — workdays and game time

- Started from current merged `main`, verified again before publishing at
  `ccd589ced2626f5ccee7f227ec9a03e1454080c8`, on separate branch `feat/day-cycle`.
  Existing room, inventories, supplier, shelves, customer FSM, routes and checkout are reused.
- Official **Godot 4.3.stable.official.77dcf97d8** passes editor import,
  **187 inventory/scene/input + 61 customer + 72 checkout + 80 day checks**
  (**400 total, zero failures**) and the 60-frame main-scene smoke run through
  `bash tests/run_checks.sh`. The final run has no logged engine/script errors or
  leaked-resource warnings. The same runner includes the day suite in GitHub Actions.
- Clock tests check 08:00, 08:59/09:00, 11:59/12:00, 13:59/14:00, 17:59/18:00,
  invalid deltas, ordered boundaries after a long frame, and the actual shorter lunch
  arrival delay. All five modal views pause game time and resume it on close.
  Existing customer/checkout suites explicitly use a frozen 09:00 clock to retain their
  focused route/transaction coverage without accidentally waiting through preparation.
- Closing tests include an empty-handed visitor, an already waiting customer plus an
  incoming shopper, checkout service after 18:00, queue advance and the last paid exit.
  Admission is blocked immediately; the report waits until all NPCs are gone. Checkout
  movement continues while its panel is open and can trigger the report without closing
  that panel manually. Paid customers count once; empty-handed visitors do not count.
- Three **complete automatic workdays** run in the real main scene at fixed 60 Hz using
  the production 1.5-game-minutes/second clock. Each day buys two apples (6 coins),
  stocks four apples and one milk, and serves all five visitors (32 coins). Reports show
  profit 26 and successive balances **126, 152, 178**. Each transition starts at 08:00,
  preserves storage and the untraded bag contents, resets only daily counters, and emits
  exactly one report. Every simulated physics frame checks goods plus session sales and
  the balance equation; no customer, goods or money duplication was observed.
- Additional checks cover purchase/sale observers seeing committed daily values, rejected
  purchases, full storage rollback, duplicate sales/next-day clicks, negative profit,
  report snapshot isolation, Esc/I locks, hidden-transaction rejection, retained unsold
  shelf stock and earned coins, and report fit within the 640×360 viewport.
- Graphical Linux verification uses the same official **Godot 4.3**, Compatibility renderer
  (software Mesa). Opened the bag with actual desktop input, confirmed the clock stayed
  at 08:36 while the menu remained open, and closed it with Esc. Inspected the rendered
  clock and report. Clicked **«Следующий день»** on the desktop and observed **day 2,
  08:00**, retained **99 coins** and the remaining apples on the shelf.
- [Clock during lunch](day-clock.png) and [day report](day-summary.png) are unmodified
  **640×360 viewport captures** from that Godot 4.3 renderer. A temporary external preview
  harness used the real purchase/transfer/NPC/service APIs and advanced the clock to show
  noon and closing quickly. The captured example buys two apples (6 coins), sells one
  apple (5 coins), and correctly reports **profit −1, balance 99**. The harness is not part
  of the game and does not add a debug shortcut or disk save mechanism.
- This is a short Linux visual check plus automated multi-day physics simulation, not a
  Windows build or exhaustive display sweep. The cloud desktop has no audio device;
  Godot used its dummy audio fallback. Touch/gamepad support, Windows export and disk
  saves remain separate work. Restarting the application still creates a fresh game.
