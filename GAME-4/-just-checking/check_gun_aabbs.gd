@tool
extends SceneTree

func _init():
	var p_scn = load("res://import/models/gun/fbx/pistolidel.fbx").instantiate()
	var g1_fbx: MeshInstance3D = find_node(p_scn, "Cube_005_9m1_0")
	if g1_fbx and g1_fbx.mesh:
		print("FBX Gun AABB: ", g1_fbx.mesh.get_aabb())

	var gun_scn = load("res://scene/gun.scn").instantiate()
	var g1_scn: MeshInstance3D = find_node(gun_scn, "Cube_005_9m1_0")
	if g1_scn and g1_scn.mesh:
		print("SCN Gun AABB: ", g1_scn.mesh.get_aabb())
		print("SCN Gun transform: ", g1_scn.transform)
	quit()

func find_node(n: Node, nm: String) -> Node:
	if n.name == nm: return n
	for c in n.get_children():
		var f = find_node(c, nm)
		if f: return f
	return null
