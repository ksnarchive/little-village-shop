"""Original pastel pixel art. Rebuild with Pillow; no runtime dependencies.
All silhouettes, wear, wallpaper, ornaments and atlas poses authored here on a pixel grid.
"""
from pathlib import Path
from random import Random
from PIL import Image, ImageDraw
ROOT = Path(__file__).resolve().parents[1] / 'assets'
INK='#685569'; EDGE='#A58491'; WOOD='#E4BC98'; LIGHT='#FFE0B5'; CREAM='#FFF2DF'
PINK='#E8B9CA'; LILAC='#C7B8E4'; MINT='#B5D6CE'; GOLD='#F2D18F'
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
def flower(c,x,y,color=PINK):
    for dx,dy in [(-2,0),(2,0),(0,-2),(0,2)]: c.box(x+dx,y+dy,3,3,color)
    c.box(x+1,y+1,1,1,GOLD)
def sprig(c,x,y):
    c.line([(x,y),(x,y-14)],'#7B9C98',2)
    for dx,dy in [(-5,-10),(1,-14),(-5,-4),(1,-7)]:
        c.poly([(x+dx,y+dy),(x+dx+5,y+dy+2),(x+dx+3,y+dy+4),(x+dx,y+dy+3)],MINT)
def pot(c,x,y):
    c.oval(x-8,y,18,4,'#B69B9990'); sprig(c,x,y-6)
    c.poly([(x-6,y-8),(x+7,y-8),(x+4,y+2),(x-3,y+2)],EDGE)
    c.poly([(x-4,y-7),(x+5,y-7),(x+3,y),(x-2,y)],PINK); c.box(x-7,y-9,15,3,CREAM)
