#!/usr/bin/env python3
"""Prepare illustrated actor materials and baked walk cycles from original masters.

Authoring only: Pillow, no runtime pixel generation. Numeric appearance IDs and
the train assets are deliberately not changed. 64x96 cells, four directions,
neutral/blink + six body walk poses per direction. Compact head states are
shared across the walk cycle. Right views mirror the left view.
"""
from pathlib import Path
import math
from PIL import Image, ImageDraw, ImageFilter, ImageOps

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / 'art/characters'
OUT = ROOT / 'assets/characters'
SIZE = (64, 96)
POSES = 8
NN = Image.Resampling.NEAREST


def cell(sheet, col, row, rows):
    w, h = sheet.size
    return sheet.crop((round(col*w/3), round(row*h/rows),
                       round((col+1)*w/3), round((row+1)*h/rows))).convert('RGBA')


def background(r, g, b):
    return r > 65 and b > 65 and r > g*1.8 and b > g*1.8


def keyed(im):
    result = im.copy()
    p = result.load()
    for y in range(im.height):
        for x in range(im.width):
            if background(*p[x, y][:3]):
                p[x, y] = (0, 0, 0, 0)
    return result


def place(im, scale, anchor, target):
    result = Image.new('RGBA', SIZE)
    im = im.resize((round(im.width*scale), round(im.height*scale)), NN)
    result.alpha_composite(im, (round(target[0]-anchor[0]*scale),
                                round(target[1]-anchor[1]*scale)))
    return result


