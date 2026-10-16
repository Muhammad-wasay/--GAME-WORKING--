extends CanvasLayer
class_name StoryDialogueBox

signal sequence_finished(sequence_id: String)
signal line_started(speaker: String, entry: Dictionary)

const FONT = preload("res://import/font-text/ballad_of_dwight_frye/Ballad of Dwight Frye.ttf")

var root_control: Control = null
var box_panel: PanelContainer = null
var speaker_panel: PanelContainer = null
var speaker_label: Label = null
var text_label: Label = null
var hint_label: Label = null
var alert_flash_rect: ColorRect = null
var voice_player: AudioStreamPlayer = null

var current_sequence: Array = []
var current_index: int = -1
var current_sequence_id: String = ""
var is_active: bool = false
var typing_tween: Tween = null
var line_timer: float = 0.0
var waiting_for_voice: bool = false
var post_voice_delay: float = 0.0
var box_style: StyleBoxFlat = null
var speaker_style: StyleBoxFlat = null

func _ready() -> void:
	layer = 25
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	
	voice_player = AudioStreamPlayer.new()
	voice_player.name = "DialogueVoicePlayer"
	voice_player.volume_db = 3.5
	voice_player.finished.connect(_on_voice_finished)
	add_child(voice_player)

func _build_ui() -> void:
	root_control = Control.new()
	root_control.set_anchors_preset(Control.PRESET_FULL_RECT)
	root_control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root_control.visible = false
	add_child(root_control)
	
	alert_flash_rect = ColorRect.new()
	alert_flash_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	alert_flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	alert_flash_rect.color = Color(0.95, 0.15, 0.2, 0.0)
	root_control.add_child(alert_flash_rect)
	
	box_panel = PanelContainer.new()
	box_panel.anchor_left = 0.12
	box_panel.anchor_right = 0.88
	box_panel.anchor_top = 0.72
	box_panel.anchor_bottom = 0.93
	box_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	box_style = StyleBoxFlat.new()
	box_style.bg_color = Color(0.05, 0.04, 0.06, 0.92)
	box_style.border_color = Color(0.85, 0.65, 0.25, 1.0)
	box_style.set_border_width_all(3)
	box_style.set_corner_radius_all(12)
	box_style.content_margin_left = 28
	box_style.content_margin_right = 28
	box_style.content_margin_top = 20
	box_style.content_margin_bottom = 16
	box_panel.add_theme_stylebox_override("panel", box_style)
	root_control.add_child(box_panel)
	
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	box_panel.add_child(vbox)
	
	var top_row := HBoxContainer.new()
	vbox.add_child(top_row)
	
	speaker_panel = PanelContainer.new()
	speaker_style = StyleBoxFlat.new()
	speaker_style.bg_color = Color(0.65, 0.12, 0.12, 0.95)
	speaker_style.set_corner_radius_all(6)
	speaker_style.content_margin_left = 14
	speaker_style.content_margin_right = 14
	speaker_style.content_margin_top = 4
	speaker_style.content_margin_bottom = 4
	speaker_panel.add_theme_stylebox_override("panel", speaker_style)
	top_row.add_child(speaker_panel)
	
	speaker_label = Label.new()
	if FONT:
		speaker_label.add_theme_font_override("font", FONT)
	speaker_label.add_theme_font_size_override("font_size", 24)
	speaker_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.85))
	speaker_panel.add_child(speaker_label)
	
	text_label = Label.new()
	text_label.add_theme_font_size_override("font_size", 24)
	text_label.add_theme_color_override("font_color", Color(0.96, 0.94, 0.90))
	text_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	text_label.add_theme_constant_override("shadow_offset_x", 2)
	text_label.add_theme_constant_override("shadow_offset_y", 2)
	text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(text_label)
	
	hint_label = Label.new()
	hint_label.text = "[SPACE] Skip / Next"
	hint_label.add_theme_font_size_override("font_size", 15)
	hint_label.add_theme_color_override("font_color", Color(0.65, 0.65, 0.65, 0.85))
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	vbox.add_child(hint_label)

func play_sequence(sequence_id: String, lines: Array) -> void:
	current_sequence_id = sequence_id
	current_sequence = lines
	current_index = -1
	is_active = true
	root_control.visible = true
	root_control.modulate.a = 0.0
	var t := create_tween()
	t.tween_property(root_control, "modulate:a", 1.0, 0.25)
	_advance_line()

func _advance_line() -> void:
	if typing_tween and typing_tween.is_valid():
		typing_tween.kill()
	if voice_player and voice_player.playing:
		voice_player.stop()
	
	current_index += 1
	if current_index >= current_sequence.size():
		_finish_sequence()
		return
	
	var entry: Dictionary = current_sequence[current_index]
	var speaker: String = entry.get("speaker", "")
	var text: String = entry.get("text", "")
	var voice: AudioStream = entry.get("voice", null)
	var color: Color = entry.get("color", Color(0.85, 0.2, 0.2))
	var is_scream: bool = entry.get("is_scream", false)
	var min_duration: float = entry.get("duration", 2.4)
	post_voice_delay = entry.get("pause_after", 0.55)
	
	speaker_label.text = speaker
	speaker_style.bg_color = color
	box_style.border_color = color.lightened(0.25)
	
	line_started.emit(speaker, entry)
	
	text_label.text = text
	text_label.visible_ratio = 0.0
	var char_time := clampf(float(text.length()) * 0.028, 0.35, 1.8)
	typing_tween = create_tween()
	typing_tween.tween_property(text_label, "visible_ratio", 1.0, char_time)
	
	if is_scream and alert_flash_rect:
		alert_flash_rect.color = Color(1.0, 0.18, 0.18, 0.38)
		var ft := create_tween()
		ft.tween_property(alert_flash_rect, "color:a", 0.0, 0.85)
		box_panel.scale = Vector2(1.05, 1.05)
		var st := create_tween()
		st.tween_property(box_panel, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	
	if voice and voice_player:
		voice_player.stream = voice
		voice_player.play()
		waiting_for_voice = true
		line_timer = 0.0
	else:
		waiting_for_voice = false
		line_timer = min_duration

func _on_voice_finished() -> void:
	if not is_active:
		return
	waiting_for_voice = false
	line_timer = maxf(0.25, post_voice_delay)

func _process(delta: float) -> void:
	if not is_active:
		return
	if not waiting_for_voice:
		line_timer -= delta
		if line_timer <= 0.0:
			_advance_line()

func _input(event: InputEvent) -> void:
	if not is_active:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_SPACE or event.keycode == KEY_ENTER:
			get_viewport().set_input_as_handled()
			if typing_tween and typing_tween.is_valid() and text_label.visible_ratio < 0.95:
				typing_tween.kill()
				text_label.visible_ratio = 1.0
			else:
				_advance_line()

func _finish_sequence() -> void:
	is_active = false
	if voice_player and voice_player.playing:
		voice_player.stop()
	var finished_id := current_sequence_id
	var t := create_tween()
	t.tween_property(root_control, "modulate:a", 0.0, 0.25)
	t.tween_callback(func():
		root_control.visible = false
		sequence_finished.emit(finished_id)
	)
