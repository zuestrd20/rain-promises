extends Control

const CREAM = Color("eee9df")
const INK = Color("15232e")
const TEAL = Color("314554")
const CORAL = Color("d07d62")
const GOLD = Color("c6a974")
const FONT = preload("res://assets/fonts/RainPromisesCJKSubset.otf")
var story: Dictionary = {}
var nodes: Dictionary = {}
var art: Dictionary = {}
var state: Dictionary = {}
var profile: Dictionary = {"read": {}, "endings": {}, "speed": 42.0, "music_volume": 0.42, "sfx_volume": 0.5, "collections": {}, "muted": false}
var canvas: Control
var scene_bg: TextureRect
var portrait: TextureRect
var title_layer: Control
var play_layer: Control
var chapter_label: Label
var speaker_label: Label
var body_label: RichTextLabel
var choices_box: VBoxContainer
var next_button: Button
var mode_label: Label
var status_label: Label
var modal: Control
var music: AudioStreamPlayer
var music_b: AudioStreamPlayer
var rain: AudioStreamPlayer
var music_tween: Tween
var active_music := ""
var music_mix := 0.0
var visible_choices: Array = []
var cg_image: TextureRect
var sfx: AudioStreamPlayer
var current_id := ""
var in_game := false
var auto_mode := false
var skip_mode := false
var was_read := false
var elapsed := 0.0
var reveal := 0.0
var cooldown := 0.0
var current_texture := ""
var textures: Dictionary = {}

func _ready() -> void:
	var file = FileAccess.open("res://data/story.json", FileAccess.READ)
	if file:
		story = JSON.parse_string(file.get_as_text())
	nodes = story.get("nodes", {})
	if FileAccess.file_exists("res://data/art.json"):
		art = JSON.parse_string(FileAccess.get_file_as_string("res://data/art.json"))
	var loaded = _read_json("user://profile.json")
	if loaded is Dictionary:
		_sanitize_profile(loaded)
	_build_ui()
	resized.connect(_resize)
	_resize()
	_setup_audio()
	_show_title()
	var args = OS.get_cmdline_user_args()
	if "--capture" in args:
		call_deferred("_capture", args)

func _style(color: Color, border := false) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.corner_radius_top_left = 4
	s.corner_radius_top_right = 4
	s.corner_radius_bottom_left = 4
	s.corner_radius_bottom_right = 4
	s.content_margin_left = 20
	s.content_margin_right = 20
	s.content_margin_top = 12
	s.content_margin_bottom = 12
	if border:
		s.set_border_width_all(2)
		s.border_color = GOLD
	return s

func _label(text: String, size: int, color := INK) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", FONT)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l

func _button(text: String, action: Callable, small := false) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size.y = 42 if small else 54
	b.add_theme_font_override("font", FONT)
	b.add_theme_font_size_override("font_size", 18 if small else 22)
	b.add_theme_color_override("font_color", CREAM)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_focus_color", Color.WHITE)
	b.add_theme_color_override("font_disabled_color", Color("829b92"))
	b.add_theme_stylebox_override("normal", _style(TEAL))
	b.add_theme_stylebox_override("hover", _style(Color("45878a"), true))
	b.add_theme_stylebox_override("pressed", _style(INK, true))
	b.add_theme_stylebox_override("focus", _style(Color("45878a"), true))
	b.add_theme_stylebox_override("disabled", _style(Color("d5dfd5")))
	if small:
		for kind in ["normal","hover","pressed","focus","disabled"]:
			var style = b.get_theme_stylebox(kind)
			style.content_margin_top = 7
			style.content_margin_bottom = 7
	b.pressed.connect(action)
	return b

func _rect(parent: Node, color: Color, rect: Rect2) -> ColorRect:
	var r := ColorRect.new()
	r.color = color
	r.position = rect.position
	r.size = rect.size
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(r)
	return r

