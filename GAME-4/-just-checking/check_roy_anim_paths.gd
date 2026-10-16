@tool
extends SceneTree

func _init():
	var a: Animation = load("res://animations/idle_2.anim")
	if a:
		print("idle_2 track count: ", a.get_track_count())
		for t in range(mini(5, a.get_track_count())):
			print("  track ", t, ": ", a.track_get_path(t), " type: ", a.track_get_type(t))
	quit()