def head_layers(im):
    p = im.load()
    cyan = [(x, y) for y in range(im.height) for x in range(im.width)
            if p[x, y][3] and p[x, y][2] > p[x, y][0]*1.18
            and p[x, y][1] > p[x, y][0]*1.16]
    bottom = max(y for x, y in cyan)
    neck = [(x, y) for x, y in cyan if y >= bottom-5]
    anchor = (sum(x for x, y in neck)/len(neck), bottom)
    mask = Image.new('L', im.size)
    for point in cyan:
        mask.putpixel(point, 255)
    # Close narrow breaks and fill the bounded eye/mouth cavities. Hair remains
    # connected to the outside; it cannot leak into the fixed facial-detail plate.
    mask = mask.filter(ImageFilter.MaxFilter(5)).filter(ImageFilter.MinFilter(5))
    flooded = ImageOps.invert(mask)
    ImageDraw.floodfill(flooded, (0, 0), 128)
    interior = flooded.load()
    layers = {name: Image.new('RGBA', im.size) for name in ['body', 'hair', 'face', 'eyes']}
    dest = {name: image.load() for name, image in layers.items()}
    red = set()
    for y in range(im.height):
        for x in range(im.width):
            r, g, b, a = p[x, y]
            if not a:
                continue
            if r > 90 and r > g*1.6 and b < r*.65:
                red.add((x, y))
                v = max(120, r)
                dest['eyes'][x, y] = (v, v, v, 255)
            elif b > r*1.18 and g > r*1.16:
                v = max(r, g, b)
                dest['body'][x, y] = (v, v, v, 255)
            elif interior[x, y] == 255:
                dest['face'][x, y] = (r, g, b, 255)
            else:
                v = round((r+g+b)/3)
                dest['hair'][x, y] = (v, v, v, 255)
    # Isolate visible iris components for a small closed-lid pose; the rest of
    # the portrait is painted source art, including nose, lips, lashes and ears.
    eyes = []
    while red:
        todo = [red.pop()]
        points = []
        while todo:
            x, y = todo.pop()
            points.append((x, y))
            for n in [(x-1, y), (x+1, y), (x, y-1), (x, y+1)]:
                if n in red:
                    red.remove(n)
                    todo.append(n)
        if len(points) > 8:
            eyes.append(points)
    scale = .155
    layers = {name: place(image, scale, anchor, (32, 46)) for name, image in layers.items()}
    closed = {name: image.copy() for name, image in layers.items()}
    for points in sorted(eyes, key=len, reverse=True)[:2]:
        x0 = round((min(x for x, y in points)-anchor[0])*scale+32)-1
        x1 = round((max(x for x, y in points)-anchor[0])*scale+32)+2
        y0 = round((min(y for x, y in points)-anchor[1])*scale+46)-1
        y1 = round((max(y for x, y in points)-anchor[1])*scale+46)+1
        # Reuse the painted lower eyelid's skin value, no universal skin color.
        sample = closed['body'].getpixel(((x0+x1)//2, min(95, y1+2)))
        tone = sample[0] if sample[3] else 190
        ImageDraw.Draw(closed['body']).ellipse((x0-1, y0, x1+1, y1+1), fill=(tone, tone, tone, 255))
        for name in ['face', 'eyes']:
            ImageDraw.Draw(closed[name]).rectangle((x0-1, y0, x1+1, y1+1), fill=(0, 0, 0, 0))
        ImageDraw.Draw(closed['face']).line([(x0, y0+2), ((x0+x1)//2, y1), (x1, y0+2)], fill='#57312e')
    return layers, closed


def garment_layers(im):
    p = im.load()
    solid = [(x, y) for y in range(im.height) for x in range(im.width) if p[x, y][3]]
    skin = set((x, y) for x, y in solid if p[x, y][1] > p[x, y][0]*1.25
               and p[x, y][1] > p[x, y][2]*1.5 and p[x, y][0] > p[x, y][2]*1.3)
    todo = list(skin)
    while todo:
        x, y = todo.pop()
        for nx, ny in [(x-1, y), (x+1, y), (x, y-1), (x, y+1)]:
            if not (0 <= nx < im.width and 0 <= ny < im.height) or (nx, ny) in skin:
                continue
            r, g, b, a = p[nx, ny]
            if a and g >= r*.98 and g > b*1.7 and r-b > 20:
                skin.add((nx, ny))
                todo.append((nx, ny))
    top = min(y for x, y in skin)
    neck = [(x, y) for x, y in skin if y < top+10]
    anchor = (sum(x for x, y in neck)/len(neck), top)
    scale = 51/(max(y for x, y in solid)-top)
    clothes, hands = Image.new('RGBA', im.size), Image.new('RGBA', im.size)
    cp, hp = clothes.load(), hands.load()
    for x, y in solid:
        r, g, b, a = p[x, y]
        if (x, y) in skin:
            v = min(255, round(g*1.05))
            hp[x, y] = (v, v, v, a)
        else:
            cp[x, y] = (r, g, b, a)
    return {name: place(image, scale, anchor, (32, 43))
            for name, image in [('clothes', clothes), ('hands', hands)]}


def walk(im, phase, direction, head=False, skirt=False, bobbing=True):
    """Offline articulated raster warp: weight grows smoothly towards extremities.
    Registered material layers use exactly the same displacement field. Feet lift
    and exchange lead; arms swing in opposition; head/cloth share a quiet bob.
    """
    result = Image.new('RGBA', SIZE)
    src, dst = im.load(), result.load()
    wave = math.sin(phase)
    follow = math.cos(phase)
    bob = round(abs(wave)) if bobbing else 0
    for y in range(SIZE[1]):
        for x in range(SIZE[0]):
            dx, dy = 0.0, float(bob)
            if head:
                dx = wave*.7*max(0, (y-43)/30)
            elif y > 74:
                weight = min(1, (y-74)/20)
                side = -1 if x < 32 else 1
                dy = bob*(1-weight)-max(0, wave*side)*2*weight
                dx = (wave*(3 if direction >= 2 else .7) + follow*1.3)*side*weight
                if skirt and y < 84:
                    dx = wave*.7
                    dy = bob
            elif 52 < y < 78 and (x < 23 or x > 41):
                weight = min(1, (y-52)/20)
                side = -1 if x < 32 else 1
                dx = wave*side*1.2*weight
                dy += (wave*side*1.5 + follow*.8)*weight
            sx, sy = round(x-dx), round(y-dy)
            if 0 <= sx < SIZE[0] and 0 <= sy < SIZE[1]:
                dst[x, y] = src[sx, sy]
    return result


def atlas(variants, kind, head=False, skirts=()):
    result = Image.new('RGBA', (64*4*POSES, 96*len(variants)))
    for variant, views in enumerate(variants):
        for direction, pair in enumerate(views):
            normal, closed = pair
            for pose in range(POSES):
                image = closed[kind] if pose == 1 else normal[kind]
                if pose >= 2:
                    image = walk(image, (pose-2)*math.tau/6, direction, head, variant in skirts)
                result.alpha_composite(image, ((direction*POSES+pose)*64, variant*96))
    result.save(OUT/(kind+'.png'), optimize=True)


def head_atlas(variants, kind):
    # Heads do not need six copies of the same face. The renderer follows the
    # torso's baked bob. Only the hair tips need two additional lag silhouettes.
    poses = 3 if kind == 'hair' else 2
    result = Image.new('RGBA', (64*4*poses, 96*len(variants)))
    for variant, views in enumerate(variants):
        for direction, (normal, closed) in enumerate(views):
            for pose in range(poses):
                if kind == 'hair':
                    image = normal[kind] if pose == 0 else walk(normal[kind], math.pi/2*(1 if pose == 1 else -1), direction, head=True, bobbing=False)
                else:
                    image = closed[kind] if pose == 1 else normal[kind]
                result.alpha_composite(image, ((direction*poses+pose)*64, variant*96))
    result.save(OUT/(kind+'.png'), optimize=True)


heads = []
for page in ['heads-a.png', 'heads-b.png']:
    sheet = Image.open(SRC/page)
    for row in range(4):
        views = [head_layers(keyed(cell(sheet, col, row, 4))) for col in range(3)]
        views.append(tuple({name: ImageOps.mirror(image) for name, image in layers.items()} for layers in views[2]))
        heads.append(views)
for kind in ['body', 'hair', 'face', 'eyes']:
    head_atlas(heads, kind)

garments = []
for page in ['garments-a.png', 'garments-b.png']:
    sheet = Image.open(SRC/page)
    for row in range(3):
        views = []
        for col in range(3):
            layers = garment_layers(keyed(cell(sheet, col, row, 3)))
            views.append((layers, layers))
        views.append(tuple({name: ImageOps.mirror(image) for name, image in layers.items()} for layers in views[2]))
        garments.append(views)
for kind in ['clothes', 'hands']:
    atlas(garments, kind, skirts=(4,))

# Reusable NPC heads / clothes share registration and animation with the player.
villagers = []
sheet = Image.open(SRC/'villagers.png')
for row in range(3):
    views = []
    for col in range(3):
        im = keyed(cell(sheet, col, row, 3))
        bbox = im.getbbox()
        scale = 88/(bbox[3]-bbox[1])
        im = place(im, scale, ((bbox[0]+bbox[2])/2, bbox[3]), (32, 95))
        head = im.copy()
        ImageDraw.Draw(head).rectangle((0, 44, 63, 95), fill=(0, 0, 0, 0))
        body = im.copy()
        ImageDraw.Draw(body).rectangle((0, 0, 63, 43), fill=(0, 0, 0, 0))
        layers = {'npc_heads': head, 'npc_clothes': body}
        views.append((layers, layers))
    views.append(tuple({name: ImageOps.mirror(image) for name, image in layers.items()} for layers in views[2]))
    villagers.append(views)
npc_heads = Image.new('RGBA', (64*4, 96*3))
for variant, views in enumerate(villagers):
    for direction, (normal, closed) in enumerate(views):
        npc_heads.alpha_composite(normal['npc_heads'], (direction*64, variant*96))
npc_heads.save(OUT/'npc_heads.png', optimize=True)
atlas(villagers, 'npc_clothes', skirts=(1,))

shadow = Image.new('RGBA', SIZE)
ImageDraw.Draw(shadow).ellipse((16, 88, 49, 95), fill='#251c214b')
shadow = shadow.filter(ImageFilter.GaussianBlur(1))
shadow.save(OUT/'actor_shadow.png', optimize=True)
room = Image.open(SRC/'dressing-room.png').convert('RGB').resize((288, 320), NN)
room = room.quantize(colors=256, dither=Image.Dither.NONE)
room.save(ROOT/'assets/frontend/dressing_room.png', optimize=True)
ambient = Image.open(SRC/'dressing-room.png').convert('RGB').resize((96, 107), NN)
ambient = ambient.filter(ImageFilter.GaussianBlur(5))
ambient = Image.blend(ambient, Image.new('RGB', ambient.size, '#57312e'), .70)
ambient.quantize(colors=64).save(ROOT/'assets/frontend/wardrobe_ambient.png', optimize=True)
print('Prepared 8 hairstyles, 6 garments, 3 NPC archetypes, four directions and six-pose walk cycles; train untouched.')
