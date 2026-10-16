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

var cutscene_layer: CanvasLayer = null
var cutscene_video: VideoStreamPlayer = null
var cutscene_skip_prompt: Label = null
var cutscene_callback: Callable = Callable()

var ambush_minions: Array[ForestEnemy] = []
var ambush_triggered: bool = false
var tent_position: Vector3 = Vector3(23.8, 0.85, -35.2)
var cage_position: Vector3 = Vector3(32.5, 0.9, 14.5)

var horde_spawn_timer: float = 0.0
var horde_spawned_count: int = 0
const MAX_HORDE: int = 8

func _ready() -> void:
	name = "StoryQuestManager"
	_setup_sounds()
	_setup_hud()
	_setup_dialogue_box()
	_setup_siren_player()
	_setup_cutscene_player()
	
	call_deferred("_initialize_world_elements")

func _setup_hud() -> void:
	objective_hud = CanvasLayer.new()
	objective_hud.layer = 12
	add_child(objective_hud)
	
	var top_center := MarginContainer.new()
	top_center.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top_center.add_theme_constant_override("margin_top", 18)
	top_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	objective_hud.add_child(top_center)
	
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	top_center.add_child(vbox)
	
	objective_label = Label.new()
	objective_label.text = "OBJECTIVE: Explore the forest and find where Jessica was taken!"
	objective_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	objective_label.add_theme_font_size_override("font_size", 22)
	objective_label.add_theme_color_override("font_color", Color(1.0, 0.88, 0.35, 1.0))
	objective_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.95))
	objective_label.add_theme_constant_override("shadow_offset_x", 2)
	objective_label.add_theme_constant_override("shadow_offset_y", 2)
	vbox.add_child(objective_label)
	
	wait_warning_label = Label.new()
	wait_warning_label.text = "⚠️ WAIT FOR JESSICA! Don't leave her behind! ⚠️"
	wait_warning_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	wait_warning_label.add_theme_font_size_override("font_size", 26)
	wait_warning_label.add_theme_color_override("font_color", Color(1.0, 0.25, 0.2, 1.0))
	wait_warning_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.95))
	wait_warning_label.add_theme_constant_override("shadow_offset_x", 2)
	wait_warning_label.add_theme_constant_override("shadow_offset_y", 2)
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

func _unhandled_input(event: InputEvent) -> void:
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
	
	# Prepare Boss for Stage 1 Encounter
	if boss:
		boss.invulnerable = true
		boss.story_frozen = true
		boss.enemy_died.connect(_on_boss_died)
	
	_update_objective("OBJECTIVE: Explore the forest and find Jessica!")

func _setup_cage_prompt() -> void:
	if not is_instance_valid(cage_instance):
		return
	cage_prompt_label = Label3D.new()
	cage_prompt_label.name = "CagePromptLabel"
	cage_prompt_label.text = "Locked! Defeat the Boss to get Key"
	cage_prompt_label.font_size = 28
	cage_prompt_label.pixel_size = 0.0035
	cage_prompt_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	cage_prompt_label.no_depth_test = true
	cage_prompt_label.modulate = Color(1.0, 0.35, 0.3, 1.0)
	cage_prompt_label.outline_size = 10
	cage_prompt_label.outline_modulate = Color(0, 0, 0, 0.95)
	cage_prompt_label.position = Vector3(0, 1.6, 0)
	cage_prompt_label.visible = false
	cage_instance.add_child(cage_prompt_label)

func _update_objective(msg: String) -> void:
	if objective_label:
		objective_label.text = msg
		var t := create_tween()
		objective_label.modulate.a = 0.2
		t.tween_property(objective_label, "modulate:a", 1.0, 0.35)

func _process(delta: float) -> void:
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

