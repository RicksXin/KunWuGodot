"""Deterministic cliff tile SPECIFICATION diagrams, not generated game art.
Run with Python + Pillow. Coordinates are continuous boundaries; PNG uses half-open pixels.
"""
from pathlib import Path
import json
from PIL import Image, ImageDraw, ImageFont
ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT/'Docs/Artifacts/camp-tilemap-exploration/cliff-kit'
OUT.mkdir(parents=True,exist_ok=True)
FONT = str(ROOT/'assets/fonts/NotoSansSC.ttf')
def font(n): return ImageFont.truetype(FONT,n)
A=[(-64,0),(0,32),(0,80),(-64,48)]
B=[(64,0),(0,32),(0,80),(64,48)]
def shift(poly,dx,dy):return [(x+dx,y+dy) for x,y in poly]
# Convex front corner and concave rear corner are replacements for two edge pieces.
outer=[A,B]
inner=[shift(B,-64,-32),shift(A,64,-32)]
rim_a=[(-64,-6),(0,26),(0,32),(-64,0)]
rim_b=[(64,-6),(0,26),(0,32),(64,0)]
foot_a=[(-64,44),(0,76),(0,80),(-64,48)]
foot_b=[(64,44),(0,76),(0,80),(64,48)]
modules=[('wall_a','立面 A',[A]),('wall_b','立面 B',[B]),('convex','外转角',outer),('concave','内转角',inner),('rim_a','崖顶 A',[rim_a]),('rim_b','崖顶 B',[rim_b]),('foot_a','崖脚 A',[foot_a]),('foot_b','崖脚 B',[foot_b])]
colors=['#b4a16e','#768f91']
# All transport cells have 8px padding around a logical 128x112 footprint.
canvas=(144,128);anchor=(72,40)
atlas=Image.new('RGBA',(576,256))
for i,(_,_,polys) in enumerate(modules):
 tile=Image.new('RGBA',canvas);draw=ImageDraw.Draw(tile)
 # Pixel-center test gives disjoint ownership on shared mathematical edges.
 def inside(x,y,poly):
  hit=False;j=len(poly)-1
  for k,(px,py) in enumerate(poly):
   qx,qy=poly[j]
   if (py>y)!=(qy>y) and x < (qx-px)*(y-py)/(qy-py)+px:hit=not hit
   j=k
  return hit
 for n,poly in enumerate(polys):
  color=colors[1-n if i==3 else n%2] if len(polys)>1 else colors[1 if i in (1,5,7) else 0]
  for y in range(canvas[1]):
   for x in range(canvas[0]):
    if inside(x+.5-anchor[0],y+.5-anchor[1],poly):draw.point((x,y),fill=color)
 atlas.alpha_composite(tile,((i%4)*144,(i//4)*128))
 tile.save(OUT/(modules[i][0]+'.png'))
atlas.save(OUT/'blueprint-atlas.png')
manifest={'status':'technical blueprint only; no approved art','projection':{'tile':[128,64],'axes':[[64,32],[-64,32]],'height_step':48},'atlas':{'file':'blueprint-atlas.png','size':[576,256],'region':[144,128],'anchor':list(anchor),'padding':8,'godot_texture_origin':[0,-24]},'modules':[{'id':id,'title':title,'region':[i%4,i//4],'polygons':polys} for i,(id,title,polys) in enumerate(modules)],'rules':{'stack_delta':[0,-48],'horizontal_a_delta':[64,32],'horizontal_b_delta':[-64,32],'corner_replaces_edges':True,'rim_foot_only_at_extremes':True}}
(OUT/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n')
# Validate alpha shape composition, real raster repeat joints, and stacking against a single face.
def compose(parts,alpha_only=True):
 out=Image.new('RGBA',(512,384))
 for id,offset in parts:
  im=Image.open(OUT/(id+'.png'))
  out.alpha_composite(im,(int(180+offset[0]-anchor[0]),int(150+offset[1]-anchor[1])))
 return out.getchannel('A') if alpha_only else out
def reference(polys):
 im=Image.new('L',(512,384))
 for y in range(384):
  for x in range(512):
   if any(inside(x+.5-180,y+.5-150,p) for p in polys):im.putpixel((x,y),255)
 return im
checks={}
def check(name,parts,poly):
 actual=compose(parts);expected=reference(poly)
 assert actual.tobytes()==expected.tobytes(),name
 checks[name]='PASS pixel-exact alpha union'
check('A consecutive segments',[('wall_a',(0,0)),('wall_a',(64,32))],[[(-64,0),(64,64),(64,112),(-64,48)]])
check('B consecutive segments',[('wall_b',(0,0)),('wall_b',(-64,32))],[[(64,0),(-64,64),(-64,112),(64,48)]])
check('48+48 stacked A',[('wall_a',(0,0)),('wall_a',(0,-48))],[[(-64,-48),(0,-16),(0,80),(-64,48)]])
check('convex replacement',[('wall_a',(0,0)),('wall_b',(0,0))],outer)
check('concave replacement',[('wall_b',(-64,-32)),('wall_a',(64,-32))],inner)
assert compose([('convex',(0,0))]).tobytes()==reference(outer).tobytes()
assert compose([('concave',(0,0))]).tobytes()==reference(inner).tobytes()
assert compose([('convex',(0,0))],False).tobytes()==compose([('wall_a',(0,0)),('wall_b',(0,0))],False).tobytes()
assert compose([('concave',(0,0))],False).tobytes()==compose([('wall_b',(-64,-32)),('wall_a',(64,-32))],False).tobytes()
(OUT/'validation.json').write_text(json.dumps({'checks':checks,'additional':['convex/concave atlas alpha equals two-face assembly','convex/concave RGBA preserves orientation colors'],'limits':'Geometry and alpha only; does not validate future artwork color/texture seams or runtime collision.'},indent=2)+'\n')
# Technical contact sheet, deliberate false colors and explicit anchors.
board=Image.new('RGB',(1440,1050),'#172126');d=ImageDraw.Draw(board)
d.text((36,22),'岩壁瓦片 · 拼接规格样板',font=font(32),fill='#eceddf')
d.text((36, 70),'地面格 128×64 · 高差 48 · 运输单元 144×128（含留边） · 十字为统一锚点',font=font(18),fill='#abbfc2')
for i,(_,title,polys) in enumerate(modules):
 x=36+(i%4)*348;y=114+(i//4)*238
 d.rounded_rectangle((x,y,x+332,y+220),8,fill='#202f36',outline='#3b5058')
 d.text((x+14,y+12),f'{i+1:02d}  {title}',font=font(21),fill='#f1e7c5')
 im=Image.open(OUT/(modules[i][0]+'.png')).resize((216,192),Image.Resampling.NEAREST)
 board.paste(im,(x+64,y+27),im)
 ax=x+64+anchor[0]*1.5;ay=y+27+anchor[1]*1.5
 d.line((ax-5,ay,ax+5,ay),fill='#ff7066',width=2);d.line((ax,ay-5,ax,ay+5),fill='#ff7066',width=2)
d.text((36,612),'组合检查：整块台地、凹形台地、双层叠高',font=font(24),fill='#eceddf')
def plateau(cells,height,origin,scale=0.58):
 assembly=Image.new("RGBA",(640,400));ad=ImageDraw.Draw(assembly)
 def point(p):return (round(320+p[0]),round(96+p[1]))
 def project(x,y):return ((x-y)*64,(x+y)*32)
 # Render wall faces directly from identical atlas polygons with face-specific placement.
 edges=[]
 for x,y in cells:
  cx,cy=project(x,y)
  if (x,y+1) not in cells:edges.append((cx,cy,'wall_a'))
  if (x+1,y) not in cells:edges.append((cx,cy,'wall_b'))
 for cx,cy,id in sorted(edges,key=lambda e:e[1]):
  for level in range(height//48):
   tile=Image.open(OUT/(id+'.png'))
   loc=point((cx-anchor[0],cy-anchor[1]-48*level))
   assembly.alpha_composite(tile,loc)
 for x,y in sorted(cells,key=lambda c:sum(c)):
  cx,cy=project(x,y)
  top=[point((cx,cy-32-height+48)),point((cx+64,cy-height+48)),point((cx,cy+32-height+48)),point((cx-64,cy-height+48))]
  ad.polygon(top,fill='#455c52',outline='#879986')
 assembly=assembly.resize((round(640*scale),round(400*scale)),Image.Resampling.NEAREST)
 board.paste(assembly,(round(origin[0]-320*scale),round(origin[1]-96*scale)),assembly)
plateau({(x,y) for x in range(3) for y in range(3)},48,(236,734))
plateau({(x,y) for x in range(3) for y in range(3)}-{(2,2)},48,(707,734))
plateau({(x,y) for x in range(3) for y in range(3)},96,(1181,760))
for x,title in [(82,'A / B 立面在前角相接'),(552,'凹口使用内转角接口'),(1040,'中段重复；崖脚只放一次')]:d.text((x,906),title,font=font(18),fill='#bdced0')
d.text((36,966),'这是几何与接口样板，不是岩石美术。转角替换对应直段，不能重叠铺两套完整岩壁。',font=font(19),fill='#e5c887')
d.text((36,1000),'已检查：同向连续拼接 / 双层叠高 / 外角 / 内角的逐像素透明轮廓；纹理接缝待美术阶段检查。',font=font(17),fill='#abbfc2')
board.save(OUT/'spec-board.png')
print('PASS:',len(checks)+4,'geometry/alpha checks; wrote atlas, manifest, individual templates and spec-board.png')
