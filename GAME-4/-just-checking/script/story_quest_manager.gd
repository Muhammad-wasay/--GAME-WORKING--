extends Node3D
class_name StoryQuestManager

enum QuestStage {
	EXPLORE_FOREST,
	BOSS_ENCOUNTER_DIALOGUE,
	FOLLOW_BOSS_TO_CAGE,
	CAGE_AMBUSH_FIGHT,
	KILL_BOSS_FOR_KEY,
	UNLOCK_CAGE,
	ESCAPE_WITH_JESSICA,
	GAME_COMPLETED
}

# ===== AUDIO STREAMS (VOICES & SIREN) =====
var VOICE_BOSS_01: AudioStream = null
var VOICE_ROY_01: AudioStream = null
var VOICE_BOSS_02: AudioStream = null
var VOICE_BOSS_03: AudioStream = null
var VOICE_ROY_02: AudioStream = null
var VOICE_JESSICA_SCREAM: AudioStream = null
var VOICE_ROY_03: AudioStream = null
var VOICE_BOSS_04: AudioStream = null
var VOICE_BOSS_05: AudioStream = null
var VOICE_JESSICA_RESCUE: AudioStream = null
var VOICE_JESSICA_SIREN: AudioStream = null
var VOICE_ROY_LEAVE: AudioStream = null
var SFX_SIREN: AudioStream = null

func _get_sound(path: String) -> AudioStream:
	if ResourceLoader.exists(path):
		return load(path)
	return null

func _setup_sounds() -> void:
	VOICE_BOSS_01 = _get_sound("res://import/sound/msg box sounds/boss_01_looking_for.mp3")
	VOICE_ROY_01 = _get_sound("res://import/sound/msg box sounds/roy_01_who_are_you.mp3")
	VOICE_BOSS_02 = _get_sound("res://import/sound/msg box sounds/boss_02_finally_here.mp3")
	VOICE_BOSS_03 = _get_sound("res://import/sound/msg box sounds/boss_03_killed_her.mp3")
	VOICE_ROY_02 = _get_sound("res://import/sound/msg box sounds/roy_02_jessica_jessica.mp3")
	VOICE_JESSICA_SCREAM = _get_sound("res://import/sound/msg box sounds/jessica_scream_roy.mp3")
	VOICE_ROY_03 = _get_sound("res://import/sound/msg box sounds/roy_03_kill_you.mp3")
	VOICE_BOSS_04 = _get_sound("res://import/sound/msg box sounds/boss_04_catch_me.mp3")
	VOICE_BOSS_05 = _get_sound("res://import/sound/msg box sounds/boss_05_rise_puppets.mp3")
	VOICE_JESSICA_RESCUE = _get_sound("res://import/sound/msg box sounds/jessica_01_thank_god.mp3")
	VOICE_JESSICA_SIREN = _get_sound("res://import/sound/msg box sounds/jessica-second-phase-voic.mp3")
	if not VOICE_JESSICA_SIREN:
		VOICE_JESSICA_SIREN = _get_sound("res://import/sound/msg box sounds/jessica_02_whats_siren.mp3")
	if not VOICE_JESSICA_SIREN:
		VOICE_JESSICA_SIREN = _get_sound("res://import/sound/msg box sounds/jessica_siren.mp3")
	VOICE_ROY_LEAVE = _get_sound("res://import/sound/msg box sounds/roy_seond-phase-voice.mp3")
	if not VOICE_ROY_LEAVE:
		VOICE_ROY_LEAVE = _get_sound("res://import/sound/msg box sounds/roy_04_leave_area.mp3")
	if not VOICE_ROY_LEAVE:
		VOICE_ROY_LEAVE = _get_sound("res://import/sound/msg box sounds/roy_leave.mp3")
	SFX_SIREN = _get_sound("res://import/sound/raid-sound.mp3")

# ===== SCENE PRELOADS =====
const ENEMY_2_SCENE = preload("res://scene/enemies/enemy_2.tscn")
const ENEMY_3_SCENE = preload("res://scene/enemies/enemy_3.tscn")
const CAGE_SCENE = preload("res://scene/jessica_cage.tscn")
const END_SCREEN_SCENE = preload("res://scene/end_screen.tscn")
const HINT_PICKUP_SCENE = preload("res://scene/hint_pickup.tscn")

var stage: QuestStage = QuestStage.EXPLORE_FOREST

var roy: CharacterBody3D = null
var boss: ForestEnemy = null
var cage_instance: Node3D = null
var jessica: CharacterBody3D = null
var dialogue_box: StoryDialogueBox = null
var siren_player: AudioStreamPlayer = null
var cinematic_camera: Camera3D = null
var cam_tween: Tween = null
var original_cam_transform: Transform3D

var objective_hud: CanvasLayer = null
var objective_label: Label = null
var wait_warning_label: Label = null

var hint_reader_layer: CanvasLayer = null
var hint_header_label: Label = null
var hint_title_label: Label = null
var hint_body_label: Label = null
var hint_open_cooldown: float = 0.0
var hints_read_indices: Dictionary = {}

var cutscene_layer: CanvasLayer = null
var cutscene_video: VideoStreamPlayer = null
var cutscene_skip_prompt: Label = null
var cutscene_callback: Callable = Callable()

var ambush_minions: Array[ForestEnemy] = []
var ambush_triggered: bool = false
var tent_position: Vector3 = Vector3(23.8, 0.85, -35.2)
var car_position: Vector3 = Vector3(21.77, 0.82, -47.19)
var escape_car: Node3D = null
var escape_car_beacon: Node3D = null
var car_beacon_label: Label3D = null
var car_ring_mat: StandardMaterial3D = null
var car_beam_mat: StandardMaterial3D = null
var car_overlay_mat: StandardMaterial3D = null
var car_pulse_time: float = 0.0
var cage_position: Vector3 = Vector3(32.5, 0.9, 14.5)

var horde_spawn_timer: float = 0.0
var horde_spawned_count: int = 0
const MAX_HORDE: int = 14

func _ready() -> void:
	name = "StoryQuestManager"
	_setup_sounds()
	_setup_hud()
	_setup_dialogue_box()
	_setup_siren_player()
	_setup_cutscene_player()
	_setup_hint_reader_ui()
	
	call_deferred("_initialize_world_elements")

static var _cached_obj_scroll_tex: Texture2D = null

static func _get_clean_objective_scroll_tex() -> Texture2D:
	if _cached_obj_scroll_tex:
		return _cached_obj_scroll_tex
	if ResourceLoader.exists("res://import/objective_scroll_bg.png"):
		var loaded_tex := load("res://import/objective_scroll_bg.png") as Texture2D
		if loaded_tex:
			var img := loaded_tex.get_image()
			if img:
				img = img.duplicate()
				if img.is_compressed():
					img.decompress()
				img.convert(Image.FORMAT_RGBA8)
				for y in range(img.get_height()):
					for x in range(img.get_width()):
						var c := img.get_pixel(x, y)
						if c.r > 0.94 and c.g > 0.94 and c.b > 0.94:
							img.set_pixel(x, y, Color(c.r, c.g, c.b, 0.0))
				var used := img.get_used_rect()
				if used.size.x > 0 and used.size.y > 0:
					img = img.get_region(used)
				_cached_obj_scroll_tex = ImageTexture.create_from_image(img)
				return _cached_obj_scroll_tex
			_cached_obj_scroll_tex = loaded_tex
			return _cached_obj_scroll_tex
	return null

