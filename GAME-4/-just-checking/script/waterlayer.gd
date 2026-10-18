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

@onready var water_volume: Area3D = get_node_or_null("watervolume") as Area3D

func _process(_delta: float) -> void:
	if river_audio and not river_audio.playing:
		river_audio.play()

func get_water_surface_y() -> float:
	var water_mesh := get_node_or_null("water") as MeshInstance3D
	if water_mesh and water_mesh.mesh is BoxMesh:
		var bm := water_mesh.mesh as BoxMesh
		var scale_y: float = absf(water_mesh.global_basis.get_scale().y)
		return water_mesh.global_position.y + (bm.size.y * 0.5 * scale_y)
	return global_position.y

func _physics_process(_delta: float) -> void:
	if not water_volume:
		return
	var surface_y: float = get_water_surface_y()
	for body in water_volume.get_overlapping_bodies():
		if body is CharacterBody3D and body.has_method("enter_water"):
			if "water_surface_y" in body:
				body.water_surface_y = surface_y
			
			var cur_scale_y: float = absf(body.global_basis.get_scale().y)
			var player_height: float = 1.23 * cur_scale_y
			var submergence: float = surface_y - body.global_position.y
			
			# Deep water check: only force swimming if body is deeply submerged (>=65% height)
			# or if body is off the ground in deep water (>=35% height and not on floor).
			var should_swim: bool = false
			if submergence >= (player_height * 0.65):
				should_swim = true
			elif submergence >= (player_height * 0.35) and not body.is_on_floor():
				should_swim = true
			
			var currently_swimming: bool = body.get("is_swimming") == true
			if should_swim and not currently_swimming:
				body.enter_water(surface_y)
			elif not should_swim and currently_swimming and body.is_on_floor():
				if body.has_method("exit_water"):
					body.exit_water()

func _on_watervolume_body_entered(body: Node3D) -> void:
	if body is CharacterBody3D:
		var surface_y: float = get_water_surface_y()
		if "water_surface_y" in body:
			body.water_surface_y = surface_y
		var cur_scale_y: float = absf(body.global_basis.get_scale().y)
		var player_height: float = 1.23 * cur_scale_y
		var submergence: float = surface_y - body.global_position.y
		if body.has_method("enter_water") and submergence >= (player_height * 0.65):
			body.enter_water(surface_y)

func _on_watervolume_body_exited(body: Node3D) -> void:
	if body is CharacterBody3D:
		if body.has_method("exit_water"):
			body.exit_water()
