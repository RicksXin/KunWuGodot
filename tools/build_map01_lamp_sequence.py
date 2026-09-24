"""Deterministic candidate assembly: fixed stone, localized cyclic energy flow."""
from pathlib import Path
import math
import numpy as np
from PIL import Image
ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'art/candidates/map01-formation-lamp'
source = Image.open(OUT / 'source_states.png').convert('RGBA')
frames = []
y, x = np.mgrid[:384, :256]
for state in range(2):
    if state == 0:
        crop = source.crop((52,26,731,998))
    else:
        repaired = Image.open(OUT / 'source_repaired_states.png').convert('RGBA')
        crop = repaired.crop((768+34,21,768+721,1001))
    crop = crop.resize((224,320),Image.Resampling.LANCZOS)
    base = Image.new('RGBA',(256,384))
    base.paste(crop,(16,30))
    a = np.array(base).astype(float)
    # Clean invisible RGB, preserve the model's real antialiased alpha.
    a[a[:,:,3]<8] = 0
    base = Image.fromarray(a.astype('uint8'))
    base.save(OUT / ('active.png' if state else 'broken.png'))
    rgb = a[:,:,:3]
    warm = np.clip((rgb[:,:,0]-rgb[:,:,2]-12)/65,0,1)
    core = np.exp(-((x-129)/17)**4-((y-179)/24)**4)
    runes = (((x>68)&(x<83))|((x>178)&(x<190))) & (y>158)&(y<218)
    mask = np.maximum(core, runes*warm)
    for n in range(8):
        phase = n*math.tau/8
        # Periodic local sampling bends the energy core while the stone stays fixed.
        displacement = np.rint(1.5*np.sin(phase+(y-160)*.13)*core).astype(int)
        sample = a[y,np.clip(x+displacement,0,255)].copy()
        flow = np.sin(phase+(y-160)*.18)
        gain = (0.16 if state else 0.23)*flow*mask
        sample[:,:,:3] *= 1+gain[:,:,None]
        if not state:
            sample[:,:,0] += (7+7*flow)*core
        sample[:,:,3] = a[:,:,3]
        sample[a[:,:,3]==0]=0
        frame = Image.fromarray(np.clip(sample,0,255).astype('uint8'))
        frames.append(frame)
# A two-second repair sweep, built from the approved endpoints without new art.
for n in range(16):
    if n == 0:
        frames.append(frames[0].copy())
        continue
    if n == 15:
        frames.append(frames[8].copy())
        continue
    t = n/15
    edge = 400-450*t
    mix = np.clip((y-edge)/70+.5,0,1)
    mix = mix*mix*(3-2*mix)
    before = np.array(frames[n%8]).astype(float)/255
    after = np.array(frames[8+n%8]).astype(float)/255
    weight = mix[:,:,None]
    alpha = before[:,:,3:]*(1-weight)+after[:,:,3:]*weight
    premult = before[:,:,:3]*before[:,:,3:]*(1-weight)+after[:,:,:3]*after[:,:,3:]*weight
    rgb = np.divide(premult,alpha,out=np.zeros_like(premult),where=alpha>0)
    glow = np.exp(-((y-edge)/23)**2)*math.sin(math.pi*t)*.28
    rgb += glow[:,:,None]*np.array([1,.75,.32])
    rgb[alpha[:,:,0]==0] = 0
    frames.append(Image.fromarray(np.clip(np.concatenate([rgb,alpha],axis=2)*255,0,255).astype('uint8')))
atlas = Image.new('RGBA',(2048,1536))
for i, frame in enumerate(frames): atlas.paste(frame,((i%8)*256,(i//8)*384))
atlas.save(OUT / 'formation_lamp_states.png')
runtime = ROOT / 'assets/maps/map_01/formation_lamp'
runtime.mkdir(parents=True,exist_ok=True)
atlas.save(runtime / 'formation_lamp_states.png')
# One atlas, two named frame ranges.
lines = ['[gd_resource type="SpriteFrames" load_steps=34 format=3]', '', '[ext_resource type="Texture2D" path="res://assets/maps/map_01/formation_lamp/formation_lamp_states.png" id="1"]']
for i in range(32):
    lines += ['',f'[sub_resource type="AtlasTexture" id="Frame_{i}"]','atlas = ExtResource("1")',f'region = Rect2({i%8*256}, {i//8*384}, 256, 384)']
lines += ['','[resource]','animations = [{']
for state, name in enumerate(['broken','active','repair']):
    if state: lines += ['}, {']
    entries = ', '.join('{"duration": 1.0, "texture": SubResource("Frame_%d")}'%i for i in range(state*8,32 if state==2 else state*8+8))
    lines += [f'"frames": [{entries}],','"loop": '+('false' if state==2 else 'true')+',',f'"name": &"{name}",','"speed": 8.0']
lines += ['}]']
(runtime/'formation_lamp_frames.tres').write_text('\n'.join(lines)+'\n')
# Animated side-by-side review, deliberately outside runtime assets.
previews=[]
for i in range(8):
    bg=Image.new('RGBA',(544,416),'#273339')
    bg.alpha_composite(frames[i],(8,16));bg.alpha_composite(frames[i+8],(280,16))
    previews.append(bg.convert('RGB'))
previews[0].save(OUT/'states_preview.gif',save_all=True,append_images=previews[1:],duration=125,loop=0)
repair_preview=[]
for frame in frames[:8]+frames[16:]+frames[8:16]*2:
    bg=Image.new('RGBA',(288,416),'#273339')
    bg.alpha_composite(frame,(16,16))
    repair_preview.append(bg.convert('RGB'))
repair_preview[0].save(OUT/'repair_preview.gif',save_all=True,append_images=repair_preview[1:],duration=125,loop=0)
assert frames[16].tobytes()==frames[0].tobytes()
assert frames[31].tobytes()==frames[8].tobytes()
# Regression properties: actual movement, fixed alpha/stone, no clipped edges.
for state in range(2):
    items=[np.array(f) for f in frames[state*8:state*8+8]]
    assert len({f.tobytes() for f in items})==8
    for f in items:
        assert np.array_equal(f[:,:,3],items[0][:,:,3])
        assert np.array_equal(f[:120],items[0][:120])
        assert np.array_equal(f[240:],items[0][240:])
        assert not f[:12,:,3].any() and not f[-12:,:,3].any()
    diffs=[np.abs(items[i].astype(float)-items[(i+1)%8]).mean() for i in range(8)]
    assert max(diffs)<2*min(diffs), diffs
print('PASS: 16 distinct frames, fixed stone/alpha/anchor, periodic seam; 2048x1536 RGBA, plus 16 repair frames')
