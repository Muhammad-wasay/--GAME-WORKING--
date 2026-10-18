extends Control

# ===== COMIC IMAGES & SFX PATHS =====
const COMIC_PAGE_1: String = "res://import/UI/comic_ending/comic_page_1.png"
const COMIC_PAGE_2: String = "res://import/UI/comic_ending/comic_page_2.png"
const COMIC_PAGE_3: String = "res://import/UI/comic_ending/comic_page_3.png"
const COMIC_PAGE_4: String = "res://import/UI/comic_ending/comic_page_4.png"

const SFX_PAGE_FLIP: String = "res://import/sound/comic_sfx/page_flip.wav"
const SFX_PAGE_1: String = "res://import/sound/comic_sfx/page1_run_chase.wav"
const SFX_PAGE_2: String = "res://import/sound/comic_sfx/page2_doors_ignition.wav"
const SFX_PAGE_3: String = "res://import/sound/comic_sfx/page3_vroom_escape.wav"
const SFX_PAGE_4: String = "res://import/sound/comic_sfx/page4_aerial_wind.wav"
const SFX_PAGE_5: String = "res://import/sound/comic_sfx/page5_roy_whisper.wav"
const SFX_PAGE_6: String = "res://import/sound/comic_sfx/page6_title_boom.wav"
const BGM_THEME: String = "res://import/sound/gametheme.wav"

# Character Voice Acting Lines
const VOICE_P1_ROY: String = "res://import/sound/comic_sfx/comic_voice_p1_roy.wav"
const VOICE_P1_JESSICA: String = "res://import/sound/comic_sfx/comic_voice_p1_jessica.wav"
const VOICE_P2_ROY: String = "res://import/sound/comic_sfx/comic_voice_p2_roy.wav"
const VOICE_P2_JESSICA: String = "res://import/sound/comic_sfx/comic_voice_p2_jessica.wav"
const VOICE_P5_WHISPER: String = "res://import/sound/comic_sfx/comic_voice_p5_jessica_whisper.wav"

const PAGE_DURATIONS: Array[float] = [3.0, 3.0, 4.0, 4.0, 3.0, 5.0]

# Node references
@onready var comic_container: Control = $ComicContainer
@onready var panel_frame: PanelContainer = $ComicContainer/PanelFrame
@onready var panel_texture: TextureRect = $ComicContainer/PanelFrame/PanelTexture
@onready var sfx_badge_container: Control = $ComicContainer/SfxBadgeContainer
@onready var page_indicator: Label = $ComicContainer/PageIndicator
@onready var skip_hint: Label = $ComicContainer/SkipHint

@onready var page5_panel: Control = $Page5MysteryPanel
@onready var page5_whisper_label: Label = $Page5MysteryPanel/WhisperLabel

@onready var credits_panel: Control = $CreditsPanel
@onready var title_label: Label = $CreditsPanel/VBoxContainer/TitleLabel
@onready var subtitle_label: Label = $CreditsPanel/VBoxContainer/SubtitleLabel
@onready var restart_button: Button = $CreditsPanel/VBoxContainer/HBoxContainer/RestartButton
@onready var quit_button: Button = $CreditsPanel/VBoxContainer/HBoxContainer/QuitButton

@onready var sfx_flip_player: AudioStreamPlayer = $SfxFlipPlayer
@onready var sfx_page_player: AudioStreamPlayer = $SfxPagePlayer
@onready var sfx_voice_player: AudioStreamPlayer = $SfxVoicePlayer
@onready var bg_music: AudioStreamPlayer = $BgMusic

var current_page: int = 0
var page_timer: float = 0.0
var is_advancing: bool = false
var ken_burns_tween: Tween = null
var current_sfx_timer_tweens: Array[Tween] = []

var textures: Array[Texture2D] = []
var page_sounds: Array[AudioStream] = []
var flip_sound: AudioStream = null
var title_sound: AudioStream = null

