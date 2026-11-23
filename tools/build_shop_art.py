"""Original Little Village Shop pixel art. Pillow is an optional authoring dependency.
Run from any directory: python3 tools/build_shop_art.py. No downloaded art or fonts.
Every mark is authored on the native 1px grid; fixed seed makes output reproducible.
"""
from pathlib import Path
from random import Random
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1] / 'assets'
INK = '#55483e'
DARK = '#745440'
WOOD = '#a67a53'
GOLD = '#cfac76'
CREAM = '#f0dfb4'
SAGE = '#7b9166'

class Canvas:
    def __init__(self, w, h, bg=(0, 0, 0, 0)):
        self.im = Image.new('RGBA', (w, h), bg)
        self.d = ImageDraw.Draw(self.im)
    def box(self, x, y, w, h, c):
        self.d.rectangle((x, y, x+w-1, y+h-1), fill=c)
    def line(self, points, c, width=1):
        self.d.line(points, fill=c, width=width)
    def poly(self, points, c):
        self.d.polygon(points, fill=c)
    def save(self, name):
        target = ROOT / name
        target.parent.mkdir(parents=True, exist_ok=True)
        self.im.save(target, optimize=True)

# Small hand-drawn 3x5 lettering for the wooden signs, not a system font.
GLYPHS = dict(zip('ACDEFGHILOPRSTV', [
    '010101111101101','111100100100111','110101101101110',
    '111100110100111','111100110100100','111100101101111',
    '101101111101101','111010010010111','100100100100111',
    '111101101101111','110101110100100','110101110101101',
    '111100111001111','111010010010010','101101101101010']))

GLYPHS['K'] = '101101110101101'

