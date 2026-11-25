#!/usr/bin/env python3
"""Prepare original painted shop modules. Does not generate characters or goods.
Pillow is authoring-only. Masters in art/shop are excluded from Godot imports.
Furniture dimensions and stock display origins match the existing interactables.
"""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter, ImageOps
import math
ROOT=Path(__file__).resolve().parents[1]; SRC=ROOT/'art/shop'; OUT=ROOT/'assets/shop'; MOD=OUT/'modular'
MOD.mkdir(parents=True,exist_ok=True)
NN=Image.Resampling.NEAREST

def keyed(im):
    im=im.convert('RGBA');p=im.load()
    for y in range(im.height):
        for x in range(im.width):
            r,g,b,a=p[x,y]
            if r>65 and b>65 and r>g*1.8 and b>g*1.8:p[x,y]=(0,0,0,0)
    return im

def palette(im):
    a=im.getchannel('A');rgb=im.convert('RGB').quantize(colors=192,dither=Image.Dither.NONE).convert('RGBA');rgb.putalpha(a);return rgb

def save(im,name):im.save(OUT/name,optimize=True)

def fit_cell(sheet,col,row,size,box=None):
    cw=sheet.width//3;ch=sheet.height//2
    im=keyed(sheet.crop(box or (col*cw,row*ch,(col+1)*cw,(row+1)*ch)))
    bbox=im.getbbox();im=im.crop(bbox)
    # Fill the existing footprint, leaving one-pixel breathing room for the edge.
    im=palette(im.resize((size[0]-2,size[1]-3),NN))
    result=Image.new('RGBA',size);result.alpha_composite(im,(1,1));return result

materials=Image.open(SRC/'materials.png').convert('RGBA');q=materials.width//2
for col,row,name in [(0,0,'floor'),(1,0,'wallpaper'),(0,1,'plaster'),(1,1,'wainscot')]:
    tile=palette(materials.crop((col*q,row*q,(col+1)*q,(row+1)*q)).resize((128,128),NN))
    # Mirrored continuation closes the tile seam without a runtime shader.
    whole=Image.new('RGBA',(256,256));whole.paste(tile,(0,0));whole.paste(ImageOps.mirror(tile),(128,0));whole.paste(ImageOps.flip(whole.crop((0,0,256,128))),(0,128))
    save(whole,'modular/'+name+'.png')
    if name=='wainscot':
        save(tile.resize((128,32),NN),'modular/baseboard.png')
        save(tile.crop((0,0,16,128)),'modular/post.png')

sheet=Image.open(SRC/'furniture.png')
for col,row,name,size in [(0,0,'shelf',(64,56)),(1,0,'pantry',(64,56)),(2,0,'storage',(64,40)),(0,1,'order_desk',(48,40)),(1,1,'checkout',(64,36)),(2,1,'modular/cabinet',(48,64))]:
    save(fit_cell(sheet,col,row,size),name+'.png')
sheet=Image.open(SRC/'decor.png')
for name,size,box in [('wide_window',(124,40),(0,130,590,490)),('side_window',(48,94),(646,20,958,523)),('clutter',(46,40),(1025,100,1536,522)),('radio_ledge',(48,30),(6,550,498,954)),('rug',(68,36),(510,590,1025,983)),('plaster_damage',(40,44),(1030,580,1512,975))]:
    save(fit_cell(sheet,0,0,size,box),'modular/'+name+'.png')
# Reusable wall contact shade. Pixel-quantized soft alpha, no runtime lights.
im=Image.new('RGBA',(128,16));p=im.load()
for y in range(16):
    a=round((1-y/15)**1.8*76/4)*4
    for x in range(128):p[x,y]=(39,24,27,a)
save(im,'modular/wall_shadow.png')
# Window-shaped sunlight plate, reusable and independent from the floor.
size=(176,144);mask=Image.new('L',size);d=ImageDraw.Draw(mask)
d.polygon([(0,5),(18,0),(159,127),(150,143)],fill=65)
d.polygon([(23,0),(43,0),(176,103),(176,129)],fill=58)
d.polygon([(47,0),(60,0),(176,82),(176,98)],fill=45)
mask=mask.filter(ImageFilter.GaussianBlur(2));mask=mask.point(lambda v:round(v/5)*5)
im=Image.new('RGBA',size,'#f6d47d');im.putalpha(mask);save(im,'modular/sunlight.png')
# Small floor wear decal: translucent dust ring lifted from the painted plaster,
# only the very faint grain survives; it never presents an apparent obstacle.
dust=Image.open(MOD/'plaster.png').crop((0,0,64,64));alpha=Image.new('L',(64,64));ap=alpha.load()
for y in range(64):
    for x in range(64):
        falloff=max(0,1-((x-32)/30)**2-((y-32)/25)**2)
        ap[x,y]=round(falloff*(8+2*math.sin(x*.2+y*.13)))
dust.putalpha(alpha);save(dust,'modular/dust.png')
# Keep the existing notebook binding and all nine-patch margins; recolor only
# the shop's copy so the wardrobe, train and frontend keep their original frame.
paper=Image.open(ROOT/'assets/ui/panel.png').convert('RGBA')
paper_colors={
    (233,223,200):(243,228,197), (128,96,75):(148,81,58),
    (197,178,140):(213,165,105), (213,198,168):(224,201,162),
    (213,203,178):(232,213,179), (183,121,95):(176,109,69),
    (81,72,63):(87,49,46), (178,172,160):(183,150,110),
}
for y in range(paper.height):
    for x in range(paper.width):
        pixel=paper.getpixel((x,y))
        paper.putpixel((x,y),(*paper_colors.get(pixel[:3],pixel[:3]),pixel[3]))
paper.save(ROOT/'assets/ui/shop_panel.png',optimize=True)
print('Prepared independent floor/walls, five interactive sprites, decor and lighting modules.')
