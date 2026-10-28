extends Node2D

## 青石渡 · 阿衡 — isometric wuxia RPG MVP

enum Mode { EXPLORE, DIALOGUE, COMBAT, WIN }

const VIEW_W := 1280.0
const VIEW_H := 720.0
const HERO_SPEED := 220.0
const PLAYER_MAX_HP := 100
const MONSTER_MAX_HP := 60
const PLAYER_ATK := 14
const MONSTER_ATK := 8

var mode: Mode = Mode.EXPLORE
var combat_unlocked := false
var player_hp := PLAYER_MAX_HP
var monster_hp := MONSTER_MAX_HP
var monster_defeated := false

# Dialogue / intro
var dialogue_lines: Array[String] = []
var dialogue_index := 0
var dialogue_kind := ""  # "intro" | "master"

var hero_target := Vector2(420, 480)
var hero_pos := Vector2(420, 480)
var monster_pos := Vector2(920, 420)
var npc_pos := Vector2(560, 300)

var map_tex: Texture2D
var hero_tex: Texture2D
var monster_tex: Texture2D
var portrait_tex: Texture2D

var sfx_click: AudioStream
var sfx_hit: AudioStream
var sfx_win: AudioStream
var sfx_dialogue: AudioStream
var audio: AudioStreamPlayer

# UI nodes
var hud_label: Label
var hp_bar_bg: ColorRect
var hp_bar_fill: ColorRect
var hp_text: Label
var hint_label: Label

var dialogue_layer: CanvasLayer
var dialogue_panel: Panel
var dialogue_name: Label
var dialogue_body: Label
var dialogue_portrait: TextureRect
var btn_continue: Button

var combat_layer: CanvasLayer
var combat_panel: Panel
var combat_title: Label
var player_combat_hp: ProgressBar
var monster_combat_hp: ProgressBar
var combat_log: Label
var btn_attack: Button
var btn_flee: Button
var combat_hero: TextureRect
var combat_monster: TextureRect

var win_layer: CanvasLayer
var npc_marker: ColorRect
var click_blocker: Control

func _ready() -> void:
	map_tex = load("res://assets/images/map-qingshi-ferry.jpg")
	hero_tex = load("res://assets/images/hero-aheng.png")
	monster_tex = load("res://assets/images/monster-river-beast.png")
	portrait_tex = load("res://assets/images/portrait-master.png")
	sfx_click = load("res://assets/sfx/click.wav")
	sfx_hit = load("res://assets/sfx/hit.wav")
	sfx_win = load("res://assets/sfx/win.wav")
	sfx_dialogue = load("res://assets/sfx/dialogue.wav")

	audio = AudioStreamPlayer.new()
	add_child(audio)

	_build_hud()
	_build_dialogue()
	_build_combat()
	_build_win()
	_build_npc_marker()

	print("READY")
	print("青石渡 prototype ready — intro, talk to 守渡人, then fight 碧鱗河妖.")
	_open_intro()


func _build_npc_marker() -> void:
	# Soft glow marker near pavilion for talking to 守渡人
	npc_marker = ColorRect.new()
	npc_marker.size = Vector2(36, 36)
	npc_marker.position = npc_pos - Vector2(18, 18)
	npc_marker.color = Color(0.35, 0.85, 0.55, 0.55)
	npc_marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Add as child of a CanvasItem so it draws under sprites — we'll draw in _draw instead
	# Keep for hit test only; hide visually and draw in _draw
	npc_marker.visible = false
	add_child(npc_marker)


