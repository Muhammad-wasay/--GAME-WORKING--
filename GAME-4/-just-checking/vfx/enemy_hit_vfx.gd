extends Node3D

# Procedural Toon / Anime Style Puff VFX
# Uses cel-shaded matte cloud spheres ("puffs") + cartoon impact star/ring that pop out, billow, and shrink cleanly!

var puff_spheres: Array[MeshInstance3D] = []
var ring_mesh: MeshInstance3D = null
var star_strips: Array[MeshInstance3D] = []

func _ready() -> void:
	_build_toon_hit_puff()

func _build_toon_hit_puff() -> void:
	# 1. Central Cartoon Impact Flash Star (2 crossed flat quads that pop & vanish in 0.12s)
	var flash_mat := StandardMaterial3D.new()
	flash_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	flash_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	flash_mat.albedo_color = Color(1.0, 0.96, 0.72, 1.0)
	flash_mat.no_depth_test = true
	
	for i in range(3):
		var star := MeshInstance3D.new()
		var q := QuadMesh.new()
		q.size = Vector2(0.14, 0.03)
		q.material = flash_mat
		star.mesh = q
		star.rotation.z = deg_to_rad(i * 60.0 + randf_range(-10.0, 10.0))
		add_child(star)
		star_strips.append(star)
		
		star.scale = Vector3(0.15, 0.15, 0.15)
		var st := create_tween()
		st.tween_property(star, "scale", Vector3(0.9, 0.9, 0.9), 0.06).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		st.tween_property(star, "scale", Vector3.ZERO, 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	
	# 2. Stylized Toon Shockwave Ring (compact flat cream-orange cartoon ring)
	ring_mesh = MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.03
	torus.outer_radius = 0.045
	torus.rings = 14
	torus.ring_segments = 8
	var ring_mat := StandardMaterial3D.new()
	ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring_mat.albedo_color = Color(1.0, 0.82, 0.45, 1.0)
	torus.material = ring_mat
	ring_mesh.mesh = torus
	ring_mesh.rotation.x = PI * 0.5
	ring_mesh.scale = Vector3(0.1, 0.1, 0.1)
	add_child(ring_mesh)
	
	var rt := create_tween()
	rt.tween_property(ring_mesh, "scale", Vector3(0.42, 0.15, 0.42), 0.14).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	rt.tween_property(ring_mesh, "scale", Vector3(0.50, 0.01, 0.50), 0.08)
	rt.tween_callback(ring_mesh.hide)
	
	# 3. Cluster of Toon Puff Cloud Spheres (compact cel-shaded puffs)
	var puff_colors: Array[Color] = [
		Color(0.98, 0.96, 0.90), # Warm cream toon cloud
		Color(0.95, 0.92, 0.85), # Soft beige cloud
		Color(1.0, 0.72, 0.48),  # Stylized warm hit accent
		Color(0.92, 0.35, 0.28)  # Stylized crimson/coral toon accent
	]
	
	var puff_count := 8
	for i in range(puff_count):
		var puff := MeshInstance3D.new()
		var sph := SphereMesh.new()
		var base_r := randf_range(0.016, 0.028)
		sph.radius = base_r
		sph.height = base_r * 2.0
		sph.radial_segments = 12
		sph.rings = 6
		
		var p_mat := StandardMaterial3D.new()
		p_mat.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
		p_mat.specular_mode = BaseMaterial3D.SPECULAR_TOON
		var col: Color = puff_colors[i % puff_colors.size()]
		p_mat.albedo_color = col
		p_mat.roughness = 0.95
		# Slight rim/emission so toon puffs pop in forest lighting
		p_mat.emission_enabled = true
		p_mat.emission = col * 0.35
		sph.material = p_mat
		puff.mesh = sph
		add_child(puff)
		
		# Compute outward burst direction around local +Z (hit normal)
		var angle := (TAU / float(puff_count)) * float(i) + randf_range(-0.25, 0.25)
		var radial := randf_range(0.035, 0.075)
		var forward_push := randf_range(0.02, 0.06)
		var target_offset := Vector3(cos(angle) * radial, sin(angle) * radial + 0.01, forward_push)
		
		puff.position = target_offset * 0.15
		puff.scale = Vector3(0.05, 0.05, 0.05)
		
		var pop_dur := randf_range(0.08, 0.12)
		var hold_dur := randf_range(0.12, 0.20)
		
		var pt := create_tween()
		# Pop out fast (elastic cartoon feel)
		pt.set_parallel(true)
		pt.tween_property(puff, "position", target_offset, pop_dur + hold_dur).set_trans(Tween.TRANS_CIRC).set_ease(Tween.EASE_OUT)
		pt.tween_property(puff, "scale", Vector3(1.0, 1.0, 1.0), pop_dur).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		
		# Then shrink down to 0 like classic anime/toon smoke puffs
		var shrink_t := create_tween()
		shrink_t.tween_interval(pop_dur)
		shrink_t.tween_property(puff, "scale", Vector3.ZERO, hold_dur).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	
	# Cleanup node after puff finishes
	var cleanup := create_tween()
	cleanup.tween_interval(0.42)
	cleanup.tween_callback(queue_free)
