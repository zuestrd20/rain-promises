import json, pathlib, collections, hashlib, sys, os
sys.setrecursionlimit(10000)
ROOT=pathlib.Path(__file__).resolve().parents[2]; OUT=pathlib.Path(__file__).resolve().parent
STORY=pathlib.Path(os.environ.get('STORY_FILE',str(ROOT/'data/story.json')));s=json.loads(STORY.read_text()); n=s['nodes']; art=json.loads((ROOT/'data/art.json').read_text()); reached=set(); cols=set(); portraits=set(); bgs=set(); cgs=set(); music=set(); endings={}; witnesses={}; collection_witnesses={}; errors=[]; branches=collections.Counter(); choices_used=collections.Counter(); visits=0
han=lambda t:sum('\u4e00'<=c<='\u9fff' for c in t)
def meets(r,a,f):return all(x in f for x in r.get('flags_all',[])) and all(a.get(p,0)>=v for p,v in r.get('affection_min',{}).items())
def effects(e,a,f,c):
 a=a.copy()
 for p,v in e.get('affection',{}).items():a[p]=a.get(p,0)+v
 return a,f|set(e.get('flags',[])),c|set(e.get('collect',[]))
def walk(k,a,f,c,path,chars,h,choice_count,chosen_chars):
 global visits
 visits+=1
 if k in path:raise RuntimeError('cycle '+k)
 x=n[k];reached.add(k);path=path+[k];chars+=len(x['text']);h+=han(x['text']);a,f,c=effects(x.get('effects',{}),a,f,c);cols.update(c);bgs.add(x['bg']);music.add(x['music'])
 if x.get('character') and not x.get('cg'):portraits.add((x['character'],x['pose']+'_'+x['expression']))
 if x.get('cg'):cgs.add(x['cg'])
 if 'ending'in x:
  e=x['ending'];w={'path':path,'chars':chars,'han':h,'choices':choice_count,'chosen_choice_chars':chosen_chars,'collections':sorted(c),'affection':a,'flags':sorted(f)}
  witnesses.setdefault(e,w)
  for col in c:collection_witnesses.setdefault(col,w)
  r=endings.setdefault(e,{'paths':0,'min_prose_unicode':chars,'max_prose_unicode':chars,'min_prose_han':h,'max_prose_han':h,'min_nodes':len(path),'max_nodes':len(path),'fast_estimate_minutes':1e9,'leisurely_estimate_minutes':0})
  r['paths']+=1
  for key,val in [('prose_unicode',chars),('prose_han',h),('nodes',len(path))]:r['min_'+key]=min(r['min_'+key],val);r['max_'+key]=max(r['max_'+key],val)
  r['fast_estimate_minutes']=min(r['fast_estimate_minutes'],h/500+len(path)*.025+choice_count*.25)
  r['leisurely_estimate_minutes']=max(r['leisurely_estimate_minutes'],h/300+len(path)*.025+choice_count*.25)
  return
 if 'choices'in x:
  for i,ch in enumerate(x['choices']):
   if meets(ch.get('requires',{}),a,f):
    choices_used[(k,i)]+=1;aa,ff,cc=effects(ch.get('effects',{}),a,f,c);walk(ch['next'],aa,ff,cc,path,chars,h,choice_count+1,chosen_chars+len(ch['text']))
 elif 'branches'in x:
  for i,b in enumerate(x['branches']):
   if meets(b.get('requires',{}),a,f):branches[(k,i)]+=1;walk(b['next'],a,f,c,path,chars,h,choice_count,chosen_chars);break
 else:walk(x['next'],a,f,c,path,chars,h,choice_count,chosen_chars)
walk(s['start'],{},set(),set(),[],0,0,0,0)
for k,x in n.items():
 if len(x['text'])>220:errors.append('text length '+k)
 if sum(key in x for key in ['next','choices','branches','ending'])!=1:errors.append('routing mode '+k)
 if 'branches'in x and x['branches'][-1].get('requires'):errors.append('no fallback '+k)
 if 'choices'in x and not any(not c.get('requires') for c in x['choices']):errors.append('no choice fallback '+k)
if reached!=set(n):errors.append('unreachable nodes '+str(sorted(set(n)-reached)))
if set(endings)!=set(s['endings']) or len(endings)!=7:errors.append('ending reachability')
if cols!=set(s['collectibles']) or len(cols)!=8:errors.append('collectible reachability')
used_files=set()
for p,key in portraits:used_files.add(art['characters'][p][key])
for bg in bgs:used_files.add(art['backgrounds'][bg])
for cg in cgs:used_files.add(art['cg'][cg])
for file in used_files:
 if not (ROOT/file.removeprefix('res://')).is_file():errors.append('missing asset '+file)
if len(portraits)!=27:errors.append('portrait actual visible coverage '+str(len(portraits)))
if len({art['backgrounds'][k] for k in bgs})!=6:errors.append('background coverage')
if len(cgs)!=6:errors.append('CG coverage')
report={'pass':not errors,'errors':errors,'story_sha256':hashlib.sha256(STORY.read_bytes()).hexdigest(),'nodes':len(n),'reachable_nodes':len(reached),'expanded_node_visits_no_state_merging':visits,'complete_legal_paths':sum(r['paths'] for r in endings.values()),'endings':endings,'collectibles_reachable':sorted(cols),'visible_portraits':sorted([list(p) for p in portraits]),'background_keys':sorted(bgs),'unique_background_files':sorted({art['backgrounds'][k] for k in bgs}),'visible_cgs':sorted(cgs),'music_keys':sorted(music),'branch_edges_exercised':len(branches),'choice_edges_exercised':len(choices_used),'all_assets_present':not any(e.startswith('missing asset') for e in errors),'reading_estimate':'Per legal complete path: actual node prose Han count / 500 or 300 per minute + .025 minutes per node + .25 per choice. Does not sum mutually exclusive branches. Estimate, not measured play time; excludes optional gallery/backlog and displayed unchosen options.'}
for r in endings.values():
 for k in ['fast_estimate_minutes','leisurely_estimate_minutes']:r[k]=round(r[k],1)
(OUT/'independent_story_report.json').write_text(json.dumps(report,ensure_ascii=False,indent=2));(OUT/'collection_witnesses.json').write_text(json.dumps(collection_witnesses,ensure_ascii=False,indent=2));(OUT/'witness_flat.json').write_text(json.dumps({e:w['path'] for e,w in witnesses.items()},ensure_ascii=False));(OUT/'independent_witnesses.json').write_text(json.dumps(witnesses,ensure_ascii=False,indent=2));print(json.dumps(report,ensure_ascii=False,indent=2));sys.exit(bool(errors))