var voice_p1_roy: AudioStream = null
var voice_p1_jessica: AudioStream = null
var voice_p2_roy: AudioStream = null
var voice_p2_jessica: AudioStream = null
var voice_p5_whisper: AudioStream = null

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	
	_load_resources()
	
	if restart_button:
		restart_button.pressed.connect(_on_restart_pressed)
	if quit_button:
		quit_button.pressed.connect(_on_quit_pressed)
	
	credits_panel.visible = false
	credits_panel.modulate.a = 0.0
	page5_panel.visible = false
	page5_panel.modulate.a = 0.0
	
	_show_page(0)

func _load_resources() -> void:
	var img_paths := [COMIC_PAGE_1, COMIC_PAGE_2, COMIC_PAGE_3, COMIC_PAGE_4]
	for p in img_paths:
		textures.append(_load_panel_texture(p))
	
	var snd_paths := [SFX_PAGE_1, SFX_PAGE_2, SFX_PAGE_3, SFX_PAGE_4, SFX_PAGE_5, SFX_PAGE_6]
	for sp in snd_paths:
		if ResourceLoader.exists(sp):
			page_sounds.append(load(sp))
		else:
			page_sounds.append(null)
			
	if ResourceLoader.exists(SFX_PAGE_FLIP):
		flip_sound = load(SFX_PAGE_FLIP)
	if ResourceLoader.exists(SFX_PAGE_6):
		title_sound = load(SFX_PAGE_6)

	if ResourceLoader.exists(VOICE_P1_ROY):
		voice_p1_roy = load(VOICE_P1_ROY)
	if ResourceLoader.exists(VOICE_P1_JESSICA):
		voice_p1_jessica = load(VOICE_P1_JESSICA)
	if ResourceLoader.exists(VOICE_P2_ROY):
		voice_p2_roy = load(VOICE_P2_ROY)
	if ResourceLoader.exists(VOICE_P2_JESSICA):
		voice_p2_jessica = load(VOICE_P2_JESSICA)
	if ResourceLoader.exists(VOICE_P5_WHISPER):
		voice_p5_whisper = load(VOICE_P5_WHISPER)

func _load_panel_texture(path: String) -> Texture2D:
	var gp := ProjectSettings.globalize_path(path)
	var target_path: String = gp if FileAccess.file_exists(gp) else path
	if FileAccess.file_exists(target_path):
		var img := Image.new()
		var err := img.load(target_path)
		if err == OK:
			return ImageTexture.create_from_image(img)
	if ResourceLoader.exists(path):
		var res = load(path)
		if res is Texture2D:
			return res
	return null

func _process(delta: float) -> void:
	if current_page < 5:
		page_timer += delta
		var dur: float = PAGE_DURATIONS[current_page]
		if page_timer >= dur and not is_advancing:
			_advance_to_page(current_page + 1)

func _unhandled_input(event: InputEvent) -> void:
	if current_page >= 5:
		return
		
	if event.is_action_pressed("ui_accept") or (event is InputEventKey and event.pressed and (event.keycode == KEY_SPACE or event.keycode == KEY_E or event.keycode == KEY_ENTER)):
		_advance_to_page(current_page + 1)
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_advance_to_page(current_page + 1)
	elif event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		_advance_to_page(5)

func _advance_to_page(next_page: int) -> void:
	if is_advancing:
		return
	is_advancing = true
	_show_page(next_page)

