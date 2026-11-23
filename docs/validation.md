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

## Pending / limitations

- Graphical desktop verification is pending at this source revision; headless tests alone
  do not prove the menu's rendered appearance.
- Windows export, hardware keyboard-layout testing, gamepad/touch input and audio testing
  have not been performed. No Windows build is claimed.
- Inventory dictionaries can round-trip through JSON, but no game save file or save/load
  menu exists. Stock resets on restart.
- Storage is seeded with free demonstration goods. Economy, purchasing, shelf stock,
  customers, checkout, time and day reports are deliberately outside this milestone.
