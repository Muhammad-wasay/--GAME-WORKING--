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

var overhead_key_label: Label3D = null
var beacon_beam: MeshInstance3D = null

func _ready() -> void:
	base_model_y = key_visual.position.y if key_visual else 0.28
	
	# If user has KEY.scn in root, prioritize and instantiate it
	if ResourceLoader.exists("res://KEY.scn"):
		var key_scn := load("res://KEY.scn") as PackedScene
		if key_scn and key_visual:
			# Remove old fallback model
			for c in key_visual.get_children():
				c.queue_free()
			var user_key := key_scn.instantiate()
			user_key.name = "UserKeyModel"
			key_visual.add_child(user_key)
			user_key.position = Vector3.ZERO
	
	# Apply golden glow material to any meshes inside key_visual
	_apply_golden_glow(key_visual)
	
	# Create overhead 3D billboard text so key is visible anywhere in the forest
	overhead_key_label = Label3D.new()
	overhead_key_label.name = "KeyNameLabel"
	overhead_key_label.text = "🔑 CAGE KEY"
	overhead_key_label.font_size = 32
	overhead_key_label.pixel_size = 0.004
	overhead_key_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	overhead_key_label.no_depth_test = true
	overhead_key_label.modulate = Color(1.0, 0.88, 0.25, 1.0)
	overhead_key_label.outline_size = 10
	overhead_key_label.outline_modulate = Color(0, 0, 0, 0.95)
	overhead_key_label.position = Vector3(0, 0.85, 0)
	add_child(overhead_key_label)
	
	# Create vertical golden light beacon pillar
	_create_beacon_beam()
	
	if detection_area:
		detection_area.body_entered.connect(_on_body_entered)
		detection_area.body_exited.connect(_on_body_exited)
	if interaction_label:
		interaction_label.visible = false
		var lbl := interaction_label.get_node_or_null("interaction") as Label3D
		if lbl:
			lbl.text = "Press E to pick up Cage Key"
			lbl.modulate = Color(1.0, 0.88, 0.32, 1.0)

func _create_beacon_beam() -> void:
	beacon_beam = MeshInstance3D.new()
	beacon_beam.name = "GoldBeaconBeam"
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.12
	cyl.bottom_radius = 0.12
	cyl.height = 3.5
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.albedo_color = Color(1.0, 0.82, 0.22, 0.28)
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	cyl.material = mat
	beacon_beam.mesh = cyl
	beacon_beam.position = Vector3(0, 1.75, 0)
	add_child(beacon_beam)

func _apply_golden_glow(node: Node) -> void:
	if not node:
		return
	var gold_mat := StandardMaterial3D.new()
	gold_mat.albedo_color = Color(1.0, 0.85, 0.25, 1.0)
	gold_mat.metallic = 0.92
	gold_mat.roughness = 0.18
	gold_mat.emission_enabled = true
	gold_mat.emission = Color(1.0, 0.78, 0.20, 1.0)
	gold_mat.emission_energy_multiplier = 1.45
	
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
		key_visual.rotate_y(delta * 1.8)
		key_visual.position.y = base_model_y + sin(bob_time) * 0.07
	
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
