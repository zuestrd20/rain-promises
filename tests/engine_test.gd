extends SceneTree
var game: Control
var failures: Array = []
var checks := 0
func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures.append(message)
		printerr("FAIL ",message)
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game._new_game()
	var initial = game.state.duplicate(true)
	game._save(3)
	game._load_slot(3)
	check(game.state==initial,"new game save roundtrip")
	game._show_node(game.current_id,false)
	check(game.state==initial,"render must not replay node effects")
	var malformed = {"version":2,"game":"rain-promises","state":initial}
	malformed.state.affection.xia="bad"
	check(not game._valid_save(malformed),"reject malformed affection")
	check(not game._valid_save({"version":1,"state":initial}),"reject version mismatch")
	check(not game._valid_save({"version":2,"game":"tide-letters","state":initial}),"reject wrong game")
	for data in [null,[],{},42,"broken"]:check(not game._valid_save(data),"reject malformed root")
	game._sanitize_profile({"speed":"oops","music_volume":[],"sfx_volume":{},"read":[],"endings":{"fake":true},"collections":{"fake":true}})
	check(not game.profile.endings.has("fake") and not game.profile.collections.has("fake"),"sanitize unknown profile unlocks")
	game._settings()
	var r = game.reveal
	var id = game.current_id
	game._process(100.0)
	game._advance()
	check(game.reveal==r and game.current_id==id,"modal pause prevents reveal and advance")
	game._close_modal()
	game._close_modal()
	check(not is_instance_valid(game.modal),"repeat modal close safe")
	game._advance()
	check(game.current_id==id,"modal close debounce")
	game.profile.read.erase(id)
	game.was_read=false
	game.skip_mode=true
	game._process(0.1)
	check(not game.skip_mode and game.current_id==id,"skip stops at unread text")
	game._journal()
	game._close_modal()
	game._history()
	game._close_modal()
	game._slots(false)
	game._close_modal()
	game._slots(true)
	game._close_modal()
	game._toggle_skip()
	check(is_instance_valid(game.modal),"skip starts with confirmation")
	game._close_modal()
	check(not game.skip_mode,"cancel skip stays disabled")
	var paths = JSON.parse_string(FileAccess.get_file_as_string("res://tests/ending_paths.json"))
	if paths is Dictionary:
		for ending in paths:
			game._new_game()
			var path: Array = paths[ending]
			for i in range(path.size()-1):
				check(game.current_id==path[i],"witness current node "+str(path[i]))
				var n: Dictionary = game.nodes[game.current_id]
				game.cooldown=0
				game.reveal=100000
				game.body_label.visible_characters=-1
				game.choices_box.visible=true
				if n.has("choices"):
					var chosen = false
					for index in n.choices.size():
						if n.choices[index].next==path[i+1] and game._meets(n.choices[index].get("requires",{})):
							game._choose(index)
							chosen=true
							break
					check(chosen,"legal witness choice")
				else: game._advance()
			check(game.nodes[game.current_id].get("ending","")==ending,"legal ending "+str(ending))
			game._save(2)
			var expected = game.state.duplicate(true)
			game._load_slot(2)
			check(game.state==expected,"ending roundtrip "+str(ending))
			game._show_node(game.current_id,false)
			check(game.state==expected,"ending effects not duplicated "+str(ending))
			game._ending()
			check(is_instance_valid(game.modal),"ending summary")
			game._close_modal()
			print("LEGAL_ENDING_PASS ",ending," nodes=",path.size())
	else: check(false,"ending path file exists")
	game._show_title()
	check(not game.in_game and not game.auto_mode and not game.skip_mode,"title clears modes")
	var report = {"passed":failures.is_empty(),"checks":checks,"failures":failures,"engine":Engine.get_version_info().string}
	var f=FileAccess.open("user://engine_test_report.json",FileAccess.WRITE)
	f.store_string(JSON.stringify(report,"  "))
	f.close()
	print("RAIN_ENGINE_REPORT ",JSON.stringify(report))
	game._stop_audio()
	await create_timer(0.25).timeout
	quit(0 if failures.is_empty() else 1)
