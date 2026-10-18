extends Node3D
class_name AmmoPickup

var player_in_range: bool = false
var player_node: CharacterBody3D = null
var is_picked_up: bool = false
var bob_time: float = 0.0
var base_model_y: float = 0.22

@export var ammo_amount: int = 12

@onready var visual_root: Node3D = $VisualRoot
@onready var detection_area: Area3D = $Area3D
@onready var interaction_label: Node3D = $item_interaction
@onready var omni_light: OmniLight3D = $OmniLight3D

var ground_ring: MeshInstance3D = null
var ring_mat: StandardMaterial3D = null
var ammo_meshes: Array[MeshInstance3D] = []

func _ready() -> void:
	base_model_y = 0.18
	if visual_root:
		visual_root.position = Vector3(0, base_model_y, 0)
	
	# Instantiate pistol_ammo.glb inside visual_root
	if ResourceLoader.exists("res://import/models/skell/pistol_ammo.glb"):
		var model_scn := load("res://import/models/skell/pistol_ammo.glb") as PackedScene
		if model_scn and visual_root:
			for c in visual_root.get_children():
				visual_root.remove_child(c)
				c.queue_free()
			var ammo_model := model_scn.instantiate() as Node3D
			ammo_model.name = "PistolAmmoModel"
			visual_root.add_child(ammo_model)
			_center_and_scale_model(ammo_model, 0.20)
			_apply_shiny_glow(ammo_model)
	
	# Subtle ground halo ring (no vertical pillar!)
	_create_ground_ring()
	
	if omni_light:
		omni_light.light_energy = 1.15
		omni_light.omni_range = 2.0
	
	if detection_area:
		detection_area.body_entered.connect(_on_body_entered)
		detection_area.body_exited.connect(_on_body_exited)
	
	if interaction_label:
		interaction_label.visible = false
		interaction_label.position = Vector3(0, 0.38, 0)
		var lbl := interaction_label.get_node_or_null("interaction") as Label3D
		if lbl:
			lbl.transform = Transform3D.IDENTITY
			lbl.pixel_size = 0.0010
			lbl.font_size = 20
			lbl.outline_size = 6
			lbl.text = "[E] Pistol Ammo (+%d)" % ammo_amount
			lbl.modulate = Color(0.45, 0.92, 1.0, 1.0)

func _create_ground_ring() -> void:
	ground_ring = MeshInstance3D.new()
	ground_ring.name = "AmmoGroundRing"
	var torus := TorusMesh.new()
	torus.inner_radius = 0.13
	torus.outer_radius = 0.17
	torus.rings = 24
	torus.ring_segments = 12
	ring_mat = StandardMaterial3D.new()
	ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ring_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	ring_mat.albedo_color = Color(0.25, 0.85, 1.0, 0.50)
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
		var s: float = (target_max_size / max_dim) if max_dim > 0.0001 else 0.14
		root.scale = Vector3(s, s, s)
		var raw_center := (total_min + total_max) * 0.5
		root.position = -(root.basis * raw_center)

func _apply_shiny_glow(node: Node) -> void:
	ammo_meshes.clear()
	_gather_meshes(node, ammo_meshes)
	for m in ammo_meshes:
		if not m or not m.mesh:
			continue
		for s in range(m.mesh.get_surface_count()):
			var orig_mat := m.get_active_material(s)
			var shiny_mat: StandardMaterial3D = null
			if orig_mat is StandardMaterial3D:
				shiny_mat = orig_mat.duplicate() as StandardMaterial3D
			else:
				shiny_mat = StandardMaterial3D.new()
				shiny_mat.albedo_color = Color(0.35, 0.78, 0.95, 1.0)
			shiny_mat.emission_enabled = true
			shiny_mat.emission = Color(0.20, 0.72, 1.0, 1.0)
			shiny_mat.emission_energy_multiplier = 0.65
			shiny_mat.rim_enabled = true
			shiny_mat.rim = 0.8
			m.set_surface_override_material(s, shiny_mat)

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
	if visual_root:
		visual_root.rotate_y(delta * 2.0)
		visual_root.position = Vector3(0.0, base_model_y + sin(bob_time) * 0.035, 0.0)
	if ring_mat:
		ring_mat.albedo_color.a = 0.30 + (sin(bob_time * 1.5) * 0.5 + 0.5) * 0.35
	
	if player_in_range and not is_picked_up:
		if Input.is_action_just_pressed("interact"):
			pick_up()

func pick_up() -> void:
	if is_picked_up:
		return
	if player_node and player_node.has_method("add_ammo"):
		is_picked_up = true
		player_node.add_ammo(ammo_amount)
		if interaction_label:
			interaction_label.visible = false
		if player_node.has_method("show_tip_message"):
			player_node.show_tip_message("+%d Pistol Ammo picked up!" % ammo_amount, 2.5)
		
		# Small toon pickup pop
		var poof_scn := load("res://vfx/enemy_death_vfx.tscn") as PackedScene
		if poof_scn and get_tree().current_scene:
			var poof := poof_scn.instantiate() as Node3D
			get_tree().current_scene.add_child(poof)
			poof.global_position = global_position + Vector3(0, 0.2, 0)
			poof.scale = Vector3(0.5, 0.5, 0.5)
		queue_free()
