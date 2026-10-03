extends CharacterBody3D

@onready var camera_mount: Node3D = $camera_mount
@onready var visuals: Node3D = $visuals
@onready var animation_player: AnimationPlayer = $visuals/person/AnimationPlayer
var SPEED = 3.0
const WALK_SPEED = 3.0
const RUN_SPEED = 6.0
const JUMP_VELOCITY = 4.5
const CROUCH_SPEED = 1.5
const SWIM_SPEED = 2.0
@onready var collision_shape_3d: CollisionShape3D = $CollisionShape3D

@export var sens_horizontal = 0.3
@export var sens_vertical = 0.1
var running = false
var is_crouching = false
var is_swimming = false

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(deg_to_rad(-event.relative.x * sens_horizontal))
		visuals.rotate_y(deg_to_rad(event.relative.x * sens_horizontal))
		camera_mount.rotate_x(deg_to_rad(event.relative.y * sens_vertical))

func _physics_process(delta: float) -> void:
	
	# ===== AGAR PLAYER PANI KE ANDAR HO (SWIMMING MODE) =====
	if is_swimming:
		var input_dir := Input.get_vector("right", "left", "backward", "forward")
		var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
		
		# Pani ke andar halki gravity ya float effect
		velocity.y = move_toward(velocity.y, 0, delta * 5.0)
		
		if direction:
			var current_scale = visuals.scale
			var target_basis = Basis.looking_at(direction, Vector3.UP).rotated(Vector3.UP, PI)
			var current_quat = visuals.global_transform.basis.get_rotation_quaternion()
			var target_quat = target_basis.get_rotation_quaternion()
			visuals.global_transform.basis = Basis(current_quat.slerp(target_quat, delta * 15.0))
			visuals.scale = current_scale
			
			velocity.x = direction.x * SWIM_SPEED
			velocity.z = direction.z * SWIM_SPEED
			
			# Move karte waqt swimming animation
			if animation_player.current_animation != "NewLib/swimming":
				animation_player.play("NewLib/swimming", 0.2)
		else:
			velocity.x = move_toward(velocity.x, 0, SWIM_SPEED)
			velocity.z = move_toward(velocity.z, 0, SWIM_SPEED)
			visuals.position.y = move_toward(visuals.position.y, -0.4, delta * 5.0)
			
			# Khare rehne par water idle animation
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

func enter_water() -> void:
	is_swimming = true
	print("Player pani ke andar enter ho gaya - Swimming started!")

func exit_water() -> void:
	is_swimming = false
	print("Player pani se bahar nikal gaya!")
