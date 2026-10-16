@tool
extends SceneTree

func _init():
	var scale_factor = 0.0059344 / 0.997919 # ~0.005946775
	print("Scale factor for Roy: ", scale_factor)
	
	var anim_map = {
		"pistol_idle.anim": {"file": "pistol idle.fbx", "loop": Animation.LOOP_LINEAR},
		"pistol_walk.anim": {"file": "Pistol Walk.fbx", "loop": Animation.LOOP_LINEAR},
		"pistol_run.anim": {"file": "Pistol Run.fbx", "loop": Animation.LOOP_LINEAR},
		"pistol_jump.anim": {"file": "pistol jump.fbx", "loop": Animation.LOOP_NONE},
		"pistol_crouch_idle.anim": {"file": "Pistol Kneeling Idle.fbx", "loop": Animation.LOOP_LINEAR},
		"pistol_crouch_to_up.anim": {"file": "Pistol Kneel To Stand.fbx", "loop": Animation.LOOP_NONE},
		"pistol_stand_to_crouch.anim": {"file": "Pistol Stand To Kneel.fbx", "loop": Animation.LOOP_NONE}
	}
	
	for dest_name in anim_map:
		var cfg = anim_map[dest_name]
		var fbx_path = "res://import/models/gun/gun aimation/" + cfg["file"]
		var scn: PackedScene = load(fbx_path)
		if not scn:
			printerr("Failed to load: ", fbx_path)
			continue
		var inst = scn.instantiate()
		var ap: AnimationPlayer = find_ap(inst)
		if not ap or not ap.has_animation("mixamo_com"):
			printerr("Missing mixamo_com in ", fbx_path)
			continue
		
		var anim: Animation = ap.get_animation("mixamo_com").duplicate()
		anim.loop_mode = cfg["loop"]
		
		# Retarget track paths from mixamorig2_ to mixamorig_
		for t in range(anim.get_track_count()):
			var p = str(anim.track_get_path(t))
			var new_p = p.replace("mixamorig2_", "mixamorig_")
			# Also ensure prefix is Skeleton3D:
			if not new_p.begins_with("Skeleton3D:"):
				var colon_idx = new_p.find(":")
				if colon_idx != -1:
					new_p = "Skeleton3D" + new_p.substr(colon_idx)
			anim.track_set_path(t, NodePath(new_p))
			
			# Scale position tracks
			if anim.track_get_type(t) == Animation.TYPE_POSITION_3D:
				var k_count = anim.track_get_key_count(t)
				for k in range(k_count):
					var val = anim.track_get_key_value(t, k)
					anim.track_set_key_value(t, k, val * scale_factor)
					
		var dest_path = "res://animations/" + dest_name
		var err = ResourceSaver.save(anim, dest_path)
		print("Saved: ", dest_path, " err=", err)
		
		# Check Hips value
		for t in range(anim.get_track_count()):
			if str(anim.track_get_path(t)).ends_with("Hips") and anim.track_get_type(t) == Animation.TYPE_POSITION_3D:
				print("   ", dest_name, " Hips[0] = ", anim.track_get_key_value(t, 0))

	quit()

func find_ap(n: Node) -> AnimationPlayer:
	if n is AnimationPlayer: return n
	for c in n.get_children():
		var a = find_ap(c)
		if a: return a
	return null
