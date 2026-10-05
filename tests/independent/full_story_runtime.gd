extends SceneTree
var game: Control
var failures: Array=[]
var checks=0
var tested_paths: Array=[]
func ck(ok: bool, label: String) -> void:
	checks+=1
	if not ok:failures.append(label);printerr("FAIL "+label)
func _initialize() -> void:call_deferred("run")
func play(w: Dictionary, expected_ending: String) -> void:
	game._new_game()
	var path=w.path
	for i in range(path.size()-1):
		ck(game.current_id==path[i],"node mismatch "+str(path[i]))
		if game.current_id!=path[i]:return
		var n: Dictionary=game.nodes[game.current_id]
		game.cooldown=0;game.reveal=100000;game.body_label.visible_characters=-1;game.choices_box.visible=true
		if n.has("choices"):
			var chosen=false
			for index in n.choices.size():
				if n.choices[index].next==path[i+1] and game._meets(n.choices[index].get("requires",{})):
					game._choose(index);chosen=true;break
			ck(chosen,"legal choice "+str(path[i]))
		else:game._advance()
	ck(game.nodes[game.current_id].get("ending","")==expected_ending,"reach ending "+expected_ending)
	for p in ["xia","xu","song"]:ck(int(game.state.affection[p])==int(w.affection.get(p,0)),"route affection exact "+expected_ending+" "+p)
	for flag in w.flags:ck(flag in game.state.flags,"route flag "+str(flag))
	for col in w.collections:ck(col in game.state.collections and game.profile.collections.has(col),"route collection "+str(col))
	game._save(2);var before=game.state.duplicate(true);game._load_slot(2);ck(game.state==before,"save load ending "+expected_ending)
	game._show_node(game.current_id,false);ck(game.state==before,"rerender ending exact state "+expected_ending)
	game._ending();ck(is_instance_valid(game.modal),"ending modal "+expected_ending);game._close_modal()
	tested_paths.append({"ending":expected_ending,"nodes":path.size()})
func run() -> void:
	game=load("res://main.tscn").instantiate();root.add_child(game);await process_frame;game.set_process(false)
	var paths=JSON.parse_string(FileAccess.get_file_as_string("res://tests/independent/independent_witnesses.json"))
	for e in paths:play(paths[e],e)
	var collections=JSON.parse_string(FileAccess.get_file_as_string("res://tests/independent/collection_witnesses.json"))
	for c in collections:
		var w=collections[c];var end=game.nodes[w.path[-1]].ending;play(w,end);ck(game.profile.collections.has(c),"collection witness "+c)
	ck(game.profile.endings.size()==7,"all 7 ending profile unlocks")
	ck(game.profile.collections.size()==8,"all 8 collection profile unlocks")
	game._save_profile();var saved=game._read_json("user://profile.json")
	ck(saved.endings.size()==7 and saved.collections.size()==8,"unlock profile persisted to disk")
	game._new_game();ck(game.profile.endings.size()==7 and game.profile.collections.size()==8,"new game preserves ending and collection unlocks")
	var texture_counts={"portraits":0,"backgrounds":0,"cg":0}
	for p in game.art.characters:
		for key in game.art.characters[p]:ck(game._texture(game.art.characters[p][key])!=null,"load portrait "+p+" "+key);texture_counts.portraits+=1
	var unique_bg={}
	for bg in game.art.backgrounds:
		var path=game.art.backgrounds[bg];ck(game._texture(path)!=null,"load background "+bg);unique_bg[path]=true
	texture_counts.backgrounds=unique_bg.size()
	for cg in game.art.cg:ck(game._texture(game.art.cg[cg])!=null,"load CG "+cg);texture_counts.cg+=1
	var actual_portraits={};var actual_cgs={}
	for id in game.nodes:
		var n=game.nodes[id]
		if n.get("cg"):
			if not actual_cgs.has(n.cg):game._show_node(id);ck(game.cg_image.visible and game.cg_image.texture!=null and not game.portrait.visible and not game.scene_bg.visible,"CG shown with plain matte "+n.cg);actual_cgs[n.cg]=true
		elif n.get("character"):
			var key=n.character+"/"+n.pose+"_"+n.expression
			if not actual_portraits.has(key):game._show_node(id);ck(game.portrait.visible and game.portrait.texture!=null and not game.cg_image.visible and game.scene_bg.visible,"portrait and background shown "+key);actual_portraits[key]=true
	ck(actual_portraits.size()==27 and actual_cgs.size()==6,"runtime shows 27 portraits and 6 CGs")
	game._journal();game._close_modal();game._gallery();game._close_modal();game._show_title();ck(game.scene_bg.visible,"title restores background after CG")
	var report={"pass":failures.is_empty(),"checks":checks,"failures":failures,"paths":tested_paths,"textures_loaded":texture_counts,"actual_portrait_states_shown":actual_portraits.size(),"actual_cgs_shown":actual_cgs.size(),"engine":Engine.get_version_info().string,"limitation":"Headless engine test; texture loaded and UI visibility asserted, not GPU visual rendering."}
	var f=FileAccess.open("res://tests/independent/full_story_runtime_report.json",FileAccess.WRITE);f.store_string(JSON.stringify(report,"  "));f.close();print(JSON.stringify(report));game._stop_audio();await create_timer(.25).timeout;quit(0 if failures.is_empty() else 1)
