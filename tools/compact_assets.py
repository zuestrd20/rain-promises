"""Reproducible r2 size optimization. No story, picture dimensions or audio removal.
Requires fonttools. Retains complete original font under provenance/font.
"""
import json,hashlib
from pathlib import Path
from fontTools import subset
from fontTools.ttLib import TTFont
ROOT=Path(__file__).resolve().parents[1]
original=ROOT/'provenance/font/NotoSansCJKtc.otf'
font=TTFont(original);font.recalcTimestamp=False
text=''.join(p.read_text() for p in [ROOT/'data/story.json',ROOT/'scripts/main.gd',ROOT/'project.godot'])
chars=set(map(ord,text))|set(range(32,127))
chars-={9,10,13}
original_cmap=font.getBestCmap();supported=chars&set(original_cmap)
missing=sorted(chars-set(original_cmap))
options=subset.Options();options.name_IDs=['*'];options.name_languages=['*'];options.name_legacy=True
subsetter=subset.Subsetter(options=options);subsetter.populate(unicodes=supported);subsetter.subset(font)
# Rename modified font unconditionally, irrespective of whether a reserved name applies.
names={1:'Rain Promises CJK Subset',2:'Regular',3:'RainPromisesCJKSubset-1.0',4:'Rain Promises CJK Subset',6:'RainPromisesCJKSubset-Regular',16:'Rain Promises CJK Subset',17:'Regular'}
for entry in font['name'].names:
 if entry.nameID in names:entry.string=names[entry.nameID].encode(entry.getEncoding())
if 'CFF ' in font:
 cff=font['CFF '].cff;cff.fontNames=['RainPromisesCJKSubset-Regular']
 top=cff.topDictIndex[0];top.FullName='Rain Promises CJK Subset';top.FamilyName='Rain Promises CJK Subset'
out=ROOT/'assets/fonts/RainPromisesCJKSubset.otf';font.save(out)
check=TTFont(out).getBestCmap();assert supported<=set(check),'Subset dropped needed codepoints'
for folder in ['backgrounds','cg']:
 for f in (ROOT/'assets'/folder).glob('*.jpg.import'):
  s=f.read_text().replace('compress/mode=0','compress/mode=1').replace('compress/lossy_quality=0.7','compress/lossy_quality=0.92');f.write_text(s)
report={'version':'1.0.1','method':'Font subset, renamed modified font; BG/CG Godot lossy texture import quality 0.92. No resolution change. Portrait alpha remains lossless; audio and story unchanged.','font_family':'Rain Promises CJK Subset','font_license':'SIL Open Font License 1.1, retained in assets/fonts/LICENSE.txt; original embedded Adobe copyright retained','original_font_bytes':original.stat().st_size,'subset_font_bytes':out.stat().st_size,'requested_codepoints':len(chars),'retained_supported_codepoints':len(supported),'unsupported_in_original_font':[f'U+{c:04X}' for c in missing],'needed_supported_codepoints_omitted':[],'source_font_sha256':hashlib.sha256(original.read_bytes()).hexdigest(),'subset_sha256':hashlib.sha256(out.read_bytes()).hexdigest(),'story_sha256':hashlib.sha256((ROOT/'data/story.json').read_bytes()).hexdigest()}
(ROOT/'tests/compact_assets_report.json').write_text(json.dumps(report,ensure_ascii=False,indent=2));print(json.dumps(report,ensure_ascii=False,indent=2))
