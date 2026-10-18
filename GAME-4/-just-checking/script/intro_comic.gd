extends Control

# ===== INTRO COMIC ASSETS =====
const INTRO_PANELS: Array[String] = [
	"res://import/UI/comic_intro/comic_intro_1.png",
	"res://import/UI/comic_intro/comic_intro_2.png",
	"res://import/UI/comic_intro/comic_intro_3.png",
	"res://import/UI/comic_intro/comic_intro_4.png",
	"res://import/UI/comic_intro/comic_intro_5.png",
	"res://import/UI/comic_intro/comic_intro_6.png",
	"res://import/UI/comic_intro/comic_intro_7.png"
]

const SFX_PAGE_FLIP: String = "res://import/sound/comic_sfx/page_flip.wav"
const BG_SOUNDTRACK: String = "res://import/sound/game-background-sound.mp3"

# Timings tuned to the authentic character dialogue durations
const PANEL_DURATIONS: Array[float] = [7.5, 6.5, 4.0, 6.5, 4.5, 6.0, 4.5]

# Node references
@onready var comic_container: Control = $ComicContainer
@onready var panel_frame: PanelContainer = $ComicContainer/PanelFrame
@onready var panel_texture: TextureRect = $ComicContainer/PanelFrame/PanelTexture
@onready var page_indicator: Label = $ComicContainer/PageIndicator
@onready var skip_hint: Label = $ComicContainer/SkipHint
@onready var fade_rect: ColorRect = $FadeRect

@onready var sfx_flip_player: AudioStreamPlayer = $SfxFlipPlayer
@onready var sfx_ambience_player: AudioStreamPlayer = $SfxAmbiencePlayer
@onready var sfx_voice_player: AudioStreamPlayer = $SfxVoicePlayer

var textures: Array[Texture2D] = []
var flip_sound: AudioStream = null
var bg_music: AudioStream = null

var voice_lines: Dictionary = {}

var current_page: int = 0
var page_timer: float = 0.0
var is_advancing: bool = false
var ken_burns_tween: Tween = null
var voice_tweens: Array[Tween] = []

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade_rect.modulate.a = 1.0
	
	# Hide all overlay text completely for a clean cinematic experience
	if is_instance_valid(page_indicator):
		page_indicator.visible = false
	if is_instance_valid(skip_hint):
		skip_hint.visible = false
	
	_load_resources()
	
	# Start subtle, calm background soundtrack (no harsh synthetic noise)
	if bg_music and is_instance_valid(sfx_ambience_player):
		sfx_ambience_player.stream = bg_music
		sfx_ambience_player.volume_db = -18.0
		sfx_ambience_player.play()
	
	# Initial fade in from black
	var ft := create_tween()
	ft.tween_property(fade_rect, "modulate:a", 0.0, 0.6)
	
	_show_page(0)

func _load_resources() -> void:
	for p in INTRO_PANELS:
		var tex := _load_panel_texture(p)
		textures.append(tex)
			
	flip_sound = _load_audio_stream(SFX_PAGE_FLIP)
	bg_music = _load_audio_stream(BG_SOUNDTRACK)

	# Load authentic character dialogue voice tracks
	var voice_paths: Dictionary = {
		"p1_jessica": "res://import/sound/comic_intro_sfx/roy_are_you_sure.mp3",
		"p1_roy": "res://import/sound/comic_intro_sfx/yah_i_checked_te_map_twice.mp3",
		"p2_jessica": "res://import/sound/comic_intro_sfx/this_place_is_beautiful.mp3",
		"p2_roy": "res://import/sound/comic_intro_sfx/i_think_we_have_found_the_perfect_place.mp3",
		"p4_jessica": "res://import/sound/comic_intro_sfx/i_am_getting_tired.mp3",
		"p4_roy": "res://import/sound/comic_intro_sfx/we should get some rest.mp3",
		"p5_call": "res://import/sound/comic_intro_sfx/jessica_jessica.mp3",
		"p6_oath": "res://import/sound/comic_intro_sfx/i_find_you_where_ever_you_are.mp3"
	}
	for key in voice_paths.keys():
		var vp: String = voice_paths[key]
		var st := _load_audio_stream(vp)
		if st != null:
			voice_lines[key] = st

func _load_panel_texture(path: String) -> Texture2D:
	# 1. Direct disk image loader (works independently of editor .ctex cache)
	var gp := ProjectSettings.globalize_path(path)
	var target_path: String = gp if FileAccess.file_exists(gp) else path
	if FileAccess.file_exists(target_path):
		var img := Image.new()
		var err := img.load(target_path)
		if err == OK:
			return ImageTexture.create_from_image(img)
	# 2. ResourceLoader fallback
	if ResourceLoader.exists(path):
		var res = load(path)
		if res is Texture2D:
			return res
	return null

func _load_audio_stream(path: String) -> AudioStream:
	if ResourceLoader.exists(path):
		var res = load(path)
		if res is AudioStream:
			return res
	var gp := ProjectSettings.globalize_path(path)
	var target_path: String = gp if FileAccess.file_exists(gp) else path
	if FileAccess.file_exists(target_path):
		var bytes := FileAccess.get_file_as_bytes(target_path)
		if bytes.size() > 0:
			if path.ends_with(".mp3"):
				var mp3 := AudioStreamMP3.new()
				mp3.data = bytes
				return mp3
			elif path.ends_with(".wav"):
				var wav := AudioStreamWAV.new()
				wav.data = bytes
				return wav
	return null

func _process(delta: float) -> void:
	if is_advancing:
		return
	page_timer += delta
	var dur: float = PANEL_DURATIONS[current_page]
	if page_timer >= dur:
		_advance_to_page(current_page + 1)

