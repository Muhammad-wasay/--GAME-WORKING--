extends Node3D

var player_in_range: bool = false
var player_node: Node3D = null
var is_picked_up: bool = false
var bob_time: float = 0.0
var base_model_y: float = 0.28

@onready var key_visual: Node3D = $KeyVisual
@onready var detection_area: Area3D = $Area3D
@onready var interaction_label: Node3D = $item_interaction
@onready var omni_light: OmniLight3D = $OmniLight3D

var ground_ring: MeshInstance3D = null
var ring_mat: StandardMaterial3D = null

func _ready() -> void:
	base_model_y = 0.22
	if key_visual:
		key_visual.position = Vector3(0, base_model_y, 0)
	
	# If user has KEY.scn in root, prioritize and instantiate it
	var active_model: Node3D = null
	if ResourceLoader.exists("res://KEY.scn"):
		var key_scn := load("res://KEY.scn") as PackedScene
		if key_scn and key_visual:
			for c in key_visual.get_children():
				key_visual.remove_child(c)
				c.queue_free()
			var user_key := key_scn.instantiate() as Node3D
			user_key.name = "UserKeyModel"
			key_visual.add_child(user_key)
			active_model = user_key
	elif key_visual and key_visual.get_child_count() > 0:
		active_model = key_visual.get_child(0) as Node3D
	
	# Center the key model precisely at (0,0,0) of KeyVisual and normalize size so it spins 360 in place
	if active_model:
		_center_and_scale_model(active_model, 0.22)
	
	# Apply shiny golden glow material to meshes inside key_visual
	_apply_golden_glow(key_visual)
	
	# Subtle ground halo ring (no vertical pillar!)
	_create_ground_ring()
	
	if omni_light:
		omni_light.light_energy = 1.35
		omni_light.omni_range = 2.2
	
	if detection_area:
		detection_area.body_entered.connect(_on_body_entered)
		detection_area.body_exited.connect(_on_body_exited)
	if interaction_label:
		interaction_label.visible = false
		interaction_label.position = Vector3(0, 0.42, 0)
		var lbl := interaction_label.get_node_or_null("interaction") as Label3D
		if lbl:
			lbl.transform = Transform3D.IDENTITY
			lbl.pixel_size = 0.0010
			lbl.font_size = 20
			lbl.outline_size = 6
			lbl.text = "[E] Pick up Cage Key"
			lbl.modulate = Color(1.0, 0.90, 0.35, 1.0)

func _create_ground_ring() -> void:
	ground_ring = MeshInstance3D.new()
	ground_ring.name = "GroundGlowRing"
	var torus := TorusMesh.new()
	torus.inner_radius = 0.14
	torus.outer_radius = 0.18
	torus.rings = 24
	torus.ring_segments = 12
	ring_mat = StandardMaterial3D.new()
	ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ring_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	ring_mat.albedo_color = Color(1.0, 0.82, 0.22, 0.55)
	ring_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	torus.material = ring_mat
	ground_ring.mesh = torus
	ground_ring.position = Vector3(0, 0.03, 0)
	add_child(ground_ring)