func _on_dialogue_line_started(speaker: String, entry: Dictionary) -> void:
	if not is_instance_valid(cinematic_camera) or not is_instance_valid(roy):
		return
	
	if cam_tween and cam_tween.is_valid():
		cam_tween.kill()
	
	var is_scream: bool = entry.get("is_scream", false)
	var is_mannequins_rising: bool = entry.get("is_mannequins_rising", false)
	
	# Scale-adaptive eye/camera height calculations (Roy is scaled 0.3, Boss is scaled 0.5, Jessica is scaled ~0.7)
	var roy_scale: float = roy.global_basis.get_scale().y if "global_basis" in roy else 0.3
	
	if speaker == "VILLAIN BOSS":
		if not is_instance_valid(boss):
			return
		var boss_scale: float = boss.global_basis.get_scale().y if "global_basis" in boss else 0.5
		# Boss face focus at actual eye level (approx 0.82m above ground)
		var boss_face := boss.global_position + Vector3(0.0, 1.65 * boss_scale, 0.0)
		var to_roy := (roy.global_position - boss.global_position)
		to_roy.y = 0.0
		var to_roy_dir := to_roy.normalized() if to_roy.length_squared() > 0.001 else -boss.global_transform.basis.z
		var boss_side := Vector3(to_roy_dir.z, 0.0, -to_roy_dir.x)
		
		# Camera placed in front of Boss, at chest height looking slightly upward at face (menacing framing)
		var cam_pos := boss_face + to_roy_dir * 1.55 + boss_side * 0.35
		cam_pos.y = boss.global_position.y + (1.30 * boss_scale)
		
		var target_basis := Basis.looking_at((boss_face - cam_pos).normalized(), Vector3.UP)
		var target_transform := Transform3D(target_basis, cam_pos)
		
		cam_tween = create_tween()
		cam_tween.tween_property(cinematic_camera, "global_transform", target_transform, 0.48).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		
	elif speaker == "ROY":
		# Roy face focus at actual eye level (approx 0.44m above ground)
		var roy_face := roy.global_position + Vector3(0.0, 1.45 * roy_scale, 0.0)
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
		
		# Camera in front of Roy, at eye/chin height, framed nicely on his face/upper chest
		var cam_pos := roy_face + to_target_dir * 1.05 + roy_side * 0.26
		cam_pos.y = roy.global_position.y + (1.38 * roy_scale)
		
		var target_basis := Basis.looking_at((roy_face - cam_pos).normalized(), Vector3.UP)
		var target_transform := Transform3D(target_basis, cam_pos)
		
		cam_tween = create_tween()
		cam_tween.tween_property(cinematic_camera, "global_transform", target_transform, 0.48).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		
	elif speaker == "JESSICA":
		if is_instance_valid(jessica):
			var jess_scale: float = jessica.global_basis.get_scale().y if "global_basis" in jessica else 0.7
			var jess_face := jessica.global_position + Vector3(0.0, 1.25 * jess_scale, 0.0)
			var to_roy := (roy.global_position - jessica.global_position)
			to_roy.y = 0.0
			var to_roy_dir := to_roy.normalized() if to_roy.length_squared() > 0.001 else -jessica.global_transform.basis.z
			var jess_side := Vector3(-to_roy_dir.z, 0.0, to_roy_dir.x)
			
			# Camera in front of Jessica at eye level
			var cam_pos := jess_face + to_roy_dir * 1.15 + jess_side * 0.22
			cam_pos.y = jessica.global_position.y + (1.20 * jess_scale)
			
			var target_basis := Basis.looking_at((jess_face - cam_pos).normalized(), Vector3.UP)
			var target_transform := Transform3D(target_basis, cam_pos)
			
			cam_tween = create_tween()
			cam_tween.tween_property(cinematic_camera, "global_transform", target_transform, 0.48).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			
	elif speaker == "..." or is_mannequins_rising:
		var focus_p := roy.global_position
		if is_instance_valid(jessica):
			focus_p = (roy.global_position + jessica.global_position) * 0.5
		
		# Spawn 2 ambush minions rising right here during this line!
		var spawn_offsets: Array[Vector3] = [
			Vector3(-2.2, 0.0, -1.8),
			Vector3(2.2, 0.0, -1.8)
		]
		for i in range(spawn_offsets.size()):
			var minion_scene: PackedScene = ENEMY_3_SCENE if (i % 2 == 1) else ENEMY_2_SCENE
			var minion := minion_scene.instantiate() as ForestEnemy
			get_tree().current_scene.add_child(minion)
			minion.scale = Vector3(0.32, 0.32, 0.32)
			minion.global_position = focus_p + spawn_offsets[i]
			minion.run_speed = 1.30
			minion.detection_range = 45.0
			minion.lose_interest_range = 65.0
			minion.emerge_from_ground(1.6)
		
		# Low angle ground camera looking at emerging minions
		var cam_pos := focus_p + Vector3(0.3, 0.65, -3.2)
		var target_basis := Basis.looking_at(((focus_p + Vector3(0, 0.25, 0)) - cam_pos).normalized(), Vector3.UP)
		var target_transform := Transform3D(target_basis, cam_pos)
		
		cam_tween = create_tween()
		cam_tween.tween_property(cinematic_camera, "global_transform", target_transform, 0.45).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		_shake_cinematic_camera(1.8, 0.03)

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
	_update_objective("🚨 ESCAPE! Bring Jessica back to the Tent!")
	
	if siren_player and not siren_player.playing:
		siren_player.play()
	
	horde_spawn_timer = 1.0