func _setup_hud() -> void:
	objective_hud = CanvasLayer.new()
	objective_hud.layer = 12
	add_child(objective_hud)
	
	# Left-side Scroll Objective Tracker directly below the HP bar
	var left_tracker := MarginContainer.new()
	left_tracker.set_anchors_preset(Control.PRESET_TOP_LEFT)
	left_tracker.add_theme_constant_override("margin_left", 20)
	left_tracker.add_theme_constant_override("margin_top", 56)
	left_tracker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	objective_hud.add_child(left_tracker)
	
	var tracker_panel := PanelContainer.new()
	tracker_panel.custom_minimum_size = Vector2(280, 128)
	tracker_panel.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	tracker_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	var scroll_tex := _get_clean_objective_scroll_tex()
	if scroll_tex:
		var tex_style := StyleBoxTexture.new()
		tex_style.texture = scroll_tex
		# Pad inside the flat yellowish parchment area of the scroll (skipping the left rolled edge & bottom curl)
		tex_style.content_margin_left = 58
		tex_style.content_margin_right = 18
		tex_style.content_margin_top = 14
		tex_style.content_margin_bottom = 26
		tracker_panel.add_theme_stylebox_override("panel", tex_style)
	else:
		var panel_style := StyleBoxFlat.new()
		panel_style.bg_color = Color(0.85, 0.78, 0.56, 0.95)
		panel_style.content_margin_left = 14
		panel_style.content_margin_right = 14
		panel_style.content_margin_top = 10
		panel_style.content_margin_bottom = 10
		tracker_panel.add_theme_stylebox_override("panel", panel_style)
	left_tracker.add_child(tracker_panel)
	
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 3)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tracker_panel.add_child(vbox)
	
	var header_lbl := Label.new()
	header_lbl.text = "OBJECTIVE"
	header_lbl.add_theme_font_size_override("font_size", 13)
	header_lbl.add_theme_color_override("font_color", Color(0.55, 0.12, 0.08, 1.0))
	vbox.add_child(header_lbl)
	
	objective_label = Label.new()
	objective_label.text = "• Pick up the Gun & read Clue #1 near the crates! (0/3)"
	objective_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	objective_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	objective_label.custom_minimum_size = Vector2(200, 0)
	objective_label.add_theme_font_size_override("font_size", 13)
	objective_label.add_theme_color_override("font_color", Color(0.16, 0.10, 0.04, 1.0))
	objective_label.add_theme_constant_override("line_spacing", 2)
	vbox.add_child(objective_label)
	
	wait_warning_label = Label.new()
	wait_warning_label.text = "⚠️ WAIT FOR JESSICA!"
	wait_warning_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	wait_warning_label.add_theme_font_size_override("font_size", 12)
	wait_warning_label.add_theme_color_override("font_color", Color(0.78, 0.10, 0.08, 1.0))
	wait_warning_label.visible = false
	vbox.add_child(wait_warning_label)

func _setup_dialogue_box() -> void:
	dialogue_box = StoryDialogueBox.new()
	add_child(dialogue_box)
	dialogue_box.sequence_finished.connect(_on_dialogue_sequence_finished)
	dialogue_box.line_started.connect(_on_dialogue_line_started)

func _setup_siren_player() -> void:
	if SFX_SIREN:
		siren_player = AudioStreamPlayer.new()
		siren_player.name = "EscapeSirenAudio"
		var s_stream := SFX_SIREN.duplicate()
		if s_stream is AudioStreamMP3:
			s_stream.loop = true
		siren_player.stream = s_stream
		siren_player.volume_db = 1.5
		add_child(siren_player)

func _setup_cutscene_player() -> void:
	cutscene_layer = CanvasLayer.new()
	cutscene_layer.name = "CutsceneVideoLayer"
	cutscene_layer.layer = 25
	cutscene_layer.visible = false
	add_child(cutscene_layer)
	
	var black_bg := ColorRect.new()
	black_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	black_bg.color = Color(0, 0, 0, 1)
	cutscene_layer.add_child(black_bg)
	
	cutscene_video = VideoStreamPlayer.new()
	cutscene_video.name = "CutsceneVideoPlayer"
	cutscene_video.set_anchors_preset(Control.PRESET_FULL_RECT)
	cutscene_video.expand = true
	cutscene_layer.add_child(cutscene_video)
	cutscene_video.finished.connect(_on_cutscene_video_finished)
	
	cutscene_skip_prompt = Label.new()
	cutscene_skip_prompt.text = "Press [SPACE] or [E] to Skip"
	cutscene_skip_prompt.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	cutscene_skip_prompt.offset_left = -260
	cutscene_skip_prompt.offset_top = -45
	cutscene_skip_prompt.add_theme_font_size_override("font_size", 18)
	cutscene_skip_prompt.add_theme_color_override("font_color", Color(1, 1, 1, 0.65))
	cutscene_layer.add_child(cutscene_skip_prompt)

func _play_cutscene(video_paths: Array[String], on_finished: Callable) -> void:
	cutscene_callback = on_finished
	
	var found_path := ""
	for p in video_paths:
		if ResourceLoader.exists(p):
			found_path = p
			break
	
	if found_path != "" and cutscene_video:
		var stream = load(found_path)
		if stream is VideoStream:
			if roy:
				roy.dialogue_locked = true
			cutscene_layer.visible = true
			cutscene_video.stream = stream
			cutscene_video.play()
			return
	
	# If no video file is present yet, immediately proceed with in-game story
	if cutscene_callback.is_valid():
		var cb := cutscene_callback
		cutscene_callback = Callable()
		cb.call()

func _on_cutscene_video_finished() -> void:
	if cutscene_layer and cutscene_layer.visible:
		cutscene_layer.visible = false
		if cutscene_video:
			cutscene_video.stop()
		if roy:
			roy.dialogue_locked = false
		if cutscene_callback.is_valid():
			var cb := cutscene_callback
			cutscene_callback = Callable()
			cb.call()