func _show_page(page_idx: int) -> void:
	current_page = page_idx
	page_timer = 0.0
	
	# Clear active badge popups and previous tweens
	_clear_badges()
	if ken_burns_tween and ken_burns_tween.is_valid():
		ken_burns_tween.kill()
	
	# Play crisp comic page flip sound
	if flip_sound and current_page > 0 and current_page <= 4:
		sfx_flip_player.stream = flip_sound
		sfx_flip_player.volume_db = -2.0
		sfx_flip_player.play()
	
	if current_page < 4:
		# Comic Panels 1 to 4
		comic_container.visible = true
		page5_panel.visible = false
		credits_panel.visible = false
		
		if current_page < textures.size() and textures[current_page] != null:
			panel_texture.texture = textures[current_page]
		
		page_indicator.text = "PANEL %d / 6" % (current_page + 1)
		
		# Play multi-layered comic audio for this page
		if current_page < page_sounds.size() and page_sounds[current_page] != null:
			sfx_page_player.stream = page_sounds[current_page]
			sfx_page_player.volume_db = 0.0
			sfx_page_player.play()
			
		_animate_panel_entrance(current_page)
		_setup_page_badges(current_page)
		
	elif current_page == 4:
		# Page 5: Pitch-Black Mystery ("Roy...")
		comic_container.visible = false
		credits_panel.visible = false
		page5_panel.visible = true
		page5_panel.modulate.a = 0.0
		page5_whisper_label.modulate.a = 0.0
		
		# Fade in black and haunting whisper
		var pt := create_tween()
		pt.tween_property(page5_panel, "modulate:a", 1.0, 0.4)
		pt.tween_property(page5_whisper_label, "modulate:a", 1.0, 1.2).set_delay(0.6)
		
		if 4 < page_sounds.size() and page_sounds[4] != null:
			sfx_page_player.stream = page_sounds[4]
			sfx_page_player.volume_db = 2.0
			sfx_page_player.play()
			
		_schedule_voice(voice_p5_whisper, 0.85, 4.0)
			
	elif current_page >= 5:
		# Page 6: Cinematic Title & Credits
		comic_container.visible = false
		page5_panel.visible = false
		_show_credits()
		
	is_advancing = false

