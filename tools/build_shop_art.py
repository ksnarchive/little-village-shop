"""Original autumn vintage pixel art. Rebuild with Pillow; no runtime dependencies.
All silhouettes, wear, wallpaper, ornaments and atlas poses authored here on a pixel grid.
"""
from pathlib import Path
from random import Random
from PIL import Image, ImageDraw
ROOT = Path(__file__).resolve().parents[1] / 'assets'
INK='#51483F'; EDGE='#80604B'; WOOD='#C5A36F'; LIGHT='#DCCA9E'; CREAM='#E9DFC8'
CLAY='#B7795F'; BLUE='#A8B4B1'; OLIVE='#879575'; GOLD='#C8AC70'
class Canvas:
    def __init__(self,w,h,bg=(0,0,0,0)):
        self.im=Image.new('RGBA',(w,h),bg); self.d=ImageDraw.Draw(self.im)
    def box(self,x,y,w,h,c): self.d.rectangle((x,y,x+w-1,y+h-1),fill=c)
    def poly(self,p,c): self.d.polygon(p,fill=c)
    def line(self,p,c,w=1): self.d.line(p,fill=c,width=w)
    def oval(self,x,y,w,h,c): self.d.ellipse((x,y,x+w-1,y+h-1),fill=c)
    def paste(self,other,x,y): self.im.alpha_composite(other.im,(x,y))
    def save(self,name):
        path=ROOT/name; path.parent.mkdir(parents=True,exist_ok=True); self.im.save(path,optimize=True)
def rim(c,x,y,w,h,fill,edge=EDGE):
    c.box(x+2,y,w-4,h,edge); c.box(x,y+2,w,h-4,edge)
    c.box(x+2,y+2,w-4,h-4,fill)
    c.box(x+3,y+2,w-6,1,CREAM)
def flower(c,x,y,color=CLAY):
    for dx,dy in [(-2,0),(2,0),(0,-2),(0,2)]: c.box(x+dx,y+dy,3,3,color)
    c.box(x+1,y+1,1,1,GOLD)
def sprig(c,x,y):
    c.line([(x,y),(x,y-14)],'#78866B',2)
    for dx,dy in [(-5,-10),(1,-14),(-5,-4),(1,-7)]:
        c.poly([(x+dx,y+dy),(x+dx+5,y+dy+2),(x+dx+3,y+dy+4),(x+dx,y+dy+3)],OLIVE)
def pot(c,x,y):
    c.oval(x-8,y,18,4,'#51483F40'); sprig(c,x,y-6)
    c.poly([(x-6,y-8),(x+7,y-8),(x+4,y+2),(x-3,y+2)],EDGE)
    c.poly([(x-4,y-7),(x+5,y-7),(x+3,y),(x-2,y)],CLAY); c.box(x-7,y-9,15,3,CREAM)