func _build_hud() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)

	var panel := Panel.new()
	panel.position = Vector2(16, 16)
	panel.size = Vector2(280, 78)
	_style_jade_panel(panel)
	layer.add_child(panel)

	hud_label = Label.new()
	hud_label.text = "青石渡"
	hud_label.position = Vector2(28, 22)
	hud_label.add_theme_font_size_override("font_size", 22)
	hud_label.add_theme_color_override("font_color", Color(0.95, 0.98, 0.9))
	layer.add_child(hud_label)

	var hp_caption := Label.new()
	hp_caption.text = "氣血"
	hp_caption.position = Vector2(28, 52)
	hp_caption.add_theme_font_size_override("font_size", 14)
	hp_caption.add_theme_color_override("font_color", Color(0.75, 0.9, 0.8))
	layer.add_child(hp_caption)

	hp_bar_bg = ColorRect.new()
	hp_bar_bg.position = Vector2(70, 56)
	hp_bar_bg.size = Vector2(200, 14)
	hp_bar_bg.color = Color(0.12, 0.2, 0.16, 0.9)
	layer.add_child(hp_bar_bg)

	hp_bar_fill = ColorRect.new()
	hp_bar_fill.position = Vector2(70, 56)
	hp_bar_fill.size = Vector2(200, 14)
	hp_bar_fill.color = Color(0.35, 0.82, 0.5, 1.0)
	layer.add_child(hp_bar_fill)

	hp_text = Label.new()
	hp_text.position = Vector2(70, 52)
	hp_text.size = Vector2(200, 18)
	hp_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hp_text.add_theme_font_size_override("font_size", 12)
	hp_text.add_theme_color_override("font_color", Color(1, 1, 1))
	layer.add_child(hp_text)

	hint_label = Label.new()
	hint_label.position = Vector2(16, VIEW_H - 40)
	hint_label.size = Vector2(VIEW_W - 32, 28)
	hint_label.add_theme_font_size_override("font_size", 15)
	hint_label.add_theme_color_override("font_color", Color(0.9, 0.95, 0.85, 0.95))
	hint_label.text = "點擊地面移動 · 點綠光與守渡人對話 · 解鎖後點擊碧鱗河妖開戰"
	layer.add_child(hint_label)

	_refresh_hud()


func _build_dialogue() -> void:
	dialogue_layer = CanvasLayer.new()
	dialogue_layer.layer = 20
	dialogue_layer.visible = false
	add_child(dialogue_layer)

	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.45)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dialogue_layer.add_child(dim)

	dialogue_panel = Panel.new()
	dialogue_panel.position = Vector2(140, 460)
	dialogue_panel.size = Vector2(1000, 220)
	_style_jade_panel(dialogue_panel)
	dialogue_layer.add_child(dialogue_panel)

	dialogue_portrait = TextureRect.new()
	dialogue_portrait.texture = portrait_tex
	dialogue_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	dialogue_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	dialogue_portrait.position = Vector2(160, 478)
	dialogue_portrait.size = Vector2(140, 180)
	dialogue_layer.add_child(dialogue_portrait)

	# Portrait frame
	var frame := ColorRect.new()
	frame.position = Vector2(156, 474)
	frame.size = Vector2(148, 188)
	frame.color = Color(0.45, 0.75, 0.55, 0.35)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dialogue_layer.add_child(frame)
	dialogue_layer.move_child(frame, dialogue_portrait.get_index())

	dialogue_name = Label.new()
	dialogue_name.text = "旁白"
	dialogue_name.position = Vector2(330, 478)
	dialogue_name.add_theme_font_size_override("font_size", 24)
	dialogue_name.add_theme_color_override("font_color", Color(0.55, 0.95, 0.7))
	dialogue_layer.add_child(dialogue_name)

	dialogue_body = Label.new()
	dialogue_body.text = ""
	dialogue_body.position = Vector2(330, 520)
	dialogue_body.size = Vector2(760, 110)
	dialogue_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dialogue_body.add_theme_font_size_override("font_size", 20)
	dialogue_body.add_theme_color_override("font_color", Color(0.95, 0.98, 0.92))
	dialogue_layer.add_child(dialogue_body)

	btn_continue = Button.new()
	btn_continue.text = "繼續"
	btn_continue.position = Vector2(980, 600)
	btn_continue.size = Vector2(120, 44)
	_style_button(btn_continue)
	btn_continue.pressed.connect(_on_dialogue_continue)
	dialogue_layer.add_child(btn_continue)


