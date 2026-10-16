@tool
extends SceneTree

func _init():
	var scn = load("res://import/models/gun/fbx/pistolidel.fbx")
	var inst = scn.instantiate()
	var g1: MeshInstance3D = find_node_by_name(inst, "Cube_005_9m1_0")
	var g2: MeshInstance3D = find_node_by_name(inst, "Cube_005_9m2_0")
	print("g1 mesh: ", g1.mesh, " mat: ", g1.mesh.surface_get_material(0) if g1.mesh else "none")
	print("g2 mesh: ", g2.mesh, " mat: ", g2.mesh.surface_get_material(0) if g2.mesh else "none")
	if g1.mesh and g1.mesh.surface_get_material(0) is StandardMaterial3D:
		var sm = g1.mesh.surface_get_material(0) as StandardMaterial3D
		print("  g1 tex: ", sm.albedo_texture)
	if g2.mesh and g2.mesh.surface_get_material(0) is StandardMaterial3D:
		var sm = g2.mesh.surface_get_material(0) as StandardMaterial3D
		print("  g2 tex: ", sm.albedo_texture)
	quit()

func find_node_by_name(n: Node, nm: String) -> Node:
	if n.name == nm: return n
	for c in n.get_children():
		var f = find_node_by_name(c, nm)
		if f: return f
	return null
