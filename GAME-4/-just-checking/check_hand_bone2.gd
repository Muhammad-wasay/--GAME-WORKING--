@tool
extends SceneTree

func _init():
	var scn = load("res://scene/Roy.tscn")
	var inst = scn.instantiate()
	var skel: Skeleton3D = inst.get_node("visuals/person/Skeleton3D")
	var b_idx = skel.find_bone("mixamorig_RightHand")
	print("RightHand idx: ", b_idx, " name: ", skel.get_bone_name(b_idx) if b_idx != -1 else "none")
	quit()
