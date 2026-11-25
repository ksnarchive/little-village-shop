#!/usr/bin/env python3
"""Original, deterministic pixel art and a quiet synthesized rail loop. No external assets."""
from pathlib import Path
from PIL import Image, ImageDraw
import math, random, wave, struct
OUT = Path(__file__).resolve().parents[1] / 'assets/train'
OUT.mkdir(parents=True, exist_ok=True)
rng = random.Random(1973)

def canvas(w, h, bg):
    im = Image.new('RGBA', (w, h), bg)
    return im, ImageDraw.Draw(im)

def save(im, name): im.save(OUT / (name + '.png'))

im, d = canvas(640, 300, '#bda47b')
# Cream painted ceiling, curved roof ribs, walnut cornice.
for y in range(48):
    d.line((0,y,639,y), fill=['#98866c','#ac9879','#c1ad8c','#d2c1a0','#ddceb0'][min(4,y//9)])
for x in range(-30,700,94):
    d.line((x,0,x+30,38), fill='#aa9679', width=3)
    d.line((x+5,0,x+35,38), fill='#e1d1b1', width=2)
d.rectangle((0,39,639,45), fill='#584738'); d.line((0,40,639,40),fill='#d3ae72',width=2)
# Wood panels with fine grain and inset mouldings.
d.rectangle((0,46,639,219),fill='#a28158')
for x in range(0,640,54):
    d.rectangle((x,47,x+50,216),fill='#b18f61')
    d.line((x+1,48,x+1,215),fill='#d1af79'); d.line((x+51,48,x+51,216),fill='#71583f',width=2)
    for _ in range(15):
        xx=x+rng.randrange(4,48); yy=rng.randrange(49,210)
        d.line((xx,yy,xx,yy+rng.randrange(3,15)),fill=rng.choice(['#a78559','#b99667','#bd9b6b']))
# Floor boards in perspective.
d.rectangle((0,220,639,299),fill='#594f43')
for y in [225,238,254,275,298]:
    d.line((0,y,640,y),fill='#393a33',width=2);d.line((0,y+2,640,y+2),fill='#72624d')
for x in range(-400,1100,80): d.line((320+(x-320)*.55,220,x,300),fill='#433f35',width=2)
for _ in range(200):
    x=rng.randrange(640); y=rng.randrange(226,299); d.line((x,y,x+rng.randrange(2,12),y),fill='#665947')
# Window with softened pixel corners, brass catches and substantial wooden sill.
d.rounded_rectangle((138,48,500,183),radius=12,fill='#5a4837')
d.rounded_rectangle((143,51,496,178),radius=10,fill='#d4b17b')
d.rounded_rectangle((148,55,491,174),radius=8,fill='#695e4a')
d.rectangle((155,59,484,168),fill=(0,0,0,0))
d.rectangle((150,65,154,163),fill='#e0c28d');d.rectangle((485,64,489,166),fill='#554c3e')
d.line((155,169,484,169),fill='#e6c690',width=2)
d.rectangle((135,180,504,187),fill='#6b5039');d.rectangle((132,178,506,181),fill='#d9b780')
for x in [164,471]:
    d.rectangle((x,172,x+8,176),fill='#6b6650');d.rectangle((x+2,171,x+6,174),fill='#d9c793')
# Wine coloured pleated curtains, tied with fabric bands.
for side in [0,1]:
    base=113 if side==0 else 493
    points=[(base,48),(base+26,48),(base+22,98),(base+14,119),(base+24,173),(base-4,173),(base,112)]
    d.polygon(points,fill='#885047')
    for dx in [2,9,17]:
        d.line((base+dx,51,base+dx-3,106,base+dx-6,118,base+dx+2,170),fill='#ab6c59',width=3)
    d.rectangle((base-2,112,base+18,117),fill='#c5aa73');d.line((base,113,base+17,113),fill='#e1c98b')
# Luggage racks: woven wire, rounded nickel rails and cast supports.
for x0,x1 in [(11,104),(530,628)]:
    d.polygon([(x0,55),(x1-7,55),(x1,65),(x0+4,65)], fill='#6c6c55')
    for x in range(x0+4,x1-4,6): d.line((x,54,x+4,63),fill='#bab69a')
    d.line((x0,65,x1,65),fill='#d7d1ad',width=3)
    for x in [x0+7,x1-10]:
        d.line((x,64,x+3,80,x+9,83),fill='#514f40',width=3)
        d.line((x+1,64,x+4,78,x+9,80),fill='#c0b99a')
# Bags on racks.
def bag(x,y,w,h,col):
    d.rounded_rectangle((x,y,x+w,y+h),radius=3,fill='#423b31')
    d.rounded_rectangle((x+2,y+2,x+w-2,y+h-2),radius=2,fill=col)
    for xx in [x+7,x+w-8]:
        d.rectangle((xx,y+1,xx+3,y+h-1),fill='#c1a476');d.rectangle((xx,y+h//2,xx+4,y+h//2+3),fill='#dfc888')
    d.line((x+w//2-6,y,x+w//2-6,y-4,x+w//2+5,y-4,x+w//2+5,y),fill='#554638',width=2)
bag(23,33,55,28,'#7c6650');bag(548,36,42,25,'#67735a')
d.polygon([(593,58),(595,43),(604,38),(618,41),(623,58)],fill='#a4906d')
# Central vintage opal ceiling light and brass plate.
d.rectangle((291,23,350,26),fill='#6d624b');d.rectangle((297,26,344,30),fill='#b7a070')
d.rounded_rectangle((300,29,341,37),radius=4,fill='#eadbb1');d.line((306,30,335,30),fill='#fff0c4',width=2)
# Rear wall details: vent, enamel number, route paper, ashtray and heating grille.
d.rounded_rectangle((27,94,92,107),radius=2,fill='#645e4a')
for x in range(32,88,5):d.line((x,97,x,104),fill='#b0a17e',width=2)
d.rectangle((43,118,78,138),fill='#6e6550');d.rectangle((46,121,75,135),fill='#e2d5b3')
# tiny hand drawn '02' plate
for x in [51,64]:d.rectangle((x,124,x+6,132),outline='#6d634e');
d.rectangle((65,125,68,128),fill='#e2d5b3');d.point((65,130),fill='#e2d5b3')
d.rectangle((547,92,603,143),fill='#6e523b');d.rectangle((550,95,600,140),fill='#ded0aa')
d.rectangle((556,102,594,105),fill='#8e7654')
for yy,ww in [(111,33),(115,28),(119,35),(127,24),(131,31)]:d.line((556,yy,556+ww,yy),fill='#b7a480')
d.rectangle((542,168,605,186),fill='#625d4c');d.line((541,166,607,166),fill='#c7b98d',width=3)
for x in range(29,108,5):d.rectangle((x,192,x+2,214),fill='#594f3d')
# Upholstered benches, padded seams, piping, buttons, armrests and metal legs.
def bench(x,y,w,col,light,shade):
    d.ellipse((x-4,y+64,x+w+14,y+99),fill='#443f35')
    d.rounded_rectangle((x,y,x+w,y+66),radius=10,fill='#3e4437')
    d.rounded_rectangle((x+3,y+2,x+w-3,y+63),radius=9,fill=shade)
    d.rounded_rectangle((x+6,y+4,x+w-6,y+58),radius=8,fill=col)
    d.line((x+10,y+6,x+w-12,y+6),fill=light,width=2)
    for xx in range(x+22,x+w-12,29):
        d.line((xx,y+9,xx,y+55),fill=shade)
        for yy in [y+21,y+43]:
            d.rectangle((xx-2,yy,xx+1,yy+2),fill=shade);d.point((xx,yy),fill=light)
    d.rounded_rectangle((x-3,y+60,x+w+9,y+81),radius=6,fill=shade)
    d.rounded_rectangle((x-1,y+59,x+w+7,y+74),radius=5,fill=col)
    d.line((x+5,y+61,x+w,y+61),fill=light,width=2)
    for xx in [x+6,x+w-12]:
        d.rectangle((xx,y+81,xx+5,y+100),fill='#46473c');d.line((xx+1,y+83,xx+1,y+98),fill='#a89f7d',width=2)
    for xx in [x-6,x+w+1]:
        d.rectangle((xx,y+44,xx+4,y+78),fill='#6d6c52');d.line((xx+1,y+46,xx+1,y+76),fill='#bbb28b')
        d.rounded_rectangle((xx-4,y+41,xx+9,y+48),radius=2,fill='#5c4738');d.line((xx-2,y+42,xx+7,y+42),fill='#bb9564')
bench(216,171,193,'#6c7c65','#9aab88','#4e604f')
bench(-61,155,146,'#8c6050','#b38565','#654b41')
bench(547,155,146,'#8c6050','#b38565','#654b41')
# Small fold-out table, thermos, paper cup, newspaper.
d.polygon([(123,197),(194,197),(210,214),(112,214)],fill='#594737')
d.polygon([(123,194),(194,194),(210,210),(112,210)],fill='#c6a571')
d.line((117,209,205,209),fill='#e0be86',width=2);d.rectangle((156,214,162,256),fill='#655c49')
d.ellipse((150,251,175,257),fill='#49463b')
d.rectangle((137,173,147,196),fill='#728477');d.rectangle((139,173,141,193),fill='#acb6a0');d.rectangle((136,171,148,175),fill='#484d43')
d.polygon([(165,185),(176,185),(174,199),(167,199)],fill='#ead9af');d.line((168,186,174,186),fill='#76634c')
d.polygon([(180,199),(194,197),(202,205),(186,208)],fill='#e1d3ae')
for yy in [201,203,205]:d.line((185,yy,195,yy-1),fill='#a28e69')
# Suitcase: worn leather, double stitching, brass corners, handle, travel label.
bag(359,203,38,31,'#9c6546')
for xx in [363,393]:
    d.line((xx,207,xx,230),fill='#c39466')
d.line((365,207,390,207),fill='#c39466');d.polygon([(374,214),(383,212),(387,222),(378,225)],fill='#ddcba4')
d.line((377,217,382,216),fill='#7f8060');d.line((379,220,384,219),fill='#a28e6b')
for xx in [359,391]:
    for yy in [203,229]:d.rectangle((xx,yy,xx+5,yy+4),fill='#c0a075');d.point((xx+2,yy+2),fill='#ead2a0')
# Subtle pixel shafts of afternoon light (not a blur).
light=Image.new('RGBA',im.size);ld=ImageDraw.Draw(light)
ld.polygon([(161,70),(224,60),(438,269),(365,281)],fill=(250,218,147,14))
ld.polygon([(375,60),(397,61),(566,239),(529,249)],fill=(255,225,165,12))
im=Image.alpha_composite(im,light);save(im,'carriage')
# Seamlessly tiled landscape layers at 768 x 110.
im,d=canvas(768,110,'#c7cbb4')
for y in range(110):d.line((0,y,767,y),fill=['#b4c2b4','#c2cabb','#d2d1b6','#dfd4b1'][min(3,y//25)])
d.ellipse((559,10,580,31),fill='#eee1b5')
for x,y in [(30,17),(270,9),(620,25)]:
    d.rectangle((x,y,x+54,y+4),fill='#dedbc4');d.rectangle((x+10,y-3,x+33,y+7),fill='#dedbc4')
save(im,'sky')
im,d=canvas(768,110,(0,0,0,0))
for shade,base,amp,phase in [('#9ba78e',62,15,1),('#87977b',81,15,2),('#748971',100,8,0)]:
    pts=[(x,int(base+math.sin(x*math.tau/384+phase)*amp+math.sin(x*math.tau/192)*4)) for x in range(769)]
    d.polygon(pts+[(768,110),(0,110)],fill=shade)
save(im,'hills')
im,d=canvas(768,110,(0,0,0,0))
d.polygon([(0,84),(100,76),(222,86),(370,78),(490,86),(610,80),(768,84),(768,110),(0,110)],fill='#b5a16c')
d.polygon([(0,96),(240,89),(390,100),(768,91),(768,110),(0,110)],fill='#8e9b68')
for x in range(0,768,19):d.line((x,104,x+23,108),fill='#b4b075')
for x,y in [(85,74),(388,77),(651,74)]:
    d.rectangle((x,y,x+27,y+19),fill='#d7c69a');d.polygon([(x-5,y+1),(x+12,y-12),(x+33,y+1)],fill='#86604a')
    d.line((x-3,y,x+29,y),fill='#b98358',width=2);d.rectangle((x+21,y-11,x+24,y-4),fill='#6b6250')
    d.rectangle((x+5,y+6,x+10,y+12),fill='#657766');d.rectangle((x+19,y+7,x+23,y+18),fill='#7d7357')
save(im,'fields')
im,d=canvas(768,110,(0,0,0,0))
for x,y in [(10,77),(49,84),(197,80),(240,86),(524,79),(560,82),(713,85)]:
    d.line((x,y-30,x,y+25),fill='#6b664b',width=3)
    for _ in range(65):
        xx=x+rng.randrange(-17,19); yy=y-24+rng.randrange(-15,21)
        d.rectangle((xx,yy,xx+rng.randrange(3,8),yy+rng.randrange(2,6)),fill=rng.choice(['#8d754a','#b28b4e','#c09a58','#9d8b54','#cdac66']))
for x in range(0,768,32):
    d.rectangle((x,100,x+2,109),fill='#a79872');d.line((x,103,x+31,103),fill='#bbab80',width=2)
save(im,'trees')
# Gentle rail ambience: filtered deterministic noise, low wheel hum, rounded joint pulses.
rate=22050; seconds=6; noise=0.; samples=[]
for i in range(rate*seconds):
    t=i/rate
    noise=.94*noise+.06*rng.uniform(-1,1)
    phase=t%0.75
    pulse=sum(math.exp(-((phase-p)/.018)**2) for p in [.06,.19])
    envelope=min(1,t/.05,(seconds-t)/.05)
    value=(.027*math.sin(math.tau*55*t)+.013*math.sin(math.tau*82*t)+.17*noise+.025*pulse*math.sin(math.tau*130*t))*envelope
    samples.append(struct.pack('<h',int(max(-1,min(1,value))*32767)))
with wave.open(str(OUT/'rails.wav'),'wb') as f:
    f.setnchannels(1);f.setsampwidth(2);f.setframerate(rate);f.writeframes(b''.join(samples))
print('Built original train artwork and ambience:',OUT)