func _setup_hint_reader_ui() -> void:
	hint_reader_layer = CanvasLayer.new()
	hint_reader_layer.name = "HintReaderLayer"
	hint_reader_layer.layer = 28
	hint_reader_layer.visible = false
	add_child(hint_reader_layer)
	
	# Dimmed forest backdrop
	var backdrop := ColorRect.new()
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0.02, 0.02, 0.01, 0.76)
	hint_reader_layer.add_child(backdrop)
	
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	hint_reader_layer.add_child(center)
	
	# Container for the user's Torn Parchment Background Image + Note Text
	var paper_holder := Control.new()
	paper_holder.custom_minimum_size = Vector2(640, 540)
	center.add_child(paper_holder)
	
	var paper_bg := TextureRect.new()
	paper_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	paper_bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	paper_bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	paper_bg.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var clean_tex := HintPickup.get_clean_parchment_texture()
	if clean_tex:
		paper_bg.texture = clean_tex
	elif ResourceLoader.exists("res://import/hint_paper_bg.png"):
		paper_bg.texture = load("res://import/hint_paper_bg.png")
	paper_holder.add_child(paper_bg)
	
	# Margin container padded inside the torn paper boundaries
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 92)
	margin.add_theme_constant_override("margin_right", 92)
	margin.add_theme_constant_override("margin_top", 78)
	margin.add_theme_constant_override("margin_bottom", 74)
	paper_holder.add_child(margin)
	
	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 12)
	margin.add_child(vbox)
	
	hint_header_label = Label.new()
	hint_header_label.text = "📜 THE BOSS'S TAUNT — CLUE #1 OF 3"
	hint_header_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_header_label.add_theme_font_size_override("font_size", 15)
	hint_header_label.add_theme_color_override("font_color", Color(0.62, 0.10, 0.08, 1.0))
	vbox.add_child(hint_header_label)
	
	hint_title_label = Label.new()
	hint_title_label.text = "CLUE #1 — THE CAMPFIRE WARNING"
	hint_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_title_label.add_theme_font_size_override("font_size", 22)
	hint_title_label.add_theme_color_override("font_color", Color(0.20, 0.10, 0.04, 1.0))
	vbox.add_child(hint_title_label)
	
	var divider := ColorRect.new()
	divider.custom_minimum_size = Vector2(0, 2)
	divider.color = Color(0.48, 0.26, 0.12, 0.55)
	vbox.add_child(divider)
	
	hint_body_label = Label.new()
	hint_body_label.text = ""
	hint_body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint_body_label.custom_minimum_size = Vector2(440, 180)
	hint_body_label.add_theme_font_size_override("font_size", 18)
	hint_body_label.add_theme_color_override("font_color", Color(0.15, 0.08, 0.03, 1.0))
	hint_body_label.add_theme_constant_override("line_spacing", 5)
	vbox.add_child(hint_body_label)
	
	var sig_label := Label.new()
	sig_label.text = "— The Forest Master 🩸"
	sig_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	sig_label.add_theme_font_size_override("font_size", 18)
	sig_label.add_theme_color_override("font_color", Color(0.60, 0.08, 0.08, 1.0))
	vbox.add_child(sig_label)
	
	var close_prompt := Label.new()
	close_prompt.text = "Press [E], [SPACE], or [ESC] to Close Note"
	close_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	close_prompt.add_theme_font_size_override("font_size", 15)
	close_prompt.add_theme_color_override("font_color", Color(0.35, 0.20, 0.09, 0.95))
	vbox.add_child(close_prompt)

func open_hint_reader(hint_idx: int, title_text: String, body_text: String) -> void:
	if not hint_reader_layer:
		return
	hint_open_cooldown = 0.22
	hints_read_indices[hint_idx] = true
	var read_count: int = hints_read_indices.size()
	
	if hint_header_label:
		hint_header_label.text = "📜 THE BOSS'S TAUNT — CLUE #%d OF 3  (Found: %d/3)" % [hint_idx, read_count]
	if hint_title_label:
		hint_title_label.text = title_text
	if hint_body_label:
		hint_body_label.text = body_text
	
	hint_reader_layer.visible = true
	if is_instance_valid(roy):
		roy.dialogue_locked = true
	
	# Dynamically update the Objective HUD based on which clue was read!
	if stage == QuestStage.EXPLORE_FOREST:
		if read_count >= 3 or hint_idx == 3:
			_update_objective("OBJECTIVE: All Clues Found (3/3) — Confront the Villain Boss in the clearing ahead!")
		elif hint_idx == 2 or read_count == 2:
			_update_objective("OBJECTIVE: Clue 2/3 Found — Head toward the river clearing to find Clue #3!")
		else:
			_update_objective("OBJECTIVE: Clue 1/3 Found — Follow the forest trail past the minions to find Clue #2!")

func close_hint_reader() -> void:
	if hint_reader_layer and hint_reader_layer.visible:
		hint_reader_layer.visible = false
		if is_instance_valid(roy):
			roy.dialogue_locked = false

func _spawn_forest_hints(scene: Node) -> void:
	if not HINT_PICKUP_SCENE or not scene:
		return
	var hints_data: Array[Dictionary] = [
		{
			"index": 1,
			"pos": Vector3(23.8, 1.2, -24.8),
			"title": "CLUE #1 — THE CAMPFIRE WARNING",
			"body": "\"So you finally woke up, Roy? Too late.\nYour precious Jessica screamed your name as my puppets dragged her deep into the mist.\nIf you think that little pistol can save her, follow the dirt trail past the wooden crates toward the river... if you dare.\""
		},
		{
			"index": 2,
			"pos": Vector3(12.2, 1.2, -11.5),
			"title": "CLUE #2 — THE PUPPET MASTER'S TRAIL",
			"body": "\"Still breathing? My wooden mannequins were only a warm-up.\nI have locked Jessica inside an iron cage beyond the river clearing.\nMy dark magic shields me as long as my guards stand. Keep walking northwest toward the water... your grave awaits.\""
		},
		{
			"index": 3,
			"pos": Vector3(2.8, 1.2, -3.2),
			"title": "CLUE #3 — THE GOLDEN KEY",
			"body": "\"You can hear the river now, can't you?\nI hold the Golden Cage Key right here in my hands.\nStep forward into the clearing and face me eye-to-eye, Roy... before I finish her off myself!\""
		}
	]
	for h in hints_data:
		var node_name := "BossHint_%d" % int(h["index"])
		var existing := scene.find_child(node_name, true, false)
		if existing:
			continue
		var hint_node := HINT_PICKUP_SCENE.instantiate() as Node3D
		hint_node.name = node_name
		hint_node.set("hint_index", int(h["index"]))
		hint_node.set("hint_title", String(h["title"]))
		hint_node.set("hint_body", String(h["body"]))
		hint_node.position = h["pos"]
		scene.add_child(hint_node)

func _unhandled_input(event: InputEvent) -> void:
	if OS.is_debug_build() or true:
		if event is InputEventKey and event.pressed and event.keycode == KEY_F9:
			print("[StoryQuestManager] F9 Pressed: Triggering Comic Book Ending Sequence!")
			_complete_game_at_tent()
	if hint_reader_layer and hint_reader_layer.visible and hint_open_cooldown <= 0.0:
		if event.is_action_pressed("interact") or event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.pressed and (event.keycode == KEY_SPACE or event.keycode == KEY_ESCAPE or event.keycode == KEY_E)):
			close_hint_reader()
			get_viewport().set_input_as_handled()
			return
	if cutscene_layer and cutscene_layer.visible:
		if event.is_action_pressed("ui_accept") or event.is_action_pressed("interact") or (event is InputEventKey and event.pressed and event.keycode == KEY_SPACE):
			_on_cutscene_video_finished()

var has_cage_key: bool = false
var cage_prompt_label: Label3D = null

