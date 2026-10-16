@tool
extends SceneTree

func _init():
	var anims = [
		"crouch_idle", "crouch_to_up", "crouch_walking", "idle_2",
		"jessica_walk", "slow_run", "swimming", "water_idle"
	]
	print("=== CHECKING ALL ANIMS IN FEMALE.TSCN ===")
	for a in anims:
		var res = load("res://animations/" + a + ".anim")
		if not res:
			print("Could not load: ", a)
			continue
		for i in range(res.get_track_count()):
			if res.track_get_type(i) == Animation.TYPE_POSITION_3D:
				print(a, " Hips pos@0: ", res.position_track_interpolate(i, 0.0))
	quit()
