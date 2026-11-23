# Original art — stage 8

All nine PNG textures were authored specifically for Little Village Shop as integer-grid
shapes. No downloaded game sprites, stock art, external fonts or asset packs are used.
The source is [`tools/build_shop_art.py`](../tools/build_shop_art.py); its fixed seed (80)
only varies wood grain and garden marks. PNGs are committed: running Godot needs no Python
or additional dependencies. To regenerate, optionally install Pillow and run:

```sh
python3 tools/build_shop_art.py
```

| Texture | Native size / use |
| --- | --- |
| `shop/room.png` | 640×360 background: original room bounds, wood, window-light accents, rugs, wall art, plants and fixture shadows |
| `shop/shelf.png` | 64×48, unchanged shelf footprint; dynamic catalog icons and fill meter remain in `shelf.gd` |
| `shop/storage.png` | 64×32 sage chest, unchanged footprint |
| `shop/order_desk.png` | 48×32 ledger/linen/wood desk, unchanged footprint |
| `shop/checkout.png` | 64×28, includes the register above the unchanged 64×16 solid counter |
| `items/apple.png`, `bread.png`, `milk.png` | 16×16 native icons, shared by world stock, customer bubbles and UI |
| `characters/villagers.png` | 288×128 atlas, twelve 24×32 cells per row, four rows |

Atlas rows: shopkeeper, straw-hat villager, silver-haired villager, green-cap villager.
Each row contains down/up/left/right groups of three frames (idle, walk A, walk B).
The draw origin is (12,20); the existing body/feet and collision capsules are retained.
`VillagerArt` selects frames using the existing facing, walking and step values.

Palette anchors: walnut `#745440`, honey wood `#a67a53`, cream `#f0dfb4`, sage `#7b9166`,
terracotta `#a76550`, muted blue glass `#799798`. Light is authored as a few discrete,
translucent pixel shapes and baked into the background; no blur, antialiased shapes,
CanvasModulate, light textures, render-mode dependency or new light simulation is needed.

Use lossless import, mipmaps off, nearest filtering, 1× world sprites and integer canvas
scaling. Render-transform snapping is enabled; do not round physics positions. Product
icons display at 16px or 32px. Text keeps Godot's readable built-in font and the existing
cream/sage/wood theme; the panels have square, non-antialiased borders and subtle shadows.
Decor is visual only: original static bodies, approaches and AStar routes are untouched.

For reproducible real game-window captures (requires a graphical display), run official
Godot 4.3 with the optional review runner:

```sh
godot --path . --audio-driver Dummy --fixed-fps 60 --script res://tools/capture_shop.gd
```

This instantiates the production scene, freezes only the clock for review, buys goods via
`ShopEconomy`, transfers storage → bag → shelves and waits for three actual NPC visits.
It saves unmodified 1280×720 window-viewport frames in `docs/stage-8-*.png` after rendering.
No save slot is touched; the runner is never loaded by the application or CI.
