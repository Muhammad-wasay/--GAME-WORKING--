extends Control

@onready var video_player: VideoStreamPlayer = $VideoStreamPlayer
@onready var credits_panel: Control = $CreditsPanel
@onready var title_label: Label = $CreditsPanel/VBoxContainer/TitleLabel
@onready var subtitle_label: Label = $CreditsPanel/VBoxContainer/SubtitleLabel
@onready var restart_button: Button = $CreditsPanel/VBoxContainer/HBoxContainer/RestartButton
@onready var quit_button: Button = $CreditsPanel/VBoxContainer/HBoxContainer/QuitButton
@onready var bg_music: AudioStreamPlayer = $BgMusic

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	credits_panel.visible = false
	credits_panel.modulate.a = 0.0
	
	restart_button.pressed.connect(_on_restart_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	
	if video_player:
		var ending_videos: Array[String] = [
			"res://import/sound/escape_ending.ogv",
			"res://import/video/escape_ending.ogv",
			"res://escape_ending.ogv",
			"res://import/sound/poster.ogv"
		]
		for p in ending_videos:
			if ResourceLoader.exists(p):
				var stream = load(p)
				if stream is VideoStream:
					video_player.stream = stream
					break
		
		video_player.finished.connect(_on_video_finished)
		video_player.play()
		# Fallback in case video length is long or fails
		get_tree().create_timer(30.0).timeout.connect(func():
			if not credits_panel.visible:
				_show_credits()
		)
	else:
		_show_credits()

func _unhandled_input(event: InputEvent) -> void:
	if not credits_panel.visible:
		if event.is_action_pressed("ui_accept") or (event is InputEventKey and event.pressed and (event.keycode == KEY_SPACE or event.keycode == KEY_ESCAPE or event.keycode == KEY_E)):
			_on_video_finished()

func _on_video_finished() -> void:
	_show_credits()

func _show_credits() -> void:
	credits_panel.visible = true
	var t := create_tween()
	t.tween_property(credits_panel, "modulate:a", 1.0, 1.2)
	if bg_music and not bg_music.playing:
		bg_music.play()

func _on_restart_pressed() -> void:
	get_tree().change_scene_to_file("res://scene/world.tscn")

func _on_quit_pressed() -> void:
	get_tree().quit()
