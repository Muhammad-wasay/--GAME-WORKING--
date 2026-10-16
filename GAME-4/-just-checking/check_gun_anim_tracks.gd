@tool
extends SceneTree

func _init():
	var scn = load("res://import/models/gun/fbx/pistolidel.fbx")
	var inst = scn.instantiate()
	var ap = find_ap(inst)
	if ap:
		for a_name in ap.get_animation_list():
			var a = ap.get_animation(a_name)
			print("Anim: ", a_name, " len=", a.length, " tracks=", a.get_track_count())
			if a.get_track_count() > 0:
				for t in range(mini(5, a.get_track_count())):
					print("   track ", t, ": ", a.track_get_path(t))
	quit()

func find_ap(n: Node) -> AnimationPlayer:
	if n is AnimationPlayer: return n
	for c in n.get_children():
		var a = find_ap(c)
		if a: return a
	return null
