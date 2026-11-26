#!/usr/bin/env python3
"""Import the original generated atlas as independent reusable outdoor resources.
Only crop, alpha cleanup, nearest sampling and baked shadows; no game-time painting.
"""
from pathlib import Path
from PIL import Image, ImageOps, ImageFilter
import math, random, struct, wave
ROOT=Path(__file__).resolve().parents[1]
im=Image.open(ROOT/'art/station/outdoor-atlas.png').convert('RGBA')
OUT=ROOT/'assets/outdoors';OUT.mkdir(exist_ok=True)
items=[('station',(224,180)),('gold_tree',(132,164)),('red_tree',(140,162)),('carriage',(320,166)),
       ('bench',(82,54)),('lamp',(36,112)),('timetable',(76,104)),('sign',(52,86)),
       ('grass',(96,96)),('path',(64,64)),('track',(128,80)),('platform',(64,64)),
       ('shrub',(66,50)),('fence',(96,46)),('pots',(44,44)),('leaves',(48,48))]
for i,(name,size) in enumerate(items):
    x,y=i%4,i//4
    cell=im.crop((round(x*im.width/4),round(y*im.height/4),round((x+1)*im.width/4),round((y+1)*im.height/4)))
    if y==2:
        cell=cell.convert('RGB').convert('RGBA')
        # Mirrored texture edges repeat without an obvious seam.
        tile=cell.resize((size[0]//2,size[1]//2),Image.Resampling.NEAREST)
        cell=Image.new('RGBA',size);cell.paste(tile,(0,0));cell.paste(ImageOps.mirror(tile),(size[0]//2,0))
        cell.paste(ImageOps.flip(cell.crop((0,0,size[0],size[1]//2))),(0,size[1]//2))
        # Rails must stay parallel: use the unmirrored complete rail pair.
        if name=='track':cell=im.crop((round(x*im.width/4),round(y*im.height/4),round((x+1)*im.width/4),round((y+1)*im.height/4))).convert('RGB').convert('RGBA').resize(size,Image.Resampling.NEAREST)
    else:
        alpha=cell.getchannel('A').point(lambda a:255 if a>=220 else 0)
        cell.putalpha(alpha);cell=cell.crop(cell.getbbox())
        cell=cell.resize(size,Image.Resampling.NEAREST)
    alpha=cell.getchannel('A');cell=cell.convert('RGB').quantize(colors=128,dither=Image.Dither.NONE).convert('RGBA');cell.putalpha(alpha)
    cell.save(OUT/(name+'.png'),optimize=True)
    if name in ['gold_tree','red_tree']:
        shadow=Image.new('RGBA',(150,42),(40,35,31,0))
        mask=cell.getchannel('A').resize((130,30),Image.Resampling.NEAREST).filter(ImageFilter.GaussianBlur(3)).point(lambda a:round(a*.24))
        shadow.paste((40,35,31,0),(0,0,150,42));shadow.putalpha(ImageOps.expand(mask,(10,6,10,6)))
        shadow.save(OUT/(name+'_shadow.png'),optimize=True)
# One leaf cut from the original isolated-leaf cell, used for ten calm sprites.
leaf=Image.open(OUT/'leaves.png').crop((5,3,23,21)).resize((9,9),Image.Resampling.NEAREST)
leaf.save(OUT/'leaf.png')
# Original quiet wind and birds, prepared once; all playback uses the existing master bus.
rng=random.Random(17);rate=22050;duration=8
with wave.open(str(ROOT/'assets/station/nature.wav'),'wb') as out:
    out.setnchannels(1);out.setsampwidth(2);out.setframerate(rate)
    smooth=0.;data=bytearray()
    for n in range(rate*duration):
        t=n/rate;smooth=.985*smooth+.015*rng.uniform(-1,1)
        wind=smooth*.25*(.65+.35*math.sin(t*math.tau/duration))
        bird=0.
        for start in [1.4,1.68,5.3,5.55]:
            age=t-start
            if 0<=age<.16:bird+=.022*math.sin(math.tau*(2400*age+1000*age*age))*math.sin(math.pi*age/.16)**2
        # Smooth loop seam.
        envelope=min(1,t/.15,(duration-t)/.15)
        data.extend(struct.pack('<h',int(max(-1,min(1,(wind+bird)*envelope))*32767)))
    out.writeframes(data)
print('Prepared 16 outdoor modules, two baked shadows, leaf and quiet nature loop.')
