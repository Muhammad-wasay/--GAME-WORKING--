extends Node3D

@onready var sparks: CPUParticles3D = $Sparks
@onready var smoke: CPUParticles3D = $Smoke
@onready var light: OmniLight3D = $OmniLight3D

func _ready() -> void:
	sparks.emitting = true
	smoke.emitting = true
	
	var tween = create_tween()
	tween.tween_property(light, "light_energy", 0.0, 0.08)
	tween.tween_interval(0.6)
	tween.tween_callback(queue_free)
