"""Original pixel art for the village, dressing room and layered 24x32 actors.
Pillow is an authoring dependency only. Every atlas has 4 directions x 3 poses.
No generated art is drawn with runtime geometry. Rebuild: python3 tools/build_frontend_art.py.
"""
from pathlib import Path
from random import Random
from PIL import Image, ImageDraw
ROOT = Path(__file__).resolve().parents[1] / 'assets'
INK='#51483F'; EDGE='#80604B'; WOOD='#C5A36F'; LIGHT='#DCCA9E'; CREAM='#E9DFC8'
CLAY='#B7795F'; BLUE='#A8B4B1'; OLIVE='#879575'; GOLD='#C8AC70'
class C:
    def __init__(self,w,h,bg=(0,0,0,0)):
        self.im=Image.new('RGBA',(w,h),bg); self.d=ImageDraw.Draw(self.im)
    def box(self,x,y,w,h,c): self.d.rectangle((x,y,x+w-1,y+h-1),fill=c)
    def poly(self,p,c): self.d.polygon(p,fill=c)
    def line(self,p,c,w=1): self.d.line(p,fill=c,width=w)
    def oval(self,x,y,w,h,c): self.d.ellipse((x,y,x+w-1,y+h-1),fill=c)
    def paste(self,p,x,y): self.im.alpha_composite(p.im,(x,y))
    def save(self,path):
        p=ROOT/path; p.parent.mkdir(parents=True,exist_ok=True); self.im.save(p,optimize=True)
def rim(c,x,y,w,h,col):
    c.box(x+2,y,w-4,h,INK); c.box(x,y+2,w,h-4,INK); c.box(x+2,y+2,w-4,h-4,col)
    c.box(x+3,y+2,w-6,1,LIGHT)
r=Random(1971)
def tree(c,x,y,s=1):
    c.oval(x-19*s,y-3*s,43*s,9*s,'#7F8667')
    c.poly([(x-3*s,y),(x+4*s,y),(x+2*s,y-44*s),(x-1*s,y-48*s)],EDGE)
    c.line([(x,y-17*s),(x-14*s,y-37*s)],EDGE,3*s)
    c.line([(x,y-26*s),(x+16*s,y-45*s)],EDGE,3*s)
    for dx,dy,sz in [(-19,-49,26),(0,-61,27),(17,-47,25),(-3,-37,28)]:
        xx=x+dx*s-12*s; yy=y+dy*s-12*s
        # Broken, stepped crowns rather than circular tree symbols.
        outline=[(0,8),(3,8),(3,4),(8,4),(8,1),(14,1),(14,0),(20,0),(20,4),(24,4),(24,8),(27,8),(27,17),(24,17),(24,23),(20,23),(20,26),(8,26),(8,23),(3,23),(3,19),(0,19)]
        pts=[(xx+px*s,yy+py*s) for px,py in outline]
        c.poly(pts,'#98764C')
        col=r.choice([GOLD,CLAY,'#B89659','#C6A366'])
        c.poly([(xx+px*s,yy+(py-2)*s) for px,py in outline],col)
        for i in range(44):
            px=r.randrange(2,25); py=r.randrange(3,22)
            if (px<5 or px>23) and (py<8 or py>18): continue
            c.line([(xx+px*s,yy+py*s),(xx+(px+2)*s,yy+(py-1)*s)],r.choice([LIGHT,'#D8B879','#A47C50',col]),s)
        c.line([(xx+5*s,yy+6*s),(xx+10*s,yy+3*s),(xx+15*s,yy+3*s)],LIGHT,s)

