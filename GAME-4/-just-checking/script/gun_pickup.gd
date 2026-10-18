extends RigidBody3D

var player_in_range: bool = false
var player_node: Node3D = null
var is_picked_up: bool = false
var saved_main_scene: Node = null
var pistol_mesh_node: MeshInstance3D = null
var spawn_grace_timer: float = 0.18

@onready var detection_area: Area3D = $Area3D
@onready var interaction_label: Node3D = $item_interaction

func _ready() -> void:
	saved_main_scene = get_tree().current_scene
	continuous_cd = true
	linear_damp = 2.0
	angular_damp = 4.0
	
	if detection_area:
		detection_area.body_entered.connect(_on_body_entered)
		detection_area.body_exited.connect(_on_body_exited)
	
	for m in find_children("*", "MeshInstance3D", true, false):
		if m is MeshInstance3D and m.mesh:
			pistol_mesh_node = m
			break
	
	if interaction_label:
		interaction_label.top_level = true
		interaction_label.visible = false
		interaction_label.scale = Vector3.ONE
		for child in interaction_label.find_children("*", "Label3D", true, false):
			if child is Label3D:
				child.position = Vector3.ZERO
				child.scale = Vector3.ONE
				child.pixel_size = 0.0009
				child.font_size = 20
				child.text = "[E] Pick Up Pistol"
				child.outline_size = 6
				child.no_depth_test = true
		_update_label_world_pos()

func _get_pistol_world_center() -> Vector3:
	if is_instance_valid(pistol_mesh_node) and pistol_mesh_node.mesh:
		var aabb := pistol_mesh_node.mesh.get_aabb()
		return pistol_mesh_node.global_transform * aabb.get_center()
	var col := get_node_or_null("CollisionShape3D") as Node3D
	if col:
		return col.global_position
	return global_position

func _update_label_world_pos() -> void:
	if is_instance_valid(interaction_label):
		interaction_label.global_position = _get_pistol_world_center() + Vector3(0.0, 0.20, 0.0)

func _find_roy() -> CharacterBody3D:
	if is_instance_valid(player_node) and player_node is CharacterBody3D and player_node.name == "Roy":
		return player_node as CharacterBody3D
	var scene := get_tree().current_scene
	if scene:
		return scene.find_child("Roy", true, false) as CharacterBody3D
	return null

func _on_body_entered(body: Node3D) -> void:
	if body is CharacterBody3D and body.name == "Roy" and not is_picked_up:
		player_in_range = true
		player_node = body
		if interaction_label:
			_update_label_world_pos()
			interaction_label.visible = true

func _on_body_exited(body: Node3D) -> void:
	if body == player_node and not is_picked_up:
		player_in_range = false
		player_node = null
		if interaction_label:
			interaction_label.visible = false

func _physics_process(_delta: float) -> void:
	if is_picked_up or freeze:
		return
	# Prevent thin pistol box from ever tunneling through ConcavePolygonShape3D terrain when dropped
	var space_state := get_world_3d().direct_space_state
	if space_state:
		var rq := PhysicsRayQueryParameters3D.create(global_position + Vector3(0.0, 1.2, 0.0), global_position + Vector3(0.0, -3.0, 0.0))
		rq.exclude = [get_rid()]
		var rhit := space_state.intersect_ray(rq)
		if rhit and rhit.has("position"):
			var floor_y: float = (rhit["position"] as Vector3).y + 0.08
			if global_position.y <= floor_y:
				global_position.y = floor_y
				if linear_velocity.y < 0.0:
					linear_velocity.y = 0.0
				linear_velocity.x *= 0.5
				linear_velocity.z *= 0.5

func _process(delta: float) -> void:
	if is_picked_up:
		return
	if spawn_grace_timer > 0.0:
		spawn_grace_timer = maxf(0.0, spawn_grace_timer - delta)
	
	# Direct distance check to Roy so dropped pistol is ALWAYS detectable even if spawned inside Area3D
	var roy := _find_roy()
	if is_instance_valid(roy):
		var dist := _get_pistol_world_center().distance_to(roy.global_position + Vector3(0.0, 0.25, 0.0))
		if dist <= 1.65:
			player_in_range = true
			player_node = roy
		elif player_node == roy and dist > 1.85:
			player_in_range = false
			player_node = null
	
	if interaction_label:
		interaction_label.visible = player_in_range
	
	if player_in_range:
		_update_label_world_pos()
		if spawn_grace_timer <= 0.0 and Input.is_action_just_pressed("interact"):
			pick_up()

func pick_up() -> void:
	if is_picked_up:
		return
	
	if player_node and player_node.has_method("add_to_inventory"):
		var item_data = {
			"id": "gun",
			"name": "Pistol",
			"icon": preload("res://import/UI/gun_icon.png"),
			"scene": load("res://scene/gun_pickup.tscn"),
			"count": 1,
			"type": "weapon",
			"weapon_id": "pistol"
		}
		var added = player_node.add_to_inventory(item_data)
		if added:
			print("Gun inventory mein chala gaya!")
			# Tell player to show the instruction banner
			if player_node.has_method("show_gun_instruction"):
				player_node.show_gun_instruction()
			is_picked_up = true
			if interaction_label:
				interaction_label.visible = false
			queue_free()
			return
	
	print("Inventory nahi mili ya full hai!")
