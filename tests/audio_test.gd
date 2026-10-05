extends SceneTree
var game: Control
var failures: Array = []
var checks := 0
func check(v: bool, text: String) -> void:
	checks+=1
	if not v: failures.append(text)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	game=load("res://main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	await create_timer(0.15).timeout
	game._change_music("warm")
	check(game.music.stream!=null,"rapid first transition retains existing stream")
	for key in ["warm","reflection","ending","city"]:
		game._change_music(key)
		await create_timer(0.7).timeout
		check(game.music.playing or game.music_b.playing,"crossfade playing "+key)
		check(game.music_mix>0 and game.music_mix<=1,"crossfade bounded "+key)
		await create_timer(0.9).timeout
		check(game.music_mix==1.0,"crossfade completes "+key)
		check(game.music_b.playing and game.music_b.stream.loop,"loop active "+key)
		var pos=game.music_b.get_playback_position()
		game._change_music(key)
		check(game.music_b.get_playback_position()>=pos,"same cue does not restart "+key)
	game.profile.music_volume=0.1
	game.profile.sfx_volume=0.9
	game._apply_volume()
	check(game.sfx.volume_db>game.music_b.volume_db,"independent volumes")
	game.profile.muted=true
	game._apply_volume()
	check(AudioServer.is_bus_mute(0),"mute bus")
	for kind in ["page","camera","ui"]:
		game._ping(kind)
		check(game.sfx.stream!=null,"SFX loaded "+kind)
	check(game.rain.stream.loop,"rain loop")
	var report={"pass":failures.is_empty(),"checks":checks,"failures":failures,"note":"Audio stream/loop/crossfade state only; dummy audio device, no listening QA"}
	var f=FileAccess.open("user://audio_engine_report.json",FileAccess.WRITE)
	f.store_string(JSON.stringify(report,"  "))
	f.close()
	print("AUDIO_ENGINE_REPORT ",JSON.stringify(report))
	game._stop_audio()
	await create_timer(0.25).timeout
	quit(0 if failures.is_empty() else 1)
