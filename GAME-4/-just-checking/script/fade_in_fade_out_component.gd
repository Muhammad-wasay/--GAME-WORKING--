class_name FadeInFadeOut_component
extends Node

@export var black_image: Control
@export var durationIn: float = 1.0
@export var DurationOut: float = 1.0

func _ready() -> void:
	black_image.visible = true
	black_image.z_index = 10
	black_image.modulate.a = 1.0
	var tween := create_tween()
	tween.tween_property(black_image, "modulate:a", 0.0, durationIn)

func NextLevel(nextlevelpath: String) -> void:
	black_image.visible = true
	var tween := create_tween()
	tween.tween_property(black_image, "modulate:a", 1.0, DurationOut)
	await tween.finished
	get_tree().change_scene_to_file(nextlevelpath)
