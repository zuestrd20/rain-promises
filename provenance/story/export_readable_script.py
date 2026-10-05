import json,pathlib
P=pathlib.Path(__file__).parent
S=json.loads((P/'story.json').read_text());scenes=json.loads((P/'scene_manifest.json').read_text());N=S['nodes']
lines=['# 雨停之前的約定｜完整分支劇本','','全角色成年。姜予澤為第一人稱男主，不使用男主肖像。以下依共通、夏以寧、許芷禾、宋若安與單人篇章列出完整正文；互斥分岔與不同結局不會在同一輪依序播放。','','正文、分支與演出資料以 story.json 為遊戲實際來源。閱讀長度與可達性另見 validation_report.md。','']
for scene in scenes:
 sid=scene['id'];nodes=[(k,v) for k,v in N.items() if k.rsplit('_',1)[0]==sid]
 lines+=['## '+scene['title'],'',f"場景索引：{sid}。背景：{N[scene['start']]['bg']}。配樂：{N[scene['start']]['music']}。",'']
 for k,n in nodes:
  if n.get('cg'):lines+=['〔完整畫面：'+n['cg']+'〕','']
  if n['speaker']=='姜予澤':lines+=[n['text'],'']
  else:lines+=[n['speaker']+'：'+n['text'],'']
  for c in n.get('choices',[]):lines+=['- 選擇：'+c['text']+' → '+c['next']]
  if n.get('choices'):lines.append('')
  if 'branches' in n:
   for br in n['branches']:
    req=br.get('requires',{}).get('flags_all',[])
    lines+=['- 後續分支：'+('已完成 '+', '.join(req) if req else '其他情況')+' → '+br['next']]
   lines.append('')
  if 'ending' in n:lines+=['〔結局：'+S['endings'][n['ending']]['title']+'〕','']
lines+=['## 第二層主題選擇','']
for c in N['route_choose_pair']['choices']:lines+=['- '+c['text']+' → '+c['next']]
lines+=['','## 八張照片與說明卡','']
for k,v in S['collectibles'].items():lines+=['- '+v['title']+'：'+v['description']]
(P/'full_script.md').write_text('\n'.join(lines))
print('Exported full_script.md')