def web(c,x,y,size=20):
    for dx,dy in [(size,0),(size,size),(0,size)]: c.line([(x,y),(x+dx,y+dy)],CREAM)
    for t in [6,12,18]:
        if t<size: c.line([(x+t,y),(x+t-2,y+t//2),(x+t//2,y+t-2),(x,y+t)],'#F1DDE2')
def wood(c,x,y,w,h):
    c.box(x,y,w,h,EDGE); c.box(x+2,y+2,w-4,h-4,WOOD); c.box(x+2,y+2,w-4,2,LIGHT)
    for yy in range(y+10,y+h-2,12):
        c.box(x+2,yy,w-4,1,'#CBA694'); c.box(x+7,yy-4,11,1,'#F0CAA4')
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
a.poly([(3,5),(6,4),(8,5),(11,4),(13,6),(14,9),(12,12),(10,13),(7,12),(4,13),(2,10),(2,7)],'#D8809D')
a.box(3,6,3,4,'#FFD1D8'); a.box(4,5,3,2,CREAM); a.box(10,10,2,2,'#B5698A'); a.box(7,1,2,4,INK)
a.poly([(9,2),(11,0),(14,0),(13,3),(10,4)],'#83B5A7'); a.save('items/apple.png')
b=Canvas(16,16)
b.poly([(1,6),(4,3),(11,2),(14,5),(15,10),(13,14),(3,15),(0,12)],INK)
b.poly([(2,6),(5,4),(11,3),(13,6),(14,10),(12,12),(3,13),(1,11)],'#DBAB79')
b.box(3,7,10,3,GOLD)
for x,y in [(4,5),(7,4),(10,5)]: b.line([(x+1,y),(x,y+3)],CREAM,2)
b.box(3,12,9,1,'#BD8A73'); b.save('items/bread.png')
m=Canvas(16,16)
m.box(5,0,6,3,INK); m.box(6,0,4,2,LILAC)
m.poly([(5,3),(11,3),(11,5),(13,7),(13,14),(11,16),(4,16),(2,14),(2,7),(5,5)],INK)
m.poly([(6,3),(10,3),(10,6),(12,7),(12,14),(4,14),(4,7),(6,6)],CREAM)
m.box(4,8,8,5,MINT); m.box(5,5,2,4,'#FFFFFF'); m.oval(6,9,4,3,'#FFFFFF'); m.box(4,14,7,1,LILAC); m.save('items/milk.png')
# Hand-carved empty display shelves, two different painted finishes.
for name,paint,back in [('shelf',PINK,'#B58E9F'),('pantry',LILAC,'#9B91B7')]:
    s=Canvas(64,56)
    s.oval(2,49,60,6,'#84717D45')
    s.poly([(1,9),(5,9),(5,5),(14,5),(14,3),(50,3),(50,5),(59,5),(59,9),(63,9),(63,51),(1,51)],INK)
    s.box(3,10,58,39,paint); s.box(6,13,52,31,back)
    s.box(5,7,54,4,CREAM); s.box(12,4,40,3,paint)
    for yy in [12,32]:
        s.box(8,yy,48,14,back); s.box(8,yy,48,2,'#8C718B' if name=='shelf' else '#807B9C')
        s.box(7,yy+14,50,4,WOOD); s.box(7,yy+14,50,1,LIGHT)
        for xx in [15,31,47]: s.box(xx,yy+15,7,3,CREAM); s.box(xx+2,yy+16,3,1,EDGE)
    for xx in [3,57]:
        s.box(xx,11,4,38,paint); s.box(xx,11,1,38,CREAM); s.box(xx+1,28,2,4,WOOD)
    s.box(5,49,6,4,INK); s.box(53,49,6,4,INK)
    # A missing slat, small chipped corner, old cobweb: still perfectly usable.
    s.line([(38,30),(44,28),(46,29)],back,2); s.box(5,45,2,3,WOOD)
    web(s,8,14,11)
    if name=='pantry': s.line([(55,37),(52,39),(54,42)],INK); s.box(17,8,5,1,WOOD)
    s.save('shop/'+name+'.png')
s=Canvas(64,40)
s.oval(1,33,62,5,'#84717D45'); s.box(4,30,6,7,INK); s.box(54,30,6,7,INK)
rim(s,0,2,64,32,INK); rim(s,2,4,60,28,MINT)
s.poly([(3,4),(53,4),(61,11),(61,15),(3,15)],'#D0E5D8'); s.box(3,15,58,2,INK)
for x in [8,51]:
    s.box(x,4,5,28,'#8BB2AC'); s.box(x,5,1,26,CREAM); s.box(x,19,5,3,GOLD)
rim(s,26,13,12,9,GOLD); s.box(31,15,2,4,INK)
s.box(20,25,24,6,CREAM); s.box(22,27,20,1,EDGE); s.box(4,29,3,2,WOOD); s.save('shop/storage.png')
s=Canvas(48,40)
s.oval(0,33,48,6,'#84717D45'); s.box(5,23,5,13,EDGE); s.box(38,24,5,13,EDGE)
wood(s,0,5,48,26); s.box(32,7,11,23,LILAC)
for yy in [9,15,21,27]: s.box(32,yy,11,2,'#DBD0EA')
s.poly([(5,10),(17,8),(21,10),(33,8),(33,24),(21,26),(17,24),(5,26)],INK)
s.poly([(6,11),(17,9),(19,11),(19,24),(17,23),(6,24)],CREAM)
s.poly([(21,11),(31,9),(31,23),(21,24)],'#F4DCC8')
for yy in [13,17,21]: s.box(8,yy,7,1,EDGE); s.box(23,yy,6,1,EDGE)
s.line([(36,13),(40,23)],'#D886A1',2); s.box(39,22,2,2,INK); s.save('shop/order_desk.png')
s=Canvas(64,36)
s.oval(0,30,64,6,'#84717D45'); wood(s,0,16,64,17); s.box(2,16,60,3,LIGHT)
s.box(5,19,14,12,PINK)
for xx in [6,17]: s.box(xx,19,1,12,CREAM)
s.box(24,10,24,13,INK); s.box(26,5,20,14,LILAC); s.box(28,6,16,7,INK); s.box(30,8,12,3,CREAM)
s.box(25,20,22,2,CREAM)
for xx in [28,33,38,43]: s.box(xx,15,3,2,CREAM)
s.box(51,18,10,4,EDGE); s.oval(53,13,6,6,GOLD); s.box(55,12,2,2,CREAM); s.save('shop/checkout.png')
# World room: all sides filled by the interior, no surrounding lawn.
c=Canvas(640,360,'#E3D1D8'); rng=Random(81)
# Stepped cutaway shadow and scalloped shop shell.
for inset,col in [(0,'#C7B8CF'),(4,'#D4C2D1')]: rim(c,66+inset,31+inset,512,294,col, '#C1A9BD')
rim(c,66,28,508,290,WOOD,INK)
c.box(70,32,500,28,PINK)
# Faded floral wallpaper on the rear and deep side returns.
for x,y,w,h in [(72,34,496,26),(70,60,72,234),(498,60,72,234)]:
    c.box(x,y,w,h,'#F0D3D8')
    for xx in range(x+4,x+w-3,12):
        c.box(xx,y,2,h,'#E8C2CF')
        for yy in range(y+6,y+h-3,18): flower(c,xx+1,yy,'#E8B9CA')
# Honey birch boards, quiet texture rather than high-contrast stripes.
for row,y in enumerate(range(64,296,12)):
    c.box(144,y,352,12,rng.choice(['#F0D5B8','#EDD0B2','#EED2B5']))
    c.box(144,y+11,352,1,'#D7B59F'); c.box(144,y,352,1,'#FFE4C6')
    for x in range(144-(row%3)*24,496,72):
        if x>=144: c.box(x,y+1,1,10,'#DDBBA4')
        xx=max(146,x+10); c.box(xx,y+6,min(14,496-xx),1,'#E2C2AA')
        if 155<x<470: c.box(x+6,y+4,3,1,'#D3B09D')
# Wainscot, molding and narrow side barrier all agree with collision walls.
for x in [132,496]:
    wood(c,x,60,12,238); c.box(x+2,62,3,232,LIGHT)
c.box(72,55,496,9,EDGE); c.box(72,55,496,3,CREAM); c.box(72,63,496,2,INK)
# Back windows, lace curtains and striped valance.
def window(x,y,w,h):
    wood(c,x-4,y-4,w+8,h+10); c.box(x,y,w,h,'#A6C3D0'); c.box(x+2,y+2,w-4,h//2,'#D5DEE3')
    c.poly([(x+2,y+h-5),(x+10,y+h-13),(x+20,y+h-9),(x+w-3,y+h-16),(x+w-3,y+h-2),(x+2,y+h-2)],MINT)
    c.box(x+w//2-1,y,2,h,CREAM); c.box(x,y+h//2,w,2,CREAM)
    for xx in [x-2,x+w-9]:
        c.poly([(xx,y-2),(xx+11,y-2),(xx+8,y+h-7),(xx+3,y+h-4),(xx,y+h-6)],CREAM)
        for sx in [xx+2,xx+6]: c.box(sx,y,1,h-11,'#E6C7CF')
        c.box(xx+2,y+h-12,7,2,PINK)
    c.box(x-6,y+h+2,w+12,4,LIGHT)
window(82,79,38,53); window(516,77,36,45)
# Rear clerestory, old shop sign, little hanging lamps.
window(280,35,80,20)
for x in [170,461]:
    c.box(x,33,2,7,INK); c.poly([(x-8,42),(x-4,37),(x+6,37),(x+10,42)],LILAC)
    c.box(x-8,42,18,2,INK); c.box(x-3,44,8,2,GOLD)
# Behind fixtures: visual display labels (icons, no English baked into art).
for x,col,kind in [(200,PINK,'shelf'),(424,LILAC,'shelf')]:
    b=Canvas(16,14); badge(b,kind,col); c.paste(b,x,87)
# Left built-in old apothecary hutch: visibly distinct from the bright usable shelves.
wood(c,76,157,50,127); c.box(80,163,42,73,'#B29DAD')
for yy in [166,190,214]:
    c.box(82,yy,38,19,'#C4B3C1'); c.box(80,yy+19,42,4,LIGHT)
for xx,yy,col in [(86,177,MINT),(107,220,PINK)]:
    c.oval(xx,yy,9,11,col); c.box(xx+2,yy-2,5,3,EDGE); c.box(xx+2,yy+3,3,4,CREAM)
for yy in [242,261]:
    rim(c,81,yy,40,17,'#E1BBC8'); c.box(97,yy+7,9,2,INK); c.box(99,yy+7,5,1,GOLD)
web(c,82,166,26)
# Chipped paint and one missing drawer pull.
c.box(79,252,3,9,CREAM); c.line([(111,266),(116,263),(116,270)],EDGE)
# Right asymmetrical nook, cabinet and old radio on a doily.
wood(c,508,151,51,69); c.box(512,167,43,43,LILAC)
for xx in [514,536]:
    rim(c,xx,169,18,36,'#D7CCE7'); c.box(xx+8,184,2,3,GOLD)
c.box(507,151,54,4,CREAM)
rim(c,518,131,32,20,WOOD,INK); c.box(521,134,12,12,'#A38D9F')
for xx in range(522,532,3): c.box(xx,135,1,10,CREAM)
c.box(537,135,10,3,CREAM); c.oval(538,141,5,5,GOLD); c.box(519,128,29,2,INK)
# Uneven stack of parcels and broken stool tucked against the solid side walls.
for xx,yy,ww,hh,col in [(510,261,25,22,MINT),(535,269,24,18,PINK),(516,245,23,17,WOOD)]:
    rim(c,xx,yy,ww,hh,col); c.box(xx+ww//2,yy+2,3,hh-4,CREAM); c.box(xx+4,yy+hh//2,6,4,CREAM)
c.line([(551,231),(548,245)],EDGE,3); c.line([(562,232),(565,242)],EDGE,3)
c.poly([(543,226),(559,224),(566,228),(564,233),(545,234)],WOOD); c.line([(553,226),(555,229),(552,233)],INK)
# Original floor rugs, with visible worn weave and fringes.
def rug(x,y,w,h,col):
    c.box(x+2,y+3,w,h,'#CEADA780'); rim(c,x,y,w,h,col)
    c.box(x+4,y+4,w-8,h-8,CREAM); c.box(x+6,y+6,w-12,h-12,col)
    for xx in range(x+3,x+w-2,4): c.box(xx,y-2,1,2,CREAM); c.box(xx,y+h,1,2,CREAM)
    for xx in range(x+13,x+w-8,16):
        c.poly([(xx,y+h//2-4),(xx+4,y+h//2),(xx,y+h//2+4),(xx-4,y+h//2)],CREAM)
    c.box(x+4,y+h-5,8,1,WOOD)
rug(276,185,88,49,MINT); rug(304,282,32,13,PINK)
# Sparse dust, a forgotten key and scratches. Never confuse debris with goods.
for x,y in [(252,119),(384,264),(161,258),(464,184)]:
    c.box(x,y,2,1,'#C4AAA4'); c.box(x+4,y+2,1,1,'#C4AAA4')
c.line([(456,280),(461,278),(465,280)],'#BDA5A0')
# Crooked little calendar and framed floral print.
wood(c,250,77,17,21); c.box(252,79,13,17,CREAM); c.box(252,79,13,4,PINK)
for xx in [254,258,262]:
    for yy in [87,91]: c.box(xx,yy,2,2,EDGE)
c.poly([(374,78),(392,80),(390,104),(372,102)],EDGE); c.poly([(376,81),(389,83),(387,100),(375,99)],CREAM)
sprig(c,382,97); flower(c,380,86,LILAC)
pot(c,155,96); pot(c,482,285)
# Ivy drapes from one high corner; opposite corner has fine old cobwebs.
for x,y in [(92,61),(97,67),(103,72),(109,78)]:
    c.line([(x-4,y-5),(x+4,y+5)],'#86AAA2'); c.oval(x,y,7,4,MINT)
web(c,498,65,27)
# Southern cutaway wall, matching the real open doorway.
for x,w in [(70,234),(336,234)]:
    c.box(x,296,w,18,EDGE); c.box(x,296,w,3,LIGHT); c.box(x+2,300,w-4,12,PINK)
    for xx in range(x+8,x+w-4,18): c.box(xx,301,1,10,'#D6A4BA')
    c.box(x,313,w,3,INK)
c.box(304,296,32,3,LIGHT); c.box(304,299,32,17,'#D4BCA8')
# Pale stone stoop, never a surrounding empty green field.
for yy in [319,332,345]:
    for xx in [302,320]: rim(c,xx,yy,18,11,'#EADDE0','#C6B3C4')
c.save('shop/room.png')
# UI nine-slice pixel frames, ornamental corner stitches and dedicated world badges.
s=Canvas(24,24)
rim(s,0,0,24,24,CREAM,INK); s.box(2,2,20,20,PINK); s.box(3,3,18,18,CREAM)
for x,y in [(3,3),(18,3),(3,18),(18,18)]:
    s.box(x,y,3,3,GOLD); s.box(x+1,y+1,1,1,CREAM)
s.save('ui/panel.png')
for kind,col in [('box',MINT),('book',LILAC),('shelf',PINK),('coin',GOLD)]:
    s=Canvas(16,14); badge(s,kind,col); s.save('ui/'+kind+'.png')
# Four chibi villagers. Big 18px heads, tiny apron bodies, expressive blush.
sheet=Canvas(288,128)
for variant,(coat,hair,skin) in enumerate([(MINT,'#826175','#F5D3BD'),(PINK,'#A37C6D','#EBC5AD'),(LILAC,'#DCD2DD','#CFA187'),(GOLD,'#69647E','#F2CCB6')]):
    for direction in range(4):
        for frame in range(3):
            p=Canvas(24,32); bob=1 if frame==2 else 0
            p.oval(4,28,17,3,'#68556940')
            for x,delta in [(7,-1 if frame==1 else 0),(14,1 if frame==1 else 0)]:
                p.box(x,25,4,5+delta,INK); p.box(x,28+delta,3,1,'#A5869B')
            p.poly([(7,17+bob),(17,17+bob),(20,25+bob),(17,28),(7,28),(4,25+bob)],INK)
            p.poly([(7,18+bob),(17,18+bob),(19,24+bob),(17,26),(7,26),(5,24+bob)],coat)
            p.box(3,21+bob,3,4,skin); p.box(18,21+bob,3,4,skin)
            if direction!=1:
                p.box(9,19+bob,6,7,CREAM); p.box(10,24,4,1,EDGE); p.box(11,19+bob,2,1,PINK)
            else: p.box(8,22,8,1,CREAM)
            p.poly([(5,3+bob),(8,1+bob),(16,1+bob),(20,5+bob),(21,13+bob),(18,18+bob),(6,18+bob),(3,14+bob),(3,7+bob)],INK)
            p.poly([(5,5+bob),(9,3+bob),(16,3+bob),(19,6+bob),(19,13+bob),(16,17+bob),(7,17+bob),(5,14+bob)],skin)
            p.poly([(4,5+bob),(7,2+bob),(16,2+bob),(19,5+bob),(19,9+bob),(16,7+bob),(14,8+bob),(12,5+bob),(9,8+bob),(5,9+bob)],hair)
            p.box(7,3+bob,6,1,'#B695A3' if variant==0 else '#F0D6C4')
            if direction==1:
                p.poly([(4,7+bob),(19,7+bob),(19,15+bob),(16,18+bob),(6,18+bob),(4,14+bob)],hair)
                p.box(7,14+bob,10,2,'#B695A3' if variant==0 else '#C2ABB9')
            elif direction in [2,3]:
                eye=6 if direction==2 else 17; p.box(eye,10+bob,2,3,INK); p.box(eye,10+bob,1,1,CREAM)
                p.box(eye-1,14+bob,3,1,PINK)
                p.box(16 if direction==2 else 4,8+bob,4,8,hair)
            else:
                for x in [7,15]:
                    p.box(x,10+bob,2,3,INK); p.box(x,10+bob,1,1,CREAM); p.box(x-1,14+bob,3,2,'#E7A8B3')
                p.box(11,14+bob,2,1,INK)
            if variant==0:
                p.box(16,4+bob,4,3,CREAM); p.box(17,5+bob,2,1,PINK)
            if variant==1:
                p.box(2,5+bob,20,3,INK); p.box(3,5+bob,18,2,GOLD); p.box(6,0+bob,12,5,GOLD); p.box(6,3+bob,12,2,PINK)
            if variant==2:
                p.box(3,10+bob,3,8,hair); p.box(18,10+bob,3,8,hair); p.box(3,16+bob,3,2,PINK); p.box(18,16+bob,3,2,PINK)
            if variant==3:
                p.box(4,3+bob,16,4,MINT); p.box(7,1+bob,10,3,MINT); p.box(14,6+bob,7,2,'#86ADA6')
            sheet.paste(p,(direction*3+frame)*24,variant*32)
sheet.save('characters/villagers.png')
print('Built original pastel room, furniture, goods, UI and 48 chibi poses.')