func _initialize_world_elements() -> void:
	var scene := get_tree().current_scene
	if not scene:
		return
	
	roy = scene.find_child("Roy", true, false) as CharacterBody3D
	boss = scene.find_child("Enemy1_Boss", true, false) as ForestEnemy
	
	if roy:
		tent_position = roy.global_position
	
	# Find the Escape Car in world.tscn (World/Terrain/car)
	escape_car = scene.find_child("car", true, false) as Node3D
	if not escape_car:
		escape_car = scene.find_child("Simca10001966", true, false) as Node3D
	if escape_car:
		car_position = escape_car.global_position
	
	# Find user's existing Jessica in world.tscn (named 'female' or 'Jessica')
	jessica = scene.find_child("female", true, false) as CharacterBody3D
	if not jessica:
		jessica = scene.find_child("Jessica", true, false) as CharacterBody3D
	
	# Find user's existing Cage in world.tscn (Node3D3 or node containing CAGE)
	var found_cage: Node3D = null
	for child in scene.get_children():
		if child.name == "Node3D3" or child.name.to_lower().contains("cage"):
			found_cage = child
			break
	
	if found_cage:
		cage_instance = found_cage
		cage_position = cage_instance.global_position
	elif CAGE_SCENE:
		cage_instance = CAGE_SCENE.instantiate()
		scene.add_child(cage_instance)
		cage_instance.global_position = cage_position
		if not jessica:
			jessica = cage_instance.find_child("Jessica", true, false) as CharacterBody3D
	
	# Configure Jessica as trapped NPC companion
	if jessica:
		jessica.is_npc_companion = true
		jessica.is_caged = true
		jessica.is_following_roy = false
	
	# Setup 3D overhead prompt on the Cage
	_setup_cage_prompt()
	
	# Spawn the 3 Boss Clue Notes along the forest trail
	_spawn_forest_hints(scene)
	
	# Prepare Boss for Stage 1 Encounter
	if boss:
		boss.invulnerable = true
		boss.story_frozen = true
		boss.enemy_died.connect(_on_boss_died)
	
	_update_objective("OBJECTIVE: Pick up the Gun & read Clue #1 near the crates! (Clues: 0/3)")

func _setup_cage_prompt() -> void:
	if not is_instance_valid(cage_instance):
		return
	cage_prompt_label = Label3D.new()
	cage_prompt_label.name = "CagePromptLabel"
	cage_prompt_label.text = "Locked! Defeat the Boss to get Key"
	cage_prompt_label.font_size = 20
	cage_prompt_label.pixel_size = 0.0020
	cage_prompt_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	cage_prompt_label.no_depth_test = true
	cage_prompt_label.modulate = Color(1.0, 0.35, 0.3, 1.0)
	cage_prompt_label.outline_size = 6
	cage_prompt_label.outline_modulate = Color(0, 0, 0, 0.95)
	cage_prompt_label.position = Vector3(0, 1.6, 0)
	cage_prompt_label.visible = false
	cage_instance.add_child(cage_prompt_label)

func _update_objective(msg: String) -> void:
	if objective_label:
		var formatted := msg.replace("OBJECTIVE: ", "• ")
		if not formatted.begins_with("• ") and not formatted.begins_with("🚨"):
			formatted = "• " + formatted
		if objective_label.text == formatted:
			return
		objective_label.text = formatted
		var t := create_tween()
		objective_label.modulate.a = 0.25
		t.tween_property(objective_label, "modulate:a", 1.0, 0.30)

func _process(delta: float) -> void:
	if hint_open_cooldown > 0.0:
		hint_open_cooldown = max(0.0, hint_open_cooldown - delta)
	elif hint_reader_layer and hint_reader_layer.visible:
		if Input.is_action_just_pressed("interact") or Input.is_action_just_pressed("ui_accept") or Input.is_action_just_pressed("ui_cancel"):
			close_hint_reader()
			return
	
	if not is_instance_valid(roy):
		return
	
	match stage:
		QuestStage.EXPLORE_FOREST:
			if is_instance_valid(boss):
				var dist_to_boss := roy.global_position.distance_to(boss.global_position)
				if dist_to_boss <= 8.5:
					# Face-to-Face check: Roy must be facing generally towards Boss
					var roy_cam := roy.get_node_or_null("camera_mount/Camera3D") as Camera3D
					var forward_dir: Vector3 = Vector3.FORWARD
					if roy_cam:
						forward_dir = -roy_cam.global_transform.basis.z
					elif "visuals" in roy and roy.visuals:
						forward_dir = -roy.visuals.global_transform.basis.z
					forward_dir.y = 0.0
					var to_boss: Vector3 = (boss.global_position - roy.global_position)
					to_boss.y = 0.0
					if forward_dir.length_squared() > 0.01 and to_boss.length_squared() > 0.01:
						var dot_facing: float = forward_dir.normalized().dot(to_boss.normalized())
						if dot_facing > 0.35: # Roy is looking towards the Boss
							_start_boss_confrontation_dialogue()
		
		QuestStage.FOLLOW_BOSS_TO_CAGE:
			var dist_to_cage := roy.global_position.distance_to(cage_position)
			if dist_to_cage <= 10.0 and not ambush_triggered:
				_trigger_cage_ambush()
		
		QuestStage.CAGE_AMBUSH_FIGHT:
			# Continuously filter out dead, deleted, or fallen minions so the player never gets stuck
			ambush_minions = ambush_minions.filter(func(m): 
				return is_instance_valid(m) and m.state != ForestEnemy.State.DEAD and m.global_position.y > -2.5
			)
			if ambush_minions.is_empty():
				_unlock_boss_fight()
			else:
				_update_objective("OBJECTIVE: Defeat the Mannequin Minions! (%d remaining)" % ambush_minions.size())
		
		QuestStage.ESCAPE_WITH_JESSICA:
			_process_escape_stage(delta)
	
	# Handle Cage interaction prompt & unlock
	if is_instance_valid(cage_instance) and is_instance_valid(roy):
		var dist_cage := roy.global_position.distance_to(cage_position)
		if dist_cage <= 3.8:
			if cage_prompt_label:
				cage_prompt_label.visible = true
				if stage == QuestStage.UNLOCK_CAGE and (has_cage_key or (roy.has_method("has_key") and roy.has_key())):
					cage_prompt_label.text = "Press E to Unlock Jessica's Cage [Key Ready]"
					cage_prompt_label.modulate = Color(0.35, 1.0, 0.55, 1.0)
					if Input.is_action_just_pressed("interact"):
						_unlock_cage_with_puff()
				else:
					cage_prompt_label.text = "Locked! Defeat the Boss to get Key"
					cage_prompt_label.modulate = Color(1.0, 0.35, 0.3, 1.0)
					if Input.is_action_just_pressed("interact"):
						if roy.has_method("show_tip_message"):
							roy.show_tip_message("Cage is Locked! Kill the Boss to get the Key first!", 2.5)
		else:
			if cage_prompt_label:
				cage_prompt_label.visible = false

