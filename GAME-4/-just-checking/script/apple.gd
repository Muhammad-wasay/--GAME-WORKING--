extends RigidBody3D

var player_in_range = false
var player_node = null
var is_picked_up = false
var saved_main_scene = null
#@onready var interaction_label: Label3D = $interaction
@onready var interaction_label: Node3D = $item_interaction

@onready var detection_area: Area3D = $Area3D

func _ready() -> void:
	saved_main_scene = get_tree().current_scene
	
	detection_area.body_entered.connect(_on_body_entered)
	detection_area.body_exited.connect(_on_body_exited)
	
	if interaction_label:
		interaction_label.visible = false

func _on_body_entered(body: Node3D) -> void:
	if body is CharacterBody3D and not is_picked_up:
		player_in_range = true
		player_node = body
		print("Press E to pick up the item!")
		# Jab player paas aaye toh text dikha do
		if interaction_label:
			interaction_label.visible = true

func _on_body_exited(body: Node3D) -> void:
	if body == player_node and not is_picked_up:
		player_in_range = false
		player_node = null
		# Jab player door jaye toh text chupa do
		if interaction_label:
			interaction_label.visible = false

func _process(delta: float) -> void:
	if player_in_range and not is_picked_up:
		if Input.is_action_just_pressed("interact"):
			pick_up()
	elif is_picked_up:
		if Input.is_action_just_pressed("drop"):
			drop_item()

func pick_up() -> void:
	is_picked_up = true
	player_in_range = false
	
	# Uthate hi object ke oopar wala text gayab ho jaye
	if interaction_label:
		interaction_label.visible = false
	
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
	
	# 2. Real physics ke sath chota sa throw (Roblox style arc)
	# Na bohot door jaye ga, na direct niche gire ga, balki halka sa aage uchal kar zameen par aayega
	var throw_impulse = (forward_dir * 0.3) + Vector3(0, 1.0, 0)
	apply_central_impulse(throw_impulse)
	
	angular_velocity = Vector3(randf_range(-2.0, 2.0), randf_range(-2.0, 2.0), randf_range(-2.0, 2.0))
	
	detection_area.monitoring = true
	print("Item dropped with real physics and correct direction!")