func _process_escape_stage(delta: float) -> void:
	if not is_instance_valid(jessica):
		return
	
	var dist_jessica_roy := roy.global_position.distance_to(jessica.global_position)
	
	# "Wait for Jessica!" Distance Check
	if dist_jessica_roy > 7.5:
		wait_warning_label.visible = true
	else:
		wait_warning_label.visible = false
	
	# Horde Spawning
	horde_spawn_timer -= delta
	if horde_spawn_timer <= 0.0 and horde_spawned_count < MAX_HORDE:
		horde_spawn_timer = 5.5
		_spawn_chase_minion()
	
	# Tent Reach Check
	var dist_roy_tent := roy.global_position.distance_to(tent_position)
	var dist_jessica_tent := jessica.global_position.distance_to(tent_position)
	
	if dist_roy_tent <= 4.5:
		if dist_jessica_tent <= 8.0:
			_complete_game_at_tent()
		else:
			if roy.has_method("show_tip_message"):
				roy.show_tip_message("Wait for Jessica before escaping!", 1.5)

func _spawn_chase_minion() -> void:
	horde_spawned_count += 1
	var minion_scene: PackedScene = ENEMY_3_SCENE if (randf() < 0.5) else ENEMY_2_SCENE
	var minion := minion_scene.instantiate() as ForestEnemy
	minion.is_emerging = true
	get_tree().current_scene.add_child(minion)
	minion.scale = Vector3(0.32, 0.32, 0.32)
	
	# Spawn ~13m behind Roy & Jessica
	var behind_dir := (roy.global_position - tent_position).normalized()
	var spawn_p := roy.global_position + (behind_dir * 13.0) + Vector3(randf_range(-3.5, 3.5), 0, randf_range(-3.5, 3.5))
	
	# Raycast downward to snap accurately to terrain surface
	var space_state := minion.get_world_3d().direct_space_state
	var ray_query := PhysicsRayQueryParameters3D.create(spawn_p + Vector3(0, 4.0, 0), spawn_p + Vector3(0, -6.0, 0))
	var ray_res := space_state.intersect_ray(ray_query)
	if ray_res and ray_res.has("position"):
		spawn_p = ray_res.position + Vector3(0, 0.02, 0)
	
	minion.global_position = spawn_p
	minion.run_speed = 1.35
	minion.detection_range = 45.0
	minion.lose_interest_range = 65.0
	minion.emerge_from_ground(1.0)

# ===== 4. TENT EXTRACTION, ENDING VIDEO & CREDITS =====
func _complete_game_at_tent() -> void:
	stage = QuestStage.GAME_COMPLETED
	set_process(false)
	
	if siren_player and siren_player.playing:
		siren_player.stop()
	
	if wait_warning_label:
		wait_warning_label.visible = false
	if objective_label:
		objective_label.visible = false
	
	# Transition to Ending Scene (End Video + LOST IN THE FOREST Made with Godot credits)
	if END_SCREEN_SCENE:
		get_tree().change_scene_to_packed(END_SCREEN_SCENE)
