extends CharacterBody3D

@onready var camera_mount: Node3D = $camera_mount
@onready var visuals: Node3D = $visuals
@onready var animation_player: AnimationPlayer = $visuals/person/AnimationPlayer
var SPEED = 3.0
const WALK_SPEED = 1.0
const RUN_SPEED = 6.0
const JUMP_VELOCITY = 4.5
const CROUCH_SPEED = 1.5
const SWIM_SPEED = 2.0
@onready var collision_shape_3d: CollisionShape3D = $CollisionShape3D
@onready var hotbar_ui: Node = get_node_or_null("HotbarUI")

@export var sens_horizontal = 0.3
@export var sens_vertical = 0.1
var running = false
var is_crouching = false
var is_swimming = false
var water_surface_y: float = 0.0  # Pani ki surface height yaad rakhni hai


@export var toon_material: Material

func apply_toon_to_children(node: Node) -> void:
	for child in node.get_children():
		if child is MeshInstance3D:
			child.material_override = toon_material
		
		if child.get_child_count() > 0:
			apply_toon_to_children(child)

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	apply_toon_to_children(self)

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(deg_to_rad(-event.relative.x * sens_horizontal))
		visuals.rotate_y(deg_to_rad(event.relative.x * sens_horizontal))
		camera_mount.rotate_x(deg_to_rad(event.relative.y * sens_vertical))

func _physics_process(delta: float) -> void:
	if Input.is_action_just_pressed("drop"):
		drop_from_inventory()
	
	# ===== AGAR PLAYER PANI KE ANDAR HO (SWIMMING MODE) =====
	if is_swimming:
		var swim_input_dir := Input.get_vector("right", "left", "backward", "forward")
		var swim_direction := (transform.basis * Vector3(swim_input_dir.x, 0, swim_input_dir.y)).normalized()
		
		# === BUOYANCY (Tairati rahein) ===
		# Player ko water surface ke thoda neeche rakhna hai
		# Character origin ke hisaab se: player ka "zero" zameen par hota hai
		# Toh agar water surface Y = water_surface_y hai,
		# hum chahte hain ke player ka origin (feet) water_surface_y - ~0.6 par ho
		# Taake haath/kandhe surface ke paas hon
		# Player ko pani mein itna rakhna hai ke body andar ho, kandhe/gardan surface ke paas
		# -0.35 = feet surface se 0.35 neeche (character ~1.2m tall, toh kamar tak pani mein)
		var target_y = water_surface_y - 0.35
		var current_y = global_position.y
		var y_diff = target_y - current_y
		
		# Agar player surface ke bahut upar chala gaya (pani se bahar) toh exit karo
		# Terrain edges ke liye Y-based fallback exit
		if global_position.y > water_surface_y + 0.4:
			exit_water()
			return
		
		# Buoyancy: smooth spring force — na bahut tight, na bahut loose
		# Clamped taake player zyada fast na uthe/gire
		var buoyancy_vel = clamp(y_diff * 5.0, -3.0, 3.0)
		velocity.y = move_toward(velocity.y, buoyancy_vel, delta * 10.0)
		
		# XZ movement
		if swim_direction:
			var current_scale = visuals.scale
			var target_basis = Basis.looking_at(swim_direction, Vector3.UP).rotated(Vector3.UP, PI)
			var current_quat = visuals.global_transform.basis.get_rotation_quaternion()
			var target_quat = target_basis.get_rotation_quaternion()
			visuals.global_transform.basis = Basis(current_quat.slerp(target_quat, delta * 15.0))
			visuals.scale = current_scale
			
			velocity.x = swim_direction.x * SWIM_SPEED
			velocity.z = swim_direction.z * SWIM_SPEED
			
			if animation_player.current_animation != "NewLib/swimming":
				animation_player.play("NewLib/swimming", 0.2)
		else:
			# Idle in water - XZ velocity zero karo
			velocity.x = move_toward(velocity.x, 0, SWIM_SPEED * 3.0)
			velocity.z = move_toward(velocity.z, 0, SWIM_SPEED * 3.0)
			
			# Visuals ko normal position par rakho (neche mat karo)
			visuals.position.y = move_toward(visuals.position.y, -0.5, delta * 5.0)
			
			if animation_player.current_animation != "NewLib/water_idle":
				animation_player.play("NewLib/water_idle", 0.2)
		
		move_and_slide()
		return # Zameen wala code skip kar dega taake conflict na ho
	
	# ===== ZAMEEN WALI PHYSICS & ANIMATIONS (NORMAL MODE) =====
	if Input.is_action_pressed("crouch"):
		is_crouching = true
		SPEED = CROUCH_SPEED
		running = false
		if collision_shape_3d:
			collision_shape_3d.shape.height = 1.0
			collision_shape_3d.position.y = 0.5
	else:
		if is_crouching:
			is_crouching = false
			SPEED = WALK_SPEED
			if collision_shape_3d:
				collision_shape_3d.shape.height = 1.0
			animation_player.play("NewLib/crouch_to_up", 0.2)
			
		if Input.is_action_pressed("run"):
			SPEED = RUN_SPEED
			running = true
		else:
			SPEED = WALK_SPEED
			running = false
	
	if not is_on_floor():
		velocity += get_gravity() * delta

	if Input.is_action_just_pressed("ui_accept") and is_on_floor() and not is_crouching:
		velocity.y = JUMP_VELOCITY

	var input_dir := Input.get_vector("right", "left", "backward", "forward")
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	if direction:
		var current_scale = visuals.scale
		var target_basis = Basis.looking_at(direction, Vector3.UP).rotated(Vector3.UP, PI)
		var current_quat = visuals.global_transform.basis.get_rotation_quaternion()
		var target_quat = target_basis.get_rotation_quaternion()
		visuals.global_transform.basis = Basis(current_quat.slerp(target_quat, delta * 15.0))
		visuals.scale = current_scale
		
		if running:
			if animation_player.current_animation != "NewLib/run":
				animation_player.play("NewLib/run", 0.2)
		elif is_crouching:
			if animation_player.current_animation != "NewLib/crouch_walking":
				animation_player.play("NewLib/crouch_walking", 0.2)
		else:
			if animation_player.current_animation != "NewLib/walking":
				animation_player.play("NewLib/walking", 0.2)
				
		velocity.x = direction.x * SPEED
		velocity.z = direction.z * SPEED
	else:
		if is_crouching:
			if animation_player.current_animation != "NewLib/crouch_idle":
				animation_player.play("NewLib/crouch_idle", 0.2)
		else:
			if animation_player.current_animation != "NewLib/idle_2":
				animation_player.play("NewLib/idle_2", 0.2)

		velocity.x = move_toward(velocity.x, 0, WALK_SPEED)
		velocity.z = move_toward(velocity.z, 0, WALK_SPEED)

	move_and_slide()

