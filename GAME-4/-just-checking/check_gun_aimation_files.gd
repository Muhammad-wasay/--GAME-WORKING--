@tool
extends SceneTree

func _init():
	var dir = DirAccess.open("res://import/models/gun/gun aimation")
	if dir:
		for f in dir.get_files():
			if f.ends_with(".fbx"):
				var scn = load("res://import/models/gun/gun aimation/" + f)
				if scn:
					var inst = scn.instantiate()
					var ap = find_ap(inst)
					var anims = []
					if ap:
						anims = ap.get_animation_list()
					print(f, " -> ", anims)
	quit()

func find_ap(n: Node) -> AnimationPlayer:
	if n is AnimationPlayer: return n
	for c in n.get_children():
		var a = find_ap(c)
		if a: return a
	return null
