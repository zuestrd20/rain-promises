extends SceneTree
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var font=load("res://assets/fonts/RainPromisesCJKSubset.otf")
	var chars={}
	for path in ["res://data/story.json","res://scripts/main.gd","res://project.godot"]:
		var txt=FileAccess.get_file_as_string(path)
		for i in txt.length():chars[txt.unicode_at(i)]=true
	for i in range(32,127):chars[i]=true
	var missing=[];var checked=0
	for c in chars:
		if c not in [9,10,13]:
			checked+=1
			if not font.has_char(c):missing.append(c)
	var art=JSON.parse_string(FileAccess.get_file_as_string("res://data/art.json"));var files={};var results=[]
	for cat in ["backgrounds","cg"]:
		for key in art[cat]:files[art[cat][key]]=true
	DirAccess.make_dir_recursive_absolute("res://tests/r2/decoded")
	for path in files:
		var texture=load(path);var im=texture.get_image();var dest="res://tests/r2/decoded/"+path.get_file()+".png"
		var err=im.save_png(dest)
		results.append({"path":path,"width":im.get_width(),"height":im.get_height(),"saved":err==OK,"decoded_png":dest})
	var report={"font_runtime_has_char_missing":missing,"font_runtime_chars_checked":checked,"images":results,"pass":missing.is_empty()}
	var f=FileAccess.open("res://tests/r2/runtime_compact_report.json",FileAccess.WRITE);f.store_string(JSON.stringify(report,"  "));f.close();print(JSON.stringify(report));quit(0 if missing.is_empty() else 1)
