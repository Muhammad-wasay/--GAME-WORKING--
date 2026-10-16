@tool
extends SceneTree

func _init():
	var inst = load("res://scene/Roy.tscn").instantiate()
	var skel: Skeleton3D = inst.get_node("visuals/person/Skeleton3D")
	var hand_idx = skel.find_bone("mixamorig_RightHand")
	var arm_idx = skel.find_bone("mixamorig_RightForeArm")
	var hand_p = skel.get_bone_global_pose(hand_idx).origin
	var arm_p = skel.get_bone_global_pose(arm_idx).origin
	print("Hand bone origin in skel: ", hand_p)
	print("Arm bone origin in skel: ", arm_p)
	print("Forearm length in skel: ", hand_p.distance_to(arm_p))
	# Multiply by person.scale (100)
	print("Forearm length in world: ", hand_p.distance_to(arm_p) * 100.0 * 1.08)
	quit()
