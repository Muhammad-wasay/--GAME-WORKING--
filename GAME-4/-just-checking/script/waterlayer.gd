extends Node3D

const RIVER_SOUND = preload("res://import/sound/water river sound.mp3")
var river_audio: AudioStreamPlayer3D = null

func _ready() -> void:
	_setup_river_sound()

func _setup_river_sound() -> void:
	if not RIVER_SOUND:
		return
	river_audio = AudioStreamPlayer3D.new()
	river_audio.name = "RiverFlowAudio3D"
	var stream_copy := RIVER_SOUND.duplicate()
	if stream_copy is AudioStreamMP3:
		stream_copy.loop = true
	river_audio.stream = stream_copy
	river_audio.volume_db = 4.0
	river_audio.unit_size = 7.5
	river_audio.max_distance = 34.0
	river_audio.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	var water_mesh := get_node_or_null("water") as Node3D
	if water_mesh:
		river_audio.position = water_mesh.position
	add_child(river_audio)
	river_audio.play()

func _process(_delta: float) -> void:
	if river_audio and not river_audio.playing:
		river_audio.play()

func _on_watervolume_body_entered(body: Node3D) -> void:
	if body is CharacterBody3D:
		print("Player pani mein enter ho gaya!")
		if body.has_method("enter_water"):
			# Water surface ki Y position pass karo
			# Node3D ka global_position.y water ke surface ke paas hogi
			var surface_y = global_position.y
			body.enter_water(surface_y)

func _on_watervolume_body_exited(body: Node3D) -> void:
	if body is CharacterBody3D:
		print("Player pani se bahar nikal gaya!")
		# Agar player ki script mein exit_water function hai toh usay call kar do
		if body.has_method("exit_water"):
			body.exit_water()
