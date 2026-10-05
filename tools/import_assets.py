"""Import generated photographs without changing identity, pose or expression.
Usage: python tools/import_assets.py ART_DIRECTORY AUDIO_DIRECTORY
"""
import json,sys,shutil
from pathlib import Path
from PIL import Image
ROOT=Path(__file__).resolve().parents[1]
source=Path(sys.argv[1]); audio=Path(sys.argv[2]) if len(sys.argv)>2 else None
art={'characters':{},'backgrounds':{},'cg':{},'aliases':{'rooftop':'riverside','hospital_exterior':'station'}}
for person in ['xia','xu','song']:
 art['characters'][person]={}
 for pose,exprs in {'standing':['neutral','smile','thoughtful'],'seated':['neutral','smile','sad'],'action':['neutral','surprised','determined']}.items():
  for expr in exprs:
   key=f'{pose}_{expr}'; files=list((source/person).rglob(f'{person}_{key}.png'))
   if not files: continue
   dest=ROOT/'assets/characters'/f'{person}_{key}.webp';dest.parent.mkdir(exist_ok=True,parents=True)
   Image.open(files[0]).save(dest,'WEBP',lossless=True,method=6)
   art['characters'][person][key]='res://'+str(dest.relative_to(ROOT))
for key in ['museum','riverside','workshop','cafe','station','gallery']:
 files=[p for p in source.rglob('*') if p.is_file() and p.suffix.lower() in ['.png','.jpg','.webp'] and p.stem in [key,f'bg_{key}']]
 if files:
  dest=ROOT/'assets/backgrounds'/f'{key}.jpg';im=Image.open(files[0]).convert('RGB');im.thumbnail((1600,1000));im.save(dest,quality=90,optimize=True)
  art['backgrounds'][key]='res://'+str(dest.relative_to(ROOT))
for key in ['xia_museum','xia_rooftop','xu_workshop','xu_cafe','song_station','song_rooftop']:
 files=[p for p in source.rglob('*') if p.is_file() and p.suffix.lower() in ['.png','.jpg','.webp'] and p.stem in [key,f'cg_{key}']]
 if files:
  dest=ROOT/'assets/cg'/f'{key}.jpg';im=Image.open(files[0]).convert('RGB');im.thumbnail((1600,1000));im.save(dest,quality=92,optimize=True)
  art['cg'][key]='res://'+str(dest.relative_to(ROOT))
for alias,target in art['aliases'].items():
 if target in art['backgrounds']:art['backgrounds'][alias]=art['backgrounds'][target]
(ROOT/'data/art.json').write_text(json.dumps(art,ensure_ascii=False,indent=2))
if audio and audio.exists():
 for f in audio.glob('*.ogg'):shutil.copy2(f,ROOT/'assets/audio'/f.name)
print(json.dumps({k:len(v) for k,v in art.items()}))
