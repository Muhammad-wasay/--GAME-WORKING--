@tool
extends SceneTree

func _init():
	var gun_scn = load("res://scene/gun.scn").instantiate()
	var g1: MeshInstance3D = find_node(gun_scn, "Cube_005_9m1_0")
	var g2: MeshInstance3D = find_node(gun_scn, "Cube_005_9m2_0")
	
	var root = Node3D.new()
	root.name = "Pistol"
	
	var m1 = MeshInstance3D.new()
	m1.name = "Body"
	m1.mesh = g1.mesh
	m1.material_override = g1.mesh.surface_get_material(0)
	root.add_child(m1)
	m1.owner = root
	
	var m2 = MeshInstance3D.new()
	m2.name = "Details"
	m2.mesh = g2.mesh
	m2.material_override = g2.mesh.surface_get_material(0)
	root.add_child(m2)
	m2.owner = root
	
	# In Roy's skeleton, forearm length is ~0.0018 units (approx 20cm).
	# Gun mesh in gun.scn has AABB length 2.368 units.
	# So gun should be scaled to match hand/forearm proportions: ~0.0018 / 2.368 ≈ 0.00076 in skeleton space!
	# (or if BoneAttachment is scaled)
	root.scale = Vector3(0.0008, 0.0008, 0.0008)
	
	var packed = PackedScene.new()
	packed.pack(root)
	ResourceSaver.save(packed, "res://scene/equipped_pistol.tscn")
	print("Saved equipped_pistol.tscn successfully!")
	quit()

func find_node(n: Node, nm: String) -> Node:
	if n.name == nm: return n
	for c in n.get_children():
		var f = find_node(c, nm)
		if f: return f
	return null