func _build_ui() -> void:
	_rect(self, INK, Rect2(0,0,10000,10000))
	canvas = Control.new()
	canvas.size = Vector2(1280,720)
	add_child(canvas)
	scene_bg = TextureRect.new()
	scene_bg.position = Vector2(22,76)
	scene_bg.size = Vector2(728,564)
	scene_bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	scene_bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	scene_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(scene_bg)
	portrait = TextureRect.new()
	portrait.position = Vector2(90,78)
	portrait.size = Vector2(570,560)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(portrait)
	cg_image = TextureRect.new()
	cg_image.position = scene_bg.position
	cg_image.size = scene_bg.size
	cg_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	cg_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	cg_image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(cg_image)
	play_layer = Control.new()
	canvas.add_child(play_layer)
	var brand = _label("雨停之前的約定",24,CREAM)
	brand.position = Vector2(28,17)
	play_layer.add_child(brand)
	chapter_label = _label("",17,GOLD)
	chapter_label.position = Vector2(285,24)
	play_layer.add_child(chapter_label)
	status_label = _label("",16,CREAM)
	status_label.position = Vector2(28,643)
	play_layer.add_child(status_label)
	var panel = Panel.new()
	panel.position = Vector2(770,76)
	panel.size = Vector2(488,564)
	panel.add_theme_stylebox_override("panel", _style(CREAM))
	play_layer.add_child(panel)
	var content = VBoxContainer.new()
	content.position = Vector2(24,18)
	content.size = Vector2(440,530)
	content.add_theme_constant_override("separation",10)
	panel.add_child(content)
	speaker_label = _label("",24,TEAL)
	content.add_child(speaker_label)
	body_label = RichTextLabel.new()
	body_label.custom_minimum_size.y = 145
	body_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body_label.add_theme_font_override("normal_font",FONT)
	body_label.add_theme_font_size_override("normal_font_size",22)
	body_label.add_theme_color_override("default_color",INK)
	body_label.add_theme_constant_override("line_separation",6)
	body_label.scroll_active = true
	body_label.gui_input.connect(func(event):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT: _advance())
	content.add_child(body_label)
	choices_box = VBoxContainer.new()
	choices_box.add_theme_constant_override("separation",7)
	content.add_child(choices_box)
	next_button = _button("下一格光影  ›",_advance,true)
	content.add_child(next_button)
	mode_label = _label("",13,TEAL)
	mode_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(mode_label)
	var toolbar = HBoxContainer.new()
	toolbar.position = Vector2(22,668)
	toolbar.size = Vector2(1236,42)
	toolbar.add_theme_constant_override("separation",6)
	play_layer.add_child(toolbar)
	for item in [["存檔",func(): _slots(false)],["讀檔",func(): _slots(true)],["回顧",_history],["記憶相簿",_journal],["自動",_toggle_auto],["已讀快進",_toggle_skip],["設定",_settings],["標題",func(): _confirm("回到標題？目前段落已自動保存。",_show_title)]]:
		var b = _button(item[0],item[1],true)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		toolbar.add_child(b)
	title_layer = Control.new()
	canvas.add_child(title_layer)
	_rect(title_layer,Color(0.045,0.075,0.10,0.9),Rect2(770,0,510,720))
	var col = VBoxContainer.new()
	col.position = Vector2(800,70)
	col.size = Vector2(450,585)
	col.add_theme_constant_override("separation",18)
	title_layer.add_child(col)
	col.add_child(_label("A PHOTOGRAPH OF TOMORROW",15,GOLD))
	col.add_child(_label("雨停之前
的約定",48,CREAM))
	col.add_child(_label("把留下的光，交還給生活。",21,CREAM))
	col.add_child(_button("開始這一次相遇",_new_game))
	col.add_child(_button("繼續未完的約定",func(): _slots(true)))
	for item in [["記憶相簿",_journal],["七種明日 · 結局",_gallery],["設定與音量",_settings],["製作與操作說明",_credits]]:
		col.add_child(_button(item[0],item[1],true))
	var foot = _label("原創成年戀愛影像小說 · 三條路線\n角色與場景皆為 AI 生成的虛構影像",16,CREAM)
	foot.position = Vector2(30,649)
	title_layer.add_child(foot)

func _resize() -> void:
	if not is_instance_valid(canvas): return
	var factor = min(size.x/1280.0,size.y/720.0)
	canvas.scale = Vector2.ONE*factor
	canvas.position = (size-Vector2(1280,720)*factor)/2

func _texture(path: String) -> Texture2D:
	if path == "" or not ResourceLoader.exists(path): return null
	if not textures.has(path): textures[path] = load(path)
	return textures[path]

func _bg(key: String) -> void:
	var path: String = art.get("backgrounds",{}).get(key,"")
	scene_bg.texture = _texture(path)

func _show_title() -> void:
	_close_modal()
	in_game = false
	auto_mode = false
	skip_mode = false
	play_layer.hide()
	title_layer.show()
	_bg("riverside")
	scene_bg.show()
	portrait.hide()
	cg_image.hide()
	_change_music("city")

func _new_game() -> void:
	state = {"node":story.get("start","c001"),"affection":{"xia":0,"xu":0,"song":0},"flags":[],"history":[],"visited":[],"collections":[]}
	_begin()

func _begin() -> void:
	_close_modal()
	in_game = true
	title_layer.hide()
	play_layer.show()
	portrait.position = Vector2(90,78)
	portrait.size = Vector2(570,560)
	auto_mode = false
	skip_mode = false
	_show_node(str(state.get("node",story.get("start","c001"))),false)

func _show_node(id: String, record := true) -> void:
	if not nodes.has(id):
		_info("故事資料錯誤","找不到段落："+id+"。請回報此段落代碼。")
		return
	current_id = id
	state["node"] = id
	var n: Dictionary = nodes[id]
	was_read = profile["read"].has(id)
	if not state["visited"].has(id):
		_apply_effects(n.get("effects",{}))
		state["visited"].append(id)
	if record or state["history"].is_empty():
		state["history"].append({"speaker":str(n.get("speaker","旁白")),"text":str(n.get("text",""))})
	_bg(str(n.get("bg","riverside")))
	_change_music(str(n.get("music","city")))
	cg_image.texture = _texture(art.get("cg",{}).get(str(n.get("cg","")),""))
	cg_image.visible = cg_image.texture != null
	scene_bg.visible = not cg_image.visible
	var character = str(n.get("character",""))
	portrait.texture = _texture(art.get("characters",{}).get(character,{}).get(str(n.get("pose","standing"))+"_"+str(n.get("expression","neutral")),""))
	portrait.visible = portrait.texture != null and not cg_image.visible
	chapter_label.text = "第 %s 日  ·  %s" % [str(int(n.get("day",1))),str(n.get("chapter","雨城影像誌"))]
	status_label.text = "共同經歷  以寧 %s  ·  芷禾 %s  ·  若安 %s     /     記憶 %s / 8" % [state["affection"].get("xia",0),state["affection"].get("xu",0),state["affection"].get("song",0),profile["collections"].size()]
	speaker_label.text = str(n.get("speaker","旁白"))
	body_label.text = str(n.get("text",""))
	body_label.visible_characters = 0
	body_label.scroll_to_line(0)
	reveal = 0.0
	elapsed = 0.0
	cooldown = 0.35
	for child in choices_box.get_children():
		choices_box.remove_child(child)
		child.queue_free()
	var choices: Array = n.get("choices",[])
	visible_choices.clear()
	for i in choices.size():
		var choice: Dictionary = choices[i]
		if not _meets(choice.get("requires",{})): continue
		visible_choices.append(i)
		var b = _button(str(visible_choices.size())+"  "+str(choice["text"]),_choose.bind(i),true)
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.custom_minimum_size.y = 45
		choices_box.add_child(b)
	choices_box.visible = false
	next_button.visible = choices.is_empty() and not n.has("ending")
	mode_label.text = "點文字展開 · 空白鍵繼續 · 數字鍵選擇"
	_save(0)
	_save_profile()
	if n.has("ending"):
		profile["endings"][str(n["ending"])] = true
		_save_profile()
		var end_button = _button("閱讀明日後記  ·  收進相簿",_ending)
		choices_box.add_child(end_button)

func _process(delta: float) -> void:
	cooldown = max(0.0,cooldown-delta)
	if not in_game or is_instance_valid(modal): return
	var count = body_label.get_total_character_count()
	reveal += delta*float(profile.get("speed",42.0))
	body_label.visible_characters = min(int(reveal),count)
	var done = body_label.visible_characters >= count
	choices_box.visible = done
	for b in choices_box.get_children(): b.disabled = cooldown>0.0
	if done:
		if not profile["read"].has(current_id):
			profile["read"][current_id] = true
			_save_profile()
		elapsed += delta
		if skip_mode and was_read and not nodes[current_id].has("choices") and not nodes[current_id].has("ending") and elapsed>0.10:
			_advance()
		elif auto_mode and not nodes[current_id].has("choices") and not nodes[current_id].has("ending") and elapsed>max(2.5,count/12.0):
			_advance()
	if skip_mode:
		if was_read: reveal = count
		else:
			skip_mode = false
			mode_label.text = "已讀快進已停下：這是尚未閱讀的段落。"

func _advance() -> void:
	if not in_game or is_instance_valid(modal) or cooldown>0: return
	if body_label.visible_characters >= 0 and body_label.visible_characters < body_label.get_total_character_count():
		reveal = body_label.get_total_character_count()
		body_label.visible_characters = int(reveal)
		return
	var n: Dictionary = nodes[current_id]
	if n.has("branches"):
		for branch in n["branches"]:
			if _meets(branch.get("requires",{})):
				_show_node(str(branch["next"]))
				return
	if n.has("next") and not n.has("choices"):
		_ping()
		_show_node(str(n["next"]))

func _choose(index: int) -> void:
	if not in_game or cooldown>0 or is_instance_valid(modal) or not choices_box.visible: return
	var choices: Array = nodes[current_id].get("choices",[])
	if index<0 or index>=choices.size(): return
	var c: Dictionary = choices[index]
	if not _meets(c.get("requires",{})): return
	_apply_effects(c.get("effects",{}))
	state["history"].append({"speaker":"我的選擇","text":str(c["text"])})
	_ping("camera" if c.get("effects",{}).has("collect") else "ui")
	_show_node(str(c["next"]))

func _meets(requirements: Dictionary) -> bool:
	for flag in requirements.get("flags_all",[]):
		if not state.get("flags",[]).has(flag): return false
	for person in requirements.get("affection_min",{}):
		if int(state.get("affection",{}).get(person,0)) < int(requirements["affection_min"][person]): return false
	return true

func _apply_effects(effects: Dictionary) -> void:
	for person in effects.get("affection",{}):
		state["affection"][person] = int(state["affection"].get(person,0))+int(effects["affection"][person])
	for flag in effects.get("flags",[]):
		if not state["flags"].has(flag): state["flags"].append(flag)
	for id in effects.get("collect",[]):
		if not state["collections"].has(id): state["collections"].append(id)
		profile["collections"][id] = true

func _unhandled_key_input(event: InputEvent) -> void:
	if not event.is_pressed() or event.is_echo(): return
	if event is InputEventKey:
		if event.keycode == KEY_ESCAPE:
			if is_instance_valid(modal): _close_modal()
			else: _settings()
		elif event.keycode == KEY_SPACE or event.keycode == KEY_ENTER: _advance()
		elif in_game and choices_box.visible and not is_instance_valid(modal):
			if event.keycode>=KEY_1 and event.keycode<=KEY_9:
				var i = event.keycode-KEY_1
				if i<visible_choices.size(): _choose(visible_choices[i])

func _toggle_auto() -> void:
	auto_mode = not auto_mode
	skip_mode = false
	mode_label.text = "自動閱讀："+("開啟（選項處會停下）" if auto_mode else "關閉")

func _toggle_skip() -> void:
	if skip_mode:
		skip_mode = false
		mode_label.text = "已讀快進：關閉"
	else:
		_confirm("快進只略過曾讀過的段落，遇到新內容或選項會停下。開始？",func():
			skip_mode = true
			auto_mode = false)

func _read_json(path: String) -> Variant:
	if not FileAccess.file_exists(path): return null
	var parser := JSON.new()
	if parser.parse(FileAccess.get_file_as_string(path)) != OK: return null
	return parser.data

func _write_json(path: String, data: Dictionary) -> bool:
	var f = FileAccess.open(path+".tmp",FileAccess.WRITE)
	if not f: return false
	f.store_string(JSON.stringify(data))
	f.close()
	return DirAccess.rename_absolute(path+".tmp",path)==OK

func _save(slot: int) -> void:
	if state.is_empty(): return
	var data = {"version":2,"game":"rain-promises","state":state,"saved":Time.get_datetime_string_from_system(true)+"Z"}
	if not _write_json("user://slot_%s.json"%slot,data):
		mode_label.text = "提醒：存檔失敗，請確認裝置儲存空間／瀏覽器隱私設定。"

func _save_profile() -> void:
	_write_json("user://profile.json",profile)

func _sanitize_profile(loaded: Dictionary) -> void:
	for category in ["read","endings","collections"]:
		if loaded.get(category) is Dictionary:
			for key in loaded[category]:
				var allowed: bool = nodes.has(key) if category=="read" else story.get("collectibles" if category=="collections" else "endings",{}).has(key)
				if allowed and loaded[category][key] == true: profile[category][key] = true
	if typeof(loaded.get("speed")) in [TYPE_INT,TYPE_FLOAT] and is_finite(float(loaded["speed"])): profile["speed"] = clampf(float(loaded["speed"]),15,150)
	for key in ["music_volume","sfx_volume"]:
		if typeof(loaded.get(key)) in [TYPE_INT,TYPE_FLOAT] and is_finite(float(loaded[key])): profile[key] = clampf(float(loaded[key]),0,1)
	if loaded.get("muted") is bool: profile["muted"] = loaded["muted"]

func _valid_save(data: Variant) -> bool:
	if not data is Dictionary or data.get("version") != 2 or data.get("game") != "rain-promises" or not data.get("state") is Dictionary: return false
	var st: Dictionary = data["state"]
	if not st.get("node") is String or not nodes.has(st["node"]): return false
	for key in ["history","visited","collections","flags"]:
		if not st.get(key) is Array or st[key].size()>20000: return false
	for entry in st["history"]:
		if not entry is Dictionary or not entry.get("speaker") is String or not entry.get("text") is String: return false
	for id in st["visited"]:
		if not id is String or not nodes.has(id): return false
	for id in st["collections"]:
		if not id is String or not story.get("collectibles",{}).has(id): return false
	for flag in st["flags"]:
		if not flag is String: return false
	if not st["visited"].has(st["node"]): return false
	if not st.get("affection") is Dictionary or st["affection"].size()!=3: return false
	for person in ["xia","xu","song"]:
		if typeof(st["affection"].get(person)) not in [TYPE_INT,TYPE_FLOAT]: return false
		if not is_finite(float(st["affection"][person])) or abs(float(st["affection"][person]))>10000: return false
	return true

func _load_slot(slot: int) -> void:
	var data = _read_json("user://slot_%s.json"%slot)
	if not _valid_save(data):
		_info("無法讀取","此存檔不存在或格式無效。")
		return
	state = data["state"].duplicate(true)
	for key in ["history","visited","collections","flags"]:
		if not state.has(key): state[key] = []
	if not state.has("affection"): state["affection"] = {"xia":0,"xu":0,"song":0}
	for person in state["affection"]: state["affection"][person] = int(state["affection"][person])
	_begin()

func _open_modal(heading: String) -> VBoxContainer:
	_close_modal()
	modal = Control.new()
	modal.size = Vector2(1280,720)
	canvas.add_child(modal)
	var veil = _rect(modal,Color(0.05,0.13,0.14,0.75),Rect2(0,0,1280,720))
	veil.mouse_filter = Control.MOUSE_FILTER_STOP
	var p = Panel.new()
	p.position = Vector2(165,28)
	p.size = Vector2(950,664)
	p.add_theme_stylebox_override("panel",_style(CREAM,true))
	modal.add_child(p)
	var head = _label(heading,30)
	head.position = Vector2(28,20)
	p.add_child(head)
	var close = _button("關閉  ×",_close_modal,true)
	close.position = Vector2(790,20)
	close.size.x = 132
	p.add_child(close)
	var scroll = ScrollContainer.new()
	scroll.position = Vector2(28,84)
	scroll.size = Vector2(894,548)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	p.add_child(scroll)
	var content = VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation",16)
	scroll.add_child(content)
	return content

func _close_modal() -> void:
	if is_instance_valid(modal):
		canvas.remove_child(modal)
		modal.queue_free()
	modal = null
	cooldown = 0.25

func _paragraph(parent: Node, text: String, size := 22) -> void:
	var l = _label(text,size)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(l)

func _info(heading: String, text: String) -> void:
	_paragraph(_open_modal(heading),text)

func _confirm(text: String, action: Callable) -> void:
	var col = _open_modal("請確認")
	_paragraph(col,text,26)
	col.add_child(_button("確認",func():
		_close_modal()
		action.call()))
	col.add_child(_button("返回",_close_modal))

func _slots(loading: bool) -> void:
	var col = _open_modal("讀取旅程" if loading else "保存旅程")
	_paragraph(col,"三個手動存檔＋一個自動存檔。每段開頭自動保存；手動存檔不會被自動覆寫。",18)
	for slot in range(0 if loading else 1,4):
		var data = _read_json("user://slot_%s.json"%slot)
		var title = "自動存檔" if slot==0 else "手動存檔 %s"%slot
		if _valid_save(data):
			var id = str(data.get("state",{}).get("node",""))
			title += "  ·  "+str(nodes.get(id,{}).get("chapter",id))+"\n"+str(data.get("saved",""))
		else: title += "  ·  尚無有效記錄"
		var b = _button(title,func():
			if loading:
				if in_game: _confirm("讀檔會回到所選時間點，並更新自動存檔。建議先把現在進度另存手動槽。繼續？",_load_slot.bind(slot))
				else: _load_slot(slot)
			elif data is Dictionary:
				_confirm("覆寫手動存檔 %s？"%slot,func():
					_save(slot)
					_slots(false))
			else:
				_save(slot)
				_slots(false))
		b.disabled = (loading and not _valid_save(data)) or (not loading and not in_game)
		col.add_child(b)

func _history() -> void:
	var col = _open_modal("對話回顧")
	if state.get("history",[]).is_empty(): _paragraph(col,"旅程尚未開始。")
	for entry in state.get("history",[]):
		_paragraph(col,str(entry["speaker"]),19)
		_paragraph(col,str(entry["text"]),21)

func _journal() -> void:
	var col = _open_modal("記憶相簿  ·  %s / 8"%profile["collections"].size())
	_paragraph(col,"姜予澤 · 29 歲 · 攝影師。照片是否公開，由畫面裡的人決定。收藏跨周目保存，與戀愛結局分開記錄。",20)
	for id in story.get("collectibles",{}):
		var entry: Dictionary = story["collectibles"][id]
		var unlocked: bool = profile["collections"].has(id)
		_paragraph(col,str(entry.get("title",id)) if unlocked else "尚未沖洗的記憶",23)
		if unlocked:
			var path: String = art.get("cg",{}).get(str(entry.get("cg","")),art.get("backgrounds",{}).get(str(entry.get("bg","riverside")),""))
			var photo = TextureRect.new()
			photo.texture = _texture(path)
			photo.custom_minimum_size = Vector2(0,250)
			photo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			photo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			col.add_child(photo)
			_paragraph(col,str(entry.get("text",entry.get("description",""))),20)

func _gallery() -> void:
	var col = _open_modal("七種明日  ·  %s / 7"%profile["endings"].size())
	_paragraph(col,"完成的結局會保存在這裡；開始新遊戲不會清除紀錄。",18)
	for id in story.get("endings",{}):
		var e: Dictionary = story["endings"][id]
		var unlocked: bool = profile["endings"].has(id)
		_paragraph(col,("✓  "+str(e.get("title",id))) if unlocked else "尚未顯影的明日",24)
		_paragraph(col,str(e.get("summary",e.get("description",""))) if unlocked else "沿著不同的選擇，看見另一種生活。",19)

func _ending() -> void:
	var id = str(nodes[current_id].get("ending",""))
	var e: Dictionary = story.get("endings",{}).get(id,{})
	var col = _open_modal("旅程結束  ·  "+str(e.get("title",id)))
	_paragraph(col,str(e.get("summary",e.get("description","謝謝你讀到這裡。"))),25)
	_paragraph(col,"這個明日已收進相簿。你可以回顧對話、讀取先前的手動存檔，或開始另一段旅程。",20)
	col.add_child(_button("回到標題",_show_title))
	col.add_child(_button("讀取另一個時間點",func(): _slots(true)))
	col.add_child(_button("留在此頁",_close_modal))

func _settings() -> void:
	var col = _open_modal("閱讀設定")
	_paragraph(col,"文字速度",23)
	var speed = HSlider.new()
	speed.min_value = 15
	speed.max_value = 150
	speed.step = 5
	speed.value = float(profile["speed"])
	speed.custom_minimum_size.y = 38
	col.add_child(speed)
	var speed_text = _label("每秒 %s 字"%int(speed.value),18)
	col.add_child(speed_text)
	speed.value_changed.connect(func(v):
		profile["speed"] = v
		speed_text.text = "每秒 %s 字"%int(v)
		_save_profile())
	for key in ["music_volume","sfx_volume"]:
		_paragraph(col,"背景音樂" if key=="music_volume" else "環境雨聲與操作音效",23)
		var volume = HSlider.new()
		volume.min_value = 0
		volume.max_value = 1
		volume.step = 0.05
		volume.value = float(profile[key])
		volume.custom_minimum_size.y = 38
		col.add_child(volume)
		volume.value_changed.connect(func(v):
			profile[key] = v
			_apply_volume()
			_save_profile())
	var mute = CheckButton.new()
	mute.text = "靜音"
	mute.button_pressed = bool(profile["muted"])
	mute.add_theme_font_override("font",FONT)
	mute.add_theme_font_size_override("font_size",24)
	mute.add_theme_color_override("font_color",INK)
	mute.add_theme_color_override("font_pressed_color",INK)
	mute.add_theme_color_override("font_hover_color",TEAL)
	mute.add_theme_color_override("font_hover_pressed_color",TEAL)
	mute.add_theme_color_override("font_focus_color",INK)
	col.add_child(mute)
	mute.toggled.connect(func(v):
		profile["muted"] = v
		_apply_volume()
		_save_profile())
	_paragraph(col,"操作：空白鍵／Enter 繼續，1–3 選擇，Esc 開啟或關閉選單。點文字先展開全文。\n自動閱讀與已讀快進在選項處停下。所有選項都有短暫防誤觸。\n建議橫向畫面與耳機。網頁存檔保存在目前瀏覽器；清除網站資料會刪除存檔。",19)

func _credits() -> void:
	_info("製作與閱讀說明","雨停之前的約定\n\n原創繁體中文成年戀愛影像小說。姜予澤 29 歲、夏以寧 28 歲、許芷禾 30 歲、宋若安 31 歲；人物皆為虛構成年人。\n\n角色與場景皆為 AI 生成的虛構影像，不是真人照片或真人演出。故事、介面、程式及多聲部配樂為此作品原創製作。沒有角色語音。\n\n字型 Noto Sans CJK TC：SIL Open Font License；Godot 4.6.3：MIT。素材來源、原始提示及授權見原始碼 README。\n\n三條路線、七種結局、八則記憶收藏。行程和攝影選擇影響相遇與記憶，情感關係需要互信與雙方清楚表達；拒絕公開照片不扣互信。\n\n空白鍵或 Enter 繼續，數字鍵選擇，Esc 選單。觸控可直接按按鈕，建議橫向閱讀。")

func _setup_audio() -> void:
	music = AudioStreamPlayer.new()
	music_b = AudioStreamPlayer.new()
	rain = AudioStreamPlayer.new()
	sfx = AudioStreamPlayer.new()
	for player in [music,music_b,rain,sfx]: add_child(player)
	for player in [music,music_b,rain]:
		player.finished.connect(func():
			if player.stream: player.play())
	if ResourceLoader.exists("res://assets/audio/ambience_rain.ogg"):
		rain.stream = load("res://assets/audio/ambience_rain.ogg")
		rain.stream.loop = true
		rain.play()
	if ResourceLoader.exists("res://assets/audio/sfx_page.ogg"): sfx.stream = load("res://assets/audio/sfx_page.ogg")
	_apply_volume()

func _change_music(key: String) -> void:
	if not is_instance_valid(music) or key==active_music: return
	var path = "res://assets/audio/music_"+key+".ogg"
	if not ResourceLoader.exists(path): return
	if is_instance_valid(music_tween): music_tween.kill()
	# Carry forward the louder stream on rapid scene changes, never fade to silence.
	if music_mix>0.5 or music.stream==null:
		var swap = music
		music = music_b
		music_b = swap
	music_b.stop()
	music_b.stream = load(path)
	music_b.stream.loop = true
	music_mix = 0.0
	_apply_volume()
	music_b.play()
	active_music = key
	music_tween = create_tween()
	music_tween.tween_method(func(v):
		music_mix = v
		_apply_volume(),0.0,1.0,1.4)
	music_tween.tween_callback(func():
		music.stop()
		music.stream = null)

func _apply_volume() -> void:
	AudioServer.set_bus_mute(0,bool(profile["muted"]))
	var volume = float(profile["music_volume"])*0.6
	if is_instance_valid(music): music.volume_db = linear_to_db(max(0.0001,volume*cos(music_mix*PI/2)))
	if is_instance_valid(music_b): music_b.volume_db = linear_to_db(max(0.0001,volume*sin(music_mix*PI/2)))
	if is_instance_valid(sfx): sfx.volume_db = linear_to_db(max(0.0001,float(profile["sfx_volume"])*0.65))
	if is_instance_valid(rain): rain.volume_db = linear_to_db(max(0.0001,float(profile["sfx_volume"])*0.22))

func _stop_audio() -> void:
	for player in [music,music_b,rain,sfx]:
		if is_instance_valid(player):
			player.stop()
			player.stream = null

func _exit_tree() -> void:
	_stop_audio()

func _ping(kind := "page") -> void:
	var path = "res://assets/audio/sfx_"+kind+".ogg"
	if is_instance_valid(sfx) and ResourceLoader.exists(path):
		sfx.stream = load(path)
		sfx.play()

func _capture(args: PackedStringArray) -> void:
	var at = args.find("--capture")
	var target = args[at+1] if args.size()>at+1 else "title"
	if target!="title":
		_new_game()
		if nodes.has(target): _show_node(target)
		reveal = 100000
		body_label.visible_characters = -1
	await get_tree().create_timer(0.5).timeout
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var output = "user://screenshots"
	var output_at = args.find("--capture-dir")
	if output_at>=0 and args.size()>output_at+1: output = args[output_at+1]
	DirAccess.make_dir_recursive_absolute(output)
	get_viewport().get_texture().get_image().save_png(output.path_join("screenshot_"+target+".png"))
	if "--hold" in args: return
	_stop_audio()
	await get_tree().create_timer(0.25).timeout
	get_tree().quit()
