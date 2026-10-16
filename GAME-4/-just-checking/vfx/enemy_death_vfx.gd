extends Node3D

# Stylized Toon / Cartoon Cloud Poof & Dust Ring VFX for Enemy Death
# Creates billowing cel-shaded cloud puffs ("poof!") + expanding ground dust ring

func _ready() -> void:
	_build_toon_death_poof()

func _build_toon_death_poof() -> void:
	# 1. Expanding Toon Ground Dust Ring (compact & proportional to character scale)
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.11
	torus.outer_radius = 0.16
	torus.rings = 20
	torus.ring_segments = 10
	var ring_mat := StandardMaterial3D.new()
	ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring_mat.albedo_color = Color(0.95, 0.92, 0.84, 1.0)
	torus.material = ring_mat
	ring.mesh = torus
	ring.position = Vector3(0, 0.03, 0)
	ring.scale = Vector3(0.15, 0.25, 0.15)
	add_child(ring)
	
	var rt := create_tween()
	rt.tween_property(ring, "scale", Vector3(1.35, 0.18, 1.35), 0.34).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	rt.tween_property(ring, "scale", Vector3(1.65, 0.01, 1.65), 0.16)
	rt.tween_callback(ring.hide)
	
	# 2. Billowing Toon Cloud Poof Balls (compact cartoon poof!)
	var cloud_colors: Array[Color] = [
		Color(0.97, 0.95, 0.90), # Bright cartoon cloud white/cream
		Color(0.90, 0.87, 0.80), # Warm light grey-cream puff
		Color(0.82, 0.78, 0.72), # Soft shadow puff
		Color(1.0, 0.85, 0.55)   # Golden/warm toon highlight puff
	]
	
	var puff_count := 12
	for i in range(puff_count):
		var puff := MeshInstance3D.new()
		var sph := SphereMesh.new()
		var is_core := i < 4
		var base_r := randf_range(0.075, 0.115) if is_core else randf_range(0.045, 0.08)
		sph.radius = base_r
		sph.height = base_r * 2.0
		sph.radial_segments = 14
		sph.rings = 8
		
		var p_mat := StandardMaterial3D.new()
		p_mat.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
		p_mat.specular_mode = BaseMaterial3D.SPECULAR_TOON
		var col: Color = cloud_colors[i % cloud_colors.size()]
		p_mat.albedo_color = col
		p_mat.roughness = 0.95
		p_mat.emission_enabled = true
		p_mat.emission = col * 0.30
		sph.material = p_mat
		puff.mesh = sph
		add_child(puff)
		
		var angle := (TAU / float(puff_count)) * float(i) + randf_range(-0.2, 0.2)
		var dist := randf_range(0.05, 0.15) if is_core else randf_range(0.14, 0.30)
		var target_y := randf_range(0.08, 0.25) if is_core else randf_range(0.04, 0.18)
		var target_pos := Vector3(cos(angle) * dist, target_y, sin(angle) * dist)
		
		puff.position = Vector3(cos(angle) * 0.03, 0.05, sin(angle) * 0.03)
		puff.scale = Vector3(0.05, 0.05, 0.05)
		
		var delay := randf_range(0.0, 0.06)
		var pop_time := randf_range(0.12, 0.18)
		var dissipate_time := randf_range(0.26, 0.42)
		
		var pt := create_tween()
		if delay > 0.0:
			pt.tween_interval(delay)
		pt.tween_property(puff, "position", target_pos, pop_time + dissipate_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		
		var st := create_tween()
		if delay > 0.0:
			st.tween_interval(delay)
		st.tween_property(puff, "scale", Vector3(1.0, 0.9, 1.0), pop_time).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		st.tween_property(puff, "scale", Vector3.ZERO, dissipate_time).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	
	# Cleanup after all toon puffs pop out
	var cleanup := create_tween()
	cleanup.tween_interval(0.80)
	cleanup.tween_callback(queue_free)
