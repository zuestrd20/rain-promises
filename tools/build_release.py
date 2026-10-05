"""Build clean Godot desktop/web packages and matching source ZIP.
Run after story/assets validation. Native smoke tests remain separate.
"""
from pathlib import Path
import subprocess,os,shutil,json,hashlib,zipfile
ROOT=Path(__file__).resolve().parents[1]
OUT=Path(os.environ.get('RAIN_OUTPUT',str(ROOT.parent.parent.parent/'shared/rain_promises_deliverables_r2')))
OUT.mkdir(parents=True,exist_ok=True)
env=os.environ.copy()
# Caller supplies XDG_DATA_HOME pointing at installed official export templates.
for target,file in [('Windows','windows/RainPromises.exe'),('Linux','linux/RainPromises.x86_64'),('Web','web/game.html')]:
 p=ROOT/'builds'/file;p.parent.mkdir(parents=True,exist_ok=True)
 subprocess.run(['godot','--headless','--path',str(ROOT),'--export-release',target,str(p)],check=True,env=env)
web=ROOT/'builds/web'
shutil.copy2(ROOT/'tools/web_index.html',web/'index.html')
shutil.copy2(ROOT/'assets/backgrounds/riverside.jpg',web/'cover.jpg')
for p in ['xia','xu','song']:shutil.copy2(ROOT/f'assets/characters/{p}_standing_smile.webp',web/f'{p}.webp')
source=[]
for f in ROOT.rglob('*'):
 if not f.is_file():continue
 rel=f.relative_to(ROOT)
 if any(x in ['.godot','.git','builds','__pycache__'] for x in rel.parts):continue
 if f.suffix in ['.log','.pyc','.tmp'] or f.name.startswith('.DS_Store'):continue
 source.append(f)
def archive(name,files,base):
 with zipfile.ZipFile(OUT/name,'w',zipfile.ZIP_DEFLATED,compresslevel=6) as z:
  for f in sorted(files):z.write(f,f.relative_to(base))
archive('RainPromises-Source.zip',source,ROOT)
for folder,label in [('windows','Windows'),('linux','Linux'),('web','Web')]:
 files=[f for f in (ROOT/'builds'/folder).rglob('*') if f.is_file() and f.suffix!='.log']
 archive(f'RainPromises-{label}.zip',files,ROOT/'builds'/folder)
manifest={'project':'RainPromises','version':'1.0.1','source_directory':'rain_promises_game_r2','files':[]}
for f in sorted(OUT.glob('*.zip')):manifest['files'].append({'name':f.name,'bytes':f.stat().st_size,'sha256':hashlib.sha256(f.read_bytes()).hexdigest()})
manifest['source_files']={str(f.relative_to(ROOT)):hashlib.sha256(f.read_bytes()).hexdigest() for f in sorted(source)}
(OUT/'release_manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2))
with zipfile.ZipFile(OUT/'RainPromises-Source.zip') as z:
 assert set(z.namelist())==set(manifest['source_files'])
 for name,h in manifest['source_files'].items():assert hashlib.sha256(z.read(name)).hexdigest()==h
print(json.dumps(manifest['files'],indent=2));print('Source ZIP verified against frozen source manifest')
