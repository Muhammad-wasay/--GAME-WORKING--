extends RigidBody3D

var player_in_range = false
var player_node = null
var is_picked_up = false
var saved_main_scene = null
var bob_time: float = 0.0
var apple_mesh_instances: Array[MeshInstance3D] = []
var omni_light: OmniLight3D = null
var overhead_label: Label3D = null

@onready var interaction_label: Node3D = $item_interaction
@onready var detection_area: Area3D = $Area3D

func _ready() -> void:
	saved_main_scene = get_tree().current_scene
	
	# Excessive rolling / spinning rokne ke liye damping aur stable physics settings
	angular_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	angular_damp = 15.0
	linear_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	linear_damp = 6.0
	can_sleep = true
	if physics_material_override:
		physics_material_override.friction = 1.0
		physics_material_override.rough = true
		physics_material_override.bounce = 0.0
	
	detection_area.body_entered.connect(_on_body_entered)
	detection_area.body_exited.connect(_on_body_exited)
	
	if interaction_label:
		interaction_label.visible = false
		var lbl := interaction_label.get_node_or_null("interaction") as Label3D
		if lbl:
			lbl.text = "[E] Apple (+25 HP)"
			lbl.font_size = 28
			lbl.outline_size = 6
	
	_setup_shiny_glow()

func _gather_meshes(node: Node) -> void:
	if node is MeshInstance3D:
		apple_mesh_instances.append(node)
	for child in node.get_children():
		_gather_meshes(child)

func _setup_shiny_glow() -> void:
	_gather_meshes(self)
	
	# Duplicate and configure glowing emission on apple mesh
	for m in apple_mesh_instances:
		if not m or not m.mesh:
			continue
		var surf_count := m.mesh.get_surface_count()
		for s in range(surf_count):
			var orig_mat := m.get_active_material(s)
			var shiny_mat: StandardMaterial3D = null
			if orig_mat is StandardMaterial3D:
				shiny_mat = orig_mat.duplicate() as StandardMaterial3D
			else:
				shiny_mat = StandardMaterial3D.new()
			shiny_mat.emission_enabled = true
			shiny_mat.emission = Color(1.0, 0.32, 0.12)
			shiny_mat.emission_energy_multiplier = 0.95
			shiny_mat.rim_enabled = true
			shiny_mat.rim = 0.75
			m.set_surface_override_material(s, shiny_mat)
	
	# Warm soft OmniLight3D
	omni_light = OmniLight3D.new()
	omni_light.name = "AppleGlowLight"
	omni_light.light_color = Color(1.0, 0.45, 0.18)
	omni_light.light_energy = 0.75
	omni_light.omni_range = 1.6
	add_child(omni_light)

func _on_body_entered(body: Node3D) -> void:
	if body is CharacterBody3D and not is_picked_up:
		player_in_range = true
		player_node = body
		if "nearby_apple" in body:
			body.nearby_apple = self
		# Jab player paas aaye toh text dikha do
		if interaction_label:
			interaction_label.visible = true
		# Pehli dafa apple ke paas aane par tutorial tip
		if body.has_method("show_tip_once"):
			body.show_tip_once("apple", "APPLE", "Press E to keep it in your bag.\nPress ENTER to eat it.")

func _on_body_exited(body: Node3D) -> void:
	if body == player_node and not is_picked_up:
		player_in_range = false
		if "nearby_apple" in body and body.nearby_apple == self:
			body.nearby_apple = null
		player_node = null
		# Jab player door jaye toh text chupa do
		if interaction_label:
			interaction_label.visible = false

func _process(delta: float) -> void:
	bob_time += delta * 3.0
	
	# Pulsing shiny emission
	var pulse := 1.2 + sin(bob_time) * 0.45
	for m in apple_mesh_instances:
		if is_instance_valid(m) and m.mesh:
			for s in range(m.mesh.get_surface_count()):
				var mat := m.get_surface_override_material(s) as StandardMaterial3D
				if mat:
					mat.emission_energy_multiplier = pulse
	
	if omni_light:
		omni_light.light_energy = 0.7 + sin(bob_time) * 0.25
	
	if player_in_range and not is_picked_up:
		if Input.is_action_just_pressed("interact"):
			pick_up()
	elif is_picked_up:
		if Input.is_action_just_pressed("drop"):
			drop_item()

func _unhandled_input(event: InputEvent) -> void:
	# ENTER dabane par zameen se hi apple kha lo (inventory mein rakhe baghair)
	if player_in_range and not is_picked_up and event is InputEventKey \
			and event.pressed and not event.echo \
			and (event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER):
		if player_node and player_node.has_method("eat_apple"):
			if player_node.eat_apple():
				get_viewport().set_input_as_handled()
				queue_free()

func pick_up() -> void:
	if is_picked_up:
		return
	
	# Agar player ke paas inventory system hai toh inventory mein daal do
	if player_node and player_node.has_method("add_to_inventory"):
		var item_data = {
			"id": "apple",
			"name": "Apple",
			"icon": preload("res://import/UI/apple_icon.png"),
			"scene": load("res://scene/apple.tscn"),
			"count": 1,
			"scale": scale
		}
		var added = player_node.add_to_inventory(item_data)
		if added:
			print("Apple inventory mein chala gaya!")
			queue_free()
			return
	
	# Fallback (agar inventory na ho)
	is_picked_up = true
	player_in_range = false
	
	# Uthate hi object ke oopar wala text gayab ho jaye
	if interaction_label:
		interaction_label.visible = false
	if overhead_label:
		overhead_label.visible = false
	if omni_light:
		omni_light.visible = false
	
	freeze = true
	
	var parent = get_parent()
	if parent:
		parent.remove_child(self)
	
	player_node.add_child(self)
	transform.origin = Vector3(0.5, 0.0, -1.0) # Haath ki position
	
	detection_area.monitoring = false
	print("Item Picked Up!")

func drop_item() -> void:
	is_picked_up = false
	if overhead_label:
		overhead_label.visible = true
	if omni_light:
		omni_light.visible = true
	
	var parent = get_parent()
	if parent:
		parent.remove_child(self)
	
	if saved_main_scene:
		saved_main_scene.add_child(self)
	
	# 1. Direction theek karne ke liye yahan minus (-) ki jagah plus (+) ya normal basis use kiya hai 
	# taake item bilkul samne spawn ho (agar ab bhi peeche ho toh sign change kar sakte hain)
	var forward_dir = player_node.global_transform.basis.z
	
	# Player ke samne 1.0 meter ki doori par rakhna
	global_position = player_node.global_position + (forward_dir * 0.3) + Vector3(0, 0.4, 0)
	
	# Physics unfreeze ki taake gravity kaam kare
	freeze = false
	
	# 2. Gentle drop without excessive bounce or spinning
	var throw_impulse = (forward_dir * 0.25) + Vector3(0, 0.35, 0)
	apply_central_impulse(throw_impulse)
	
	angular_velocity = Vector3.ZERO
	
	detection_area.monitoring = true
	print("Item dropped with real physics and correct direction!")