func enter_water(surface_y: float = 0.0) -> void:
	is_swimming = true
	water_surface_y = surface_y
	# Visuals ko normal position reset karo
	visuals.position.y = 0.0
	print("Player pani ke andar enter ho gaya - Swimming started! Surface Y: ", surface_y)

func exit_water() -> void:
	is_swimming = false
	water_surface_y = 0.0
	# Visuals position wapas normal karo
	visuals.position.y = 0.0
	print("Player pani se bahar nikal gaya!")

# ===== INVENTORY FUNCTIONS =====
func add_to_inventory(item_data: Dictionary) -> bool:
	if hotbar_ui:
		return hotbar_ui.add_item(item_data)
	return false

func drop_from_inventory() -> void:
	if not hotbar_ui:
		return
	var dropped_data = hotbar_ui.drop_selected_item(1)
	if not dropped_data.is_empty():
		spawn_dropped_item(dropped_data)

func spawn_dropped_item(item_data: Dictionary) -> void:
	var item_scene = item_data.get("scene", null)
	if not item_scene:
		return
	
	var item_inst = item_scene.instantiate()
	var current_scene = get_tree().current_scene
	if current_scene:
		current_scene.add_child(item_inst)
	else:
		get_parent().add_child(item_inst)
	
	var forward_dir = global_transform.basis.z
	item_inst.global_position = global_position + (forward_dir * 0.5) + Vector3(0, 0.4, 0)
	
	if item_inst is RigidBody3D:
		item_inst.freeze = false
		var throw_impulse = (forward_dir * 0.5) + Vector3(0, 1.2, 0)
		item_inst.apply_central_impulse(throw_impulse)
		item_inst.angular_velocity = Vector3(randf_range(-2.0, 2.0), randf_range(-2.0, 2.0), randf_range(-2.0, 2.0))
	print("Item dropped from inventory:", item_data.get("name", "Item"))
