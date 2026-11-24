"""Make a static OFL Pixelify Sans derivative with complete Russian capitals.
Optional authoring dependencies: fonttools. Source and OFL license in assets/fonts.
Upstream cmap omits Cyrillic О and П. О reuses Latin O; П is hand-drawn to Н metrics.
"""
from pathlib import Path
from fontTools.ttLib import TTFont
from fontTools.varLib.instancer import instantiateVariableFont
from fontTools.pens.ttGlyphPen import TTGlyphPen
root=Path(__file__).resolve().parents[1]/'assets/fonts'
f=instantiateVariableFont(TTFont(root/'PixelifySans.ttf'),{'wght':400},inplace=False)
order=f.getGlyphOrder()[:]
pen=TTGlyphPen(None)
pen.moveTo((60,-12))
for point in [(60,631),(525,631),(525,-12),(423,-12),(423,531),(161,531),(161,-12)]: pen.lineTo(point)
pen.closePath()
name='villagePe'
f['glyf'][name]=pen.glyph(); f['hmtx'][name]=(586,60); f.setGlyphOrder(order+[name])
latin_o=f.getBestCmap()[ord('O')]
for table in f['cmap'].tables:
    if table.isUnicode(): table.cmap[0x41f]=name; table.cmap[0x41e]=latin_o
for record in f['name'].names:
    if record.nameID in [1,3,4,6,16]:
        record.string=('VillagePixel-Regular' if record.nameID==6 else 'Village Pixel').encode(record.getEncoding())
f.save(root/'VillagePixel-Regular.ttf')
assert all(i in f.getBestCmap() for i in [*range(0x410,0x450),0x401,0x451])
print('Built Village Pixel: all Russian letters covered, static 400 weight.')
