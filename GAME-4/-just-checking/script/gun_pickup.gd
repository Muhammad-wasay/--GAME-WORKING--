extends RigidBody3D

var player_in_range = false
var player_node = null
var is_picked_up = false
var saved_main_scene = null

@onready var detection_area: Area3D = $Area3D
@onready var interaction_label: Node3D = $item_interaction

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
		if interaction_label:
			interaction_label.visible = true

func _on_body_exited(body: Node3D) -> void:
	if body == player_node and not is_picked_up:
		player_in_range = false
		player_node = null
		if interaction_label:
			interaction_label.visible = false

func _process(_delta: float) -> void:
	if player_in_range and not is_picked_up:
		if Input.is_action_just_pressed("interact"):
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
