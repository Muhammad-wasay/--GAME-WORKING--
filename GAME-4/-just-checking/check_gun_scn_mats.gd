@tool
extends SceneTree

func _init():
	var scn = load("res://scene/gun.scn")
	var inst = scn.instantiate()
	var g1: MeshInstance3D = find_node_by_name(inst, "Cube_005_9m1_0")
	var g2: MeshInstance3D = find_node_by_name(inst, "Cube_005_9m2_0")
	if g1 and g1.mesh:
		var sm = g1.mesh.surface_get_material(0) as StandardMaterial3D
		print("gun.scn g1 tex: ", sm.albedo_texture if sm else "none")
	if g2 and g2.mesh:
		var sm = g2.mesh.surface_get_material(0) as StandardMaterial3D
		print("gun.scn g2 tex: ", sm.albedo_texture if sm else "none")
	quit()

func find_node_by_name(n: Node, nm: String) -> Node:
	if n.name == nm: return n
	for c in n.get_children():
		var f = find_node_by_name(c, nm)
		if f: return f
	return null