func _build_combat() -> void:
	combat_layer = CanvasLayer.new()
	combat_layer.layer = 25
	combat_layer.visible = false
	add_child(combat_layer)

	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.05, 0.08, 0.1, 0.72)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	combat_layer.add_child(dim)

	combat_title = Label.new()
	combat_title.text = "戰鬥 · 碧鱗河妖"
	combat_title.position = Vector2(0, 24)
	combat_title.size = Vector2(VIEW_W, 40)
	combat_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	combat_title.add_theme_font_size_override("font_size", 28)
	combat_title.add_theme_color_override("font_color", Color(0.85, 0.98, 0.9))
	combat_layer.add_child(combat_title)

	combat_hero = TextureRect.new()
	combat_hero.texture = hero_tex
	combat_hero.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	combat_hero.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	combat_hero.position = Vector2(180, 140)
	combat_hero.size = Vector2(280, 360)
	combat_layer.add_child(combat_hero)

	combat_monster = TextureRect.new()
	combat_monster.texture = monster_tex
	combat_monster.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	combat_monster.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	combat_monster.position = Vector2(780, 120)
	combat_monster.size = Vector2(320, 380)
	combat_layer.add_child(combat_monster)

	var p_label := Label.new()
	p_label.text = "阿衡"
	p_label.position = Vector2(200, 500)
	p_label.add_theme_font_size_override("font_size", 18)
	p_label.add_theme_color_override("font_color", Color(0.9, 0.95, 0.85))
	combat_layer.add_child(p_label)

	player_combat_hp = ProgressBar.new()
	player_combat_hp.position = Vector2(200, 530)
	player_combat_hp.size = Vector2(260, 22)
	player_combat_hp.max_value = PLAYER_MAX_HP
	player_combat_hp.value = PLAYER_MAX_HP
	player_combat_hp.show_percentage = false
	combat_layer.add_child(player_combat_hp)

	var m_label := Label.new()
	m_label.text = "碧鱗河妖"
	m_label.position = Vector2(820, 500)
	m_label.add_theme_font_size_override("font_size", 18)
	m_label.add_theme_color_override("font_color", Color(0.95, 0.8, 0.75))
	combat_layer.add_child(m_label)

	monster_combat_hp = ProgressBar.new()
	monster_combat_hp.position = Vector2(820, 530)
	monster_combat_hp.size = Vector2(260, 22)
	monster_combat_hp.max_value = MONSTER_MAX_HP
	monster_combat_hp.value = MONSTER_MAX_HP
	monster_combat_hp.show_percentage = false
	combat_layer.add_child(monster_combat_hp)

	combat_panel = Panel.new()
	combat_panel.position = Vector2(340, 580)
	combat_panel.size = Vector2(600, 110)
	_style_jade_panel(combat_panel)
	combat_layer.add_child(combat_panel)

	combat_log = Label.new()
	combat_log.text = "碧鱗河妖護著濁氣堵住的靈泉，擋路。選擇行動。"
	combat_log.position = Vector2(360, 592)
	combat_log.size = Vector2(560, 30)
	combat_log.add_theme_font_size_override("font_size", 16)
	combat_log.add_theme_color_override("font_color", Color(0.92, 0.96, 0.9))
	combat_layer.add_child(combat_log)

	btn_attack = Button.new()
	btn_attack.text = "攻擊"
	btn_attack.position = Vector2(400, 630)
	btn_attack.size = Vector2(160, 44)
	_style_button(btn_attack)
	btn_attack.pressed.connect(_on_attack)
	combat_layer.add_child(btn_attack)

	btn_flee = Button.new()
	btn_flee.text = "逃跑"
	btn_flee.position = Vector2(720, 630)
	btn_flee.size = Vector2(160, 44)
	_style_button(btn_flee)
	btn_flee.pressed.connect(_on_flee)
	combat_layer.add_child(btn_flee)


func _build_win() -> void:
	win_layer = CanvasLayer.new()
	win_layer.layer = 30
	win_layer.visible = false
	add_child(win_layer)

	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.55)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	win_layer.add_child(dim)

	var panel := Panel.new()
	panel.position = Vector2(340, 250)
	panel.size = Vector2(600, 200)
	_style_jade_panel(panel)
	win_layer.add_child(panel)

	var title := Label.new()
	title.text = "勝利"
	title.position = Vector2(340, 270)
	title.size = Vector2(600, 40)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", Color(0.7, 1.0, 0.75))
	win_layer.add_child(title)

	var body := Label.new()
	body.text = "碧鱗河妖退入水中，靈泉濁氣稍解。渡舟緩緩靠岸。\n守渡人點頭：「阿衡，心與氣都通了一寸。做得不錯。」"
	body.position = Vector2(380, 320)
	body.size = Vector2(520, 80)
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_theme_font_size_override("font_size", 18)
	body.add_theme_color_override("font_color", Color(0.95, 0.98, 0.92))
	win_layer.add_child(body)

	var btn := Button.new()
	btn.text = "返回渡口"
	btn.position = Vector2(540, 400)
	btn.size = Vector2(200, 36)
	_style_button(btn)
	btn.pressed.connect(_on_win_ok)
	win_layer.add_child(btn)


func _style_jade_panel(panel: Panel) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.22, 0.16, 0.92)
	sb.border_color = Color(0.45, 0.78, 0.55, 0.95)
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(10)
	sb.shadow_color = Color(0, 0, 0, 0.35)
	sb.shadow_size = 8
	panel.add_theme_stylebox_override("panel", sb)


func _style_button(btn: Button) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.18, 0.42, 0.3, 0.95)
	normal.border_color = Color(0.55, 0.88, 0.65, 1)
	normal.set_border_width_all(2)
	normal.set_corner_radius_all(6)
	var hover := normal.duplicate()
	hover.bg_color = Color(0.25, 0.55, 0.38, 0.98)
	var pressed := normal.duplicate()
	pressed.bg_color = Color(0.12, 0.32, 0.22, 0.98)
	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_color_override("font_color", Color(0.95, 1.0, 0.92))
	btn.add_theme_font_size_override("font_size", 18)


