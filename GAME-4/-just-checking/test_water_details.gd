@tool
extends SceneTree

func _init():
	print("=== TESTING WATER AND ROY ANIMATIONS ===")
	
	# 1. Load Roy.tscn and test swimming and water_idle animations
	var roy_scn = load("res://scene/Roy.tscn")
	var roy = roy_scn.instantiate()
	var ap: AnimationPlayer = roy.get_node("visuals/person/AnimationPlayer")
	print("Roy AnimationPlayer:", ap)
	print("Has NewLib/swimming: ", ap.has_animation("NewLib/swimming"))
	print("Has NewLib/water_idle: ", ap.has_animation("NewLib/water_idle"))
	
	var swim_anim: Animation = ap.get_animation("NewLib/swimming")
	print("Swimming anim track count: ", swim_anim.get_track_count(), " length: ", swim_anim.length)
	for i in range(mini(5, swim_anim.get_track_count())):
		print("  Swim track ", i, ": ", swim_anim.track_get_path(i), " type: ", swim_anim.track_get_type(i))
		if swim_anim.track_get_type(i) == Animation.TYPE_POSITION_3D:
			print("    pos@0: ", swim_anim.position_track_interpolate(i, 0.0))
			
	var water_idle_anim: Animation = ap.get_animation("NewLib/water_idle")
	print("Water idle anim track count: ", water_idle_anim.get_track_count(), " length: ", water_idle_anim.length)
	for i in range(mini(5, water_idle_anim.get_track_count())):
		print("  WaterIdle track ", i, ": ", water_idle_anim.track_get_path(i), " type: ", water_idle_anim.track_get_type(i))
		if water_idle_anim.track_get_type(i) == Animation.TYPE_POSITION_3D:
			print("    pos@0: ", water_idle_anim.position_track_interpolate(i, 0.0))
	
	# 2. Check watervolume in terrain.scn
	var terrain_scn = load("res://scene/terrain.scn")
	var terrain = terrain_scn.instantiate()
	var waterlayer = terrain.get_node_or_null("waterlayer")
	if waterlayer:
		print("waterlayer found in terrain!")
		print("waterlayer global_pos: ", waterlayer.position)
		var watervolume: Area3D = waterlayer.get_node_or_null("watervolume")
		if watervolume:
			print("watervolume collision_layer: ", watervolume.collision_layer, " mask: ", watervolume.collision_mask)
			var cs = watervolume.get_node_or_null("CollisionShape3D")
			if cs:
				print("watervolume shape: ", cs.shape, " pos: ", cs.position)
				if cs.shape is BoxShape3D:
					print("Box size: ", cs.shape.size)
			print("Signals on watervolume: ", watervolume.body_entered.get_connections())
	else:
		print("waterlayer NOT found in terrain.scn!")
		
	# 3. Check Roy's collision_layer and mask
	print("Roy collision_layer: ", roy.collision_layer, " mask: ", roy.collision_mask)
	quit()
