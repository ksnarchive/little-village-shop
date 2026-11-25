#!/usr/bin/env python3
"""Large seated illustration layers. Existing numeric appearance IDs are unchanged.
Original painted material-ID masters are separated into tintable skin, hair
and iris plates; garments contain bent knees, resting arms and complete shoes.
"""
from pathlib import Path
from PIL import Image, ImageDraw
ROOT=Path(__file__).resolve().parents[1]; OUT=ROOT/'assets/train'
SZ=(96,144)

def save(im,n):im.save(OUT/('seated_'+n+'.png'),optimize=True)
# Six painted full seated bodies. Lime is a skin material ID, not a game color.
master=Image.open(ROOT/'art/train/seated-garments.png').convert('RGBA')
clothes=Image.new('RGBA',(96,144*6));hands=Image.new('RGBA',(96,144*6))
for variant in range(6):
    cell=master.crop(((variant%3)*512,(variant//3)*512,(variant%3+1)*512,(variant//3+1)*512))
    cp=cell.load();skin=[];solid=[]
    for yy in range(512):
        for xx in range(512):
            r,g,b,a=cp[xx,yy]
            if r>70 and b>70 and r>g*1.8 and b>g*1.8:continue
            solid.append((xx,yy))
            if g>r*1.25 and g>b*1.5 and r>b*1.3:skin.append((xx,yy))
    # Grow the lime material through its yellow-green highlights, while the
    # dark stitched garment edge prevents the flood from reaching olive cloth.
    skin_set=set(skin);todo=list(skin)
    while todo:
        xx,yy=todo.pop()
        for nx,ny in [(xx-1,yy),(xx+1,yy),(xx,yy-1),(xx,yy+1)]:
            if not (0<=nx<512 and 0<=ny<512) or (nx,ny) in skin_set:continue
            r,g,b,a=cp[nx,ny]
            if g>=r*.98 and g>b*1.7 and r-b>20:
                skin_set.add((nx,ny));todo.append((nx,ny))
    skin=list(skin_set)
    top=min(y for x,y in skin);neck=[(x,y) for x,y in skin if y<top+30]
    neck_x=sum(x for x,y in neck)/len(neck);bottom=max(y for x,y in solid)
    scale=91/(bottom-top);tx=60-neck_x*scale;ty=52-top*scale
    cloth=Image.new('RGBA',(512,512));flesh=Image.new('RGBA',(512,512));dp=cloth.load();sp=flesh.load()
    for xx,yy in solid:
        r,g,b,a=cp[xx,yy]
        if (xx,yy) in skin_set:
            v=min(255,round(g*1.05));sp[xx,yy]=(v,v,v,255)
        else:dp[xx,yy]=(r,g,b,255)
    for src,dst in [(cloth,clothes),(flesh,hands)]:
        im=Image.new('RGBA',SZ);im.alpha_composite(src.resize((round(512*scale),round(512*scale)),Image.Resampling.NEAREST),(round(tx),round(ty)))
        dst.alpha_composite(im,(0,144*variant))
save(clothes,'clothes');save(hands,'hands')
# Authored portrait heads use cyan skin / silver hair / red irises as material
# masks. Align each portrait by the visible iris, preserving all eight stable IDs.
master=Image.open(ROOT/'art/train/portrait-heads.png').convert('RGBA')
atlases={n:Image.new('RGBA',(96,144*(16 if n=='eyes' else 8))) for n in ['head','hair','face','lids','eyes']}
for variant in range(8):
    cell=master.crop(((variant%4)*384,(variant//4)*512,(variant%4+1)*384,(variant//4+1)*512))
    cp=cell.load();red=set()
    for yy in range(512):
        for xx in range(384):
            r,g,b,a=cp[xx,yy]
            if r>90 and r>g*1.6 and b<r*.65:red.add((xx,yy))
    components=[]
    while red:
        start=red.pop();todo=[start];points=[start]
        while todo:
            xx,yy=todo.pop()
            for neighbor in [(xx-1,yy),(xx+1,yy),(xx,yy-1),(xx,yy+1)]:
                if neighbor in red:red.remove(neighbor);todo.append(neighbor);points.append(neighbor)
        if len(points)>8:components.append(points)
    components.sort(key=len,reverse=True)
    primary=components[0]; eye_x=sum(x for x,y in primary)/len(primary);eye_y=sum(y for x,y in primary)/len(primary)
    scale=.185;tx=44-eye_x*scale;ty=31-eye_y*scale
    layers={n:Image.new('RGBA',(384,512)) for n in atlases if n!='eyes'}
    iris=Image.new('RGBA',(384,512));eyes=[]
    for component in components[:2]:
        x0=min(x for x,y in component);x1=max(x for x,y in component);y0=min(y for x,y in component);y1=max(y for x,y in component)
        eyes.append((x0-12,y0-4,x1+15,y1+5))
    lp={n:im.load() for n,im in layers.items()};ip=iris.load()
    for yy in range(512):
        for xx in range(384):
            r,g,b,a=cp[xx,yy]
            if r>70 and b>70 and r>g*1.8 and b>g*1.8:continue
            in_eye=any(x0<=xx<=x1 and y0<=yy<=y1 for x0,y0,x1,y1 in eyes)
            is_skin=b>r*1.18 and g>r*1.16
            is_iris=r>90 and r>g*1.6 and b<r*.65
            if is_skin:
                v=max(r,g,b);lp['head'][xx,yy]=(v,v,v,255)
            elif is_iris:
                v=max(110,r);ip[xx,yy]=(v,v,v,255)
            elif in_eye:
                # Sclera and lashes retain their painted values, independent of hair tint.
                lp['face'][xx,yy]=(r,g,b,255)
            else:
                v=round((r+g+b)/3);lp['hair'][xx,yy]=(v,v,v,255)
    def positioned(im):
        dst=Image.new('RGBA',SZ);im=im.resize((round(384*scale),round(512*scale)),Image.Resampling.NEAREST)
        dst.alpha_composite(im,(round(tx),round(ty)));return dst
    for n,im in layers.items():
        if n!='lids':atlases[n].alpha_composite(positioned(im),(0,variant*144))
    atlases['eyes'].alpha_composite(positioned(iris),(0,variant*288))
    lids=Image.new('RGBA',SZ);ld=ImageDraw.Draw(lids);closed=Image.new('RGBA',SZ);cd=ImageDraw.Draw(closed)
    for x0,y0,x1,y1 in eyes:
        a=round(x0*scale+tx);b=round(y0*scale+ty);c=round(x1*scale+tx);e=round(y1*scale+ty)
        ld.ellipse((a-1,b-1,c+1,e+1),fill='#bdbdbd')
        cd.line((a,b+3,(a+c)//2,e-1,c,b+3),fill='#777777',width=1)
    atlases['lids'].alpha_composite(lids,(0,variant*144));atlases['eyes'].alpha_composite(closed,(0,variant*288+144))
for n,im in atlases.items():save(im,n)
print('Prepared 8 shaded portrait heads, isolated skin/hair/iris colors, 6 full seated outfits and blink plates.')