func _animate_panel_entrance(page_idx: int) -> void:
	panel_frame.scale = Vector2(0.96, 0.96)
	panel_frame.modulate.a = 0.0
	
	var dur: float = PAGE_DURATIONS[page_idx]
	var in_t := create_tween().set_parallel(true)
	in_t.tween_property(panel_frame, "modulate:a", 1.0, 0.35).set_trans(Tween.TRANS_SINE)
	in_t.tween_property(panel_frame, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	
	# Dynamic Ken Burns subtle motion per page
	ken_burns_tween = create_tween()
	match page_idx:
		0:
			# Page 1: Subtle zoom in to amplify running speed
			panel_texture.position = Vector2.ZERO
			panel_texture.scale = Vector2.ONE
			ken_burns_tween.tween_property(panel_texture, "scale", Vector2(1.04, 1.04), dur)
		1:
			# Page 2: Slight pan across the car from Roy to Jessica
			panel_texture.position = Vector2(-15, 0)
			panel_texture.scale = Vector2(1.03, 1.03)
			ken_burns_tween.tween_property(panel_texture, "position", Vector2(15, 0), dur)
		2:
			# Page 3: Vibration rumble + forward zoom
			panel_texture.scale = Vector2.ONE
			ken_burns_tween.tween_property(panel_texture, "scale", Vector2(1.05, 1.05), dur)
			_screen_rumble(dur, 2.5)
		3:
			# Page 4: Smooth aerial drone drift
			panel_texture.position = Vector2(0, -12)
			panel_texture.scale = Vector2(1.04, 1.04)
			ken_burns_tween.tween_property(panel_texture, "position", Vector2(0, 12), dur)

func _setup_page_badges(page_idx: int) -> void:
	match page_idx:
		0:
			# Page 1: Character Voices
			_schedule_voice(voice_p1_roy, 0.25, 4.0)       # Roy: "Jessica, the car!"
			_schedule_voice(voice_p1_jessica, 1.45, 4.0)   # Jessica: "Go!"
		1:
			# Page 2: Character Voices + Door Slams & Ignition timed badges
			_schedule_voice(voice_p2_roy, 0.25, 4.0)       # Roy: "Get in!"
			_schedule_badge("SLAM!!", Vector2(0.24, 0.68), Color(1.0, 0.88, 0.2), 0.42, -8.0)
			
			_schedule_voice(voice_p2_jessica, 1.05, 4.0)   # Jessica: "I'm in!"
			_schedule_badge("THUD!!", Vector2(0.72, 0.68), Color(1.0, 0.88, 0.2), 1.08, 7.0)
			
			_schedule_badge("KRR-CHK-VROOM!", Vector2(0.48, 0.82), Color(1.0, 0.45, 0.15), 1.85, 0.0, 1.4)
		2:
			# Page 3: Speed / acceleration burst
			_schedule_badge("SCREEECH!!", Vector2(0.78, 0.84), Color(1.0, 0.95, 0.35), 0.25, 12.0)

func _schedule_voice(stream: AudioStream, delay: float, vol_db: float = 3.0) -> void:
	if not stream:
		return
	var tw := create_tween()
	current_sfx_timer_tweens.append(tw)
	tw.tween_interval(delay)
	tw.tween_callback(func():
		if is_instance_valid(sfx_voice_player):
			sfx_voice_player.stream = stream
			sfx_voice_player.volume_db = vol_db
			sfx_voice_player.play()
	)

func _schedule_badge(text: String, rel_pos: Vector2, col: Color, delay: float, rot_deg: float = 0.0, scale_mul: float = 1.0) -> void:
	var tw := create_tween()
	current_sfx_timer_tweens.append(tw)
	tw.tween_interval(delay)
	tw.tween_callback(func():
		_spawn_comic_badge(text, rel_pos, col, rot_deg, scale_mul)
	)

func _spawn_comic_badge(text: String, rel_pos: Vector2, col: Color, rot_deg: float, scale_mul: float) -> void:
	if not is_instance_valid(sfx_badge_container) or current_page >= 4:
		return
		
	var badge := Label.new()
	badge.text = text
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge.add_theme_font_size_override("font_size", int(32 * scale_mul))
	badge.add_theme_color_override("font_color", col)
	badge.add_theme_color_override("font_outline_color", Color(0.02, 0.02, 0.02, 1.0))
	badge.add_theme_constant_override("outline_size", 10)
	badge.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.8))
	badge.add_theme_constant_override("shadow_offset_x", 3)
	badge.add_theme_constant_override("shadow_offset_y", 3)
	
	sfx_badge_container.add_child(badge)
	
	var c_size := sfx_badge_container.size
	badge.pivot_offset = Vector2(80, 25)
	badge.position = Vector2(c_size.x * rel_pos.x - 80, c_size.y * rel_pos.y - 25)
	badge.rotation_degrees = rot_deg
	badge.scale = Vector2(0.1, 0.1)
	badge.modulate.a = 0.0
	
	var bt := create_tween()
	bt.set_parallel(true)
	bt.tween_property(badge, "scale", Vector2(1.15, 1.15) * scale_mul, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	bt.tween_property(badge, "modulate:a", 1.0, 0.12)
	bt.chain().tween_property(badge, "scale", Vector2.ONE * scale_mul, 0.1)

func _clear_badges() -> void:
	for tw in current_sfx_timer_tweens:
		if tw and tw.is_valid():
			tw.kill()
	current_sfx_timer_tweens.clear()
	
	if is_instance_valid(sfx_badge_container):
		for child in sfx_badge_container.get_children():
			child.queue_free()

func _screen_rumble(duration: float, intensity: float) -> void:
	var rt := create_tween()
	var steps: int = int(duration * 18.0)
	var step_dur := duration / float(steps)
	var base_pos := panel_frame.position
	for i in range(steps):
		var offset := Vector2(randf_range(-intensity, intensity), randf_range(-intensity, intensity))
		rt.tween_property(panel_frame, "position", base_pos + offset, step_dur)
	rt.tween_property(panel_frame, "position", base_pos, 0.05)

func _show_credits() -> void:
	credits_panel.visible = true
	var t := create_tween()
	t.tween_property(credits_panel, "modulate:a", 1.0, 1.4).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	
	# Play deep cinematic title impact boom
	if title_sound:
		sfx_page_player.stream = title_sound
		sfx_page_player.volume_db = 2.5
		sfx_page_player.play()
		
	# Smoothly fade in main game theme music
	if bg_music and not bg_music.playing:
		bg_music.volume_db = -24.0
		bg_music.play()
		var mt := create_tween()
		mt.tween_property(bg_music, "volume_db", -3.0, 3.5).set_delay(1.0)

func _on_restart_pressed() -> void:
	get_tree().change_scene_to_file("res://scene/world.tscn")

func _on_quit_pressed() -> void:
	get_tree().quit()