def house(c,x,y,w,h,paint,shop=False):
    c.poly([(x-8,y+h),(x+w,y+h-5),(x+w+29,y+h+12),(x+8,y+h+17)],'#8C8B6B')
    c.box(x,y,w,h,EDGE); c.box(x+2,y+2,w-4,h-3,paint)
    for yy in range(y+5,y+h-3,6): c.box(x+2,yy,w-4,1,'#B6A481')
    c.box(x+w-17,y-28,8,22,EDGE); c.box(x+w-18,y-29,10,3,LIGHT)
    c.poly([(x-8,y+1),(x+w//2,y-32),(x+w+8,y+1),(x+w+8,y+6),(x-8,y+6)],INK)
    c.poly([(x-6,y),(x+w//2,y-29),(x+w+5,y)],'#926A50')
    for yy in range(y-24,y,4):
        half=int((yy-y+29)*w/58)
        c.box(x+w//2-half,yy,2*half,1,'#AF8260')
        for xx in range(x+w//2-half+3,x+w//2+half,9): c.box(xx,yy-2,1,2,'#715744')
    c.box(x-7,y+1,w+14,2,GOLD)
    door=x+w//2-6
    rim(c,door,y+h-28,14,28,OLIVE); c.box(door+3,y+h-24,8,10,BLUE); c.box(door+10,y+h-11,2,2,GOLD)
    for xx in [x+8,x+w-24]:
        rim(c,xx,y+13,17,21,BLUE); c.box(xx+3,y+15,11,15,'#D9CCA0')
        c.box(xx+8,y+14,1,18,CREAM); c.box(xx+2,y+23,13,1,CREAM)
        c.box(xx-2,y+12,3,22,OLIVE); c.box(xx+16,y+12,3,22,OLIVE)
        c.box(xx-1,y+33,20,3,EDGE)
        for fx in [xx+2,xx+9,xx+15]: c.box(fx,y+30,3,3,CLAY)
    c.box(door-3,y+h,w//3,3,LIGHT)
    if shop:
        rim(c,x+12,y-2,w-24,13,OLIVE)
        # Slatted hanging shop sign, with tiny goods engraved below the UI lettering.
        for xx in range(x+10,x+w-8,9):
            c.box(xx,y+12,9,7,CREAM if (xx-x)%18 else CLAY)
            c.oval(xx,y+16,9,6,CREAM if (xx-x)%18 else CLAY)
        c.box(x+w-23,y+h-9,12,8,WOOD)
        for xx in range(x+w-22,x+w-12,3): c.oval(xx,y+h-11,4,4,CLAY)
# A full landscape, with room on the left for a quiet paper menu.
c=C(640,360,'#DDD4B9')
for y,col in [(35,'#E3D6B5'),(70,'#E8D8AF'),(105,'#EBDCBA')]: c.box(0,y,640,40,col)
c.oval(477,30,53,53,'#F2E3B8'); c.oval(484,36,39,39,'#F6E9C8')
c.poly([(0,139),(30,133),(52,130),(73,131),(96,137),(118,137),(141,132),(160,131),(184,135),(215,144),(248,146),(280,140),(306,134),(334,133),(359,136),(390,132),(418,125),(438,124),(458,127),(480,131),(506,130),(532,123),(552,120),(579,122),(607,128),(640,130),(640,235),(0,235)],'#A4AC8B')
c.poly([(0,183),(84,148),(147,167),(243,147),(319,173),(410,148),(498,161),(574,137),(640,149),(640,282),(0,282)],'#919C78')
for x in range(5,640,15):
    c.oval(x,151+r.randint(-9,9),24,22,r.choice(['#9B9E76','#ADB187','#B5AE7B']))
c.poly([(0,235),(101,205),(205,234),(312,195),(419,216),(525,194),(640,219),(640,360),(0,360)],'#ABB18A')
# Winding village lane, shaded verges, little stone edges.
road=[(418,194),(433,194),(425,211),(403,226),(393,237),(408,248),(475,261),(502,281),(494,303),(462,325),(475,360),(371,360),(403,318),(449,293),(452,280),(412,270),(368,258),(353,240),(369,223),(401,210)]
c.poly(road,'#B59F78')
c.poly([(421,194),(429,194),(419,213),(389,232),(381,241),(393,253),(468,271),(482,284),(475,300),(433,329),(427,360),(390,360),(414,319),(458,293),(460,283),(445,277),(381,261),(365,247),(364,235),(380,222),(409,210)],'#D8C39A')
for i in range(190):
    x=r.randrange(355,490); y=r.randrange(204,360)
    if c.im.getpixel((x,y))[:3]==(216,195,154): c.box(x,y,r.randrange(1,4),1,r.choice([LIGHT,'#BFA77F','#E4CFA8']))
house(c,292,176,67,49,'#D1C5A0'); house(c,508,166,71,56,'#D0B68C')
house(c,432,213,87,62,'#D9C9A6',True)
house(c,192,207,62,48,'#C6BEA0')
# Village fence, grass tufts, warm orchard and flowered roadside.
for x in range(520,640,11):
    c.poly([(x,261),(x+2,258),(x+5,261),(x+5,282),(x,282)],LIGHT)
c.box(520,266,120,3,WOOD); c.box(520,275,120,2,WOOD)
for x,y,s in [(617,300,2),(553,255,1),(351,226,1),(268,284,1),(27,296,2),(124,249,1)]: tree(c,x,y,s)
for i in range(1000):
    x=r.randrange(640); y=r.randrange(224,360)
    if c.im.getpixel((x,y))[:3] in [(171,177,138),(145,156,120)]:
        c.line([(x,y),(x+1,y-2)],r.choice(['#8F9D76','#BFC098','#9CA779']))
for i in range(200):
    x=r.randrange(640); y=r.randrange(269,360)
    if 300<x<505: continue
    c.box(x,y,3,1,r.choice([GOLD,CLAY,LIGHT]))
# A bicycle beside the shop, barrel, post and mailbox.
for x in [518,540]: c.oval(x,265,13,13,INK); c.oval(x+2,267,9,9,'#ABB18A')
c.line([(524,271),(532,258),(546,271),(524,271),(537,261)],CLAY,2); c.line([(532,258),(529,255),(534,255)],INK)
c.line([(543,264),(544,253),(549,253)],INK)
c.box(393,254,3,27,EDGE); rim(c,386,250,17,10,CLAY); c.box(390,252,8,1,CREAM)
c.oval(277,277,16,7,EDGE); c.box(277,280,16,13,WOOD); c.oval(277,289,16,6,EDGE)
for x in [280,285,290]: c.box(x,280,1,10,EDGE)
# Pixel-stepped sun wash, transparent amber on the orchard.
sun=C(640,360); sun.poly([(486,70),(522,66),(604,360),(478,360)],'#FFF0C018'); c.paste(sun,0,0)
c.save('frontend/village.png')
cloud=C(96,24)
for x,y,w,h in [(0,12,96,10),(10,8,76,13),(20,3,25,18),(43,0,29,21),(66,8,20,13)]: cloud.oval(x,y,w,h,'#F0E5CD')
cloud.box(12,21,72,2,'#DACFB9'); cloud.save('frontend/cloud.png')
leaves=C(24,8)
for i,col in enumerate([CLAY,GOLD,OLIVE]):
    x=i*8; leaves.poly([(x,3),(x+2,1),(x+5,1),(x+7,0),(x+6,5),(x+3,7),(x+1,6)],col); leaves.line([(x,7),(x+5,2)],EDGE)
leaves.save('frontend/leaves.png')
# Dressing room: floral wallpaper, oak boards, brass mirror, real clothes on a rail.
c=C(288,320,'#D9CEB1')
for x in range(0,288,12):
    c.box(x,0,2,217,'#CEC2A4')
    for y in range(7,210,19):
        for dx,dy in [(0,-2),(-2,0),(2,0),(0,2)]: c.box(x+5+dx,y+dy,2,2,'#B4B28F')
        c.box(x+5,y,2,2,CLAY)
c.box(0,211,288,6,EDGE); c.box(0,211,288,2,LIGHT)
for y in range(217,320,12):
    c.box(0,y,288,12,r.choice([WOOD,'#C3A47B','#CEB58D'])); c.box(0,y+11,288,1,'#A38967')
    for x in range((y%3)*19,288,62): c.box(x,y+1,1,10,EDGE); c.box(x+6,y+5,12,1,LIGHT)
# Tall, stepped oval mirror with carved shoulders and brass finials.
for x,y,w,h,col in [(46,29,142,225,INK),(49,32,136,219,EDGE),(52,35,130,213,GOLD),(57,40,120,203,LIGHT),(61,44,112,195,EDGE),(64,47,106,189,BLUE)]:
    c.oval(x,y,w,h,col)
c.poly([(78,76),(102,56),(156,60),(162,92),(145,150),(79,210),(71,182)],'#C6CFBF')
c.poly([(151,78),(157,89),(83,215),(78,211)],'#D8DCC7')
for x in [61,166]:
    c.box(x,210,6,54,EDGE); c.box(x+1,212,2,50,WOOD); c.oval(x-2,258,11,5,INK)
for x,y in [(51,130),(176,130),(114,29)]:
    c.oval(x-5,y-5,10,10,EDGE); c.oval(x-3,y-3,6,6,GOLD); c.box(x-1,y-3,2,2,CREAM)
# Rug: tasseled, woven, floral centre.
c.oval(42,246,173,46,'#926D54'); c.oval(46,249,165,39,CLAY); c.oval(53,253,151,31,GOLD); c.oval(57,255,143,27,'#A47659')
for x in range(58,201,8): c.line([(x,250),(x+3,253)],CREAM); c.line([(x,280),(x+3,283)],CREAM)
for x in range(73,193,13): c.poly([(x,266),(x+4,261),(x+8,266),(x+4,271)],GOLD)
# Vintage garment rail and six detailed garments.
c.box(212,79,4,180,EDGE); c.box(276,79,4,180,EDGE); c.box(210,78,72,4,LIGHT)
for i,col in enumerate([OLIVE,CLAY,BLUE]):
    x=214+i*19; c.line([(x+7,82),(x+7,89),(x,94),(x+15,94),(x+7,89)],INK)
    c.poly([(x,96),(x+5,93),(x+10,93),(x+17,97),(x+18,108),(x+14,109),(x+13,147),(x+2,147),(x+2,110),(x-2,109)],INK)
    c.poly([(x+1,98),(x+6,95),(x+10,95),(x+15,98),(x+15,106),(x+11,106),(x+11,144),(x+4,144),(x+4,106),(x+1,106)],col)
    c.box(x+7,99,1,43,LIGHT)
    for y in [108,117,126]: c.box(x+8,y,1,1,INK)
c.box(203,257,23,4,INK); c.box(267,257,19,4,INK)
# Low dresser, quilted stool, gramophone, potted dried flowers.
rim(c,213,174,70,65,WOOD)
for y in [180,198,216]:
    rim(c,218,y,60,15,'#B99A70'); c.oval(245,y+5,7,3,EDGE); c.box(247,y+5,3,1,GOLD)
c.box(209,171,77,5,LIGHT)
c.box(223,238,4,9,INK); c.box(273,238,4,9,INK)
c.box(235,160,27,11,EDGE); c.oval(238,158,22,5,INK); c.oval(244,159,9,3,GOLD)
c.line([(255,160),(257,146),(251,140)],GOLD,3)
c.poly([(251,145),(236,139),(236,126),(252,129),(258,138)],EDGE); c.oval(233,125,12,18,GOLD); c.oval(235,127,8,14,'#6D6350')
for x in [14,36]: c.box(x,276,3,21,EDGE)
c.oval(4,266,44,16,INK); c.oval(6,266,40,12,OLIVE)
for x in range(9,41,7): c.line([(x,267),(x+5,273)],LIGHT)
c.poly([(13,213),(33,213),(29,236),(18,236)],EDGE); c.box(14,211,19,4,CLAY)
for dx,dy in [(-5,-27),(6,-39),(13,-23),(1,-18)]:
    c.line([(23,212),(23+dx,212+dy)],OLIVE,2)
    for sx,sy in [(0,0),(-2,2),(2,3),(0,5)]: c.box(23+dx+sx,212+dy+sy,3,3,GOLD)
c.save('frontend/dressing_room.png')
# Layered actor atlases. White/grey ramps are tinted at runtime, retaining pixel shadows.
def atlas(rows, painter, name):
    sheet=C(288,32*rows)
    for variant in range(rows):
        for direction in range(4):
            for frame in range(3):
                p=C(24,32); painter(p,variant,direction,frame); sheet.paste(p,(direction*3+frame)*24,variant*32)
    sheet.save('characters/'+name+'.png')
def body(p,v,d,f):
    b=int(f==2)
    for x,step in [(7,-1 if f==1 else 0),(14,1 if f==1 else 0)]:
        p.box(x,25,4,5+step,INK); p.box(x,28+step,3,1,WOOD)
    p.poly([(5,3+b),(8,1+b),(16,1+b),(20,5+b),(21,13+b),(18,18+b),(6,18+b),(3,14+b),(3,7+b)],'#9C9C9C')
    p.poly([(5,5+b),(9,3+b),(16,3+b),(19,6+b),(19,13+b),(16,17+b),(7,17+b),(5,14+b)],'#FFFFFF')
    p.box(6,13+b,2,2,'#DADADA'); p.box(17,13+b,2,2,'#DADADA')
    p.box(3,21+b,3,4,'#FFFFFF'); p.box(18,21+b,3,4,'#DADADA'); p.box(10,17+b,4,3,'#FFFFFF')
def clothes(p,v,d,f):
    b=int(f==2); col=[OLIVE,CLAY,BLUE,GOLD,'#847A88','#A6A184'][v]
    p.poly([(7,17+b),(17,17+b),(20,25+b),(17,28),(7,28),(4,25+b)],INK)
    p.poly([(7,18+b),(17,18+b),(19,24+b),(17,26),(7,26),(5,24+b)],col)
    if v==0: # apron
        p.box(9,19+b,6,7,CREAM); p.box(10,24+b,4,1,EDGE); p.box(11,19+b,2,1,CLAY)
        if d==1: p.box(8,22+b,8,1,CREAM)
    elif v==1: # cardigan
        p.box(11,18+b,2,8,CREAM)
        for y in [20,23,25]: p.box(13,y+b,1,1,GOLD)
        p.box(7,23+b,3,2,EDGE); p.box(15,23+b,3,2,EDGE)
    elif v==2: # overalls
        p.box(8,18+b,2,8,CREAM); p.box(14,18+b,2,8,CREAM); p.box(9,21+b,6,5,'#728D90'); p.box(11,22+b,3,2,LIGHT)
    elif v==3: # striped knit
        for y in [20,23,26]: p.box(7,y+b,10,1,CREAM)
        p.box(10,18+b,4,1,EDGE)
    elif v==4: # pinafore
        p.poly([(9,18+b),(15,18+b),(18,27),(6,27)],CREAM); p.box(11,20+b,3,4,col); p.box(9,25,6,1,GOLD)
    else: # collared shirt and scarf
        p.poly([(8,18+b),(11,18+b),(12,21+b),(14,18+b),(17,18+b),(15,22+b),(10,22+b)],CREAM)
        p.box(11,20+b,2,7,CLAY); p.box(12,22+b,3,2,CLAY)
def eyes(p,v,d,f):
    b=int(f==2)
    if d==1: return
    for x in ([7,15] if d==0 else [6] if d==2 else [17]):
        p.box(x,10+b,2,3,'#686868'); p.box(x,10+b,1,2,'#FFFFFF')
    # Mouth/cheeks stay on the independent face detail atlas.
def face(p,v,d,f):
    b=int(f==2)
    if d==1: return
    for x in ([6,15] if d==0 else [5] if d==2 else [17]): p.box(x,14+b,3,1,'#CB9980')
    if d==0: p.box(11,14+b,2,1,EDGE)
def hair(p,v,d,f):
    b=int(f==2)
    col='#FFFFFF'; shadow='#B8B8B8'; mid='#DADADA'
    p.poly([(4,5+b),(7,2+b),(16,2+b),(19,5+b),(19,9+b),(16,7+b),(14,8+b),(12,5+b),(9,8+b),(5,9+b)],col)
    p.box(7,3+b,7,1,mid); p.box(4,7+b,2,5,shadow)
    if d==1:
        p.poly([(4,7+b),(19,7+b),(19,15+b),(16,18+b),(6,18+b),(4,14+b)],col)
        p.box(7,15+b,9,2,shadow)
    elif d in [2,3]: p.box(16 if d==2 else 4,8+b,4,9,col)
    if v==1: # rounded bob
        for x in [3,18]: p.box(x,8+b,3,12,col); p.box(x,18+b,3,2,shadow)
    elif v==2: # wavy crop
        for x,y in [(3,4),(6,1),(10,0),(15,1),(18,4)]: p.oval(x,y+b,5,5,col); p.box(x,y+b+3,2,1,mid)
    elif v==3: # long loose
        for x in [3,18]: p.box(x,8+b,3,16,col); p.box(x,21+b,3,3,shadow)
        if d==1: p.box(5,10+b,14,13,col); p.box(7,21+b,10,2,mid)
    elif v==4: # two braids
        for x in [2,19]:
            p.box(x,8+b,3,14,col)
            for y in [12,16,20]: p.box(x,y+b,2,1,shadow)
            p.box(x-1,20+b,4,2,CLAY)
    elif v==5: # bun
        p.oval(8,0,9,6,shadow); p.oval(9,0,7,4,col)
        if d==1: p.oval(8,6+b,9,8,shadow); p.oval(9,6+b,7,6,col)
    elif v==6: # side ponytail
        x=0 if d==2 else 19; p.oval(x,6+b,5,14,col); p.box(x+1,8+b,3,2,CLAY); p.box(x+1,16+b,2,4,mid)
    elif v==7: # swept fringe
        p.poly([(5,4+b),(17,3+b),(19,7+b),(14,11+b),(10,10+b),(11,6+b),(5,9+b)],col)
        p.line([(7,4+b),(14,4+b),(16,6+b)],mid)
atlas(1,body,'body'); atlas(6,clothes,'clothes'); atlas(1,eyes,'eyes'); atlas(1,face,'face'); atlas(8,hair,'hair')
print('Built village landscape, dressing room, clouds/leaves and 204 layered actor cells.')
