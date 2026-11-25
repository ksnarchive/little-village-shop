#!/usr/bin/env python3
"""Prepare original raster paintings for the train. Authoring only: Python + Pillow.
Masters in art/train are deliberately outside Godot's resource import/export.
Does not change the original rail audio, character IDs or story data.
"""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter
import math
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'assets/train'
SRC=ROOT/'art/train'
OUT.mkdir(exist_ok=True)
NEAREST=Image.Resampling.NEAREST

def key_magenta(im):
    im=im.convert('RGBA'); p=im.load()
    for y in range(im.height):
        for x in range(im.width):
            r,g,b,a=p[x,y]
            if r>70 and b>70 and r>g*1.8 and b>g*1.8:
                p[x,y]=(0,0,0,0)
    return im

def save(im,name): im.save(OUT/name,optimize=True)

def limited_palette(im):
    alpha=im.getchannel('A')
    rgb=im.convert('RGB').quantize(colors=256,dither=Image.Dither.NONE).convert('RGBA')
    rgb.putalpha(alpha)
    return rgb

for name,sz,curtains in [
 ('carriage',(640,360),[[(0,0),(133,0),(111,67),(82,119),(44,143),(62,225),(0,232)],[(354,51),(407,78),(423,227),(382,237),(370,162)]]),
 ('carriage_portrait',(400,600),[[(0,14),(65,29),(58,111),(25,179),(35,323),(0,330)],[(177,102),(226,120),(239,301),(217,302),(202,222)]])]:
    source=Image.open(SRC/('compartment-portrait.png' if 'portrait' in name else 'compartment-landscape.png')).convert('RGBA')
    room=limited_palette(key_magenta(source.resize(sz,NEAREST)))
    save(room,name+'.png')
    # Baked one-pixel cloth deformation: three complete rasters, zero per-pixel
    # runtime work, and the moving fabric retains its correct window cutout.
    mask=Image.new('L',sz); md=ImageDraw.Draw(mask)
    for polygon in curtains: md.polygon(polygon,fill=255)
    for frame,phase in [(1,-1),(2,1)]:
        dst=room.copy(); dp=dst.load(); rp=room.load(); mp=mask.load()
        for y in range(sz[1]):
            for x in range(sz[0]):
                if mp[x,y] and y>30:
                    dx=round(phase*math.sin(y*.018)*min(1,y/110))
                    dp[x,y]=rp[max(0,min(sz[0]-1,x+dx)),y]
        save(dst,name+f'_{frame}.png')
    # Bright paint is lifted into a tiny, low-opacity moving light plate.
    sun=Image.new('RGBA',sz); sp=sun.load(); rp=room.load()
    for y in range(int(sz[1]*.42),sz[1]):
        for x in range(sz[0]):
            r,g,b,a=rp[x,y]
            if a and r>180 and g>95 and r>g*1.2 and g>b*1.5:
                sp[x,y]=(255,206,112,min(36,max(0,(r+g-280)//5)))
    save(sun,name+'_light.png')

sheet=Image.open(SRC/'autumn-layers.png').convert('RGBA')
for i,name in enumerate(['sky','hills','fields','trees']):
    strip=sheet.crop((0,i*256,1536,(i+1)*256)).resize((768,128),NEAREST)
    if i: strip=key_magenta(strip)
    strip=limited_palette(strip)
    tile=Image.new('RGBA',(1536,128))
    tile.paste(strip,(0,0));tile.paste(strip.transpose(Image.Transpose.FLIP_LEFT_RIGHT),(768,0))
    save(tile,name+'.png')
# A painterly little steam atlas: two thin tapering curls, rising/fading calmly.
steam=Image.new('RGBA',(48*12,64))
for frame in range(12):
    layer=Image.new('RGBA',(48,64));d=ImageDraw.Draw(layer)
    for strand in range(2):
        for step in range(42):
            y=59-step
            fade=math.sin(math.pi*step/43)**.8
            x=24+math.sin(step*.19+frame*math.tau/12+strand*2.1)*(3+step*.075)+strand*3
            d.ellipse((round(x),y,round(x)+1,y+2),fill=(250,233,202,int(fade*54)))
    steam.alpha_composite(layer,(48*frame,0))
save(steam,'steam.png')
print('Prepared two painted compositions, cloth/light plates, seamless scenery and steam atlas.')