func _gather_meshes(node: Node, list: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D and node.mesh:
		list.append(node)
	for child in node.get_children():
		_gather_meshes(child, list)

func _get_transform_relative_to(node: Node3D, ancestor: Node3D) -> Transform3D:
	var t := Transform3D.IDENTITY
	var cur: Node3D = node
	while cur and cur != ancestor:
		t = cur.transform * t
		cur = cur.get_parent() as Node3D
	return t

func _center_and_scale_model(root: Node3D, target_max_size: float) -> void:
	root.position = Vector3.ZERO
	root.scale = Vector3.ONE
	var meshes: Array[MeshInstance3D] = []
	_gather_meshes(root, meshes)
	if meshes.is_empty():
		return
	
	var total_min := Vector3(INF, INF, INF)
	var total_max := Vector3(-INF, -INF, -INF)
	for m in meshes:
		if m.mesh:
			var aabb: AABB = m.mesh.get_aabb()
			var t_to_root: Transform3D = _get_transform_relative_to(m, root)
			var corners: Array[Vector3] = [
				aabb.position,
				aabb.position + Vector3(aabb.size.x, 0, 0),
				aabb.position + Vector3(0, aabb.size.y, 0),
				aabb.position + Vector3(0, 0, aabb.size.z),
				aabb.position + Vector3(aabb.size.x, aabb.size.y, 0),
				aabb.position + Vector3(aabb.size.x, 0, aabb.size.z),
				aabb.position + Vector3(0, aabb.size.y, aabb.size.z),
				aabb.position + aabb.size
			]
			for c in corners:
				var local_c: Vector3 = t_to_root * c
				total_min = total_min.min(local_c)
				total_max = total_max.max(local_c)
	
	if total_min.x != INF:
		var raw_size: Vector3 = total_max - total_min
		var max_dim: float = maxf(raw_size.x, maxf(raw_size.y, raw_size.z))
		var s: float = (target_max_size / max_dim) if max_dim > 0.0001 else 0.08
		root.scale = Vector3(s, s, s)
		var raw_center: Vector3 = (total_min + total_max) * 0.5
		# Offset by scaled basis * raw_center so the geometric center sits at (0,0,0) of KeyVisual!
		root.position = -(root.basis * raw_center)

func _apply_golden_glow(node: Node) -> void:
	if not node:
		return
	var gold_mat := StandardMaterial3D.new()
	gold_mat.albedo_color = Color(1.0, 0.85, 0.25, 1.0)
	gold_mat.metallic = 0.90
	gold_mat.roughness = 0.20
	gold_mat.emission_enabled = true
	gold_mat.emission = Color(1.0, 0.78, 0.20, 1.0)
	gold_mat.emission_energy_multiplier = 1.25
	gold_mat.rim_enabled = true
	gold_mat.rim = 0.85
	
	for child in node.get_children():
		if child is MeshInstance3D:
			child.material_override = gold_mat
		if child.get_child_count() > 0:
			_apply_golden_glow(child)

func _on_body_entered(body: Node3D) -> void:
	if body is CharacterBody3D and body.name == "Roy" and not is_picked_up:
		player_in_range = true
		player_node = body
		if interaction_label:
			interaction_label.visible = true

func _on_body_exited(body: Node3D) -> void:
	if body == player_node and not is_picked_up:
		player_in_range = false
		player_node = null
		if interaction_label:
			interaction_label.visible = false

func _process(delta: float) -> void:
	bob_time += delta * 2.8
	if key_visual:
		key_visual.rotate_y(delta * 2.0)
		key_visual.position = Vector3(0.0, base_model_y + sin(bob_time) * 0.04, 0.0)
	if ring_mat:
		ring_mat.albedo_color.a = 0.35 + (sin(bob_time * 1.5) * 0.5 + 0.5) * 0.35
	
	if player_in_range and not is_picked_up:
		if Input.is_action_just_pressed("interact"):
			pick_up()

func _make_key_icon() -> ImageTexture:
	var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var gold := Color(1.0, 0.82, 0.22, 1.0)
	var dark_gold := Color(0.75, 0.52, 0.08, 1.0)
	# Draw key bow (ring on left)
	for y in range(16, 48):
		for x in range(8, 30):
			var dx := float(x - 19)
			var dy := float(y - 32)
			var dist := sqrt(dx * dx + dy * dy)
			if dist >= 5.5 and dist <= 10.5:
				img.set_pixel(x, y, gold if dy < 0 else dark_gold)
	# Draw key shaft
	for y in range(29, 35):
		for x in range(28, 56):
			img.set_pixel(x, y, gold if y < 32 else dark_gold)
	# Draw key teeth
	for y in range(35, 45):
		for x in range(44, 48):
			img.set_pixel(x, y, dark_gold)
		for x in range(51, 55):
			img.set_pixel(x, y, gold)
	return ImageTexture.create_from_image(img)

func pick_up() -> void:
	if is_picked_up:
		return
	if player_node and player_node.has_method("add_to_inventory"):
		var item_data := {
			"id": "key",
			"name": "Cage Key",
			"icon": _make_key_icon(),
			"scene": load("res://scene/key_pickup.tscn"),
			"count": 1,
			"type": "key"
		}
		var added: bool = player_node.add_to_inventory(item_data)
		if added:
			is_picked_up = true
			if interaction_label:
				interaction_label.visible = false
			if player_node.has_method("show_tip_message"):
				player_node.show_tip_message("Cage Key acquired! Go unlock Jessica's Cage!", 4.5)
			var quest_mgr := get_tree().current_scene.find_child("StoryQuestManager", true, false)
			if quest_mgr and quest_mgr.has_method("on_key_picked_up"):
				quest_mgr.on_key_picked_up()
			queue_free()
