"""Use extraction alpha with approved RGB; uniform scale and explicit foot anchor."""
from pathlib import Path
import json
from PIL import Image
ROOT=Path(__file__).resolve().parents[1]
source=ROOT/'art/candidates/camp-council-isometric/gpt-v2-plaque/council.png'
mask=ROOT/'art/candidates/camp-council-isometric/gpt-v3-alpha/extracted.png'
im=Image.open(source).convert('RGBA'); alpha=Image.open(mask).getchannel('A')
assert im.size==alpha.size
alpha=alpha.point(lambda a: 255 if a>=245 else (0 if a<12 else round(a*255/245)))
im.putalpha(alpha)
out=ROOT/'assets/prototypes/camp_council';out.mkdir(parents=True,exist_ok=True)
# Width of stone foundation in source is about1240 px; target256. No nonuniform warp.
size=(317,211);scaled=im.resize(size,Image.Resampling.LANCZOS)
canvas=Image.new('RGBA',(336,240));canvas.alpha_composite(scaled,(0,12));canvas.save(out/'council.png')
(out/'SOURCE.json').write_text(json.dumps({'source':str(source.relative_to(ROOT)),'alpha_source':str(mask.relative_to(ROOT)),'approved_visual':'GPT building with 议事殿 plaque','method':'Approved RGB plus extracted alpha; uniform downscale and padding','canvas':[336,240],'anchor':[182,216],'source_anchor_estimate':[880,990],'source_size':list(im.size),'scaled_size':list(size),'scope':'Camp prototype only; authored blockers remain unchanged','note':'Hand-painted building reduced for prototype; text readability at native scale is limited.'},ensure_ascii=False,indent=2)+'\n')
