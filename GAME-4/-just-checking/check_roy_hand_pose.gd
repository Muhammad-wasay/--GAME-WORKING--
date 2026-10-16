@tool
extends SceneTree

func _init():
	var inst = load("res://scene/Roy.tscn").instantiate()
	var skel: Skeleton3D = inst.get_node("visuals/person/Skeleton3D")
	var hand_idx = skel.find_bone("mixamorig_RightHand")
	print("Roy RightHand pose: ", skel.get_bone_global_pose(hand_idx))
	print("Roy person transform: ", inst.get_node("visuals/person").transform)
	print("Roy visuals transform: ", inst.get_node("visuals").transform)
	quit()
