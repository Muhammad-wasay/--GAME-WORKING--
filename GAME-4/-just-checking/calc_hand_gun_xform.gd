@tool
extends SceneTree

func _init():
	var inst = load("res://import/models/gun/fbx/pistolidel.fbx").instantiate()
	var skel: Skeleton3D = find_skel(inst)
	var g1: Node3D = find_node(inst, "Cube_005_9m1_0")
	var hand_idx = skel.find_bone("mixamorig2_RightHand")
	
	# Skeleton global rest / pose of RightHand
	var hand_pose = skel.get_bone_global_pose(hand_idx)
	print("Hand bone pose: ", hand_pose)
	
	# Gun global transform in FBX
	# gun is under Empty
	var empty = g1.get_parent()
	var gun_local = empty.transform * g1.transform
	print("Gun under model: ", gun_local)
	
	# Transform of gun relative to hand:
	var rel_xform = hand_pose.affine_inverse() * gun_local
	print("Relative transform gun-to-hand: ", rel_xform)
	quit()

func find_skel(n: Node) -> Skeleton3D:
	if n is Skeleton3D: return n
	for c in n.get_children():
		var s = find_skel(c)
		if s: return s
	return null

func find_node(n: Node, nm: String) -> Node:
	if n.name == nm: return n
	for c in n.get_children():
		var f = find_node(c, nm)
		if f: return f
	return null