# ===== 1. FIRST BOSS ENCOUNTER & DIALOGUE =====
func _start_boss_confrontation_dialogue() -> void:
	stage = QuestStage.BOSS_ENCOUNTER_DIALOGUE
	roy.dialogue_locked = true
	roy.face_world_position(boss.global_position)
	if boss:
		boss.story_frozen = true
		var to_roy := roy.global_position - boss.global_position
		to_roy.y = 0.0
		if to_roy.length_squared() > 0.001:
			boss._face_direction(to_roy.normalized(), 1.0)
	
	_update_objective("BOSS ENCOUNTER")
	
	# Setup cinematic dialogue camera
	if not cinematic_camera:
		cinematic_camera = Camera3D.new()
		cinematic_camera.name = "CinematicDialogueCam"
		cinematic_camera.fov = 54.0
		add_child(cinematic_camera)
	
	var r_cam := roy.get_node_or_null("camera_mount/Camera3D") as Camera3D
	if r_cam:
		original_cam_transform = r_cam.global_transform
		cinematic_camera.global_transform = original_cam_transform
		cinematic_camera.current = true
	
	var lines: Array = [
		{
			"speaker": "VILLAIN BOSS",
			"text": "What are you looking for?",
			"voice": VOICE_BOSS_01,
			"color": Color(0.85, 0.18, 0.15),
			"pause_after": 0.5
		},
		{
			"speaker": "ROY",
			"text": "Who are you?! And what have you done to Jessica?!",
			"voice": VOICE_ROY_01,
			"color": Color(0.25, 0.55, 0.95),
			"pause_after": 0.5
		},
		{
			"speaker": "VILLAIN BOSS",
			"text": "Oh... so you are finally here.",
			"voice": VOICE_BOSS_02,
			"color": Color(0.85, 0.18, 0.15),
			"pause_after": 0.4
		},
		{
			"speaker": "...",
			"text": ". . .",
			"voice": null,
			"duration": 1.4,
			"color": Color(0.5, 0.5, 0.5),
			"pause_after": 0.4
		},
		{
			"speaker": "VILLAIN BOSS",
			"text": "I have killed her.",
			"voice": VOICE_BOSS_03,
			"color": Color(0.85, 0.18, 0.15),
			"pause_after": 0.4
		},
		{
			"speaker": "ROY",
			"text": "Jessica! Jessica!!",
			"voice": VOICE_ROY_02,
			"color": Color(0.25, 0.55, 0.95),
			"pause_after": 0.35
		},
		{
			"speaker": "JESSICA (DISTANT)",
			"text": "ROYYYYYY!!!!!!!",
			"voice": VOICE_JESSICA_SCREAM,
			"color": Color(1.0, 0.22, 0.4),
			"is_scream": true,
			"pause_after": 0.6
		},
		{
			"speaker": "ROY",
			"text": "Now you are done and dusted... I will kill you!!",
			"voice": VOICE_ROY_03,
			"color": Color(0.25, 0.55, 0.95),
			"pause_after": 0.5
		},
		{
			"speaker": "VILLAIN BOSS",
			"text": "Hahaha! For this... you have to catch me!",
			"voice": VOICE_BOSS_04,
			"color": Color(0.85, 0.18, 0.15),
			"pause_after": 0.5
		}
	]
	
	dialogue_box.play_sequence("encounter_1", lines)

func _safe_dialogue_camera_transform(look_at_pos: Vector3, desired_cam_pos: Vector3, min_ground_clearance: float = 0.36) -> Transform3D:
	var safe_pos := desired_cam_pos
	
	if is_inside_tree() and get_world_3d():
		var space_state := get_world_3d().direct_space_state
		if space_state:
			# 1. Line-of-sight raycast from look_at_pos (character's face) to desired_cam_pos
			var los_exclude: Array[RID] = []
			if is_instance_valid(roy):
				los_exclude.append(roy.get_rid())
			if is_instance_valid(boss):
				los_exclude.append(boss.get_rid())
			if is_instance_valid(jessica):
				los_exclude.append(jessica.get_rid())
			
			var los_q := PhysicsRayQueryParameters3D.create(look_at_pos, desired_cam_pos)
			los_q.exclude = los_exclude
			var los_res := space_state.intersect_ray(los_q)
			if los_res and los_res.has("position"):
				var hit_p: Vector3 = los_res.position
				var hit_norm: Vector3 = los_res.get("normal", Vector3.UP)
				safe_pos = hit_p + (hit_norm * 0.18)
				var to_look := look_at_pos - safe_pos
				if to_look.length() < 0.28:
					safe_pos = look_at_pos - (to_look.normalized() * 0.28)
			
			# 2. Downward ground clearance check: ensure camera never dips inside terrain/rocks
			var down_q := PhysicsRayQueryParameters3D.create(safe_pos + Vector3(0.0, 1.6, 0.0), safe_pos + Vector3(0.0, -2.8, 0.0))
			down_q.exclude = los_exclude
			var down_res := space_state.intersect_ray(down_q)
			if down_res and down_res.has("position"):
				var ground_y: float = down_res.position.y
				if safe_pos.y < ground_y + min_ground_clearance:
					safe_pos.y = ground_y + min_ground_clearance
	
	var dir_to_look := look_at_pos - safe_pos
	if dir_to_look.length_squared() < 0.0001:
		dir_to_look = Vector3.FORWARD
	var cam_basis := Basis.looking_at(dir_to_look.normalized(), Vector3.UP)
	return Transform3D(cam_basis, safe_pos)

func _on_dialogue_line_started(speaker: String, entry: Dictionary) -> void:
	if not is_instance_valid(cinematic_camera) or not is_instance_valid(roy):
		return
	
	if cam_tween and cam_tween.is_valid():
		cam_tween.kill()
	
	var is_scream: bool = entry.get("is_scream", false)
	var is_mannequins_rising: bool = entry.get("is_mannequins_rising", false)
	
	if speaker == "VILLAIN BOSS":
		if not is_instance_valid(boss):
			return
		# Boss face focus at actual eye level (approx 0.78m above ground)
		var boss_face := boss.global_position + Vector3(0.0, 0.78, 0.0)
		var to_roy := (roy.global_position - boss.global_position)
		to_roy.y = 0.0
		var to_roy_dir := to_roy.normalized() if to_roy.length_squared() > 0.001 else -boss.global_transform.basis.z
		var boss_side := Vector3(to_roy_dir.z, 0.0, -to_roy_dir.x)
		
		# Safe menacing framing on Boss's face
		var desired_cam := boss_face + (to_roy_dir * 1.30) + (boss_side * 0.32) + Vector3(0.0, 0.06, 0.0)
		var target_transform := _safe_dialogue_camera_transform(boss_face, desired_cam, 0.45)
		cinematic_camera.fov = 48.0
		
		cam_tween = create_tween()
		cam_tween.tween_property(cinematic_camera, "global_transform", target_transform, 0.48).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		
	elif speaker == "ROY":
		# Roy face focus at actual eye level (0.33m above ground for 0.3 scale)
		var roy_face := roy.global_position + Vector3(0.0, 0.33, 0.0)
		var to_target: Vector3
		if is_instance_valid(boss) and stage == QuestStage.BOSS_ENCOUNTER_DIALOGUE:
			to_target = (boss.global_position - roy.global_position)
		elif is_instance_valid(jessica):
			to_target = (jessica.global_position - roy.global_position)
		else:
			to_target = -roy.global_transform.basis.z
		to_target.y = 0.0
		var to_target_dir := to_target.normalized() if to_target.length_squared() > 0.001 else -roy.global_transform.basis.z
		var roy_side := Vector3(-to_target_dir.z, 0.0, to_target_dir.x)
		
		# Close cinematic medium shot cleanly centered on Roy's face, elevated above terrain slope
		var desired_cam := roy_face + (to_target_dir * 0.58) + (roy_side * 0.16) + Vector3(0.0, 0.13, 0.0)
		var target_transform := _safe_dialogue_camera_transform(roy_face, desired_cam, 0.36)
		cinematic_camera.fov = 44.0
		
		cam_tween = create_tween()
		cam_tween.tween_property(cinematic_camera, "global_transform", target_transform, 0.48).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		
	elif speaker == "JESSICA" or speaker.begins_with("JESSICA"):
		if is_instance_valid(jessica):
			var jess_face := jessica.global_position + Vector3(0.0, 0.72, 0.0)
			var to_roy := (roy.global_position - jessica.global_position)
			to_roy.y = 0.0
			var to_roy_dir := to_roy.normalized() if to_roy.length_squared() > 0.001 else -jessica.global_transform.basis.z
			var jess_side := Vector3(-to_roy_dir.z, 0.0, to_roy_dir.x)
			
			# Camera in front of Jessica at eye level
			var desired_cam := jess_face + (to_roy_dir * 1.15) + (jess_side * 0.22) + Vector3(0.0, 0.08, 0.0)
			var target_transform := _safe_dialogue_camera_transform(jess_face, desired_cam, 0.40)
			cinematic_camera.fov = 46.0
			
			cam_tween = create_tween()
			cam_tween.tween_property(cinematic_camera, "global_transform", target_transform, 0.48).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			
	elif speaker == "..." or is_mannequins_rising:
		var focus_p := roy.global_position
		if is_instance_valid(jessica):
			focus_p = (roy.global_position + jessica.global_position) * 0.5
		
		# Spawn minions further away towards the forest edge (~7.5m - 9m away)
		var spawn_offsets: Array[Vector3] = [
			Vector3(-6.8, 0.0, -6.5),
			Vector3(6.8, 0.0, -6.5)
		]
		for i in range(spawn_offsets.size()):
			var minion_scene: PackedScene = ENEMY_3_SCENE if (i % 2 == 1) else ENEMY_2_SCENE
			var minion := minion_scene.instantiate() as ForestEnemy
			minion.is_emerging = true
			get_tree().current_scene.add_child(minion)
			minion.scale = Vector3(0.32, 0.32, 0.32)
			
			var spawn_pos := focus_p + spawn_offsets[i]
			var space_state := minion.get_world_3d().direct_space_state
			var ray_q := PhysicsRayQueryParameters3D.create(spawn_pos + Vector3(0, 4.0, 0), spawn_pos + Vector3(0, -6.0, 0))
			var ray_res := space_state.intersect_ray(ray_q)
			if ray_res and ray_res.has("position"):
				spawn_pos = ray_res.position + Vector3(0, 0.02, 0)
			
			minion.global_position = spawn_pos
			minion.run_speed = 1.30
			minion.detection_range = 999.0
			minion.lose_interest_range = 999.0
			minion.persistent_chase = true
			minion.emerge_from_ground(1.6)
		
		# Dramatic wide camera looking out into the distant woods towards the emerging horde
		var target_look := focus_p + Vector3(0.0, 0.5, -6.5)
		var cam_pos := focus_p + Vector3(0.0, 1.15, 2.8)
		var target_basis := Basis.looking_at((target_look - cam_pos).normalized(), Vector3.UP)
		var target_transform := Transform3D(target_basis, cam_pos)
		
		cam_tween = create_tween()
		cam_tween.tween_property(cinematic_camera, "global_transform", target_transform, 0.52).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		_shake_cinematic_camera(1.8, 0.035)

	if is_scream:
		_shake_cinematic_camera(0.65, 0.04)