def web(c,x,y,size=20):
    for dx,dy in [(size,0),(size,size),(0,size)]: c.line([(x,y),(x+dx,y+dy)],CREAM)
    for t in [6,12,18]:
        if t<size: c.line([(x+t,y),(x+t-2,y+t//2),(x+t//2,y+t-2),(x,y+t)],'#D4CCB5')
def wood(c,x,y,w,h):
    c.box(x,y,w,h,EDGE); c.box(x+2,y+2,w-4,h-4,WOOD); c.box(x+2,y+2,w-4,2,LIGHT)
    for yy in range(y+10,y+h-2,12):
        c.box(x+2,yy,w-4,1,'#A48360'); c.box(x+7,yy-4,11,1,'#D4BC8E')
def badge(c,kind,fill):
    rim(c,0,0,16,14,fill,INK)
    if kind=='box':
        c.box(4,5,8,6,CREAM); c.box(4,4,8,2,WOOD); c.box(7,5,2,5,EDGE)
    elif kind=='book':
        c.poly([(3,4),(7,3),(8,4),(12,3),(12,10),(8,11),(7,10),(3,11)],CREAM); c.box(7,4,1,6,EDGE)
    elif kind=='shelf':
        for yy in [5,10]: c.box(3,yy,10,2,CREAM)
        c.box(4,3,2,8,CREAM); c.box(10,3,2,8,CREAM)
    else:
        c.oval(4,3,8,8,GOLD); c.box(7,5,2,4,INK)
# Goods: chunky silhouettes, readable even at 16px.
a=Canvas(16,16)
a.poly([(2,5),(5,3),(8,4),(11,3),(14,5),(15,9),(13,13),(10,15),(7,14),(4,15),(1,11),(1,7)],INK)
a.poly([(3,5),(6,4),(8,5),(11,4),(13,6),(14,9),(12,12),(10,13),(7,12),(4,13),(2,10),(2,7)],'#B7795F')
a.box(3,6,3,4,'#D9AA7C'); a.box(4,5,3,2,CREAM); a.box(10,10,2,2,'#8F5744'); a.box(7,1,2,4,INK)
a.poly([(9,2),(11,0),(14,0),(13,3),(10,4)],'#879575'); a.save('items/apple.png')
b=Canvas(16,16)
b.poly([(1,6),(4,3),(11,2),(14,5),(15,10),(13,14),(3,15),(0,12)],INK)
b.poly([(2,6),(5,4),(11,3),(13,6),(14,10),(12,12),(3,13),(1,11)],'#DBAB79')
b.box(3,7,10,3,GOLD)
for x,y in [(4,5),(7,4),(10,5)]: b.line([(x+1,y),(x,y+3)],CREAM,2)
b.box(3,12,9,1,'#BD8A73'); b.save('items/bread.png')
m=Canvas(16,16)
m.box(5,0,6,3,INK); m.box(6,0,4,2,BLUE)
m.poly([(5,3),(11,3),(11,5),(13,7),(13,14),(11,16),(4,16),(2,14),(2,7),(5,5)],INK)
m.poly([(6,3),(10,3),(10,6),(12,7),(12,14),(4,14),(4,7),(6,6)],CREAM)
m.box(4,8,8,5,OLIVE); m.box(5,5,2,4,'#FFFFFF'); m.oval(6,9,4,3,'#FFFFFF'); m.box(4,14,7,1,BLUE); m.save('items/milk.png')
# Hand-carved empty displays: olive and oxidised blue paint over walnut.
def chips(c,points):
    for x,y,w,h in points:
        c.box(x,y,w,h,EDGE)
        c.box(x,y,w,1,LIGHT)

for name,paint,back in [('shelf',OLIVE,'#716D55'),('pantry',BLUE,'#768889')]:
    s=Canvas(64,56)
    s.oval(2,49,60,6,'#51483F50')
    s.poly([(1,9),(5,9),(5,5),(14,5),(14,3),(50,3),(50,5),(59,5),(59,9),(63,9),(63,51),(1,51)],INK)
    s.box(3,10,58,39,paint); s.box(6,13,52,31,back)
    s.box(5,7,54,4,CREAM); s.box(12,4,40,3,paint)
    for yy in [12,32]:
        s.box(8,yy,48,14,back); s.box(8,yy,48,2,'#5B5F4E' if name=='shelf' else '#5E7275')
        s.box(7,yy+14,50,4,WOOD); s.box(7,yy+14,50,1,LIGHT)
        for xx in [15,31,47]: s.box(xx,yy+15,7,3,CREAM); s.box(xx+2,yy+16,3,1,EDGE)
    for xx in [3,57]:
        s.box(xx,11,4,38,paint); s.box(xx,11,1,38,CREAM); s.box(xx+1,28,2,4,WOOD)
    s.box(5,49,6,4,INK); s.box(53,49,6,4,INK)
    # A missing slat, small chipped corner, old cobweb: still perfectly usable.
    s.line([(38,30),(44,28),(46,29)],back,2); s.box(5,45,2,3,WOOD)
    web(s,8,14,11)
    if name=='pantry': s.line([(55,37),(52,39),(54,42)],INK); s.box(17,8,5,1,WOOD)
    # Warped lip and exposed timber where the old paint has flaked off.
    chips(s,[(3,18,3,7),(57,40,3,5),(16,7,7,2),(48,47,9,2),(9,30,5,2)])
    s.poly([(34,26),(41,26),(39,28),(37,28),(36,30),(34,30)],back)
    s.line([(44,10),(43,16),(45,19),(44,24)],EDGE)
    s.box(9,25,20,1,'#C6BDA0'); s.box(46,45,7,1,'#C6BDA0')
    s.save('shop/'+name+'.png')
s=Canvas(64,40)
s.oval(1,33,62,5,'#51483F50'); s.box(4,30,6,7,INK); s.box(54,30,6,7,INK)
rim(s,0,2,64,32,INK); rim(s,2,4,60,28,OLIVE)
s.poly([(3,4),(53,4),(61,11),(61,15),(3,15)],'#BEC5AE'); s.box(3,15,58,2,INK)
for x in [8,51]:
    s.box(x,4,5,28,'#6F826A'); s.box(x,5,1,26,CREAM); s.box(x,19,5,3,GOLD)
rim(s,26,13,12,9,GOLD); s.box(31,15,2,4,INK)
s.box(20,25,24,6,CREAM); s.box(22,27,20,1,EDGE); s.box(4,29,3,2,WOOD)
chips(s,[(5,22,4,7),(14,29,9,2),(53,6,5,3),(47,27,5,3)])
s.line([(17,8),(20,9),(19,12)],EDGE); s.save('shop/storage.png')
s=Canvas(48,40)
s.oval(0,33,48,6,'#51483F50'); s.box(5,23,5,13,EDGE); s.box(38,24,5,13,EDGE)
wood(s,0,5,48,26); s.box(32,7,11,23,BLUE)
for yy in [9,15,21,27]: s.box(32,yy,11,2,'#CAD0BE')
s.poly([(5,10),(17,8),(21,10),(33,8),(33,24),(21,26),(17,24),(5,26)],INK)
s.poly([(6,11),(17,9),(19,11),(19,24),(17,23),(6,24)],CREAM)
s.poly([(21,11),(31,9),(31,23),(21,24)],'#D9CEAF')
for yy in [13,17,21]: s.box(8,yy,7,1,EDGE); s.box(23,yy,6,1,EDGE)
s.line([(36,13),(40,23)],'#B7795F',2); s.box(39,22,2,2,INK); s.save('shop/order_desk.png')
s=Canvas(64,36)
s.oval(0,30,64,6,'#51483F50'); wood(s,0,16,64,17); s.box(2,16,60,3,LIGHT)
s.box(5,19,14,12,CLAY)
for xx in [6,17]: s.box(xx,19,1,12,CREAM)
s.box(24,10,24,13,INK); s.box(26,5,20,14,BLUE); s.box(28,6,16,7,INK); s.box(30,8,12,3,CREAM)
s.box(25,20,22,2,CREAM)
for xx in [28,33,38,43]: s.box(xx,15,3,2,CREAM)
s.box(51,18,10,4,EDGE); s.oval(53,13,6,6,GOLD); s.box(55,12,2,2,CREAM)
chips(s,[(5,26,4,5),(13,19,3,3),(42,6,3,3),(54,29,7,2)])
s.line([(49,24),(53,23),(57,25)],EDGE); s.save('shop/checkout.png')
# World room: all sides filled by the interior, no surrounding lawn.
c=Canvas(640,360,'#D5CDBB'); rng=Random(81)
# Stepped cutaway shadow and scalloped shop shell.
for inset,col in [(0,'#B0B6AD'),(4,'#C4C6B9')]: rim(c,66+inset,31+inset,512,294,col, '#A8A99A')
rim(c,66,28,508,290,WOOD,INK)
c.box(70,32,500,28,CLAY)
# Faded floral wallpaper on the rear and deep side returns.
for x,y,w,h in [(72,34,496,26),(70,60,72,234),(498,60,72,234)]:
    c.box(x,y,w,h,'#DDD4B9')
    for xx in range(x+4,x+w-3,12):
        c.box(xx,y,2,h,'#CEC8A9')
        for yy in range(y+6,y+h-3,18): flower(c,xx+1,yy,'#B0B394')
# Paper seams, sun-bleached sections and curling tears exposing plaster.
for x,y,w,h in [(72,65,58,12),(73,139,48,12),(527,62,41,9),(78,287,44,7)]:
    c.box(x,y,w,h,'#E2DAC3')
for x in [90,114,528,551]: c.line([(x,65),(x,294)],'#B9B59A')
for x,y,flip in [(73,109,1),(117,245,-1),(548,182,1),(522,279,1),(552,42,-1)]:
    c.poly([(x,y),(x+flip*13,y+2),(x+flip*10,y+8),(x+flip*14,y+14),
            (x+flip*7,y+23),(x,y+21)],'#C0AA89')
    c.poly([(x,y),(x+flip*8,y+3),(x+flip*5,y+9),(x,y+11)],CREAM)
    c.line([(x,y+11),(x+flip*5,y+9),(x+flip*8,y+3)],'#95846B')
# Worn oak boards, patched lengths, scratches and dark nail holes.

for row,y in enumerate(range(64,296,12)):
    c.box(144,y,352,12,rng.choice(['#C8AC80','#C3A479','#CEB58D']))
    c.box(144,y+11,352,1,'#A38967'); c.box(144,y,352,1,'#D8C198')
    for x in range(144-(row%3)*24,496,72):
        if x>=144: c.box(x,y+1,1,10,'#A38B6C')
        xx=max(146,x+10); c.box(xx,y+6,min(14,496-xx),1,'#B59A73')
        if 155<x<470: c.box(x+6,y+4,3,1,'#92795F')
# Uneven traffic wear: pale scuffs, thin splits, wood knots and inset nails.
for i in range(95):
    x=rng.randrange(148,486); y=rng.randrange(68,292)
    c.box(x,y,rng.randrange(2,11),1,rng.choice(['#B39670','#D3BC94','#AE916B']))
for x,y in [(168,78),(280,113),(458,197),(245,265),(383,280),(368,162)]:
    c.line([(x,y),(x+5,y-1),(x+13,y-1)],'#8C735A')
    c.line([(x+2,y+1),(x+10,y+1)],'#DCCA9E')
for x,y in [(171,147),(402,246),(259,89)]:
    c.oval(x,y,7,3,'#A08765'); c.box(x+2,y+1,3,1,'#806B53')
for row,y in enumerate(range(65,296,12)):
    for x in range(148+(row%3)*24,494,72): c.box(x,y+3,1,1,'#806B53')
# Broad pixel-stepped sunlight through the side windows; no blur or smooth gradients.
light=Canvas(640,360)
light.poly([(145,101),(148,101),(264,171),(264,191),(242,191),(145,135)],'#F2DFAC38')
light.poly([(495,100),(490,100),(385,171),(385,199),(417,199),(495,133)],'#F6E4B346')
light.line([(490,113),(403,180)],'#A5957330',3)
light.line([(167,121),(245,172)],'#A5957328',3)
c.paste(light,0,0)
# Soft stepped ambient shadows sit against the wall, leaving the aisle clear.
shade=Canvas(640,360)
for x,y,w,h in [(144,65,7,230),(489,65,7,230),(145,65,350,4)]: shade.box(x,y,w,h,'#51483F18')
c.paste(shade,0,0)
# Wainscot, molding and narrow side barrier all agree with collision walls.
for x in [132,496]:
    wood(c,x,60,12,238); c.box(x+2,62,3,232,LIGHT)
c.box(72,55,496,9,EDGE); c.box(72,55,496,3,CREAM); c.box(72,63,496,2,INK)
# Back windows, lace curtains and striped valance.
def window(x,y,w,h):
    wood(c,x-4,y-4,w+8,h+10); c.box(x,y,w,h,'#A8B4B1'); c.box(x+2,y+2,w-4,h//2,'#D7D8BE')
    c.poly([(x+2,y+h-5),(x+10,y+h-13),(x+20,y+h-9),(x+w-3,y+h-16),(x+w-3,y+h-2),(x+2,y+h-2)],OLIVE)
    # Amber leaves behind the old glass give a small autumn accent.
    if h > 30:
        c.box(x+w-14,y+12,2,h-14,EDGE)
        for dx,dy,col in [(-18,9,GOLD),(-12,6,CLAY),(-9,12,WOOD),(-20,15,WOOD),(-14,17,GOLD)]:
            c.oval(x+w+dx,y+dy,8,7,col)
    c.box(x+w//2-1,y,2,h,CREAM); c.box(x,y+h//2,w,2,CREAM)
    for xx in [x-2,x+w-9]:
        c.poly([(xx,y-2),(xx+11,y-2),(xx+8,y+h-7),(xx+3,y+h-4),(xx,y+h-6)],CREAM)
        for sx in [xx+2,xx+6]: c.box(sx,y,1,h-11,'#CFC7AD')
        c.box(xx+2,y+h-12,7,2,CLAY)
    c.box(x-6,y+h+2,w+12,4,LIGHT)
window(82,79,38,53); window(516,77,36,45)
# Rear clerestory, old shop sign, little hanging lamps.
window(280,35,80,20)
for x in [170,461]:
    c.box(x,33,2,7,INK); c.poly([(x-8,42),(x-4,37),(x+6,37),(x+10,42)],BLUE)
    c.box(x-8,42,18,2,INK); c.box(x-3,44,8,2,GOLD)
# Behind fixtures: visual display labels (icons, no English baked into art).
for x,col,kind in [(200,OLIVE,'shelf'),(424,BLUE,'shelf')]:
    b=Canvas(16,14); badge(b,kind,col); c.paste(b,x,87)
# Left built-in old apothecary hutch: visibly distinct from the usable painted shelves.
wood(c,76,157,50,127); c.box(80,163,42,73,'#6F7B70')
for yy in [166,190,214]:
    c.box(82,yy,38,19,'#A1A993'); c.box(80,yy+19,42,4,LIGHT)
for xx,yy,col in [(86,177,OLIVE),(107,220,CLAY)]:
    c.oval(xx,yy,9,11,col); c.box(xx+2,yy-2,5,3,EDGE); c.box(xx+2,yy+3,3,4,CREAM)
for yy in [242,261]:
    rim(c,81,yy,40,17,'#A6B3AF'); c.box(97,yy+7,9,2,INK); c.box(99,yy+7,5,1,GOLD)
web(c,82,166,26)
# Chipped paint and one missing drawer pull.
c.box(79,252,3,9,CREAM); c.line([(111,266),(116,263),(116,270)],EDGE)
# Right asymmetrical nook, cabinet and old radio on a doily.
wood(c,508,151,51,69); c.box(512,167,43,43,BLUE)
for xx in [514,536]:
    rim(c,xx,169,18,36,'#B8C2BC'); c.box(xx+8,184,2,3,GOLD)
c.box(507,151,54,4,CREAM)
rim(c,518,131,32,20,WOOD,INK); c.box(521,134,12,12,'#786957')
for xx in range(522,532,3): c.box(xx,135,1,10,CREAM)
c.box(537,135,10,3,CREAM); c.oval(538,141,5,5,GOLD); c.box(519,128,29,2,INK)
# Uneven stack of parcels and broken stool tucked against the solid side walls.
for xx,yy,ww,hh,col in [(510,261,25,22,'#AC936F'),(535,269,24,18,'#B9AB8B'),(516,245,23,17,WOOD)]:
    rim(c,xx,yy,ww,hh,col); c.box(xx+ww//2,yy+2,3,hh-4,CREAM); c.box(xx+4,yy+hh//2,6,4,CREAM)
c.line([(551,231),(548,245)],EDGE,3); c.line([(562,232),(565,242)],EDGE,3)
c.poly([(543,226),(559,224),(566,228),(564,233),(545,234)],WOOD); c.line([(553,226),(555,229),(552,233)],INK)
# Dust shelves, a cracked ceramic jug, detached handle and an old clock.
for x,y in [(81,222),(513,207),(77,275),(546,154)]:
    c.box(x,y,10,1,'#CFC5A8'); c.box(x+3,y-1,3,1,'#CFC5A8')
chips(c,[(511,173,3,9),(538,199,7,3),(84,245,6,2),(117,263,3,8)])
c.oval(514,230,12,12,BLUE); c.box(517,227,6,4,BLUE)
c.poly([(519,228),(522,231),(519,234),(522,238)],EDGE)
c.box(526,239,3,2,BLUE); c.box(529,241,2,2,BLUE)
# A long-stopped clock with a chipped case, tucked above the radio.
wood(c,536,92,21,31); c.oval(540,95,13,14,CREAM)
c.line([(546,97),(546,102),(550,102)],INK)
c.box(544,114,5,2,GOLD); c.box(537,119,3,3,CREAM)
web(c,557,65,11)
# Faded blue kilim and clay doormat, worn weave and broken fringes.
def rug(x,y,w,h,col):
    c.box(x+2,y+3,w,h,'#66544050'); rim(c,x,y,w,h,col)
    c.box(x+4,y+4,w-8,h-8,CREAM); c.box(x+6,y+6,w-12,h-12,col)
    for xx in range(x+3,x+w-2,4): c.box(xx,y-2,1,2,CREAM); c.box(xx,y+h,1,2,CREAM)
    for xx in range(x+13,x+w-8,16):
        c.poly([(xx,y+h//2-4),(xx+4,y+h//2),(xx,y+h//2+4),(xx-4,y+h//2)],CREAM)
    c.box(x+4,y+h-5,8,1,WOOD)
    c.box(x+w-10,y+2,5,3,WOOD); c.box(x+w-7,y+5,4,2,WOOD)
    for xx in range(x+10,x+w-10,9): c.box(xx,y+h-9,3,1,'#B6B79A')
rug(276,185,88,49,BLUE); rug(304,282,32,13,CLAY)
# Sparse dust, a forgotten key and scratches. Never confuse debris with goods.
for x,y in [(252,119),(384,264),(161,258),(464,184)]:
    c.box(x,y,2,1,'#9E8B6F'); c.box(x+4,y+2,1,1,'#9E8B6F')
c.line([(456,280),(461,278),(465,280)],'#80604B')
# Crooked little calendar and framed floral print.
wood(c,250,77,17,21); c.box(252,79,13,17,CREAM); c.box(252,79,13,4,CLAY)
for xx in [254,258,262]:
    for yy in [87,91]: c.box(xx,yy,2,2,EDGE)
c.poly([(374,78),(392,80),(390,104),(372,102)],EDGE); c.poly([(376,81),(389,83),(387,100),(375,99)],CREAM)
sprig(c,382,97); flower(c,380,86,BLUE)
pot(c,155,96); pot(c,482,285)
# Ivy drapes from one high corner; opposite corner has fine old cobwebs.
for x,y in [(92,61),(97,67),(103,72),(109,78)]:
    c.line([(x-4,y-5),(x+4,y+5)],'#7B886C'); c.oval(x,y,7,4,OLIVE)
web(c,498,65,27)
# Southern cutaway wall, matching the real open doorway.
for x,w in [(70,234),(336,234)]:
    c.box(x,296,w,18,EDGE); c.box(x,296,w,3,LIGHT); c.box(x+2,300,w-4,12,CLAY)
    for xx in range(x+8,x+w-4,18): c.box(xx,301,1,10,'#A4775E')
    c.box(x,313,w,3,INK)
c.box(304,296,32,3,LIGHT); c.box(304,299,32,17,'#C0AA83')
# Pale stone stoop, never a surrounding empty green field.
for yy in [319,332,345]:
    for xx in [302,320]: rim(c,xx,yy,18,11,'#CDC9B7','#9DA699')
c.save('shop/room.png')
# UI nine-slice notebook covers, inset paper and binding stitches and dedicated world badges.
s=Canvas(24,24)
rim(s,0,0,24,24,CREAM,EDGE)
s.box(2,2,20,20,'#C5B28C'); s.box(3,3,18,18,CREAM)
s.box(3,3,3,18,'#D5C6A8'); s.box(6,3,1,18,'#B7795F')
for y in [5,17]:
    s.box(2,y,3,2,INK); s.box(3,y,3,1,'#B2ACA0')
s.box(9,4,10,1,'#D5CBB2'); s.box(9,19,10,1,'#D5CBB2')
s.save('ui/panel.png')
for kind,col in [('box',OLIVE),('book',BLUE),('shelf',CLAY),('coin',GOLD)]:
    s=Canvas(16,14); badge(s,kind,col); s.save('ui/'+kind+'.png')
# Four chibi villagers. Big 18px heads, tiny apron bodies, expressive blush.
sheet=Canvas(288,128)
for variant,(coat,hair,skin) in enumerate([(OLIVE,'#80604B','#F5D3BD'),(CLAY,'#A37C6D','#EBC5AD'),(BLUE,'#C7C3B7','#CFA187'),(GOLD,'#626F70','#F2CCB6')]):
    for direction in range(4):
        for frame in range(3):
            p=Canvas(24,32); bob=1 if frame==2 else 0
            p.oval(4,28,17,3,'#51483F50')
            for x,delta in [(7,-1 if frame==1 else 0),(14,1 if frame==1 else 0)]:
                p.box(x,25,4,5+delta,INK); p.box(x,28+delta,3,1,'#AA9475')
            p.poly([(7,17+bob),(17,17+bob),(20,25+bob),(17,28),(7,28),(4,25+bob)],INK)
            p.poly([(7,18+bob),(17,18+bob),(19,24+bob),(17,26),(7,26),(5,24+bob)],coat)
            p.box(3,21+bob,3,4,skin); p.box(18,21+bob,3,4,skin)
            if direction!=1:
                p.box(9,19+bob,6,7,CREAM); p.box(10,24,4,1,EDGE); p.box(11,19+bob,2,1,CLAY)
            else: p.box(8,22,8,1,CREAM)
            p.poly([(5,3+bob),(8,1+bob),(16,1+bob),(20,5+bob),(21,13+bob),(18,18+bob),(6,18+bob),(3,14+bob),(3,7+bob)],INK)
            p.poly([(5,5+bob),(9,3+bob),(16,3+bob),(19,6+bob),(19,13+bob),(16,17+bob),(7,17+bob),(5,14+bob)],skin)
            p.poly([(4,5+bob),(7,2+bob),(16,2+bob),(19,5+bob),(19,9+bob),(16,7+bob),(14,8+bob),(12,5+bob),(9,8+bob),(5,9+bob)],hair)
            p.box(7,3+bob,6,1,'#A58768' if variant==0 else '#F0D6C4')
            if direction==1:
                p.poly([(4,7+bob),(19,7+bob),(19,15+bob),(16,18+bob),(6,18+bob),(4,14+bob)],hair)
                p.box(7,14+bob,10,2,'#A58768' if variant==0 else '#AEA89A')
            elif direction in [2,3]:
                eye=6 if direction==2 else 17; p.box(eye,10+bob,2,3,INK); p.box(eye,10+bob,1,1,CREAM)
                p.box(eye-1,14+bob,3,1,CLAY)
                p.box(16 if direction==2 else 4,8+bob,4,8,hair)
            else:
                for x in [7,15]:
                    p.box(x,10+bob,2,3,INK); p.box(x,10+bob,1,1,CREAM); p.box(x-1,14+bob,3,2,'#CB9980')
                p.box(11,14+bob,2,1,INK)
            if variant==0:
                p.box(16,4+bob,4,3,CREAM); p.box(17,5+bob,2,1,CLAY)
            if variant==1:
                p.box(2,5+bob,20,3,INK); p.box(3,5+bob,18,2,GOLD); p.box(6,0+bob,12,5,GOLD); p.box(6,3+bob,12,2,CLAY)
            if variant==2:
                p.box(3,10+bob,3,8,hair); p.box(18,10+bob,3,8,hair); p.box(3,16+bob,3,2,CLAY); p.box(18,16+bob,3,2,CLAY)
            if variant==3:
                p.box(4,3+bob,16,4,OLIVE); p.box(7,1+bob,10,3,OLIVE); p.box(14,6+bob,7,2,'#748772')
            sheet.paste(p,(direction*3+frame)*24,variant*32)
sheet.save('characters/villagers.png')
print('Built original autumn vintage room, furniture, goods, UI and 48 chibi poses.')
