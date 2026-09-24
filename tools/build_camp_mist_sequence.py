"""Bake a periodic code-native mist field into a real RGBA sprite atlas."""
from pathlib import Path
import numpy as np
from PIL import Image
ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'resources/prototypes/camp_mist_sequence'
W,H,N = 512,192,96
u,v = np.meshgrid(np.linspace(0,1,W),np.linspace(0,1,H))
rng = np.random.default_rng(924)
waves = [(rng.integers(1,9),rng.integers(-5,6),rng.uniform(0,2*np.pi),rng.uniform(.25,1)) for _ in range(32)]
def cloud_field(x,y,t):
    field = np.zeros((H,W))
    for kx,ky,phase,weight in waves:
        field += np.sin(2*np.pi*(kx*(3*x-t)+ky*y)+phase)*weight/(kx+abs(ky))**.7
    return np.clip(.5 + field*.12,0,1)
def frame(t):
    cloud = cloud_field(u,v,t)
    rise = np.clip(v/.55,0,1)
    feather = rise*rise*(3-2*rise)
    alpha = np.clip(feather*(.95+.10*cloud),0,.99)
    rgba = np.zeros((H,W,4),dtype=np.uint8)
    for c,base in enumerate([64,82,91]):rgba[:,:,c] = base+cloud*12
    rgba[:,:,3] = np.rint(alpha*255)
    return rgba
frames=[frame(i/N) for i in range(N)]
assert np.array_equal(frame(0),frame(1))
assert all(not np.any(f[0,:,3]) and np.min(f[-1,:,3]) >= 240 and np.array_equal(f[:,0],f[:,-1]) for f in frames)
atlas=Image.new('RGBA',(W*8,H*((N+7)//8)))
for i,f in enumerate(frames):atlas.paste(Image.fromarray(f),(i%8*W,i//8*H))
atlas.save(OUT/'sheet.png')
lines=['[gd_resource type="SpriteFrames" format=3]','','[ext_resource type="Texture2D" path="res://resources/prototypes/camp_mist_sequence/sheet.png" id="1"]','']
for i in range(N):lines += [f'[sub_resource type="AtlasTexture" id="F{i}"]','atlas = ExtResource("1")',f'region = Rect2({i%8*W}, {i//8*H}, {W}, {H})','filter_clip = true','']
lines += ['[resource]','animations = [{','"frames": ['+', '.join('{"duration": 1.0, "texture": SubResource("F%d")}'%i for i in range(N))+'],','"loop": true,','"name": &"default",','"speed": 12.0','}]']
(OUT/'frames.tres').write_text('\n'.join(lines)+'\n')
preview=[]
for f in frames:
 bg=Image.new('RGBA',(W,H),(28,43,51,255));bg.alpha_composite(Image.fromarray(f));preview.append(bg.convert('RGB'))
preview[0].save(ROOT/'art/candidates/camp-mist-v1/sequence.webp',save_all=True,append_images=preview[1:],duration=83,loop=0)
assert np.allclose(cloud_field(u+0.1/3,v,0.1),cloud_field(u,v,0))
means=np.array([f[:,:,3].mean() for f in frames])
assert np.ptp(means)/means.mean() < .03
print('PASS 96 frames/12fps/8s; coherent rightward transport, fixed envelope, density variation %.2f%%; clear upper edge, dense lower edge, seamless horizontal tiling, exact loop' % (100*np.ptp(means)/means.mean()))