def text(c, x, y, value, color=CREAM):
    for char in value:
        bits = GLYPHS.get(char, '0'*15)
        for i, bit in enumerate(bits):
            if bit == '1':
                c.box(x+i%3, y+i//3, 1, 1, color)
        x += 4

def sign(c, x, y, w, label):
    c.box(x+1, y+2, w, 12, '#6c513d')
    c.box(x, y, w, 12, DARK)
    c.box(x+1, y+1, w-2, 9, '#8d6c4c')
    c.box(x+2, y+2, w-4, 1, '#b59163')
    text(c, x+(w-len(label)*4+1)//2, y+4, label)
    for px in [x+2, x+w-3]:
        c.box(px, y+5, 1, 1, GOLD)

def pot(c, x, y, flowers=False):
    c.box(x-6, y+1, 14, 3, '#554e3d')
    c.box(x-5, y-7, 11, 10, '#9b604a')
    c.box(x-4, y-6, 8, 8, '#bf835e')
    c.box(x-6, y-8, 13, 3, '#d49a6b')
    c.box(x-3, y-5, 2, 6, '#dba371')
    c.box(x, y-23, 2, 15, '#5d7050')
    for dx, dy in [(-6,-19),(2,-22),(-7,-13),(2,-15)]:
        c.box(x+dx, y+dy, 6, 4, '#5c7957')
        c.box(x+dx+1, y+dy, 4, 2, '#93a774')
    if flowers:
        for dx, dy in [(-5,-20),(4,-23),(5,-15)]:
            c.box(x+dx, y+dy, 3, 3, '#eadab0')
            c.box(x+dx+1, y+dy+1, 1, 1, '#c99456')

def wood(c, x, y, w, h, seed=1, fill=WOOD):
    c.box(x, y, w, h, DARK)
    c.box(x+1, y+1, w-2, h-2, fill)
    c.box(x+2, y+1, w-4, 1, GOLD)
    r = Random(seed)
    for sy in range(y+5, y+h-2, 7):
        c.box(x+2, sy, w-4, 1, '#916745')
        for _ in range(2):
            sx = r.randrange(x+3, x+w-10)
            c.box(sx, sy-2, r.randrange(3,8), 1, '#b88d60')

# Product silhouettes have dark edges, warm highlights, and distinct colour families.
a = Canvas(16,16)
a.poly([(3,5),(5,3),(7,4),(9,4),(11,3),(14,6),(14,10),(12,13),(10,14),(5,14),(2,11),(2,7)], '#813f38')
a.poly([(4,5),(6,4),(8,5),(11,4),(13,6),(13,10),(11,12),(5,12),(3,10),(3,7)], '#b95547')
a.box(4,6,2,4,'#de8a64'); a.box(6,5,1,2,'#ebad7a'); a.box(10,10,2,2,'#a3453d')
a.box(7,1,2,4,DARK); a.box(9,1,4,2,'#6a8958'); a.box(9,1,2,1,'#a9b777'); a.box(5,13,5,1,'#9f493e')
a.save('items/apple.png')
b = Canvas(16,16)
b.poly([(1,7),(3,4),(5,3),(11,3),(14,5),(15,8),(14,12),(12,14),(3,14),(1,12)], '#805337')
b.poly([(2,7),(4,5),(6,4),(11,4),(13,6),(14,9),(12,12),(3,12),(2,11)], '#c18a4d')
b.box(3,7,10,3,'#dbaa61'); b.box(4,6,2,3,'#f1d69b'); b.box(7,5,2,4,'#f1d69b'); b.box(10,6,2,3,'#f1d69b'); b.box(4,12,8,1,'#a77242'); b.box(3,10,1,1,'#edc786')
b.save('items/bread.png')
m = Canvas(16,16)
m.box(5,1,6,3,'#526f78'); m.box(6,1,4,1,'#9fb7ad')
m.poly([(5,4),(11,4),(11,5),(13,7),(13,14),(12,15),(4,15),(3,14),(3,7),(5,5)], '#698286')
m.poly([(6,4),(10,4),(10,6),(12,7),(12,13),(4,13),(4,7),(6,6)], '#e8e2c8')
m.box(5,6,2,6,'#fff1d5'); m.box(4,8,8,4,'#7e9b9e'); m.box(5,8,1,4,'#aac3ba'); m.box(7,9,3,2,'#e8e2c8'); m.box(5,14,6,1,'#bcc7b7')
m.save('items/milk.png')

# Room and exterior mat. Fixed original collision footprint: (128,48)-(512,312).
c = Canvas(640,360, '#68765d')
rng = Random(80)
# A quiet garden frame, shaded towards the screen edge.
for y in range(0,360,8):
    for x in range(0,640,8):
        dist = min(x,640-x,y,360-y)
        col = ['#65735b','#6d7d60','#758765'][min(2,dist//32)]
        c.box(x,y,8,8,col)
for _ in range(1000):
    x,y=rng.randrange(640),rng.randrange(360)
    if not (116<x<524 and 20<y<322):
        c.box(x,y,2,1,rng.choice(['#81906b','#72835f','#5f7156']))
# Entry stones, unblocked doorway.
for y in [314,326,338,350]:
    for x in [304,321]:
        c.box(x,y,15,9,'#5f6954'); c.box(x+1,y,13,7,'#b3b197'); c.box(x+2,y,10,1,'#c8c3a2')
# Soft, stepped building shadow, entirely on the pixel grid.
c.box(126,35,394,282,'#59614e'); c.box(130,40,394,280,'#5e6952')
c.box(128,32,384,280, DARK)
# Natural horizontal floorboards, staggered joints, tiny knots and nail heads.
for row,y in enumerate(range(64,296,8)):
    base = rng.choice(['#c4a273','#c9a779','#c0a075','#c6a577'])
    c.box(144,y,352,8,base); c.box(144,y+7,352,1,'#a48560')
    c.box(144,y,352,1,'#d3b489')
    for x in range(144-(row%3)*24,496,72):
        if x>=144:
            c.box(x,y+1,1,6,'#a48560'); c.box(x+2,y+2,1,1,'#947a59')
        start=max(x+8,145)
        c.box(start,y+3,min(18,495-start),1,'#bd9b6e')
        if rng.randrange(3)==0 and 151<x<476:
            c.box(x+12,y+4,4,1,'#aa895e'); c.box(x+13,y+5,2,1,'#d3b080')
# Wall cast shadow and corner ambient shade.
c.box(144,64,352,3,'#8b7558'); c.box(144,67,352,3,'#ad8e64')
c.box(144,70,3,226,'#b09268'); c.box(492,67,4,229,'#ad8e64')
# Back wall above the solid north border, wainscot and timber beams.
c.box(128,32,384,32,'#ded0a5')
for x in range(147,496,8):
    c.box(x,35,1,24,'#cdbf97')
c.box(128,32,384,4,'#795740'); c.box(130,33,380,1,'#b18a5c')
c.box(128,58,384,6,'#896344'); c.box(128,58,384,1,'#d3ae79')
for x in [128,492]:
    wood(c,x,32,20,280,3,'#8b684b')
    for y in range(72,298,40):
        c.box(x+3,y,12,1,'#76583f')
# Southern cutaway wall, leaving precisely the existing 32px opening.
for x,w in [(128,176),(336,176)]:
    c.box(x,296,w,16,'#785b44'); c.box(x+2,298,w-4,11,'#a48057'); c.box(x,296,w,2,'#d4b381')
    c.box(x+2,310,w-4,2,'#5d4a3b')
    for sx in range(x+8,x+w-4,16):
        c.box(sx,300,1,9,'#8d6c4c')
c.box(304,296,32,4,'#9d825d'); c.box(304,296,32,1,'#e0c597')
# Windows, curtains, sill flowers. Light accents below are deliberately discrete.
for x in [193,413]:
    wood(c,x,35,36,26,2,'#9c7b55')
    c.box(x+3,38,30,18,'#799798'); c.box(x+4,39,28,8,'#adc0ad'); c.box(x+4,48,28,7,'#93b0a4')
    c.poly([(x+4,51),(x+9,46),(x+16,49),(x+21,45),(x+31,50),(x+31,54),(x+4,54)],'#849b7c')
    c.box(x+17,38,2,18,CREAM); c.box(x+3,46,30,2,CREAM)
    for dx in [1,29]:
        c.box(x+dx,37,6,16,'#eee0b9'); c.box(x+dx+1,38,1,13,'#ccbb96'); c.box(x+dx,51,6,2,'#ac7960')
    c.box(x-2,57,40,3,'#d5b582'); c.box(x-1,60,38,2,'#77583f')
sign(c,279,39,82,'VILLAGE SHOP')
# Layer translucent sunshine on the boards: no filtered gradients or shader dependency.
light = Canvas(640,360)
for x in [197,417]:
    light.poly([(x,67),(x+26,67),(x+51,105),(x+11,105)],(255,232,163,24))
    light.poly([(x+3,68),(x+23,68),(x+44,99),(x+13,99)],(255,239,188,20))
    light.line([(x+13,70),(x+30,99)],(122,117,84,28),2)
    light.line([(x+6,81),(x+33,81)],(122,117,84,24),2)
c.im = Image.alpha_composite(c.im,light.im); c.d=ImageDraw.Draw(c.im)
# Handwoven central runner, keeps approach points completely visible.
def rug(x,y,w,h):
    c.box(x+1,y+2,w,h,'#a68a63'); c.box(x,y,w,h,'#a76550'); c.box(x+2,y+2,w-4,h-4,'#c48b69')
    c.box(x+4,y+4,w-8,h-8,'#8b7456')
    for xx in range(x+6,x+w-5,6):
        for yy in [y+3,y+h-4]: c.box(xx,yy,2,1,'#ead4a2')
    for xx in range(x+2,x+w,3):
        c.box(xx,y-2,1,2,'#d8bf91'); c.box(xx,y+h,1,2,'#d8bf91')
    for xx in range(x+10,x+w-8,12):
        c.poly([(xx,y+h//2-3),(xx+3,y+h//2),(xx,y+h//2+3),(xx-3,y+h//2)],'#d6b485')
rug(281,201,78,33); rug(304,281,32,12)
# Quiet wall-side decor, away from authored approaches.
pot(c,158,94); pot(c,481,94,True); pot(c,477,278)
sign(c,184,80,48,'FRESH'); sign(c,408,80,48,'LOCAL')
# Wall calendar and a framed botanical drawing, leave central aisle uncluttered.
c.box(252,72,15,19,DARK); c.box(253,73,13,16,CREAM); c.box(253,73,13,3,'#ad7257')
for xx in [255,259,263]:
    for yy in [79,83,87]: c.box(xx,yy,2,1,'#a39273')
c.box(373,72,15,19,DARK); c.box(375,74,11,15,'#eee0b9'); c.box(380,78,1,9,SAGE)
c.box(377,79,3,2,SAGE); c.box(381,82,3,2,SAGE); c.box(379,76,3,2,'#b97e5d')
# Small warm brass sconces.
for x in [166,474]:
    c.box(x,49,4,8,DARK); c.box(x-2,48,8,2,GOLD); c.box(x-1,43,6,5,'#e0bb79'); c.box(x,43,4,4,'#f5dfaa'); c.box(x-2,56,8,2,'#b08c56')
# Fixture shadows sit underneath the original footprint; never affect collision.
for x,y,w,h in [(176,112,64,48),(400,112,64,48),(176,208,64,32),(400,208,48,32),(176,272,64,16)]:
    c.box(x+1,y+h,w+3,2,'#a58961'); c.box(x+3,y+h+2,w,2,'#b0966a')
# Crates and baskets stay tucked against wall, no new blocking geometry.
wood(c,152,178,17,19,5,'#b58a58'); c.box(154,183,13,2,DARK); c.box(154,190,13,2,DARK)
c.box(157,179,6,2,'#d4af72')
# Outside flower patches and little edging stones.
for x,y in [(104,88),(536,112),(102,274),(538,280)]:
    for dx,dy in [(-4,2),(2,-4),(6,3)]:
        c.box(x+dx,y+dy,2,5,'#526e4f'); c.box(x+dx-1,y+dy-2,4,3,'#cbbd8c'); c.box(x+dx,y+dy-1,2,1,'#ad8656')
c.save('shop/room.png')

# Shelves use the existing six 16x16 product slots at (-24,-20), 20px tier spacing.
s = Canvas(64,48)
wood(s,0,0,64,48,9,'#a77c51')
s.box(3,3,58,39,'#674d3b')
for y in [3,23]:
    s.box(6,y,52,16,'#816045')
    for x in [14,30,46]: s.box(x,y+1,1,14,'#76563e')
    s.box(5,y+16,54,3,'#c59c64'); s.box(5,y+16,54,1,'#e2be83'); s.box(5,y+19,54,1,'#634a36')
for x in [1,59]:
    s.box(x,2,4,43,'#b88d5b'); s.box(x,2,1,42,'#d0a673'); s.box(x+1,7,1,1,DARK); s.box(x+1,37,1,1,DARK)
s.box(5,45,5,3,DARK); s.box(54,45,5,3,DARK)
# Cream paper price tags on the front rails.
for x in [12,28,44]:
    for y in [19,39]: s.box(x,y,8,2,'#efe0b6'); s.box(x+3,y,2,1,'#9a7e57')
s.save('shop/shelf.png')
# Sage-painted storage chest with brass hardware and woven liner.
s = Canvas(64,32)
wood(s,0,0,64,32,5,'#8a9b70')
s.box(2,2,60,10,'#99a77e'); s.box(3,3,58,1,'#c0c69b'); s.box(2,12,60,2,'#536b4f')
for x in [8,50]:
    s.box(x,1,5,29,'#677a58'); s.box(x+1,2,1,26,'#a7ad7e'); s.box(x,4,5,2,'#d2b276'); s.box(x,22,5,2,'#d2b276')
s.box(27,11,10,7,DARK); s.box(28,11,8,5,GOLD); s.box(31,13,2,3,DARK)
s.box(20,21,24,7,'#d6c79f'); text(s,22,22,'STOCK',DARK)
s.save('shop/storage.png')
# Supplier desk: tablecloth, ledger, pencil, cup, seedling.
s = Canvas(48,32)
wood(s,0,0,48,32,21,'#bb915e'); s.box(3,26,42,3,DARK); s.box(4,29,5,3,DARK); s.box(39,29,5,3,DARK)
s.box(29,2,13,25,'#d1c19a'); s.box(30,2,1,25,'#ece0b9'); s.box(33,2,1,25,'#b7a37f'); s.box(38,2,1,25,'#b7a37f')
s.box(6,7,25,15,'#5f7256'); s.box(7,6,11,13,'#f1dfb3'); s.box(19,6,11,13,'#e5cfa3'); s.box(18,7,1,12,'#a68f69')
for y in [9,12,15]: s.box(9,y,7,1,'#bda780'); s.box(21,y,6,1,'#bda780')
s.box(8,23,17,2,'#9c5f49'); s.box(23,23,2,2,'#e7c794'); s.box(25,23,1,2,INK)
s.box(36,12,5,5,'#d8b57c'); s.box(35,11,7,2,'#ede1b7'); s.box(37,5,1,7,SAGE); s.box(38,6,3,2,SAGE)
s.save('shop/order_desk.png')
# Counter remains 64x16; the register and linen overhang are visual only.
s = Canvas(64,28)
wood(s,0,12,64,16,9,'#ac8054'); s.box(1,12,62,3,'#dfbb83'); s.box(3,26,58,2,'#79563d')
s.box(5,15,16,10,'#ded1aa'); s.box(7,15,1,10,'#a87b5c'); s.box(18,15,1,10,'#a87b5c')
s.box(23,9,24,10,DARK); s.box(25,5,20,10,'#687c67'); s.box(27,6,16,5,'#354f48'); s.box(29,7,12,2,'#c6cfaa')
s.box(25,15,20,2,'#d3b078'); s.box(29,12,2,1,CREAM); s.box(33,12,2,1,CREAM); s.box(37,12,2,1,CREAM)
s.box(51,14,8,6,'#775c41'); s.box(52,13,6,4,'#f1d9a5'); s.box(53,12,4,1,'#bc8a51')
s.save('shop/checkout.png')

# Four coordinated villagers, four facings, idle + two walking frames. 24x32 cells.
# Origin in game is (12,20), matching the existing feet/body and collision shapes.
sheet = Canvas(288,128)
for variant,(coat,hair,skin) in enumerate([
    ('#718c6b','#614a3c','#e0ad84'),('#ad7357','#74553b','#e6b58d'),
    ('#7a939c','#c7baa1','#bd8965'),('#b29a60','#51483b','#e6bf99')]):
    for direction in range(4):
        for frame in range(3):
            p = Canvas(24,32)
            bob = 1 if frame == 2 else 0
            stride = 1 if frame else 0
            p.box(5,28,14,2,(63,55,43,54)); p.box(7,27,10,4,(63,55,43,35))
            p.box(7,25,4,5-stride,INK); p.box(13,25,4,4+stride,INK)
            p.box(7,28-stride,3,1,'#8f7858'); p.box(14,28+stride,3,1,'#8f7858')
            p.box(5,16+bob,14,11,INK); p.box(6,16+bob,12,10,coat)
            p.box(4,18+bob,3,7,coat); p.box(17,18+bob,3,7,coat)
            p.box(4,24+bob,3,2,skin); p.box(17,24+bob,3,2,skin)
            if direction != 1:
                p.box(9,17+bob,6,8,'#e1d1a5' if variant==0 else '#c9b88e')
                p.box(10,22+bob,4,2,'#b6a37d')
            else:
                p.box(7,18+bob,1,6,'#9fa980'); p.box(16,18+bob,1,6,'#596f55')
            p.box(8,7+bob,9,10,INK); p.box(8,8+bob,8,8,skin)
            p.box(6,5+bob,12,6,hair); p.box(7,4+bob,10,2,hair)
            p.box(7,6+bob,8,1,'#977052' if variant<2 else '#aa9b7f')
            p.box(6,10+bob,3,4,hair)
            if direction==1:
                p.box(7,8+bob,10,6,hair); p.box(8,14+bob,8,1,hair)
            elif direction in [2,3]:
                eye=9 if direction==2 else 15
                p.box(eye,12+bob,1,2,INK); p.box(eye,15+bob,2,1,'#be8569')
                if direction==3: p.box(7,10+bob,5,6,hair)
            else:
                p.box(10,12+bob,1,2,INK); p.box(15,12+bob,1,2,INK)
                p.box(9,15+bob,2,1,'#ca8d70'); p.box(15,15+bob,1,1,'#ca8d70')
            if variant==1:
                p.box(4,6+bob,16,2,'#9d7c4e'); p.box(7,2+bob,10,5,'#d3b67a'); p.box(7,5+bob,10,1,'#ac7754')
            if variant==2:
                p.box(15,9+bob,3,7,hair); p.box(15,16+bob,2,2,'#ac7359')
            if variant==3:
                p.box(6,5+bob,12,3,'#77845e'); p.box(7,4+bob,10,2,'#8e9a70')
            sheet.im.alpha_composite(p.im,((direction*3+frame)*24,variant*32))
sheet.save('characters/villagers.png')
print('Built 9 original pixel-art textures (native grid, seed 80).')
