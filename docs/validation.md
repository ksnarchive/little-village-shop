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

## Pending / limitations

- Graphical Godot 4.3 testing and a broader resolution sweep remain pending.
- Windows export, hardware keyboard-layout testing, gamepad/touch input and audio testing
  have not been performed. No Windows build is claimed.
- Inventory dictionaries can round-trip through JSON, but no game save file or save/load
  menu exists. Stock resets on restart.
- Storage is seeded with free demonstration goods. Economy, purchasing, shelf stock,
  customers, checkout, time and day reports are deliberately outside this milestone.