func _play(stream: AudioStream) -> void:
	if stream == null:
		return
	audio.stream = stream
	audio.play()


func _refresh_hud() -> void:
	var ratio := clampf(float(player_hp) / float(PLAYER_MAX_HP), 0.0, 1.0)
	hp_bar_fill.size.x = 200.0 * ratio
	if ratio > 0.5:
		hp_bar_fill.color = Color(0.35, 0.82, 0.5, 1.0)
	elif ratio > 0.25:
		hp_bar_fill.color = Color(0.9, 0.75, 0.25, 1.0)
	else:
		hp_bar_fill.color = Color(0.9, 0.3, 0.28, 1.0)
	hp_text.text = "%d / %d" % [player_hp, PLAYER_MAX_HP]


func _process(delta: float) -> void:
	if mode == Mode.EXPLORE:
		var dist := hero_pos.distance_to(hero_target)
		if dist > 2.0:
			hero_pos = hero_pos.move_toward(hero_target, HERO_SPEED * delta)
			queue_redraw()
	queue_redraw()


func _draw() -> void:
	# Map background
	if map_tex:
		draw_texture_rect(map_tex, Rect2(0, 0, VIEW_W, VIEW_H), false)

	# NPC glow marker (talk hotspot)
	if not combat_unlocked or true:
		var pulse := 0.45 + 0.2 * sin(Time.get_ticks_msec() / 300.0)
		draw_circle(npc_pos, 22.0, Color(0.35, 0.9, 0.55, pulse))
		draw_circle(npc_pos, 10.0, Color(0.7, 1.0, 0.8, 0.85))
		# Small label shadow
		draw_string(ThemeDB.fallback_font, npc_pos + Vector2(-28, -28), "守渡人", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.1, 0.2, 0.15, 0.8))
		draw_string(ThemeDB.fallback_font, npc_pos + Vector2(-29, -29), "守渡人", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.75, 1.0, 0.85))

	# Y-sort: draw farther (smaller y) first
	var entities: Array = []
	entities.append({"kind": "hero", "y": hero_pos.y, "pos": hero_pos})
	if not monster_defeated:
		entities.append({"kind": "monster", "y": monster_pos.y, "pos": monster_pos})
	entities.sort_custom(func(a, b): return a["y"] < b["y"])

	for e in entities:
		if e["kind"] == "hero":
			_draw_sprite(hero_tex, e["pos"], Vector2(110, 150))
		else:
			_draw_sprite(monster_tex, e["pos"], Vector2(160, 140))
			# Monster hover ring if combat unlocked
			if combat_unlocked and mode == Mode.EXPLORE:
				draw_arc(e["pos"] + Vector2(0, 40), 55.0, 0, TAU, 32, Color(0.95, 0.4, 0.35, 0.7), 3.0)


func _draw_sprite(tex: Texture2D, pos: Vector2, size: Vector2) -> void:
	if tex == null:
		return
	var rect := Rect2(pos - Vector2(size.x * 0.5, size.y * 0.85), size)
	# Soft shadow
	draw_circle(pos + Vector2(0, 8), size.x * 0.28, Color(0, 0, 0, 0.28))
	draw_texture_rect(tex, rect, false)


func _unhandled_input(event: InputEvent) -> void:
	if mode != Mode.EXPLORE:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var pos: Vector2 = event.position
		_play(sfx_click)

		# Talk to master?
		if pos.distance_to(npc_pos) < 48.0:
			_open_dialogue()
			get_viewport().set_input_as_handled()
			return

		# Attack monster?
		if combat_unlocked and not monster_defeated:
			var m_center := monster_pos + Vector2(0, -20)
			if pos.distance_to(m_center) < 90.0 or pos.distance_to(monster_pos) < 80.0:
				_start_combat()
				get_viewport().set_input_as_handled()
				return

		# Move — clamp to walkable-ish band (lower half / mid map)
		var target := pos
		target.x = clampf(target.x, 80.0, VIEW_W - 80.0)
		target.y = clampf(target.y, 260.0, VIEW_H - 40.0)
		hero_target = target
		get_viewport().set_input_as_handled()


