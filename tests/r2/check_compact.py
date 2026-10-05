from pathlib import Path
import json,hashlib,os
from fontTools.ttLib import TTFont
from fontTools.pens.recordingPen import RecordingPen
P=Path(__file__).resolve().parent;R=P.parents[1];O=Path(os.environ['RAIN_R1_SOURCE'])
h=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
paths=[Path('data/story.json'),Path('data/art.json')]+[p.relative_to(R) for folder,ext in [('characters','webp'),('backgrounds','jpg'),('cg','jpg'),('audio','ogg')] for p in (R/'assets'/folder).glob('*.'+ext)]
changed=[str(p) for p in paths if h(R/p)!=h(O/p)]
original=TTFont(R/'provenance/font/NotoSansCJKtc.otf');subset=TTFont(R/'assets/fonts/RainPromisesCJKSubset.otf');oc=original.getBestCmap();sc=subset.getBestCmap();chars=set(map(ord,''.join((R/p).read_text() for p in ['data/story.json','scripts/main.gd','project.godot'])))|set(range(32,127));chars-={9,10,13}
missing=sorted(chars-set(sc));og=original.getGlyphSet();sg=subset.getGlyphSet();different=[]
for c in chars:
 if c in oc and c in sc:
  a=RecordingPen();b=RecordingPen();og[oc[c]].draw(a);sg[sc[c]].draw(b)
  if a.value!=b.value:different.append(c)
names={str(i):sorted({n.toUnicode() for n in subset['name'].names if n.nameID==i}) for i in [1,2,3,4,6,16,17]};cff=subset['CFF '].cff
imports=[]
for folder in ['backgrounds','cg']:
 for f in (R/'assets'/folder).glob('*.jpg.import'):
  t=f.read_text();imports.append({'file':str(f.relative_to(R)),'quality92':'compress/lossy_quality=0.92' in t,'lossy_mode':'compress/mode=1' in t})
report={'pass':not changed and not missing and not different and len(paths)==49 and all(x['quality92'] and x['lossy_mode'] for x in imports),'content_files_compared':len(paths),'changed_content':changed,'font_codepoints_required':len(chars),'missing_subset_codepoints':missing,'glyph_outlines_different_from_original':different,'font_names':names,'CFF_font_names':cff.fontNames,'CFF_full_name':cff.topDictIndex[0].FullName,'CFF_family_name':cff.topDictIndex[0].FamilyName,'full_original_font_matches_r1':h(R/'provenance/font/NotoSansCJKtc.otf')==h(O/'assets/fonts/NotoSansCJKtc.otf'),'OFL_preserved':(R/'assets/fonts/LICENSE.txt').exists(),'copyright_name_table_preserved':{n.toUnicode() for n in original['name'].names if n.nameID==0}<={n.toUnicode() for n in subset['name'].names if n.nameID==0},'texture_imports':imports,'main_sha256':h(R/'scripts/main.gd'),'story_sha256':h(R/'data/story.json')}
(P/'independent_compact_report.json').write_text(json.dumps(report,ensure_ascii=False,indent=2));print(json.dumps(report,ensure_ascii=False))
