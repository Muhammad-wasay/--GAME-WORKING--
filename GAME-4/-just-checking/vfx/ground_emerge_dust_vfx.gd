extends Node3D

# Stylized Ground Emergence Dust & Dirt VFX ("Dhool Mitti Burst")
# Triggered when enemies/zombies emerge from underground.
# Features:
# 1. Ruptured earth ground ring
# 2. Billowing forest dirt/dust clouds rising from the breach
# 3. Flying soil clods and earthen debris bursting upward
# 4. 3D audio earth rupture sound

var SFX_DIRT_RUMBLE: AudioStream = null

func _ready() -> void:
	if ResourceLoader.exists("res://import/sound/comic_sfx/page6_title_boom.wav"):
		SFX_DIRT_RUMBLE = load("res://import/sound/comic_sfx/page6_title_boom.wav")
	elif ResourceLoader.exists("res://import/sound/male_character/freesound_community-footstep-1-83098.mp3"):
		SFX_DIRT_RUMBLE = load("res://import/sound/male_character/freesound_community-footstep-1-83098.mp3")
	
	_play_dirt_sound()
	_build_ruptured_ground_ring()
	_build_billowing_dust_clouds()
	_build_flying_dirt_clods()
	
	var cleanup := create_tween()
	cleanup.tween_interval(1.45)
	cleanup.tween_callback(queue_free)

func _play_dirt_sound() -> void:
	if not SFX_DIRT_RUMBLE:
		return
	var audio := AudioStreamPlayer3D.new()
	audio.name = "DirtBurstAudio"
	audio.stream = SFX_DIRT_RUMBLE
	audio.pitch_scale = randf_range(0.75, 0.95)
	audio.volume_db = -2.0
	audio.unit_size = 4.0
	audio.max_distance = 25.0
	add_child(audio)
	audio.play()

func _build_ruptured_ground_ring() -> void:
	# Expanding ring of disturbed dirt on the ground
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.08
	torus.outer_radius = 0.15
	torus.rings = 16
	torus.ring_segments = 8
	
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	mat.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
	mat.albedo_color = Color(0.32, 0.22, 0.13, 0.95)
	mat.roughness = 0.98
	torus.material = mat
	
	ring.mesh = torus
	ring.position = Vector3(0, 0.02, 0)
	ring.scale = Vector3(0.2, 0.25, 0.2)
	add_child(ring)
	
	var rt := create_tween()
	rt.tween_property(ring, "scale", Vector3(1.65, 0.12, 1.65), 0.38).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	rt.tween_property(ring, "scale", Vector3(2.10, 0.01, 2.10), 0.35)
	rt.tween_callback(ring.hide)

func _build_billowing_dust_clouds() -> void:
	# Billowing clouds of brown and tan forest dust rising upward
	var dust_colors: Array[Color] = [
		Color(0.48, 0.38, 0.26), # Forest loam dirt
		Color(0.58, 0.48, 0.34), # Tan forest dust
		Color(0.38, 0.28, 0.18), # Deep dark earth
		Color(0.65, 0.55, 0.42)  # Dry surface dust
	]
	
	var cloud_count := 12
	for i in range(cloud_count):
		var puff := MeshInstance3D.new()
		var sph := SphereMesh.new()
		var base_radius := randf_range(0.08, 0.15)
		sph.radius = base_radius
		sph.height = base_radius * 1.85
		sph.radial_segments = 12
		sph.rings = 6
		
		var p_mat := StandardMaterial3D.new()
		p_mat.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
		p_mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
		var col: Color = dust_colors[i % dust_colors.size()]
		p_mat.albedo_color = col
		p_mat.roughness = 1.0
		sph.material = p_mat
		puff.mesh = sph
		add_child(puff)
		
		var angle := (TAU / float(cloud_count)) * float(i) + randf_range(-0.35, 0.35)
		var spread_dist := randf_range(0.12, 0.34)
		var rise_height := randf_range(0.25, 0.62)
		var target_pos := Vector3(cos(angle) * spread_dist, rise_height, sin(angle) * spread_dist)
		
		puff.position = Vector3(cos(angle) * 0.04, 0.02, sin(angle) * 0.04)
		puff.scale = Vector3(0.08, 0.08, 0.08)
		
		var delay := randf_range(0.0, 0.12)
		var rise_time := randf_range(0.24, 0.38)
		var fade_time := randf_range(0.45, 0.70)
		
		var pt := create_tween()
		if delay > 0.0:
			pt.tween_interval(delay)
		pt.tween_property(puff, "position", target_pos, rise_time + fade_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		
		var st := create_tween()
		if delay > 0.0:
			st.tween_interval(delay)
		st.tween_property(puff, "scale", Vector3(1.15, 1.30, 1.15), rise_time).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		st.tween_property(puff, "scale", Vector3.ZERO, fade_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

func _build_flying_dirt_clods() -> void:
	# Small chunky soil/dirt pebbles bursting outward
	var clod_count := 14
	for i in range(clod_count):
		var clod := MeshInstance3D.new()
		var box := BoxMesh.new()
		var clod_size := randf_range(0.025, 0.055)
		box.size = Vector3(clod_size, clod_size * randf_range(0.7, 1.4), clod_size)
		
		var c_mat := StandardMaterial3D.new()
		c_mat.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
		c_mat.albedo_color = Color(randf_range(0.22, 0.34), randf_range(0.14, 0.22), randf_range(0.08, 0.14))
		box.material = c_mat
		clod.mesh = box
		add_child(clod)
		
		var angle := randf() * TAU
		var burst_dist := randf_range(0.25, 0.65)
		var burst_peak_y := randf_range(0.35, 0.75)
		
		clod.position = Vector3(0.0, 0.03, 0.0)
		clod.rotation = Vector3(randf() * TAU, randf() * TAU, randf() * TAU)
		
		var peak_pos := Vector3(cos(angle) * (burst_dist * 0.5), burst_peak_y, sin(angle) * (burst_dist * 0.5))
		var land_pos := Vector3(cos(angle) * burst_dist, 0.01, sin(angle) * burst_dist)
		
		var fly_time := randf_range(0.20, 0.32)
		var fall_time := randf_range(0.25, 0.38)
		
		var mt := create_tween()
		mt.tween_property(clod, "position", peak_pos, fly_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		mt.tween_property(clod, "position", land_pos, fall_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		
		var rot_tween := create_tween()
		rot_tween.tween_property(clod, "rotation", clod.rotation + Vector3(randf_range(2.0, 6.0), randf_range(2.0, 6.0), 0), fly_time + fall_time)
		
		var scale_tween := create_tween()
		scale_tween.tween_interval(fly_time + fall_time + randf_range(0.15, 0.35))
		scale_tween.tween_property(clod, "scale", Vector3.ZERO, 0.18)