func _shake_cinematic_camera(duration: float, intensity: float) -> void:
	if not is_instance_valid(cinematic_camera):
		return
	var st := create_tween()
	var original_pos := cinematic_camera.position
	for i in range(6):
		var offset := Vector3(randf_range(-intensity, intensity), randf_range(-intensity, intensity), 0.0)
		st.tween_property(cinematic_camera, "position", original_pos + offset, duration / 6.0)
	st.tween_property(cinematic_camera, "position", original_pos, 0.05)

func _on_dialogue_sequence_finished(sequence_id: String) -> void:
	if sequence_id == "encounter_1":
		stage = QuestStage.FOLLOW_BOSS_TO_CAGE
		_update_objective("OBJECTIVE: Follow the Boss to save Jessica!")
		
		# Return camera to Roy's gameplay camera
		var r_cam := roy.get_node_or_null("camera_mount/Camera3D") as Camera3D
		if is_instance_valid(cinematic_camera) and is_instance_valid(r_cam):
			var ret_tween := create_tween()
			ret_tween.tween_property(cinematic_camera, "global_transform", r_cam.global_transform, 0.45).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			ret_tween.tween_callback(func():
				if is_instance_valid(r_cam):
					r_cam.current = true
				if is_instance_valid(cinematic_camera):
					cinematic_camera.current = false
				if is_instance_valid(roy):
					roy.dialogue_locked = false
			)
		else:
			if is_instance_valid(roy):
				roy.dialogue_locked = false
				
		if boss:
			# Boss retreats using safe dry clearing waypoints to the cage clearing
			var end_p := cage_position + Vector3(0.0, 0.0, -2.4)
			var wp1 := Vector3(-0.8, 0.68, 4.5)
			var wp2 := Vector3(0.8, 0.72, 7.2)
			boss.retreat_to_position(end_p, [wp1, wp2, end_p])
			
	elif sequence_id == "jessica_rescue":
		var r_cam := roy.get_node_or_null("camera_mount/Camera3D") as Camera3D
		if is_instance_valid(cinematic_camera) and is_instance_valid(r_cam):
			var ret_tween := create_tween()
			ret_tween.tween_property(cinematic_camera, "global_transform", r_cam.global_transform, 0.45).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			ret_tween.tween_callback(func():
				if is_instance_valid(r_cam):
					r_cam.current = true
				if is_instance_valid(cinematic_camera):
					cinematic_camera.current = false
				if is_instance_valid(roy):
					roy.dialogue_locked = false
			)
		else:
			if is_instance_valid(roy):
				roy.dialogue_locked = false
		_start_horde_escape()

# ===== 2. CAGE AMBUSH & MINIONS RISING FROM GROUND =====
func _trigger_cage_ambush() -> void:
	ambush_triggered = true
	stage = QuestStage.CAGE_AMBUSH_FIGHT
	_update_objective("OBJECTIVE: Defeat the Mannequin Minions! (4 remaining)")
	
	if boss:
		boss.story_frozen = true
		boss.invulnerable = true
		boss._play_anim("idle", true)
	
	# Boss voice: "Rise, my puppets! Tear him apart!"
	if VOICE_BOSS_05:
		var p_audio := AudioStreamPlayer.new()
		p_audio.stream = VOICE_BOSS_05
		p_audio.volume_db = 4.0
		add_child(p_audio)
		p_audio.play()
		p_audio.finished.connect(p_audio.queue_free)
	
	# Spawn 4 mannequin minions (50/50 brown and yellow) in open spots around the cage
	ambush_minions.clear()
	var spawn_offsets: Array[Vector3] = [
		Vector3(-2.2, 0.0, -1.8),
		Vector3(2.2, 0.0, -1.8),
		Vector3(-1.8, 0.0, 2.0),
		Vector3(1.8, 0.0, 2.0)
	]
	
	for i in range(spawn_offsets.size()):
		var minion_scene: PackedScene = ENEMY_3_SCENE if (i % 2 == 1) else ENEMY_2_SCENE
		var minion := minion_scene.instantiate() as ForestEnemy
		
		# Set is_emerging immediately so gravity doesn't accelerate body during stagger delay
		minion.is_emerging = true
		get_tree().current_scene.add_child(minion)
		minion.scale = Vector3(0.32, 0.32, 0.32)
		
		var target_pos := cage_position + spawn_offsets[i]
		
		# Raycast downwards to snap spawn position directly to the ground surface
		var space_state := minion.get_world_3d().direct_space_state
		var ray_from := target_pos + Vector3(0, 4.0, 0)
		var ray_to := target_pos + Vector3(0, -6.0, 0)
		var ray_query := PhysicsRayQueryParameters3D.create(ray_from, ray_to)
		var ray_res := space_state.intersect_ray(ray_query)
		if ray_res and ray_res.has("position"):
			target_pos = ray_res.position + Vector3(0, 0.02, 0)
		
		minion.global_position = target_pos
		minion.enemy_died.connect(_on_ambush_minion_died)
		ambush_minions.append(minion)
		
		# Stagger emergence slightly for dramatic visual
		var delay := float(i) * 0.18
		get_tree().create_timer(delay).timeout.connect(func():
			if is_instance_valid(minion):
				minion.emerge_from_ground(1.2)
		)

