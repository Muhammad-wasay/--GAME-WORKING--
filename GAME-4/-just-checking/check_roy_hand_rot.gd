@tool
extends SceneTree

func _init():
	var inst = load("res://scene/Roy.tscn").instantiate()
	var skel: Skeleton3D = inst.get_node("visuals/person/Skeleton3D")
	var ap: AnimationPlayer = inst.get_node("visuals/person/AnimationPlayer")
	
	var lib = ap.get_animation_library("NewLib")
	lib.add_animation("pistol_idle", load("res://animations/pistol_idle.anim"))
	ap.play("NewLib/pistol_idle")
	ap.advance(0.1)
	
	var hand_idx = skel.find_bone("mixamorig_RightHand")
	var hand_rest = skel.get_bone_rest(hand_idx)
	var hand_pose = skel.get_bone_global_pose(hand_idx)
	print("Hand rest: ", hand_rest)
	print("Hand pose: ", hand_pose)
	quit()
