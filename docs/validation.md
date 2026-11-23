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
