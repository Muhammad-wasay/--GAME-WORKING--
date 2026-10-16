extends Node3D

@onready var light: OmniLight3D = $OmniLight3D
@onready var flash_sprite: Sprite3D = $FlashSprite
@onready var particles: CPUParticles3D = $CPUParticles3D

var _flash_tween: Tween = null

func _ready() -> void:
	visible = false
	if light:
		light.visible = false

func flash() -> void:
	visible = true
	if _flash_tween and _flash_tween.is_valid():
		_flash_tween.kill()
	
	# Randomize flash rotation & small realistic scale
	flash_sprite.rotation_degrees.z = randf_range(0, 360)
	var s = randf_range(0.08, 0.14) # Small realistic 8-14cm flash
	flash_sprite.scale = Vector3(s, s, s)
	
	light.light_energy = 1.8
	light.visible = true
	particles.restart()
	particles.emitting = true
	
	_flash_tween = create_tween()
	_flash_tween.tween_property(light, "light_energy", 0.0, 0.05)
	_flash_tween.parallel().tween_property(flash_sprite, "scale", Vector3.ZERO, 0.05)
	_flash_tween.tween_callback(func():
		visible = false
		light.visible = false
	)