func _on_ambush_minion_died(minion: ForestEnemy) -> void:
	ambush_minions.erase(minion)
	ambush_minions = ambush_minions.filter(func(m): 
		return is_instance_valid(m) and m.state != ForestEnemy.State.DEAD and m.global_position.y > -2.5
	)
	if stage == QuestStage.CAGE_AMBUSH_FIGHT:
		if ambush_minions.is_empty():
			_unlock_boss_fight()
		else:
			_update_objective("OBJECTIVE: Defeat the Mannequin Minions! (%d remaining)" % ambush_minions.size())

func _unlock_boss_fight() -> void:
	if stage != QuestStage.CAGE_AMBUSH_FIGHT:
		return
	stage = QuestStage.KILL_BOSS_FOR_KEY
	_update_objective("OBJECTIVE: Kill the Boss to get the Cage Key!")
	if is_instance_valid(boss):
		boss.invulnerable = false
		boss.story_frozen = false
		boss.alert_group()

func _on_boss_died(_boss_ref: ForestEnemy) -> void:
	if stage == QuestStage.KILL_BOSS_FOR_KEY or stage == QuestStage.CAGE_AMBUSH_FIGHT:
		stage = QuestStage.UNLOCK_CAGE
		_update_objective("OBJECTIVE: Pick up the Key and Unlock Jessica's Cage!")

func on_key_picked_up() -> void:
	has_cage_key = true
	if is_instance_valid(roy) and "has_cage_key" in roy:
		roy.has_cage_key = true
	if stage == QuestStage.UNLOCK_CAGE:
		_update_objective("OBJECTIVE: Go unlock Jessica's Cage! [E]")

