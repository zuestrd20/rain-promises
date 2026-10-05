extends SceneTree
var game: Control
var failures: Array=[]
var checks: Array=[]
func ck(ok: bool, label: String) -> void:
	checks.append({"name":label,"pass":ok})
	if not ok: failures.append(label)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	game=load("res://main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game._new_game()
	var fixture={"text":"測試一個段落。","speaker":"QA","bg":"riverside","character":null,"expression":"neutral","pose":"standing","music":"city","effects":{"affection":{"xia":5},"flags":["qa_flag"]},"next":"qa_next"}
	game.nodes["qa_effect"]=fixture
	game.nodes["qa_next"]={"text":"下一頁。","speaker":"QA","bg":"cafe","character":null,"expression":"neutral","pose":"standing","music":"warm","next":"qa_effect"}
	game._show_node("qa_effect")
	ck(game.state.affection.xia==5 and "qa_flag" in game.state.flags,"node effects apply first entry")
	var st=game.state.duplicate(true)
	game._show_node("qa_effect",false)
	ck(game.state==st,"repeat render does not replay nonzero node effect")
	game._save(3);game._load_slot(3)
	ck(game.state==st,"save/load does not replay nonzero node effect")
	ck(game._meets({"flags_all":["qa_flag"],"affection_min":{"xia":5}}),"requires flags and affection threshold inclusive")
	ck(not game._meets({"flags_all":["missing"]}) and not game._meets({"affection_min":{"xia":6}}),"requires rejects missing flag and low affection")
	fixture.erase("next");fixture["branches"]=[{"requires":{"flags_all":["missing"]},"next":"qa_effect"},{"next":"qa_next"}]
	game.cooldown=0;game.body_label.visible_characters=-1;game._advance()
	ck(game.current_id=="qa_next","branches choose legal fallback")
	fixture.erase("branches");fixture["choices"]=[{"text":"hidden","next":"qa_next","requires":{"flags_all":["missing"]}},{"text":"open","next":"qa_next","effects":{"affection":{"xu":3},"flags":["qa_choice"]}}]
	game._show_node("qa_effect",false);game.cooldown=0;game.choices_box.visible=true
	ck(game.visible_choices==[1],"unmet choices hidden and keyboard index mapped")
	game._choose(0);ck(game.current_id=="qa_effect","programmatic illegal choice rejected")
	game._choose(1);ck(game.current_id=="qa_next" and game.state.affection.xu==3 and "qa_choice" in game.state.flags,"legal choice applies affection and flags")
	game._choose(1);ck(game.state.affection.xu==3,"repeated choice during cooldown cannot duplicate effects")
	game.auto_mode=true;game._settings();var before=game.state.duplicate(true);var reveal=game.reveal
	game._process(100);game._advance();game._choose(0)
	ck(game.state==before and game.reveal==reveal,"auto mode and all progression pause inside modal")
	game._close_modal();game._close_modal();ck(not is_instance_valid(game.modal),"double modal close safe")
	game._advance();ck(game.state==before,"modal close debounce")
	game.profile.read.erase(game.current_id);game.was_read=false;game.skip_mode=true;game.auto_mode=false;game._process(.1)
	ck(not game.skip_mode and game.current_id=="qa_next","read-only skip stops on unread")
	game.was_read=true;game.skip_mode=true;game.cooldown=0;game.elapsed=0;game._process(.2);game._process(.2)
	ck(game.current_id=="qa_effect","read-only skip advances already read node")
	game.skip_mode=false;game.auto_mode=true;game.cooldown=0;game.reveal=10000;game._process(100)
	ck(game.current_id=="qa_effect","auto mode pauses on choices")
	game._save(3);var good=game._read_json("user://slot_3.json")
	ck(game._valid_save(good),"valid save accepted")
	for bad in [null,[],{},42,"broken",{"version":1,"game":"rain-promises","state":game.state},{"version":2,"game":"wrong-game","state":game.state}]: ck(not game._valid_save(bad),"malformed/version/game save rejected: "+str(bad).left(90))
	for field in ["node","affection","history","visited","collections","flags"]:
		var bad=good.duplicate(true);bad.state[field]=null;ck(not game._valid_save(bad),"invalid field rejected "+field)
	var bad=good.duplicate(true);bad.state.affection.xia="bad";ck(not game._valid_save(bad),"invalid affection type rejected")
	var prev=game.state.duplicate(true);game._load_slot(97);ck(game.state==prev and is_instance_valid(game.modal),"missing save preserves progress and reports error");game._close_modal()
	var f=FileAccess.open("user://slot_98.json",FileAccess.WRITE);f.store_string("{broken");f.close();game._load_slot(98)
	ck(game.state==prev and is_instance_valid(game.modal),"corrupt JSON save preserves progress and reports error");game._close_modal()
	game._new_game();ck(game.state.affection=={"xia":0,"xu":0,"song":0} and not "qa_flag" in game.state.flags,"new game resets route state")
	game._show_title();ck(not game.auto_mode and not game.skip_mode and not game.in_game,"title resets progression modes")
	var report={"passed":failures.is_empty(),"check_count":checks.size(),"checks":checks,"failures":failures,"engine":Engine.get_version_info().string,"scope":"Independent runtime synthetic state tests; does not replace full story witnesses"}
	var out=FileAccess.open("res://tests/r2/independent_engine_report.json",FileAccess.WRITE);out.store_string(JSON.stringify(report,"  "));out.close()
	print(JSON.stringify(report));game._stop_audio();await create_timer(.3).timeout;quit(0 if failures.is_empty() else 1)
