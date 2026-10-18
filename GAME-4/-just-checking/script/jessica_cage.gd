extends Node3D

signal cage_unlocked(jessica_node: CharacterBody3D)

const POOF_VFX_SCENE = preload("res://vfx/enemy_death_vfx.tscn")

var player_in_range: bool = false
var player_node: Node3D = null
var is_unlocked: bool = false

@onready var cage_model: Node3D = $CageModel
@onready var jessica_node: CharacterBody3D = $Jessica
@onready var detection_area: Area3D = $Area3D
@onready var interaction_label: Node3D = $item_interaction
@onready var cage_light: OmniLight3D = $OmniLight3D

func _ready() -> void:
	if detection_area:
		detection_area.body_entered.connect(_on_body_entered)
		detection_area.body_exited.connect(_on_body_exited)
	if interaction_label:
		interaction_label.visible = false
	_update_prompt_text()

func _on_body_entered(body: Node3D) -> void:
	if body is CharacterBody3D and body.name == "Roy" and not is_unlocked:
		player_in_range = true
		player_node = body
		_update_prompt_text()
		if interaction_label:
			interaction_label.visible = true

func _on_body_exited(body: Node3D) -> void:
	if body == player_node and not is_unlocked:
		player_in_range = false
		player_node = null
		if interaction_label:
			interaction_label.visible = false

func _update_prompt_text() -> void:
	if not interaction_label:
		return
	var lbl := interaction_label.get_node_or_null("interaction") as Label3D
	if not lbl:
		return
	if player_node and player_node.has_method("has_key") and player_node.has_key():
		lbl.text = "Press E to Unlock Jessica's Cage [Key Ready]"
		lbl.modulate = Color(0.35, 1.0, 0.55, 1.0)
	else:
		lbl.text = "Locked! Defeat the Boss to get the Cage Key"
		lbl.modulate = Color(1.0, 0.45, 0.35, 1.0)

func _process(_delta: float) -> void:
	if player_in_range and not is_unlocked:
		_update_prompt_text()
		if Input.is_action_just_pressed("interact"):
			_try_unlock_cage()

func _try_unlock_cage() -> void:
	if is_unlocked or not is_instance_valid(player_node):
		return
	if not player_node.has_method("has_key") or not player_node.has_key():
		if player_node.has_method("show_tip_message"):
			player_node.show_tip_message("Cage is Locked! Kill the Boss and pick up the Key first!", 3.0)
		return
	
	is_unlocked = true
	if player_node.has_method("consume_key"):
		player_node.consume_key()
	if interaction_label:
		interaction_label.visible = false
	
	# Spawn Toon Cloud Poof VFX as the cage unlocks and lifts open
	if POOF_VFX_SCENE and get_tree().current_scene:
		var vfx := POOF_VFX_SCENE.instantiate() as Node3D
		get_tree().current_scene.add_child(vfx)
		vfx.global_position = global_position + Vector3(0, 0.35, 0)
	
	if cage_model:
		# Disable any static collision inside the cage model so Jessica can walk out freely
		for col in cage_model.find_children("*", "CollisionShape3D", true, false):
			if col is CollisionShape3D:
				col.set_deferred("disabled", true)
		var t := create_tween().set_parallel(true)
		t.tween_property(cage_model, "position:y", cage_model.position.y + 1.6, 0.75).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		t.tween_property(cage_model, "scale", Vector3(0.01, 0.01, 0.01), 0.75)
		t.chain().tween_callback(func():
			if is_instance_valid(cage_model):
				cage_model.visible = false
		)
	
	if cage_light:
		cage_light.light_color = Color(0.3, 1.0, 0.55)
	
	# Detach Jessica into world root so she can follow Roy all the way to the Tent
	if is_instance_valid(jessica_node):
		var world_root := get_tree().current_scene
		var saved_global := jessica_node.global_transform
		if world_root and jessica_node.get_parent() != world_root:
			remove_child(jessica_node)
			world_root.add_child(jessica_node)
			jessica_node.global_transform = saved_global
		if jessica_node.has_method("set_rescued"):
			jessica_node.set_rescued()
	
	cage_unlocked.emit(jessica_node)
	var quest_mgr := get_tree().current_scene.find_child("StoryQuestManager", true, false)
	if quest_mgr and quest_mgr.has_method("on_jessica_rescued"):
		quest_mgr.on_jessica_rescued(jessica_node)