func _unhandled_input(event: InputEvent) -> void:
	if is_advancing:
		return
	if event.is_action_pressed("ui_accept") or (event is InputEventKey and event.pressed and (event.keycode == KEY_SPACE or event.keycode == KEY_E or event.keycode == KEY_ENTER)):
		_advance_to_page(current_page + 1)
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_advance_to_page(current_page + 1)
	elif event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		_start_gameplay()

func _advance_to_page(next_page: int) -> void:
	if next_page >= INTRO_PANELS.size():
		_start_gameplay()
	else:
		_show_page(next_page)

func _show_page(page_idx: int) -> void:
	current_page = page_idx
	page_timer = 0.0
	
	_clear_voice_tweens()
	if ken_burns_tween and ken_burns_tween.is_valid():
		ken_burns_tween.kill()
		
	# Subtle page turn flip sound
	if flip_sound and current_page > 0:
		sfx_flip_player.stream = flip_sound
		sfx_flip_player.volume_db = -8.0
		sfx_flip_player.play()
		
	# Keep page indicator hidden
	if is_instance_valid(page_indicator):
		page_indicator.visible = false
	
	if current_page < textures.size() and textures[current_page] != null:
		panel_texture.texture = textures[current_page]
		
	_animate_panel(current_page)
	_schedule_panel_voices(current_page)

func _animate_panel(page_idx: int) -> void:
	panel_frame.scale = Vector2(0.97, 0.97)
	panel_frame.modulate.a = 0.0
	
	var dur: float = PANEL_DURATIONS[page_idx]
	var in_t := create_tween().set_parallel(true)
	in_t.tween_property(panel_frame, "modulate:a", 1.0, 0.35).set_trans(Tween.TRANS_SINE)
	in_t.tween_property(panel_frame, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	
	# Gentle Ken Burns cinematic motion
	ken_burns_tween = create_tween()
	match page_idx:
		0:
			panel_texture.scale = Vector2.ONE
			ken_burns_tween.tween_property(panel_texture, "scale", Vector2(1.04, 1.04), dur)
		1:
			panel_texture.position = Vector2(-12, 0)
			panel_texture.scale = Vector2(1.03, 1.03)
			ken_burns_tween.tween_property(panel_texture, "position", Vector2(12, 0), dur)
		2:
			panel_texture.scale = Vector2.ONE
			ken_burns_tween.tween_property(panel_texture, "scale", Vector2(1.03, 1.03), dur)
		3:
			panel_texture.position = Vector2(0, -6)
			panel_texture.scale = Vector2(1.03, 1.03)
			ken_burns_tween.tween_property(panel_texture, "position", Vector2(0, 6), dur)
		4:
			panel_texture.scale = Vector2(1.0, 1.0)
			ken_burns_tween.tween_property(panel_texture, "scale", Vector2(1.04, 1.04), dur)
		5:
			panel_texture.position = Vector2(-16, 0)
			panel_texture.scale = Vector2(1.03, 1.03)
			ken_burns_tween.tween_property(panel_texture, "position", Vector2(16, 0), dur)
		6:
			panel_texture.scale = Vector2(1.05, 1.05)
			ken_burns_tween.tween_property(panel_texture, "scale", Vector2(1.0, 1.0), dur)

func _schedule_panel_voices(page_idx: int) -> void:
	match page_idx:
		0:
			# Panel 1: Jessica asks, Roy answers
			_schedule_voice(voice_lines.get("p1_jessica"), 0.5, 4.0)
			_schedule_voice(voice_lines.get("p1_roy"), 4.6, 4.0)
		1:
			# Panel 2: Jessica admires, Roy agrees
			_schedule_voice(voice_lines.get("p2_jessica"), 0.5, 4.0)
			_schedule_voice(voice_lines.get("p2_roy"), 2.6, 4.0)
		2:
			# Panel 3: Silent visual storytelling - campsite prep, no dialogue
			pass
		3:
			# Panel 4: Night at camp - Jessica tired, Roy agrees to rest
			_schedule_voice(voice_lines.get("p4_jessica"), 0.5, 4.0)
			_schedule_voice(voice_lines.get("p4_roy"), 3.6, 4.0)
		4:
			# Panel 5: Fajr dawn - Roy calls out looking for Jessica
			_schedule_voice(voice_lines.get("p5_call"), 0.8, 4.0)
		5:
			# Panel 6: Roy finds clue and swears an oath to find her
			_schedule_voice(voice_lines.get("p6_oath"), 1.0, 4.0)
		6:
			# Panel 7: High aerial view fades to gameplay
			pass

func _schedule_voice(stream: AudioStream, delay: float, vol_db: float = 3.0) -> void:
	if not stream:
		return
	var tw := create_tween()
	voice_tweens.append(tw)
	tw.tween_interval(delay)
	tw.tween_callback(func():
		if is_instance_valid(sfx_voice_player):
			sfx_voice_player.stream = stream
			sfx_voice_player.volume_db = vol_db
			sfx_voice_player.play()
	)

func _clear_voice_tweens() -> void:
	for tw in voice_tweens:
		if tw and tw.is_valid():
			tw.kill()
	voice_tweens.clear()

func _start_gameplay() -> void:
	if is_advancing:
		return
	is_advancing = true
	_clear_voice_tweens()
	
	# Smoothly fade to black, stop audio, and enter game world!
	var ft := create_tween()
	ft.set_parallel(true)
	ft.tween_property(fade_rect, "modulate:a", 1.0, 0.8)
	if is_instance_valid(sfx_ambience_player):
		ft.tween_property(sfx_ambience_player, "volume_db", -35.0, 0.8)
	ft.chain().tween_callback(func():
		get_tree().change_scene_to_file("res://scene/world.tscn")
	)
