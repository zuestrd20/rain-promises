extends SceneTree
var fails=[]
var checks=[]
func ck(ok: bool,label: String) -> void:
	checks.append({"name":label,"pass":ok})
	if not ok:fails.append(label)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var game=load("res://main.tscn").instantiate();root.add_child(game);await process_frame;game.set_process(false)
	for key in ["city","warm","reflection","ending"]:
		game._change_music(key)
		ck(game.active_music==key and game.music_b.stream!=null and game.music_b.stream.resource_path=="res://assets/audio/music_"+key+".ogg" and game.music_b.stream.loop,"music selected and looping "+key)
	ck(game.rain.stream!=null and game.rain.stream.loop,"rain selected and looping")
	for key in ["page","ui","camera"]:
		game._ping(key);ck(game.sfx.stream!=null and game.sfx.stream.resource_path=="res://assets/audio/sfx_"+key+".ogg","sfx runtime "+key)
	game.profile.muted=true;game._apply_volume();ck(AudioServer.is_bus_mute(0),"mute switches actual master bus")
	game.profile.muted=false;game.profile.music_volume=0;game.profile.sfx_volume=0;game._apply_volume();ck(not AudioServer.is_bus_mute(0) and game.music.volume_db<=-79 and game.music_b.volume_db<=-79 and game.sfx.volume_db<=-79 and game.rain.volume_db<=-79,"zero sliders silence all playback channels")
	var report={"pass":fails.is_empty(),"checks":checks,"failures":fails,"runtime_assets_selected":8,"audio_listened":false,"note":"Headless stream resource/loop/volume wiring test only. Objective decode/peak analysis separately supplied; no listening claim."}
	var f=FileAccess.open("res://tests/r2/audio_runtime_report.json",FileAccess.WRITE);f.store_string(JSON.stringify(report,"  "));f.close();print(JSON.stringify(report));game._stop_audio();await create_timer(.25).timeout;quit(0 if fails.is_empty() else 1)
