extends Control

@onready var start_button: TextureButton = $BoxContainer/StartButton
@onready var quit_button: TextureButton = $BoxContainer/QuitButton
@onready var fade_in_fade_out_component: Node = $FadeIn_Fade_out_component

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	start_button.pressed.connect(_on_start_pressed)
	quit_button.pressed.connect(get_tree().quit)

func _on_start_pressed() -> void:
	start_button.disabled = true
	$buttonsound.play()
	var tween := create_tween()
	tween.tween_property($StartSound, "volume_db", -40.0, 0.8)
	fade_in_fade_out_component.NextLevel("res://scene/intro_comic.tscn")
