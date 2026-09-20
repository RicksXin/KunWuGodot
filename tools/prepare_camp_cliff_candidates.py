"""Compile generated cliff material into approved geometry, preserving original sources.
Local deterministic UV normalization and optional periodic seam bands, not new AI artwork.
"""
from pathlib import Path
import json
import numpy as np
from PIL import Image, ImageDraw, ImageFont
ROOT=Path(__file__).resolve().parents[1]
DIR=ROOT/'art/candidates/camp-cliff-tiles/gpt-v1'
SPEC=ROOT/'Docs/Artifacts/camp-tilemap-exploration/cliff-kit'
metadata={'scope':'unapproved material candidate only','tool':'built-in image_gen','meowa_credits':0,'canvas':[144,128],'anchor':[72,40],'sources':{},'processing':'Fit opaque face edges, normalize surface UV into 64x48 material, project into fixed blueprint mask; optional 4-pixel periodic seam bands. Sources unchanged; not uniform scaling of original sprites.'}
def metric(a):
 return {'horizontal_mean_rgb_difference':round(float(np.abs(a[:,0].astype(float)-a[:,-1]).mean()),2),'vertical_mean_rgb_difference':round(float(np.abs(a[0].astype(float)-a[-1]).mean()),2)}
def periodic(a):
 a=a.astype(float)
 for axis in (1,0):
  for i,w in enumerate([0.5,0.3,0.15,0.05]):
   first=[slice(None)]*3;last=first.copy();first[axis]=i;last[axis]=-1-i
   left=a[tuple(first)].copy();right=a[tuple(last)].copy()
   a[tuple(first)]=left*(1-w)+right*w
   a[tuple(last)]=right*(1-w)+left*w
 return np.rint(a).clip(0,255).astype('uint8')
def project(plane,key):
 alpha=np.array(Image.open(SPEC/f'wall_{key}.png').getchannel('A'))
 out=np.zeros((128,144,4),dtype='uint8');a=np.asarray(plane)
 for y,x in zip(*np.where(alpha>0)):
  u=(x+.5-(8 if key=='a' else 72))/64
  top=40+u*32 if key=='a' else 72-u*32
  v=(y+.5-top)/48
  out[y,x,:3]=a[min(47,max(0,int(v*48))),min(63,max(0,int(u*64))),:3]
  out[y,x,3]=255
 return Image.fromarray(out)
for key in ('a','b'):
 source=Image.open(DIR/f'wall-{key}-source.png').convert('RGBA')
 alpha=np.array(source.getchannel('A'));mask=alpha>128;counts=mask.sum(axis=0)
 xs=np.where(counts>counts.max()*.5)[0];l,r=int(xs[0]),int(xs[-1]);cols=np.arange(l+10,r-10)
 top=np.polyfit(cols,np.argmax(mask[:,cols],axis=0),1)
 bottom=np.polyfit(cols,mask.shape[0]-1-np.argmax(mask[::-1,cols],axis=0),1)
 # Inset only the generated bevel/noise; exact outer silhouette comes from the blueprint.
 left,right=l+8,r-8
 quad=(left,float(np.polyval(top,left)+8),left,float(np.polyval(bottom,left)-8),right,float(np.polyval(bottom,right)-8),right,float(np.polyval(top,right)+8))
 surface=source.transform((256,192),Image.Transform.QUAD,quad,Image.Resampling.BICUBIC).resize((64,48),Image.Resampling.LANCZOS)
 assert np.array(surface.getchannel('A')).min()>240,'material fit sampled transparent pixels'
 raw=np.array(surface.convert('RGB'));fixed=periodic(raw)
 Image.fromarray(raw).save(DIR/f'material-{key}-raw.png')
 Image.fromarray(fixed).save(DIR/f'material-{key}-seam.png')
 project(Image.fromarray(raw),key).save(DIR/f'wall-{key}-raw.png')
 compiled=project(Image.fromarray(fixed),key);compiled.save(DIR/f'wall-{key}-compiled.png')
 assert compiled.getchannel('A').tobytes()==Image.open(SPEC/f'wall_{key}.png').getchannel('A').tobytes()
 metadata['sources'][key]={'file':f'wall-{key}-source.png','size':list(source.size),'top_fit':top.tolist(),'bottom_fit':bottom.tolist(),'sample_quad':list(quad),'raw_seams':metric(raw),'repaired_seams':metric(fixed),'blueprint_alpha':'exact match'}
# Corner drafts use the exact same two pieces; texture transition remains visual review.
for name,parts in [('convex',[('a',(0,0)),('b',(0,0))]),('concave',[('b',(-64,-32)),('a',(64,-32))])]:
 canvas=Image.new('RGBA',(144,128))
 for key,offset in parts:canvas.alpha_composite(Image.open(DIR/f'wall-{key}-compiled.png'),offset)
 assert canvas.getchannel('A').tobytes()==Image.open(SPEC/f'{name}.png').getchannel('A').tobytes()
 canvas.save(DIR/f'{name}-draft.png')
metadata['limitations']=['Periodic border equality does not prove natural-looking rock continuity','A/B generated rock patterns resemble masonry more than massive continuous cliff strata','Corner drafts require visual review; rim, foot, end caps and stairs are not generated','Not promoted to assets or installed in game']
(DIR/'validation.json').write_text(json.dumps(metadata,ensure_ascii=False,indent=2)+'\n')
# Contact sheet and repeat proofs, rendered from compiled candidate tiles at integer scale.
board=Image.new('RGB',(1280,940),'#172126');d=ImageDraw.Draw(board)
f=lambda n:ImageFont.truetype(str(ROOT/'assets/fonts/NotoSansSC.ttf'),n)
d.text((30,20),'岩壁 A / B · 美术候选与拼接检查',font=f(28),fill='#f0e9d8')
d.text((30,65),'原图保留；本地投影到固定模板。以下放大 2 倍，未接入运行地图。',font=f(17),fill='#abc0c4')
for i,(name,title) in enumerate([('wall-a-compiled','A 面'),('wall-b-compiled','B 面'),('convex-draft','外转角组合'),('concave-draft','内转角组合')]):
 x=20+i*315;d.text((x+14,110),title,font=f(21),fill='#d8cb9a')
 im=Image.open(DIR/f'{name}.png').resize((288,256),Image.Resampling.NEAREST);board.paste(im,(x,126),im)
def strip(key,repaired,x,y):
 canvas=Image.new('RGBA',(340,250))
 for i in range(3):
  tile=Image.open(DIR/(f'wall-{key}-compiled.png' if repaired else f'wall-{key}-raw.png'))
  canvas.alpha_composite(tile,(i*64,12+i*32))
 canvas=canvas.resize((680,500),Image.Resampling.NEAREST)
 board.paste(canvas,(x,y),canvas)
d.text((32,413),'A 面连续三片：原始适配',font=f(20),fill='#d8cb9a');strip('a',False,15,370)
d.text((682,413),'A 面连续三片：局部接缝处理',font=f(20),fill='#d8cb9a');strip('a',True,660,370)
d.text((30,843),'检查结果：轮廓匹配模板；边缘色差已收敛。岩块仍有重复感，需视觉判断。',font=f(18),fill='#e3ca94')
d.text((30,886),'这组更接近粗石砌壁，尚不能当成整套天然岩壁瓦片的最终美术。',font=f(18),fill='#abc0c4')
board.save(DIR/'candidate-review.png')
print(json.dumps(metadata['sources'],ensure_ascii=False,indent=2))
