"""Exhaustive legal-state reachability, assets and realistic reading-time audit."""
import json,collections,sys,hashlib
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
story=json.loads((ROOT/'data/story.json').read_text());nodes=story['nodes'];art=json.loads((ROOT/'data/art.json').read_text())
people=['xia','xu','song'];errors=[]
def check(ok,msg):
 if not ok:errors.append(msg)
def meets(req,a,f):return all(x in f for x in req.get('flags_all',[])) and all(a[people.index(k)]>=v for k,v in req.get('affection_min',{}).items())
def effects(e,a,f,c):
 a=list(a)
 for p,v in e.get('affection',{}).items():a[people.index(p)]+=v
 return tuple(a),f|frozenset(e.get('flags',[])),c|frozenset(e.get('collect',[]))
for id,n in nodes.items():
 check(len(n['text'])<=220,f'{id}: text exceeds 220')
 check(sum(k in n for k in ['next','choices','branches','ending'])==1,f'{id}: invalid routing')
 for k in ['bg','speaker','text','character','expression','pose','music']:check(k in n,f'{id}: missing {k}')
 if n.get('character'):
  key=n['pose']+'_'+n['expression'];check(key in art['characters'].get(n['character'],{}),f'{id}: missing {n["character"]}/{key}')
 check(n['bg'] in art['backgrounds'],f'{id}: missing BG {n["bg"]}')
 if n.get('cg'):check(n['cg'] in art['cg'],f'{id}: missing CG {n["cg"]}')
 if 'branches' in n:check('requires' not in n['branches'][-1],f'{id}: no branch fallback')
 if 'choices' in n:check(any(not c.get('requires') for c in n['choices']),f'{id}: choices without fallback')
 for c in n.get('choices',[])+n.get('branches',[]):check(c['next'] in nodes,f'{id}: dangling target')
 if 'next' in n:check(n['next'] in nodes,f'{id}: dangling next')
# DAG check.
visiting=set();visited=set()
def dfs(id):
 if id in visiting:raise ValueError(f'cycle at {id}')
 if id in visited:return
 visiting.add(id);n=nodes[id]
 for t in ([n['next']] if 'next'in n else [])+[c['next'] for c in n.get('choices',[])+n.get('branches',[])]:dfs(t)
 visiting.remove(id);visited.add(id)
dfs(story['start'])
# Exact state search; merge only equivalent state keys, preserve legal witness paths.
queue=collections.deque([(story['start'],(0,0,0),frozenset(),frozenset(),[],0)])
seen=set();paths={};routes={};reached=set();max_states=1000000
while queue:
 id,a,f,c,path,chars=queue.popleft();n=nodes[id];a,f,c=effects(n.get('effects',{}),a,f,c)
 key=(id,a,f,c)
 if key in seen:continue
 seen.add(key);reached.add(id);path=path+[id];chars+=len(n['text'])
 if len(seen)>max_states:raise RuntimeError('State space too large; no truncation permitted')
 if 'ending'in n:
  eid=n['ending'];paths.setdefault(eid,path);r=routes.setdefault(eid,{'min_chars':chars,'max_chars':chars,'min_nodes':len(path),'max_nodes':len(path)})
  r['min_chars']=min(r['min_chars'],chars);r['max_chars']=max(r['max_chars'],chars);r['min_nodes']=min(r['min_nodes'],len(path));r['max_nodes']=max(r['max_nodes'],len(path));continue
 if 'choices'in n:
  for choice in n['choices']:
   if meets(choice.get('requires',{}),a,f):
    aa,ff,cc=effects(choice.get('effects',{}),a,f,c);queue.append((choice['next'],aa,ff,cc,path,chars+len(choice['text'])))
 elif 'branches'in n:
  for branch in n['branches']:
   if meets(branch.get('requires',{}),a,f):queue.append((branch['next'],a,f,c,path,chars));break
 else:queue.append((n['next'],a,f,c,path,chars))
check(set(paths)==set(story['endings']),f'Unreachable endings: {set(story["endings"])-set(paths)}')
check(len(paths)==7,'Expected seven endings');check(len(story['collectibles'])==8,'Expected eight collections')
coverage={p:sorted({n['pose']+'_'+n['expression'] for n in nodes.values() if n.get('character')==p})for p in people}
for p,keys in coverage.items():check(len(keys)==9,f'{p} uses {len(keys)}/9 pose expressions')
cgs=sorted({n['cg'] for n in nodes.values() if n.get('cg')});check(len(cgs)==6,'Expected six story CGs')
for r in routes.values():r['estimated_minutes_250_to_450_chars_per_min']=[round(r['min_chars']/450,1),round(r['max_chars']/250,1)]
report={'pass':not errors,'errors':errors,'nodes':len(nodes),'legal_states':len(seen),'reachable_nodes':len(reached),'endings':len(paths),'total_story_chars':sum(len(n['text'])for n in nodes.values()),'routes':routes,'pose_expression_coverage':coverage,'cg_used':cgs,'background_keys_used':sorted({n['bg']for n in nodes.values()}),'reading_estimate_method':'Visible Unicode characters / 250–450 characters per minute; choices and pauses add time. State-equivalent merged paths may omit alternative path length extremes.'}
(ROOT/'tests/story_report.json').write_text(json.dumps(report,ensure_ascii=False,indent=2));(ROOT/'tests/ending_paths.json').write_text(json.dumps(paths,ensure_ascii=False,indent=2));print(json.dumps(report,ensure_ascii=False,indent=2));sys.exit(bool(errors))