func _open_intro() -> void:
	dialogue_kind = "intro"
	dialogue_lines = [
		"青石渡：過得了心，才過得了江。",
		"青石渡是凡間與求道路的交界渡口。守渡人表面擺渡垂釣，實則考驗過江者。",
		"外門弟子阿衡體內有一段未醒的靈脈印記；盤踞水車棧道的碧鱗河妖受地脈濁氣所侵，堵住靈泉與渡口。",
		"唯有通過對話考驗、降伏河妖，渡舟才會為你靠岸。點綠光，先去見守渡人。",
	]
	dialogue_index = 0
	mode = Mode.DIALOGUE
	dialogue_name.text = "旁白"
	_show_dialogue_line()
	dialogue_layer.visible = true
	_play(sfx_dialogue)
	hint_label.text = "聆聽開場……"


func _open_dialogue() -> void:
	dialogue_kind = "master"
	dialogue_lines = [
		"少年，你是劍宗外門的阿衡？我在這渡口擺渡多年——過江的人不少，過得了心的卻不多。",
		"水車棧道旁那頭碧鱗河妖，護著被濁氣堵住的靈泉，阻了去路。你若心境未澄、氣血未通，渡舟不會為你靠岸。",
		"這便是我給你的考驗：聽完這些，再去降伏牠。通過對話、降伏河妖，渡舟才會靠岸。",
	]
	dialogue_index = 0
	mode = Mode.DIALOGUE
	dialogue_name.text = "守渡人"
	_show_dialogue_line()
	dialogue_layer.visible = true
	_play(sfx_dialogue)
	hint_label.text = "聆聽守渡人……"


func _show_dialogue_line() -> void:
	if dialogue_index < dialogue_lines.size():
		dialogue_body.text = dialogue_lines[dialogue_index]
		if dialogue_index >= dialogue_lines.size() - 1:
			btn_continue.text = "明白" if dialogue_kind == "intro" else "受考驗"
		else:
			btn_continue.text = "繼續"


func _on_dialogue_continue() -> void:
	_play(sfx_click)
	dialogue_index += 1
	if dialogue_index < dialogue_lines.size():
		_show_dialogue_line()
		return
	dialogue_layer.visible = false
	mode = Mode.EXPLORE
	if dialogue_kind == "master":
		combat_unlocked = true
		hint_label.text = "考驗通過 · 點擊碧鱗河妖開戰 · 點擊地面移動"
	else:
		hint_label.text = "點擊地面移動 · 點綠光與守渡人對話 · 通過考驗後點碧鱗河妖開戰"
	queue_redraw()


func _start_combat() -> void:
	mode = Mode.COMBAT
	monster_hp = MONSTER_MAX_HP if monster_hp <= 0 else monster_hp
	if monster_hp <= 0:
		monster_hp = MONSTER_MAX_HP
	player_combat_hp.value = player_hp
	monster_combat_hp.value = monster_hp
	combat_log.text = "碧鱗河妖護著濁氣堵住的靈泉，擋路。選擇行動。"
	btn_attack.disabled = false
	btn_flee.disabled = false
	combat_layer.visible = true
	_play(sfx_click)


func _on_attack() -> void:
	if mode != Mode.COMBAT:
		return
	_play(sfx_hit)
	monster_hp = max(0, monster_hp - PLAYER_ATK)
	monster_combat_hp.value = monster_hp
	combat_log.text = "阿衡出掌，造成 %d 傷害！" % PLAYER_ATK

	if monster_hp <= 0:
		_win_combat()
		return

	# Monster counter
	await get_tree().create_timer(0.45).timeout
	if mode != Mode.COMBAT:
		return
	_play(sfx_hit)
	player_hp = max(1, player_hp - MONSTER_ATK)  # keep at least 1 for MVP
	player_combat_hp.value = player_hp
	_refresh_hud()
	combat_log.text = "碧鱗河妖反撲，你受到 %d 傷害。" % MONSTER_ATK


func _on_flee() -> void:
	_play(sfx_click)
	combat_layer.visible = false
	mode = Mode.EXPLORE
	hint_label.text = "你退回岸邊。點擊碧鱗河妖可再戰。"


func _win_combat() -> void:
	monster_defeated = true
	combat_layer.visible = false
	mode = Mode.WIN
	win_layer.visible = true
	_play(sfx_win)
	hint_label.text = "勝利！靈泉稍清，渡舟靠岸。"
	queue_redraw()


func _on_win_ok() -> void:
	_play(sfx_click)
	win_layer.visible = false
	mode = Mode.EXPLORE
	hint_label.text = "碧鱗河妖已退，渡舟已靠岸。可再與守渡人對話，或在渡口走動。"
	# Soft heal after win
	player_hp = mini(PLAYER_MAX_HP, player_hp + 20)
	_refresh_hud()