func _unlock_cage_with_puff() -> void:
	if stage != QuestStage.UNLOCK_CAGE:
		return
	
	has_cage_key = false
	if is_instance_valid(roy):
		if "has_cage_key" in roy:
			roy.has_cage_key = false
		if roy.has_method("consume_key"):
			roy.consume_key()
	
	# 1. Spawn Toon Cloud Poof VFX directly on the Cage
	var poof_scn := load("res://vfx/enemy_death_vfx.tscn") as PackedScene
	if poof_scn and get_tree().current_scene:
		var poof := poof_scn.instantiate() as Node3D
		get_tree().current_scene.add_child(poof)
		poof.global_position = cage_position + Vector3(0, 0.40, 0)
		poof.scale = Vector3(1.35, 1.35, 1.35)
	
	# 2. Disable cage collisions, shrink with cartoon pop-out, and free
	if is_instance_valid(cage_instance):
		for col in cage_instance.find_children("*", "CollisionShape3D", true, false):
			if col is CollisionShape3D:
				col.set_deferred("disabled", true)
		if cage_prompt_label:
			cage_prompt_label.visible = false
		var t := create_tween()
		t.tween_property(cage_instance, "scale", Vector3(0.01, 0.01, 0.01), 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		t.tween_callback(func():
			if is_instance_valid(cage_instance):
				cage_instance.queue_free()
		)
	
	# 3. Release Jessica directly and trigger siren & post-rescue dialogue
	if is_instance_valid(jessica):
		if jessica.has_method("set_rescued"):
			jessica.set_rescued()
		on_jessica_rescued(jessica)

# ===== 3. JESSICA RESCUED & ESCAPE =====
func on_jessica_rescued(j_node: CharacterBody3D) -> void:
	jessica = j_node
	roy.dialogue_locked = true
	
	# 1. Start emergency siren blaring immediately!
	if siren_player and not siren_player.playing:
		siren_player.play()
	
	# 2. Setup cinematic camera to frame the scene
	if not cinematic_camera:
		cinematic_camera = Camera3D.new()
		cinematic_camera.name = "CinematicDialogueCam"
		cinematic_camera.fov = 54.0
		add_child(cinematic_camera)
	
	var r_cam := roy.get_node_or_null("camera_mount/Camera3D") as Camera3D
	if r_cam:
		original_cam_transform = r_cam.global_transform
		cinematic_camera.global_transform = original_cam_transform
		cinematic_camera.current = true
	
	if roy.has_method("face_world_position"):
		roy.face_world_position(jessica.global_position)
	
	var lines: Array = [
		{
			"speaker": "JESSICA",
			"text": "What... what is that siren sound?!",
			"voice": VOICE_JESSICA_SIREN if VOICE_JESSICA_SIREN else VOICE_JESSICA_RESCUE,
			"color": Color(0.95, 0.45, 0.75),
			"pause_after": 0.45
		},
		{
			"speaker": "ROY",
			"text": "I don't know... We should immediately leave this area!",
			"voice": VOICE_ROY_LEAVE,
			"color": Color(0.25, 0.55, 0.95),
			"pause_after": 0.45
		},
		{
			"speaker": "...",
			"text": ". . .       . . .       . . .",
			"voice": null,
			"duration": 2.2,
			"color": Color(0.85, 0.25, 0.25),
			"pause_after": 0.4,
			"is_mannequins_rising": true
		}
	]
	dialogue_box.play_sequence("jessica_rescue", lines)

func _start_horde_escape() -> void:
	stage = QuestStage.ESCAPE_WITH_JESSICA
	_update_objective("OBJECTIVE: PROTECT JESSICA! Escape together to the Car!")
	_highlight_escape_car()
	
	if is_instance_valid(roy) and "instruction_banner" in roy and is_instance_valid(roy.instruction_banner) and roy.instruction_banner.has_method("hide_banner"):
		roy.instruction_banner.hide_banner()
	
	if siren_player and not siren_player.playing:
		siren_player.play()
	
	horde_spawn_timer = 1.0

func _apply_car_mesh_highlight(node: Node, overlay_mat: Material) -> void:
	if node is MeshInstance3D:
		(node as MeshInstance3D).material_overlay = overlay_mat
	for child in node.get_children():
		_apply_car_mesh_highlight(child, overlay_mat)

func _highlight_escape_car() -> void:
	if is_instance_valid(escape_car_beacon):
		return
	var scene := get_tree().current_scene
	if not scene:
		return
	
	if is_instance_valid(escape_car):
		car_position = escape_car.global_position
		# 1. Apply glowing golden-yellow highlight overlay directly onto the Car meshes
		car_overlay_mat = StandardMaterial3D.new()
		car_overlay_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		car_overlay_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		car_overlay_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		car_overlay_mat.albedo_color = Color(1.0, 0.88, 0.25, 0.36)
		car_overlay_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		_apply_car_mesh_highlight(escape_car, car_overlay_mat)
	
	escape_car_beacon = Node3D.new()
	escape_car_beacon.name = "EscapeCarBeacon"
	scene.add_child(escape_car_beacon)
	escape_car_beacon.global_position = car_position
	
	# 2. Glowing Extraction Ring on the ground around the Car
	var ground_ring := MeshInstance3D.new()
	ground_ring.name = "CarExtractionRing"
	var torus := TorusMesh.new()
	torus.inner_radius = 2.65
	torus.outer_radius = 3.20
	torus.rings = 36
	torus.ring_segments = 16
	car_ring_mat = StandardMaterial3D.new()
	car_ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	car_ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	car_ring_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	car_ring_mat.albedo_color = Color(1.0, 0.88, 0.22, 0.72)
	car_ring_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	torus.material = car_ring_mat
	ground_ring.mesh = torus
	ground_ring.position = Vector3(0.0, 0.08, 0.0)
	escape_car_beacon.add_child(ground_ring)
	
	# 3. Tall Vertical Golden Sky Beam above the Car so player can spot it from far away
	var sky_beam := MeshInstance3D.new()
	sky_beam.name = "CarSkyBeam"
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.45
	cyl.bottom_radius = 1.35
	cyl.height = 18.0
	cyl.radial_segments = 20
	car_beam_mat = StandardMaterial3D.new()
	car_beam_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	car_beam_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	car_beam_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	car_beam_mat.albedo_color = Color(1.0, 0.90, 0.30, 0.20)
	car_beam_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	cyl.material = car_beam_mat
	sky_beam.mesh = cyl
	sky_beam.position = Vector3(0.0, 9.0, 0.0)
	escape_car_beacon.add_child(sky_beam)
	
	# 4. Warm Golden OmniLight3D illuminating the Car
	var car_light := OmniLight3D.new()
	car_light.name = "CarHighlightLight"
	car_light.light_color = Color(1.0, 0.88, 0.35, 1.0)
	car_light.light_energy = 3.2
	car_light.omni_range = 10.0
	car_light.position = Vector3(0.0, 2.4, 0.0)
	escape_car_beacon.add_child(car_light)
	
	# 5. 3D Floating Waypoint Marker Label (visible through trees so player knows where to run!)
	car_beacon_label = Label3D.new()
	car_beacon_label.name = "CarBeaconLabel"
	car_beacon_label.text = "[ ESCAPE CAR ]"
	car_beacon_label.font_size = 24
	car_beacon_label.pixel_size = 0.0022
	car_beacon_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	car_beacon_label.no_depth_test = true
	car_beacon_label.fixed_size = false
	car_beacon_label.modulate = Color(1.0, 0.94, 0.32, 1.0)
	car_beacon_label.outline_size = 8
	car_beacon_label.outline_modulate = Color(0.0, 0.0, 0.0, 0.96)
	car_beacon_label.position = Vector3(0.0, 2.65, 0.0)
	escape_car_beacon.add_child(car_beacon_label)

func _process_escape_stage(delta: float) -> void:
	if not is_instance_valid(jessica):
		return
	
	car_pulse_time += delta * 3.8
	var pulse_01: float = sin(car_pulse_time) * 0.5 + 0.5
	if car_overlay_mat:
		car_overlay_mat.albedo_color.a = lerpf(0.18, 0.52, pulse_01)
	if car_ring_mat:
		car_ring_mat.albedo_color.a = lerpf(0.42, 0.88, pulse_01)
	if car_beam_mat:
		car_beam_mat.albedo_color.a = lerpf(0.11, 0.26, pulse_01)
	
	var dist_jessica_roy := roy.global_position.distance_to(jessica.global_position)
	
	# "Wait for Jessica!" Distance Check
	if dist_jessica_roy > 7.5:
		wait_warning_label.visible = true
	else:
		wait_warning_label.visible = false
	
	# Horde Spawning
	horde_spawn_timer -= delta
	if horde_spawn_timer <= 0.0 and horde_spawned_count < MAX_HORDE:
		horde_spawn_timer = 3.2
		_spawn_chase_minion()
	
	# Escape Car Reach Check & Live Distance Update
	var dist_roy_car := roy.global_position.distance_to(car_position)
	var dist_jessica_car := jessica.global_position.distance_to(car_position)
	var meters_left: int = maxi(0, int(round(dist_roy_car)))
	
	if is_instance_valid(car_beacon_label):
		car_beacon_label.text = "[ ESCAPE CAR — %dm ]" % meters_left
		car_beacon_label.position.y = 2.65 + sin(car_pulse_time * 0.8) * 0.14
	
	_update_objective("OBJECTIVE: PROTECT JESSICA! Escape together to the Car! (%dm)" % meters_left)
	
	# Trigger ONLY when Roy enters inside the glowing extraction circle around the car (<= 3.0m)
	if dist_roy_car <= 3.0:
		if dist_jessica_car <= 4.2:
			_complete_game_at_tent()
		else:
			if roy.has_method("show_tip_message"):
				roy.show_tip_message("Wait for Jessica to enter the Escape Circle!", 1.5)

func _spawn_chase_minion() -> void:
	horde_spawned_count += 1
	var minion_scene: PackedScene = ENEMY_3_SCENE if (randf() < 0.5) else ENEMY_2_SCENE
	var minion := minion_scene.instantiate() as ForestEnemy
	minion.is_emerging = true
	get_tree().current_scene.add_child(minion)
	minion.scale = Vector3(0.32, 0.32, 0.32)
	
	# Spawn 10m to 16m behind the escaping heroes relative to the Escape Car direction
	var behind_dir := (roy.global_position - car_position).normalized()
	var trail_anchor: Vector3 = jessica.global_position if is_instance_valid(jessica) else roy.global_position
	var spawn_dist: float = randf_range(10.0, 16.0)
	var spawn_p := trail_anchor + (behind_dir * spawn_dist) + Vector3(randf_range(-3.5, 3.5), 0, randf_range(-3.5, 3.5))
	
	# Raycast downward to snap accurately to terrain surface
	var space_state := minion.get_world_3d().direct_space_state
	var ray_query := PhysicsRayQueryParameters3D.create(spawn_p + Vector3(0, 5.0, 0), spawn_p + Vector3(0, -7.0, 0))
	var ray_res := space_state.intersect_ray(ray_query)
	if ray_res and ray_res.has("position"):
		spawn_p = ray_res.position + Vector3(0, 0.02, 0)
	
	minion.global_position = spawn_p
	minion.run_speed = 2.85
	minion.attack_range = 0.55
	minion.attack_damage = 15.0
	minion.detection_range = 999.0
	minion.lose_interest_range = 999.0
	minion.persistent_chase = true
	minion.emerge_from_ground(1.15)

# ===== 4. CAR EXTRACTION, ENDING VIDEO & CREDITS =====
#func _unhandled_input(event: InputEvent) -> void:
	

func _complete_game_at_tent() -> void:
	stage = QuestStage.GAME_COMPLETED
	set_process(false)
	
	if siren_player and siren_player.playing:
		siren_player.stop()
	
	if is_instance_valid(escape_car_beacon):
		escape_car_beacon.queue_free()
	
	if wait_warning_label:
		wait_warning_label.visible = false
	if objective_label:
		objective_label.visible = false
	
	# Transition to Ending Scene (6-Page Cinematic Comic-Book Sequence)
	if END_SCREEN_SCENE:
		get_tree().change_scene_to_packed(END_SCREEN_SCENE)
