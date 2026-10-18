extends CharacterBody3D
@onready var held_gun: Node3D = $visuals/person/Skeleton3D/BoneAttachment3D
@onready var camera_mount: Node3D = $camera_mount
@onready var visuals: Node3D = $visuals
@onready var animation_player: AnimationPlayer = $visuals/person/AnimationPlayer
var SPEED = 3.0
const WALK_SPEED = 1.0
const RUN_SPEED = 2.0
const JUMP_VELOCITY = 3
const CROUCH_SPEED = 1.0
const SWIM_SPEED = 1.5
var is_jumping := false
var in_air := false
const JUMP_KEEPS_MOMENTUM := true
var jump_velocity_xz := Vector3.ZERO
var default_shape_height: float = 1.2316895
var default_shape_pos_y: float = 0.600182
var default_floor_snap: float = 0.35
@onready var collision_shape_3d: CollisionShape3D = $CollisionShape3D
@onready var hotbar_ui: Node = get_node_or_null("HotbarUI")
#@onready var footstep_player: AudioStreamPlayer3D = $Node3D/FootstepPlayer

@onready var camera: Camera3D = $camera_mount/Camera3D
@onready var blur_rect: ColorRect = $BlurLayer/BlurRect

var base_fov: float
var base_cam_pos: Vector3
var blur_amount := 0.0

@export var sens_horizontal = 0.3
@export var sens_vertical = 0.1
var running = false
var is_crouching = false
var is_swimming = false
var water_surface_y: float = 0.0

# ===== GUN SYSTEM =====
var gun_equipped: bool = false
var equipped_pistol_node: Node3D = null
var current_bone_attachment: BoneAttachment3D = null
var instruction_banner: Node = null

const EQUIPPED_PISTOL_SCENE = preload("res://scene/equipped_pistol.tscn")
const INSTRUCTION_BANNER_SCENE = preload("res://scene/instruction_banner.tscn")
const MUZZLE_FLASH_SCENE = preload("res://vfx/muzzle_flash.tscn")
const BULLET_IMPACT_SCENE = preload("res://vfx/bullet_impact.tscn")
const BULLET_TRACER_SCENE = preload("res://vfx/bullet_tracer.tscn")
const PISTOL_IDLE_MAIN_ANIM = preload("res://animations/pistol_idle_main.anim")
const PLAYER_HIT_REACTION_ANIM = preload("res://animations/player_hit_reaction.anim")
const PLAYER_DEATH_ANIM = preload("res://import/enemies/falling-back-death.anim")
const ENEMY_DEATH_VFX_SCENE = preload("res://vfx/enemy_death_vfx.tscn")

# ===== PLAYER AUDIO STREAMS =====
var SFX_FOOTSTEP: AudioStream = null
var SFX_CROUCH_WALK: AudioStream = null
var SFX_SWIMMING: AudioStream = null
var SFX_GETTING_HIT: AudioStream = null

var sfx_footstep_player: AudioStreamPlayer = null
var sfx_crouch_player: AudioStreamPlayer = null
var sfx_swim_player: AudioStreamPlayer = null
var sfx_hit_player: AudioStreamPlayer = null
var footstep_timer: float = 0.0
var has_cage_key: bool = false
var dialogue_locked: bool = false

# ===== AMMO SYSTEM =====
const MAGAZINE_SIZE: int = 12
var clip_ammo: int = 12
var reserve_ammo: int = 6
var current_ammo: int = 18
var max_ammo: int = 60
var ammo_hud_layer: CanvasLayer = null
var ammo_hud_container: Control = null
var ammo_hud_label: Label = null
var sfx_gunshot_player: AudioStreamPlayer = null
var SFX_GUNSHOT: AudioStream = null

var can_fire := true
var fire_cooldown := 0.22
var fire_timer := 0.0
var is_firing := false
var recoil_timer := 0.0
var hit_react_timer := 0.0
var muzzle_flash_node: Node3D = null
var crosshair_layer: CanvasLayer = null

# ===== HEALTH / STAMINA / DEATH / VFX =====
const MAX_HEALTH := 100.0
const MAX_STAMINA := 100.0
const STAMINA_DRAIN := 20.0   # per second jab bhag raha ho
const STAMINA_REGEN := 15.0   # per second jab walk/idle ho
const APPLE_HEAL := 25.0
var health: float = MAX_HEALTH
var stamina: float = MAX_STAMINA
var stamina_exhausted := false
var stamina_regen_delay := 0.0
var stamina_warning_visible := false
var stamina_warning_tween: Tween = null
var health_bar: ProgressBar = null
var stamina_bar: ProgressBar = null
var stamina_warning: Label = null
var tip_popup: TipPopup = null
var shown_tips: Dictionary = {}
var nearby_apple: Node = null

var is_dead: bool = false
var invulnerable_timer: float = 0.0
var damage_flash_alpha: float = 0.0
var vignette_pulse_time: float = 0.0
var damage_vignette_mat: ShaderMaterial = null
var death_ui_layer: CanvasLayer = null
var player_body_materials: Array[StandardMaterial3D] = []

@export var toon_material: Material

func apply_toon_to_children(node: Node) -> void:
	for child in node.get_children():
		if child is MeshInstance3D:
			if toon_material:
				child.material_override = toon_material
		
		if child.get_child_count() > 0:
			apply_toon_to_children(child)
			
			
func _update_camera_effects(delta: float) -> void:
	var run_active := running and is_on_floor() and not is_swimming \
		and Vector2(velocity.x, velocity.z).length() > 0.1

	var target_fov := base_fov + (12.0 if run_active else 0.0)
	var target_pos := base_cam_pos + (Vector3(0, 0.1, -0.6) if run_active else Vector3.ZERO)
	var target_blur := 0.008 if run_active else 0.0

	var t := 1.0 - exp(-6.0 * delta)
	camera.fov = lerp(camera.fov, target_fov, t)
	camera.position = camera.position.lerp(target_pos, t)
	blur_amount = lerp(blur_amount, target_blur, t)
	blur_rect.material.set_shader_parameter("strength", blur_amount)
func _ready() -> void:
	if collision_shape_3d and collision_shape_3d.shape:
		if collision_shape_3d.shape is CapsuleShape3D:
			default_shape_height = collision_shape_3d.shape.height
		default_shape_pos_y = collision_shape_3d.position.y
	default_floor_snap = floor_snap_length
	base_fov = camera.fov
	base_cam_pos = camera.position
	held_gun.visible = false
	print("PLAYER READY | hotbar_ui = ", hotbar_ui)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	apply_toon_to_children(self)
	_prepare_player_body_materials()
	
	# Instruction banner UI add karna
	if INSTRUCTION_BANNER_SCENE:
		instruction_banner = INSTRUCTION_BANNER_SCENE.instantiate()
		add_child(instruction_banner)
	
	# Hotbar signal se gun equip/unequip handle karna
	if hotbar_ui:
		hotbar_ui.item_selected.connect(_on_hotbar_item_selected)
	
	_setup_bars()
	_setup_damage_vignette()
	_setup_gun_and_crosshair()
	_setup_audio()
	_setup_gunshot_sound()
	_setup_ammo_hud()

func _input(event: InputEvent) -> void:
	if is_dead:
		if event is InputEventKey and event.pressed and not event.echo:
			if event.keycode == KEY_R or event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER or event.keycode == KEY_SPACE:
				_respawn_player()
			elif event.keycode == KEY_Q:
				get_tree().quit()
			elif event.keycode == KEY_M:
				get_tree().reload_current_scene()
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(deg_to_rad(-event.relative.x * sens_horizontal))
		visuals.rotate_y(deg_to_rad(event.relative.x * sens_horizontal))
		camera_mount.rotation.x = clamp(camera_mount.rotation.x + deg_to_rad(event.relative.y * sens_vertical), deg_to_rad(-20.0),deg_to_rad(40.0))

func _physics_process(delta: float) -> void:
	_update_camera_effects(delta)
	_update_damage_vignette(delta)
	if invulnerable_timer > 0.0:
		invulnerable_timer -= delta
	
	if is_dead:
		velocity.x = move_toward(velocity.x, 0.0, WALK_SPEED * 5.0)
		velocity.z = move_toward(velocity.z, 0.0, WALK_SPEED * 5.0)
		if not is_on_floor():
			velocity += get_gravity() * delta
		move_and_slide()
		return
	
	_update_stamina(delta)
	if fire_timer > 0.0:
		fire_timer -= delta
	if recoil_timer > 0.0:
		recoil_timer -= delta
		if recoil_timer <= 0.0:
			is_firing = false
	if hit_react_timer > 0.0:
		hit_react_timer -= delta
	
	if dialogue_locked:
		velocity.x = move_toward(velocity.x, 0.0, WALK_SPEED * 4.0)
		velocity.z = move_toward(velocity.z, 0.0, WALK_SPEED * 4.0)
		if not is_on_floor():
			velocity += get_gravity() * delta
		_stop_movement_sounds()
		if gun_equipped:
			if animation_player.current_animation != "NewLib/pistol_idle_main":
				animation_player.play("NewLib/pistol_idle_main", 0.25)
		else:
			if animation_player.current_animation != "NewLib/idle_2":
				animation_player.play("NewLib/idle_2", 0.2)
		move_and_slide()
		return
	
	if Input.is_action_just_pressed("drop"):
		drop_from_inventory()
	
	# ===== AGAR PLAYER PANI KE ANDAR HO (SWIMMING MODE) =====
	if is_swimming:
		floor_snap_length = 0.0
		var swim_input_dir := Input.get_vector("right", "left", "backward", "forward")
		var swim_direction := (transform.basis * Vector3(swim_input_dir.x, 0, swim_input_dir.y)).normalized()
		
		var cur_scale_y: float = absf(global_basis.get_scale().y)
		var player_height: float = default_shape_height * cur_scale_y
		var target_y: float = water_surface_y - (player_height * 0.35)
		var current_y: float = global_position.y
		var y_diff: float = target_y - current_y
		var submergence: float = water_surface_y - current_y
		
		# Seamless exit onto riverbank or shore if feet touch the ground and water is shallow enough to walk
		if is_on_floor() and submergence < (player_height * 0.60):
			exit_water()
			# Don't return early; seamlessly continue into ground walking physics below in the same frame!
		else:
			var max_buoyancy: float = 3.5 * cur_scale_y
			var buoyancy_vel: float = clamp(y_diff * 6.5, -max_buoyancy, max_buoyancy)
			
			# Space se pani ke upar swim / kinare par jump lagana
			if Input.is_action_just_pressed("jump"):
				buoyancy_vel = 3.2 * cur_scale_y
				velocity.y = JUMP_VELOCITY
				if is_on_floor() or submergence < (player_height * 0.50):
					exit_water()
					is_jumping = true
					in_air = true
			
			if is_swimming:
				velocity.y = move_toward(velocity.y, buoyancy_vel, delta * 12.0 * cur_scale_y)
				
				if swim_direction:
					var current_scale = visuals.scale
					var target_basis = Basis.looking_at(swim_direction, Vector3.UP).rotated(Vector3.UP, PI)
					var current_quat = visuals.global_transform.basis.get_rotation_quaternion()
					var target_quat = target_basis.get_rotation_quaternion()
					visuals.global_transform.basis = Basis(current_quat.slerp(target_quat, delta * 15.0))
					visuals.scale = current_scale
					
					velocity.x = swim_direction.x * SWIM_SPEED
					velocity.z = swim_direction.z * SWIM_SPEED
					
					visuals.position.y = move_toward(visuals.position.y, 0.0, delta * 5.0)
					
					if animation_player.current_animation != "NewLib/swimming":
						animation_player.play("NewLib/swimming", 0.2)
					if sfx_swim_player and not sfx_swim_player.playing:
						sfx_swim_player.play()
				else:
					velocity.x = move_toward(velocity.x, 0, SWIM_SPEED * 3.0)
					velocity.z = move_toward(velocity.z, 0, SWIM_SPEED * 3.0)
					
					visuals.position.y = move_toward(visuals.position.y, -0.2, delta * 5.0)
					
					if animation_player.current_animation != "NewLib/water_idle":
						animation_player.play("NewLib/water_idle", 0.2)
					if sfx_swim_player and sfx_swim_player.playing:
						sfx_swim_player.stop()
				
				if sfx_footstep_player and sfx_footstep_player.playing:
					sfx_footstep_player.stop()
				if sfx_crouch_player and sfx_crouch_player.playing:
					sfx_crouch_player.stop()
				move_and_slide()
				return
	
	# ===== ZAMEEN WALI PHYSICS & ANIMATIONS (NORMAL MODE) =====
	if Input.is_action_pressed("crouch"):
		is_crouching = true
		SPEED = CROUCH_SPEED
		running = false
		if collision_shape_3d and collision_shape_3d.shape:
			collision_shape_3d.shape.height = default_shape_height * 0.75
			collision_shape_3d.position.y = default_shape_pos_y * 0.75
	else:
		if is_crouching:
			is_crouching = false
			SPEED = WALK_SPEED
			if collision_shape_3d and collision_shape_3d.shape:
				collision_shape_3d.shape.height = default_shape_height
				collision_shape_3d.position.y = default_shape_pos_y
			animation_player.play("NewLib/crouch_to_up", 0.2)
			
		if Input.is_action_pressed("run") and not stamina_exhausted:
			SPEED = RUN_SPEED
			running = true
		else:
			SPEED = WALK_SPEED
			running = false
	
	if not is_on_floor():
		velocity += get_gravity() * delta
	else:
		if not is_jumping:
			floor_snap_length = default_floor_snap

	if Input.is_action_just_pressed("jump") and is_on_floor() and not is_crouching and not is_jumping:
		is_jumping = true
		in_air = false
		floor_snap_length = 0.0
		velocity.y = JUMP_VELOCITY
		jump_velocity_xz = Vector3(velocity.x, 0, velocity.z)
		var jump_anim := animation_player.get_animation("NewLib/jump")
		if jump_anim:
			var air_time := 3.4 * JUMP_VELOCITY / maxf(get_gravity().length(), 0.1)
			var anim_speed := jump_anim.length / maxf(air_time, 0.1)
			animation_player.play("NewLib/jump", 0.1, anim_speed)

	if is_jumping:
		_stop_movement_sounds()
		var air_input_dir := Input.get_vector("right", "left", "backward", "forward")
		var air_direction := (transform.basis * Vector3(air_input_dir.x, 0, air_input_dir.y)).normalized()
		if air_direction != Vector3.ZERO:
			velocity.x = air_direction.x * SPEED
			velocity.z = air_direction.z * SPEED
		else:
			velocity.x = move_toward(velocity.x, 0.0, delta * 3.0)
			velocity.z = move_toward(velocity.z, 0.0, delta * 3.0)
		
		move_and_slide()
		if not is_on_floor():
			in_air = true
		elif in_air:
			is_jumping = false
			in_air = false
			floor_snap_length = default_floor_snap
		return

	var input_dir := Input.get_vector("right", "left", "backward", "forward")
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	if is_firing:
		_face_aim_direction(delta * 25.0)
	
	if direction:
		if not is_firing:
			var current_scale = visuals.scale
			var target_basis = Basis.looking_at(direction, Vector3.UP).rotated(Vector3.UP, PI)
			var current_quat = visuals.global_transform.basis.get_rotation_quaternion()
			var target_quat = target_basis.get_rotation_quaternion()
			visuals.global_transform.basis = Basis(current_quat.slerp(target_quat, delta * 15.0))
			visuals.scale = current_scale
		
		if hit_react_timer <= 0.0:
			if running:
				if gun_equipped:
					if not is_firing and animation_player.current_animation != "NewLib/pistol_run":
						animation_player.play("NewLib/pistol_run", 0.2)
				else:
					if animation_player.current_animation != "NewLib/run":
						animation_player.play("NewLib/run", 0.2)
			elif is_crouching:
				if gun_equipped:
					if not is_firing and animation_player.current_animation != "NewLib/pistol_crouch_idle":
						animation_player.play("NewLib/pistol_crouch_idle", 0.2)
				else:
					if animation_player.current_animation != "NewLib/crouch_walking":
						animation_player.play("NewLib/crouch_walking", 0.2)
			else:
				if gun_equipped:
					if not is_firing and animation_player.current_animation != "NewLib/pistol_walk":
						animation_player.play("NewLib/pistol_walk", 0.2)
				else:
					if animation_player.current_animation != "NewLib/walking":
						animation_player.play("NewLib/walking", 0.2)
		
		# Wading in shallow water (water dampened speed)
		var move_speed: float = SPEED
		if water_surface_y != 0.0 and global_position.y < water_surface_y:
			move_speed *= 0.85
		
		velocity.x = direction.x * move_speed
		velocity.z = direction.z * move_speed
		_update_movement_sounds(delta, true)
	else:
		if hit_react_timer <= 0.0:
			if is_crouching:
				if gun_equipped:
					if not is_firing and animation_player.current_animation != "NewLib/pistol_crouch_idle":
						animation_player.play("NewLib/pistol_crouch_idle", 0.2)
				else:
					if animation_player.current_animation != "NewLib/crouch_idle":
						animation_player.play("NewLib/crouch_idle", 0.2)
			else:
				if gun_equipped:
					if not is_firing and animation_player.current_animation != "NewLib/pistol_idle_main":
						animation_player.play("NewLib/pistol_idle_main", 0.25)
				else:
					if animation_player.current_animation != "NewLib/idle_2":
						animation_player.play("NewLib/idle_2", 0.2)

		velocity.x = move_toward(velocity.x, 0, WALK_SPEED)
		velocity.z = move_toward(velocity.z, 0, WALK_SPEED)
		_update_movement_sounds(delta, false)

	move_and_slide()

# ===== WATER FUNCTIONS =====
func enter_water(surface_y: float = 0.0) -> void:
	is_swimming = true
	water_surface_y = surface_y
	visuals.position.y = 0.0
	floor_snap_length = 0.0
	_stop_movement_sounds()

func exit_water() -> void:
	is_swimming = false
	water_surface_y = 0.0
	visuals.position.y = 0.0
	floor_snap_length = default_floor_snap
	if sfx_swim_player and sfx_swim_player.playing:
		sfx_swim_player.stop()

# ===== INVENTORY & PICKUP FUNCTIONS =====
func add_to_inventory(item_data: Dictionary) -> bool:
	print("ADD ITEM: ", item_data)
	if hotbar_ui:
		var added = hotbar_ui.add_item(item_data)
		if added and (item_data.get("id", "") == "gun" or item_data.get("type", "") == "weapon"):
			show_gun_instruction()
		return added
	return false

func drop_from_inventory() -> void:
	if not hotbar_ui:
		return
	var dropped_data = hotbar_ui.drop_selected_item(1)
	if not dropped_data.is_empty():
		spawn_dropped_item(dropped_data)
		if dropped_data.get("id", "") == "gun" or dropped_data.get("type", "") == "weapon":
			_unequip_gun()

func spawn_dropped_item(item_data: Dictionary) -> void:
	var item_scene = item_data.get("scene", null)
	if not item_scene:
		return
	
	var item_inst = item_scene.instantiate()
	if item_inst is Node3D:
		item_inst.scale = item_data.get("scale", Vector3.ONE)
	
	var current_scene = get_tree().current_scene
	if current_scene:
		current_scene.add_child(item_inst)
	else:
		get_parent().add_child(item_inst)
	
	var forward_dir = global_transform.basis.z.normalized()
	item_inst.global_position = global_position + (forward_dir * 0.5) + Vector3(0, 0.4, 0)
	
	if item_inst is RigidBody3D:
		item_inst.freeze = false
		var throw_impulse = (forward_dir * 0.5) + Vector3(0, 1.2, 0)
		item_inst.apply_central_impulse(throw_impulse)
		item_inst.angular_velocity = Vector3(randf_range(-2.0, 2.0), randf_range(-2.0, 2.0), randf_range(-2.0, 2.0))
# ===== GUN SYSTEM FUNCTIONS =====

func show_gun_instruction() -> void:
	if instruction_banner and instruction_banner.has_method("show_message"):
		instruction_banner.show_message("Press TAB to hold the gun!", 5.0)

func _on_hotbar_item_selected(_slot_index: int, item_data: Dictionary) -> void:
	var item_id = item_data.get("id", "")
	var item_type = item_data.get("type", "")
	
	if item_id == "gun" or item_type == "weapon":
		return
	_unequip_gun()

func _has_gun_in_inventory() -> bool:
	if hotbar_ui and hotbar_ui.has_method("has_item"):
		return hotbar_ui.has_item("gun")
	return false

func _equip_gun() -> void:
	if gun_equipped:
		return
	# Gun sirf tab hold hogi jab player ne gun pick up kar ke inventory mein daali ho
	if not _has_gun_in_inventory():
		show_tip_message("Pick up the gun first!")
		return
	gun_equipped = true
	held_gun.visible = true
	if crosshair_layer:
		crosshair_layer.visible = true
	if ammo_hud_container:
		ammo_hud_container.visible = true
	_update_ammo_hud()
	animation_player.play("NewLib/pistol_idle_main", 0.25)

func _unequip_gun() -> void:
	if not gun_equipped:
		return
	gun_equipped = false
	held_gun.visible = false
	is_firing = false
	if crosshair_layer:
		crosshair_layer.visible = false
	if ammo_hud_container:
		ammo_hud_container.visible = false
	animation_player.play("NewLib/idle_2", 0.2)

func _face_aim_direction(weight: float = 1.0) -> void:
	if not camera or not visuals:
		return
	var cam_forward := -camera.global_transform.basis.z
	var aim_dir_xz := Vector3(cam_forward.x, 0.0, cam_forward.z).normalized()
	if aim_dir_xz.length_squared() > 0.0001:
		var current_scale := visuals.scale
		var target_basis := Basis.looking_at(aim_dir_xz, Vector3.UP).rotated(Vector3.UP, PI)
		if weight >= 1.0:
			visuals.global_transform.basis = target_basis
		else:
			var current_quat := visuals.global_transform.basis.get_rotation_quaternion()
			var target_quat := target_basis.get_rotation_quaternion()
			visuals.global_transform.basis = Basis(current_quat.slerp(target_quat, clampf(weight, 0.0, 1.0)))
		visuals.scale = current_scale

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("gun_interact"):
		if gun_equipped:
			_unequip_gun()
		else:
			_equip_gun()
	
	# Left click fire
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if gun_equipped and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			fire_gun()
			get_viewport().set_input_as_handled()
	
	# R key = manual reload from reserve_ammo into clip_ammo
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_R:
		if gun_equipped and clip_ammo < MAGAZINE_SIZE and reserve_ammo > 0:
			reload_gun()
	
	# ENTER = inventory se selected apple khana (agar zameen par apple paas na ho)
	if event is InputEventKey and event.pressed and not event.echo \
			and (event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER):
		if is_instance_valid(nearby_apple):
			return # zameen wala apple khud handle karega
		eat_selected_from_inventory()

func reload_gun() -> void:
	if reserve_ammo <= 0 or clip_ammo >= MAGAZINE_SIZE:
		return
	var needed: int = MAGAZINE_SIZE - clip_ammo
	var take: int = mini(needed, reserve_ammo)
	clip_ammo += take
	reserve_ammo -= take
	current_ammo = clip_ammo + reserve_ammo
	_update_ammo_hud()

func fire_gun() -> void:
	if not gun_equipped or fire_timer > 0.0:
		return
	
	if clip_ammo <= 0:
		if reserve_ammo > 0:
			reload_gun()
		else:
			show_tip_message("Out of Ammo! Find ammo boxes!", 1.5)
			return
	
	clip_ammo -= 1
	current_ammo = clip_ammo + reserve_ammo
	_update_ammo_hud()
	
	# Auto-reload when magazine hits 0 and reserve ammo is available
	if clip_ammo <= 0 and reserve_ammo > 0:
		get_tree().create_timer(0.32).timeout.connect(func():
			if is_inside_tree() and clip_ammo <= 0 and reserve_ammo > 0:
				reload_gun()
		)
	
	# Gunshot sound effect
	if sfx_gunshot_player:
		sfx_gunshot_player.pitch_scale = randf_range(0.96, 1.05)
		sfx_gunshot_player.play()
	
	fire_timer = fire_cooldown
	is_firing = true
	recoil_timer = 0.22
	
	# Immediately rotate character towards the direction the player is shooting
	_face_aim_direction(1.0)
	
	# Shoot animation (purani pistol_idle animation ko gun fire ke tor par integrate kiya)
	animation_player.stop()
	animation_player.play("NewLib/pistol_idle", 0.03, 2.6)
	
	# Muzzle flash VFX
	var muzzle_pos: Vector3 = get_gun_muzzle_global_pos()
	if is_instance_valid(muzzle_flash_node):
		muzzle_flash_node.global_position = muzzle_pos
		var aim_dir = -camera.global_transform.basis.z.normalized()
		if aim_dir.length_squared() > 0.01:
			muzzle_flash_node.look_at(muzzle_pos + aim_dir, Vector3.UP)
		muzzle_flash_node.flash()
	
	# Raycast from camera center
	var space_state = get_world_3d().direct_space_state
	var cam_transform = camera.global_transform
	var ray_origin = cam_transform.origin
	var ray_dir = -cam_transform.basis.z.normalized()
	var ray_end = ray_origin + ray_dir * 100.0
	
	var query = PhysicsRayQueryParameters3D.create(ray_origin, ray_end)
	query.exclude = [self.get_rid()]
	var result = space_state.intersect_ray(query)
	
	var hit_pos = ray_end
	if not result.is_empty():
		hit_pos = result.position
		var hit_normal: Vector3 = result.normal
		var collider = result.collider
		
		# Bullet impact VFX
		var impact = BULLET_IMPACT_SCENE.instantiate()
		var scene_root = get_tree().current_scene
		if scene_root:
			scene_root.add_child(impact)
		else:
			get_parent().add_child(impact)
		impact.global_position = hit_pos
		if hit_normal.length_squared() > 0.01:
			var up_vec = Vector3.UP if abs(hit_normal.y) < 0.9 else Vector3.FORWARD
			impact.look_at(hit_pos + hit_normal, up_vec)
		
		# Damage target
		if is_instance_valid(collider) and collider.has_method("take_damage"):
			collider.take_damage(25.0, hit_pos, hit_normal)
		
		# Physics impulse
		if is_instance_valid(collider) and collider is RigidBody3D and collider.is_inside_tree():
			collider.apply_impulse(ray_dir * 14.0, hit_pos - collider.global_position)
	
	# Bullet tracer beam
	var tracer = BULLET_TRACER_SCENE.instantiate()
	var spawn_parent = get_tree().current_scene if get_tree().current_scene else get_parent()
	if spawn_parent:
		spawn_parent.add_child(tracer)
	tracer.init_tracer(muzzle_pos, hit_pos)

func get_gun_muzzle_global_pos() -> Vector3:
	if is_instance_valid(held_gun) and held_gun.visible:
		var mesh = held_gun.find_child("Cube_005_9m1_0", true, false)
		if mesh and mesh is MeshInstance3D and mesh.mesh:
			var aabb = mesh.mesh.get_aabb()
			var barrel_local = Vector3(
				aabb.position.x + aabb.size.x * 0.5,
				aabb.position.y + aabb.size.y * 0.65,
				aabb.position.z
			)
			return mesh.global_transform * barrel_local
		return held_gun.global_position
	return global_position + Vector3(0, 1.2, 0) + (-visuals.global_transform.basis.z * 0.5)

# ===== SETUP GUN & CROSSHAIR =====
func _setup_gun_and_crosshair() -> void:
	# Ensure pistol_idle_main, player_hit_reaction, and player_death are in NewLib
	var lib = animation_player.get_animation_library("NewLib")
	if lib:
		if not lib.has_animation("pistol_idle_main"):
			lib.add_animation("pistol_idle_main", PISTOL_IDLE_MAIN_ANIM)
		if not lib.has_animation("player_hit_reaction"):
			lib.add_animation("player_hit_reaction", PLAYER_HIT_REACTION_ANIM)
		var hit_anim_res := lib.get_animation("player_hit_reaction")
		if hit_anim_res:
			hit_anim_res.loop_mode = Animation.LOOP_NONE
		if not lib.has_animation("player_death") and PLAYER_DEATH_ANIM:
			var death_dup: Animation = PLAYER_DEATH_ANIM.duplicate()
			death_dup.loop_mode = Animation.LOOP_NONE
			lib.add_animation("player_death", death_dup)
		
		# Fix vertical bobbing/shifting when holding gun, walking with gun, or firing gun:
		# Lock Hips position to Roy's grounded idle_2 Hips height & strip non-Hips position/scale tracks
		_normalize_pistol_and_combat_animations(lib)
	
	# Muzzle flash VFX attachment (top_level so it does not inherit bone scale)
	if not is_instance_valid(muzzle_flash_node):
		muzzle_flash_node = MUZZLE_FLASH_SCENE.instantiate()
		add_child(muzzle_flash_node)
		muzzle_flash_node.top_level = true
		muzzle_flash_node.scale = Vector3.ONE
		muzzle_flash_node.visible = false
	
	# Crosshair UI (visible when gun is equipped)
	crosshair_layer = CanvasLayer.new()
	crosshair_layer.layer = 6
	var center = Control.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	var dot = ColorRect.new()
	dot.custom_minimum_size = Vector2(4, 4)
	dot.size = Vector2(4, 4)
	dot.color = Color(1.0, 1.0, 1.0, 0.85)
	dot.set_anchors_preset(Control.PRESET_CENTER)
	dot.offset_left = -2
	dot.offset_top = -2
	dot.offset_right = 2
	dot.offset_bottom = 2
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(dot)
	
	crosshair_layer.add_child(center)
	add_child(crosshair_layer)
	crosshair_layer.visible = false

func _normalize_pistol_and_combat_animations(lib: AnimationLibrary) -> void:
	var skel: Skeleton3D = get_node_or_null("visuals/person/Skeleton3D") as Skeleton3D
	var base_hips_pos := Vector3(-2.8305112e-07, 0.006056122, -6.6381617e-06)
	if skel and skel.get_bone_count() > 0:
		base_hips_pos = skel.get_bone_pose_position(0)
		# Reset all non-Hips bone positions and scales to exact rest pose so no animation stretches the rig
		for b in range(1, skel.get_bone_count()):
			skel.set_bone_pose_position(b, skel.get_bone_rest(b).origin)
			skel.set_bone_pose_scale(b, Vector3.ONE)
		skel.set_bone_pose_scale(0, Vector3.ONE)
	
	if lib.has_animation("idle_2"):
		var idle_anim: Animation = lib.get_animation("idle_2")
		if idle_anim:
			for t in range(idle_anim.get_track_count()):
				if idle_anim.track_get_type(t) == Animation.TYPE_POSITION_3D and str(idle_anim.track_get_path(t)).ends_with("Hips"):
					if idle_anim.track_get_key_count(t) > 0:
						base_hips_pos = idle_anim.track_get_key_value(t, 0)
					break
	
	var target_anims := [
		"pistol_idle_main",
		"pistol_idle",
		"pistol_walk",
		"pistol_run",
		"pistol_crouch_idle",
		"player_hit_reaction",
		"player_death",
		"walking",
		"run",
		"idle_2"
	]
	
	for anim_name in target_anims:
		if not lib.has_animation(anim_name):
			continue
		var anim: Animation = lib.get_animation(anim_name)
		if not anim:
			continue
		
		var is_crouch_or_death: bool = (anim_name == "pistol_crouch_idle" or anim_name == "player_death")
		var hips_pos_track_found := false
		
		for t in range(anim.get_track_count() - 1, -1, -1):
			var raw_path := str(anim.track_get_path(t))
			var fixed_path := raw_path.replace("mixamorig2_", "mixamorig_").replace("mixamorig1_", "mixamorig_")
			if not fixed_path.begins_with("Skeleton3D:"):
				var colon_idx := fixed_path.find(":")
				if colon_idx != -1:
					fixed_path = "Skeleton3D" + fixed_path.substr(colon_idx)
			if fixed_path != raw_path:
				anim.track_set_path(t, NodePath(fixed_path))
			
			var ttype := anim.track_get_type(t)
			var is_hips := fixed_path.ends_with("Hips")
			
			# Remove all scale tracks and all non-Hips position tracks so bone lengths stay 100% locked to rest pose
			if ttype == Animation.TYPE_SCALE_3D:
				anim.remove_track(t)
				continue
			if ttype == Animation.TYPE_POSITION_3D and not is_hips:
				anim.remove_track(t)
				continue
			
			# Lock Hips position track to grounded base_hips_pos (prevents vertical bobbing/jumping)
			if ttype == Animation.TYPE_POSITION_3D and is_hips:
				hips_pos_track_found = true
				var kc := anim.track_get_key_count(t)
				for k in range(kc):
					if is_crouch_or_death:
						var v: Vector3 = anim.track_get_key_value(t, k)
						var crouch_y: float = v.y * (0.005946775 if v.y > 0.05 else 1.0)
						anim.track_set_key_value(t, k, Vector3(base_hips_pos.x, crouch_y, base_hips_pos.z))
					else:
						anim.track_set_key_value(t, k, base_hips_pos)
		
		# Ensure a Hips position track exists so blending never interpolates from an unscaled pose
		if not hips_pos_track_found and not is_crouch_or_death:
			var nt := anim.add_track(Animation.TYPE_POSITION_3D)
			anim.track_set_path(nt, NodePath("Skeleton3D:mixamorig_Hips"))
			anim.track_insert_key(nt, 0.0, base_hips_pos)
	
	# Stabilize lower body on pistol_idle (used for firing) so shooting never dips/bobs the character's legs or hips
	if lib.has_animation("pistol_idle") and lib.has_animation("pistol_idle_main"):
		var shoot_anim: Animation = lib.get_animation("pistol_idle")
		var hold_anim: Animation = lib.get_animation("pistol_idle_main")
		if shoot_anim and hold_anim:
			var lower_bones := [
				"Skeleton3D:mixamorig_Hips",
				"Skeleton3D:mixamorig_LeftUpLeg",
				"Skeleton3D:mixamorig_RightUpLeg",
				"Skeleton3D:mixamorig_LeftLeg",
				"Skeleton3D:mixamorig_RightLeg",
				"Skeleton3D:mixamorig_LeftFoot",
				"Skeleton3D:mixamorig_RightFoot",
				"Skeleton3D:mixamorig_LeftToeBase",
				"Skeleton3D:mixamorig_RightToeBase"
			]
			for bpath in lower_bones:
				var hold_t := hold_anim.find_track(NodePath(bpath), Animation.TYPE_ROTATION_3D)
				var shoot_t := shoot_anim.find_track(NodePath(bpath), Animation.TYPE_ROTATION_3D)
				if hold_t != -1 and shoot_t != -1 and hold_anim.track_get_key_count(hold_t) > 0:
					var steady_rot: Quaternion = hold_anim.track_get_key_value(hold_t, 0)
					for k in range(shoot_anim.track_get_key_count(shoot_t)):
						shoot_anim.track_set_key_value(shoot_t, k, steady_rot)

# ===== PLAYER BODY MATERIALS & HEALING VFX =====
func _prepare_player_body_materials() -> void:
	player_body_materials.clear()
	var body_mesh := get_node_or_null("visuals/person/Skeleton3D/node_0") as MeshInstance3D
	if not body_mesh or not body_mesh.mesh:
		return
	for s in range(body_mesh.mesh.get_surface_count()):
		var orig_mat := body_mesh.get_active_material(s)
		if orig_mat is StandardMaterial3D:
			var dup_mat := orig_mat.duplicate() as StandardMaterial3D
			body_mesh.set_surface_override_material(s, dup_mat)
			player_body_materials.append(dup_mat)

func _play_heal_vfx() -> void:
	# 1. Shiny Emerald Green Body Flash on Roy's character mesh (fades back to normal smoothly)
	for mat in player_body_materials:
		if is_instance_valid(mat):
			mat.emission_enabled = true
			mat.emission = Color(0.15, 1.0, 0.42, 1.0)
			mat.emission_energy_multiplier = 2.0
			var mat_tween := create_tween()
			mat_tween.tween_property(mat, "emission_energy_multiplier", 0.0, 0.85).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	
	# 2. Temporary emerald green OmniLight3D on Roy's body
	var heal_light := OmniLight3D.new()
	heal_light.light_color = Color(0.2, 1.0, 0.45, 1.0)
	heal_light.light_energy = 2.2
	heal_light.omni_range = 2.2
	heal_light.position = Vector3(0.0, 0.65, 0.0)
	add_child(heal_light)
	var light_tween := create_tween()
	light_tween.tween_property(heal_light, "light_energy", 0.0, 0.85)
	light_tween.tween_callback(heal_light.queue_free)
	
	# 3. Rising Green Halo Ring around Roy's body
	var ring_inst := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.42
	torus.outer_radius = 0.50
	torus.rings = 24
	torus.ring_segments = 12
	var r_mat := StandardMaterial3D.new()
	r_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	r_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	r_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	r_mat.albedo_color = Color(0.2, 1.0, 0.45, 0.75)
	r_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	torus.material = r_mat
	ring_inst.mesh = torus
	ring_inst.position = Vector3(0.0, 0.15, 0.0)
	add_child(ring_inst)
	var ring_tween := create_tween().set_parallel(true)
	ring_tween.tween_property(ring_inst, "position:y", 1.15, 0.75).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	ring_tween.tween_property(ring_inst, "scale", Vector3(1.25, 1.0, 1.25), 0.75)
	ring_tween.tween_property(r_mat, "albedo_color:a", 0.0, 0.75)
	ring_tween.chain().tween_callback(ring_inst.queue_free)
	
	# 4. Floating Green "+ + +" 3D Healing Symbols rising close around Roy's body
	var plus_count: int = 7
	for i in range(plus_count):
		var plus_lbl := Label3D.new()
		plus_lbl.text = "+"
		plus_lbl.font_size = 28 if (i % 2 == 0) else 22
		plus_lbl.pixel_size = 0.0045
		plus_lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		plus_lbl.no_depth_test = true
		plus_lbl.modulate = Color(0.22, 1.0, 0.45, 0.98)
		plus_lbl.outline_size = 8
		plus_lbl.outline_modulate = Color(0.02, 0.28, 0.08, 0.95)
		
		var angle: float = (TAU / float(plus_count)) * float(i) + randf_range(-0.2, 0.2)
		var radius: float = randf_range(0.38, 0.58)
		var start_y: float = randf_range(0.25, 0.68)
		plus_lbl.position = Vector3(cos(angle) * radius, start_y, sin(angle) * radius)
		plus_lbl.scale = Vector3(0.4, 0.4, 0.4)
		add_child(plus_lbl)
		
		var delay: float = float(i) * 0.05
		var pt := create_tween()
		if delay > 0.0:
			pt.tween_interval(delay)
		pt.tween_property(plus_lbl, "scale", Vector3.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		pt.parallel().tween_property(plus_lbl, "position:y", start_y + randf_range(0.55, 0.85), 0.75).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		pt.parallel().tween_property(plus_lbl, "modulate:a", 0.0, 0.75).set_delay(0.15)
		pt.tween_callback(plus_lbl.queue_free)

# ===== HEALTH, LOW-HP RED SCREEN SHADING, & DEATH =====
func heal(amount: float) -> bool:
	if is_dead or health >= MAX_HEALTH:
		return false
	health = min(MAX_HEALTH, health + amount)
	_update_health_bar()
	_play_heal_vfx()
	return true

func take_damage(amount: float) -> void:
	if is_dead or invulnerable_timer > 0.0 or dialogue_locked:
		return
	health = max(0.0, health - amount)
	_update_health_bar()
	_flash_damage_vignette()
	if sfx_hit_player:
		sfx_hit_player.pitch_scale = randf_range(0.95, 1.06)
		sfx_hit_player.play()
	
	if health <= 0.0:
		_trigger_player_death()
		return
	
	# Hit reaction animation (protected by hit_react_timer so idle/walk doesn't cancel it)
	if animation_player.has_animation("NewLib/player_hit_reaction") and health > 0.0:
		hit_react_timer = 0.55
		animation_player.stop()
		animation_player.play("NewLib/player_hit_reaction", 0.06, 1.35)

func _setup_damage_vignette() -> void:
	var dmg_layer := get_node_or_null("DamageFlashLayer") as CanvasLayer
	if not dmg_layer:
		dmg_layer = CanvasLayer.new()
		dmg_layer.name = "DamageFlashLayer"
		dmg_layer.layer = 15
		var dmg_rect := ColorRect.new()
		dmg_rect.name = "DamageRect"
		dmg_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
		dmg_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		
		var sh := Shader.new()
		sh.code = """
shader_type canvas_item;
uniform float intensity : hint_range(0.0, 1.0) = 0.0;
uniform float pulse : hint_range(0.0, 1.0) = 0.0;
void fragment() {
	vec2 uv = UV * 2.0 - 1.0;
	float dist = length(uv);
	float vig = smoothstep(0.32, 1.25, dist);
	float center_tint = smoothstep(0.65, 1.45, dist) * 0.35;
	float alpha = clamp((vig + center_tint) * intensity * (0.86 + 0.14 * pulse), 0.0, 0.90);
	COLOR = vec4(0.82, 0.03, 0.03, alpha);
}
"""
		damage_vignette_mat = ShaderMaterial.new()
		damage_vignette_mat.shader = sh
		dmg_rect.material = damage_vignette_mat
		dmg_layer.add_child(dmg_rect)
		add_child(dmg_layer)

func _flash_damage_vignette() -> void:
	if not damage_vignette_mat:
		_setup_damage_vignette()
	damage_flash_alpha = 0.78

func _update_damage_vignette(delta: float) -> void:
	if not damage_vignette_mat:
		return
	if damage_flash_alpha > 0.0:
		damage_flash_alpha = move_toward(damage_flash_alpha, 0.0, delta * 1.45)
	
	# Persistent red edge shading only when health drops below 50 HP
	var low_hp_intensity: float = 0.0
	if is_dead:
		low_hp_intensity = 0.92
	elif health < 50.0:
		low_hp_intensity = clampf((50.0 - health) / 50.0, 0.0, 1.0) * 0.85
	
	var pulse_speed: float = 6.5 if health <= 25.0 else 3.5
	vignette_pulse_time += delta * pulse_speed
	var pulse_val: float = (sin(vignette_pulse_time) * 0.5 + 0.5) if (health < 50.0 and not is_dead) else 0.0
	
	var final_intensity: float = maxf(damage_flash_alpha, low_hp_intensity)
	damage_vignette_mat.set_shader_parameter("intensity", final_intensity)
	damage_vignette_mat.set_shader_parameter("pulse", pulse_val)

func _trigger_player_death() -> void:
	if is_dead:
		return
	is_dead = true
	running = false
	is_firing = false
	velocity = Vector3.ZERO
	_stop_movement_sounds()
	
	if animation_player:
		animation_player.stop()
		if animation_player.has_animation("NewLib/player_death"):
			animation_player.play("NewLib/player_death", 0.12, 1.0)
	
	# Spawn toon cloud poof when body hits ground
	var dt := create_tween()
	dt.tween_interval(0.55)
	dt.tween_callback(func():
		if ENEMY_DEATH_VFX_SCENE and get_tree().current_scene:
			var vfx := ENEMY_DEATH_VFX_SCENE.instantiate() as Node3D
			get_tree().current_scene.add_child(vfx)
			vfx.global_position = global_position + Vector3(0, 0.1, 0)
			vfx.scale = Vector3(0.45, 0.45, 0.45)
	)
	dt.tween_interval(0.65)
	dt.tween_callback(_show_death_screen)

var death_title_text: String = "YOU DIED"

func trigger_jessica_died() -> void:
	if is_dead:
		return
	is_dead = true
	running = false
	is_firing = false
	velocity = Vector3.ZERO
	_stop_movement_sounds()
	if animation_player:
		animation_player.stop()
		if animation_player.has_animation("NewLib/idle"):
			animation_player.play("NewLib/idle")
	show_tip_message("JESSICA WAS KILLED! Protect Jessica!", 3.0)
	var dt := create_tween()
	dt.tween_interval(0.8)
	dt.tween_callback(func(): _show_death_screen("JESSICA WAS KILLED!\nMISSION FAILED"))

func _show_death_screen(custom_title: String = "") -> void:
	if custom_title != "":
		death_title_text = custom_title
	if not is_dead:
		return
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	
	# Stop world background music / siren so Try Again sound plays clearly
	var scene_root := get_tree().current_scene
	if scene_root:
		var bg_music := scene_root.find_child("AudioStreamPlayer2D", true, false)
		if bg_music and bg_music.has_method("stop"):
			bg_music.stop()
		var siren := scene_root.find_child("EscapeSirenAudio", true, false)
		if siren and siren.has_method("stop"):
			siren.stop()
	
	if not death_ui_layer:
		death_ui_layer = CanvasLayer.new()
		death_ui_layer.name = "PlayerDeathUILayer"
		death_ui_layer.layer = 30
		add_child(death_ui_layer)
		
		var bg := ColorRect.new()
		bg.name = "BlackFadeRect"
		bg.set_anchors_preset(Control.PRESET_FULL_RECT)
		bg.color = Color(0.0, 0.0, 0.0, 0.0)
		death_ui_layer.add_child(bg)
		
		var center := CenterContainer.new()
		center.set_anchors_preset(Control.PRESET_FULL_RECT)
		death_ui_layer.add_child(center)
		
		var vbox := VBoxContainer.new()
		vbox.name = "DeathMenuBox"
		vbox.add_theme_constant_override("separation", 22)
		vbox.modulate.a = 0.0
		center.add_child(vbox)
		
		var title := Label.new()
		title.text = death_title_text
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		title.add_theme_font_size_override("font_size", 54 if death_title_text.contains("\n") else 68)
		title.add_theme_color_override("font_color", Color(0.88, 0.14, 0.14, 1.0))
		title.add_theme_constant_override("outline_size", 12)
		title.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
		vbox.add_child(title)
		
		var btn_row := HBoxContainer.new()
		btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
		btn_row.add_theme_constant_override("separation", 24)
		vbox.add_child(btn_row)
		
		var btn_try_again := Button.new()
		btn_try_again.text = "  TRY AGAIN  "
		btn_try_again.custom_minimum_size = Vector2(210, 50)
		btn_try_again.add_theme_font_size_override("font_size", 22)
		btn_try_again.pressed.connect(_respawn_player)
		btn_row.add_child(btn_try_again)
		
		var btn_quit := Button.new()
		btn_quit.text = "  QUIT  "
		btn_quit.custom_minimum_size = Vector2(210, 50)
		btn_quit.add_theme_font_size_override("font_size", 22)
		btn_quit.pressed.connect(func(): get_tree().quit())
		btn_row.add_child(btn_quit)
		
		var sub := Label.new()
		sub.text = "[R / ENTER] Try Again      [Q] Quit"
		sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		sub.add_theme_font_size_override("font_size", 16)
		sub.add_theme_color_override("font_color", Color(0.75, 0.75, 0.75, 0.85))
		vbox.add_child(sub)
		
		if ResourceLoader.exists("res://import/sound/try-again-background-sound.mp3"):
			var try_again_audio := AudioStreamPlayer.new()
			try_again_audio.name = "TryAgainAudio"
			var stream := load("res://import/sound/try-again-background-sound.mp3") as AudioStream
			if stream:
				var s_dup := stream.duplicate()
				if s_dup is AudioStreamMP3:
					s_dup.loop = true
				try_again_audio.stream = s_dup
				death_ui_layer.add_child(try_again_audio)
	
	death_ui_layer.visible = true
	var try_audio := death_ui_layer.get_node_or_null("TryAgainAudio") as AudioStreamPlayer
	if try_audio and not try_audio.playing:
		try_audio.play()
	
	var fade_bg := death_ui_layer.get_node_or_null("BlackFadeRect") as ColorRect
	var menu_box := death_ui_layer.find_child("DeathMenuBox", true, false) as Control
	if fade_bg and menu_box:
		fade_bg.color = Color(0.0, 0.0, 0.0, 0.0)
		menu_box.modulate.a = 0.0
		var ft := create_tween()
		# 1. Ahista ahista black fadeout (1.6 seconds)
		ft.tween_property(fade_bg, "color:a", 0.96, 1.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		# 2. Black hone ke baad YOU DIED + TRY AGAIN / QUIT fade in
		ft.tween_property(menu_box, "modulate:a", 1.0, 0.65).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func _respawn_player() -> void:
	if not is_dead:
		return
	if death_ui_layer:
		var try_audio := death_ui_layer.get_node_or_null("TryAgainAudio") as AudioStreamPlayer
		if try_audio:
			try_audio.stop()
	if ResourceLoader.exists("res://scene/start_screen.tscn"):
		get_tree().change_scene_to_file("res://scene/start_screen.tscn")
	else:
		get_tree().reload_current_scene()

func _update_health_bar() -> void:
	if health_bar:
		var t := create_tween()
		t.tween_property(health_bar, "value", health, 0.25)

func eat_apple() -> bool:
	# Return true agar apple khaya gaya (health full ho to false)
	if heal(APPLE_HEAL):
		return true
	show_tip_message("Health is already full!")
	return false

func eat_selected_from_inventory() -> void:
	if not hotbar_ui:
		return
	var item = hotbar_ui.get_selected_item()
	if item.is_empty() or item.get("id", "") != "apple":
		return
	if eat_apple():
		hotbar_ui.consume_selected_item(1)

# ===== STAMINA =====
func _update_stamina(delta: float) -> void:
	var is_running_now := running and is_on_floor() and not is_swimming \
		and Vector2(velocity.x, velocity.z).length() > 0.1
	
	if is_running_now:
		stamina = max(0.0, stamina - STAMINA_DRAIN * delta)
		stamina_regen_delay = 1.0
		if stamina <= 0.0:
			stamina_exhausted = true
			running = false
	else:
		stamina_regen_delay = max(0.0, stamina_regen_delay - delta)
		if stamina_regen_delay <= 0.0:
			stamina = min(MAX_STAMINA, stamina + STAMINA_REGEN * delta)
			if stamina_exhausted and stamina >= MAX_STAMINA * 0.25:
				stamina_exhausted = false
	
	if stamina_bar:
		stamina_bar.value = stamina
	
	# Warning: stamina kam hone par right upper side pop
	var low := stamina <= MAX_STAMINA * 0.3
	if low != stamina_warning_visible:
		stamina_warning_visible = low
		_set_stamina_warning(low)

func _set_stamina_warning(visible_now: bool) -> void:
	if not stamina_warning:
		return
	if stamina_warning_tween and stamina_warning_tween.is_valid():
		stamina_warning_tween.kill()
	stamina_warning_tween = create_tween()
	if visible_now:
		stamina_warning.visible = true
		stamina_warning_tween.tween_property(stamina_warning, "modulate:a", 1.0, 0.25)
	else:
		stamina_warning_tween.tween_property(stamina_warning, "modulate:a", 0.0, 0.4)
		stamina_warning_tween.tween_callback(func(): stamina_warning.visible = false)

func _setup_bars() -> void:
	var health_scene = load("res://progress_ui_system/health_bar.tscn")
	var stamina_scene = load("res://progress_ui_system/stamina_bar.tscn")
	if health_scene:
		var h = health_scene.instantiate()
		add_child(h)
		health_bar = h.find_child("Health", true, false) as ProgressBar
		if health_bar:
			health_bar.max_value = MAX_HEALTH
			health_bar.value = health
	if stamina_scene:
		var s = stamina_scene.instantiate()
		add_child(s)
		stamina_bar = s.find_child("ProgressBar", true, false) as ProgressBar
		if stamina_bar:
			stamina_bar.max_value = MAX_STAMINA
			stamina_bar.value = stamina
			# Warning label bar ke neeche (right upper)
			stamina_warning = Label.new()
			stamina_warning.text = "Stamina is getting low!"
			stamina_warning.add_theme_font_size_override("font_size", 22)
			stamina_warning.add_theme_color_override("font_color", Color(1, 0.35, 0.25))
			stamina_warning.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
			stamina_warning.add_theme_constant_override("shadow_offset_x", 2)
			stamina_warning.add_theme_constant_override("shadow_offset_y", 2)
			stamina_warning.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			stamina_warning.anchor_left = stamina_bar.anchor_left
			stamina_warning.anchor_right = stamina_bar.anchor_right
			stamina_warning.anchor_top = stamina_bar.anchor_top
			stamina_warning.anchor_bottom = stamina_bar.anchor_top
			stamina_warning.offset_left = -170.0
			stamina_warning.offset_right = 170.0
			stamina_warning.offset_top = 20.0
			stamina_warning.offset_bottom = 55.0
			stamina_warning.modulate.a = 0.0
			stamina_warning.visible = false
			s.add_child(stamina_warning)
	tip_popup = TipPopup.new()
	add_child(tip_popup)
	
	# Game start par picture tutorial (mouse enable, game pause)
	add_child(TutorialScreen.new())

# ===== TIP / TUTORIAL SYSTEM =====
# Har tip sirf pehli dafa dikhta hai. ESC se band hota hai.
func show_tip_once(tip_id: String, title: String, body: String, image: Texture2D = null) -> void:
	if shown_tips.has(tip_id) or not tip_popup:
		return
	shown_tips[tip_id] = true
	tip_popup.show_tip(title, body, image)

func show_tip_message(text: String, duration: float = 2.5) -> void:
	if instruction_banner and instruction_banner.has_method("show_message"):
		instruction_banner.show_message(text, duration)

# ===== PLAYER AUDIO SYSTEM =====
func _setup_audio() -> void:
	if ResourceLoader.exists("res://import/sound/male_character/freesound_community-footstep-1-83098.mp3"):
		SFX_FOOTSTEP = load("res://import/sound/male_character/freesound_community-footstep-1-83098.mp3")
		
	if ResourceLoader.exists("res://import/sound/male_character/crouch_walk.mp3"):
		SFX_CROUCH_WALK = load("res://import/sound/male_character/crouch_walk.mp3")
		
	if ResourceLoader.exists("res://import/sound/male_character/swimming.mp3"):
		SFX_SWIMMING = load("res://import/sound/male_character/swimming.mp3")
		
	if ResourceLoader.exists("res://import/sound/male_character/getting-hit.mp3"):
		SFX_GETTING_HIT = load("res://import/sound/male_character/getting-hit.mp3")

	if SFX_FOOTSTEP:
		sfx_footstep_player = AudioStreamPlayer.new()
		sfx_footstep_player.name = "FootstepAudio"
		sfx_footstep_player.stream = SFX_FOOTSTEP
		sfx_footstep_player.volume_db = -3.0
		add_child(sfx_footstep_player)
	
	if SFX_CROUCH_WALK:
		sfx_crouch_player = AudioStreamPlayer.new()
		sfx_crouch_player.name = "CrouchWalkAudio"
		var cw_stream := SFX_CROUCH_WALK.duplicate()
		if cw_stream is AudioStreamMP3:
			cw_stream.loop = true
		sfx_crouch_player.stream = cw_stream
		sfx_crouch_player.volume_db = -4.0
		add_child(sfx_crouch_player)
	
	if SFX_SWIMMING:
		sfx_swim_player = AudioStreamPlayer.new()
		sfx_swim_player.name = "SwimmingAudio"
		var sw_stream := SFX_SWIMMING.duplicate()
		if sw_stream is AudioStreamMP3:
			sw_stream.loop = true
		sfx_swim_player.stream = sw_stream
		sfx_swim_player.volume_db = -2.0
		add_child(sfx_swim_player)
	
	if SFX_GETTING_HIT:
		sfx_hit_player = AudioStreamPlayer.new()
		sfx_hit_player.name = "HitAudio"
		sfx_hit_player.stream = SFX_GETTING_HIT
		sfx_hit_player.volume_db = 0.0
		add_child(sfx_hit_player)

func _update_movement_sounds(_delta: float, is_moving: bool) -> void:
	if sfx_swim_player and sfx_swim_player.playing:
		sfx_swim_player.stop()
	
	if not is_moving or not is_on_floor():
		if sfx_footstep_player and sfx_footstep_player.playing:
			sfx_footstep_player.stop()
		if sfx_crouch_player and sfx_crouch_player.playing:
			sfx_crouch_player.stop()
		footstep_timer = 0.0
		return
	
	if is_crouching:
		if sfx_footstep_player and sfx_footstep_player.playing:
			sfx_footstep_player.stop()
		if sfx_crouch_player and not sfx_crouch_player.playing:
			sfx_crouch_player.play()
		return
	else:
		if sfx_crouch_player and sfx_crouch_player.playing:
			sfx_crouch_player.stop()
	
	# Normal Walk vs Run footsteps
	if sfx_footstep_player:
		var target_pitch := 1.32 if running else 1.0
		sfx_footstep_player.pitch_scale = target_pitch
		if not sfx_footstep_player.playing:
			sfx_footstep_player.play()

func _stop_movement_sounds() -> void:
	if sfx_footstep_player and sfx_footstep_player.playing:
		sfx_footstep_player.stop()
	if sfx_crouch_player and sfx_crouch_player.playing:
		sfx_crouch_player.stop()
	if sfx_swim_player and sfx_swim_player.playing:
		sfx_swim_player.stop()

func has_key() -> bool:
	if has_cage_key:
		return true
	if hotbar_ui and hotbar_ui.has_method("has_item"):
		return hotbar_ui.has_item("key")
	return false

func consume_key() -> void:
	has_cage_key = false
	if hotbar_ui and hotbar_ui.has_method("remove_item_by_id"):
		hotbar_ui.remove_item_by_id("key", 1)

func face_world_position(target_pos: Vector3) -> void:
	var dir := target_pos - global_position
	dir.y = 0.0
	if dir.length_squared() > 0.001 and visuals:
		var cur_scale := visuals.scale
		visuals.global_transform.basis = Basis.looking_at(dir.normalized(), Vector3.UP).rotated(Vector3.UP, PI)
		visuals.scale = cur_scale

# ===== AMMO HUD & SOUND SYSTEM =====
func _load_clean_ui_tex(path: String, strip_white_bg: bool = true) -> Texture2D:
	if not ResourceLoader.exists(path):
		return null
	var raw_tex := load(path) as Texture2D
	if not raw_tex:
		return null
	var img: Image = raw_tex.get_image()
	if not img:
		return raw_tex
	if img.is_compressed():
		img.decompress()
	img.convert(Image.FORMAT_RGBA8)
	if strip_white_bg:
		var w: int = img.get_width()
		var h: int = img.get_height()
		for y in range(h):
			for x in range(w):
				var c: Color = img.get_pixel(x, y)
				if c.a > 0.0 and c.r > 0.94 and c.g > 0.94 and c.b > 0.94:
					img.set_pixel(x, y, Color(0, 0, 0, 0))
	var used_rect: Rect2i = img.get_used_rect()
	if used_rect.size.x > 8 and used_rect.size.y > 8:
		img = img.get_region(used_rect)
	return ImageTexture.create_from_image(img)

func _setup_ammo_hud() -> void:
	ammo_hud_layer = CanvasLayer.new()
	ammo_hud_layer.name = "AmmoHudLayer"
	ammo_hud_layer.layer = 12
	add_child(ammo_hud_layer)
	
	ammo_hud_container = Control.new()
	ammo_hud_container.name = "AmmoPanel"
	ammo_hud_layer.add_child(ammo_hud_container)
	
	# Bottom right anchor
	ammo_hud_container.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	ammo_hud_container.offset_left = -258.0
	ammo_hud_container.offset_top = -104.0
	ammo_hud_container.offset_right = -22.0
	ammo_hud_container.offset_bottom = -16.0
	ammo_hud_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# 1. Base Layer: Wide horizontal beige parchment banner (ammo_banner_bg.png)
	var banner_bg := TextureRect.new()
	banner_bg.name = "AmmoBannerBg"
	banner_bg.position = Vector2(24.0, 14.0)
	banner_bg.size = Vector2(212.0, 62.0)
	banner_bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	banner_bg.stretch_mode = TextureRect.STRETCH_SCALE
	banner_bg.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	banner_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner_bg.texture = _load_clean_ui_tex("res://import/UI/ammo_banner_bg.png", true)
	ammo_hud_container.add_child(banner_bg)
	
	# 2. Overlapping Left Badge: Yellow-gold notched badge (ammo_gun_badge.png) on top of banner_bg
	var yellow_badge := TextureRect.new()
	yellow_badge.name = "YellowGunBadge"
	yellow_badge.position = Vector2(0.0, 2.0)
	yellow_badge.size = Vector2(92.0, 84.0)
	yellow_badge.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	yellow_badge.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	yellow_badge.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	yellow_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	yellow_badge.texture = _load_clean_ui_tex("res://import/UI/ammo_gun_badge.png", true)
	ammo_hud_container.add_child(yellow_badge)
	
	# 3. Gun Icon on top of the yellow badge (gun_icon.png)
	var gun_icon := TextureRect.new()
	gun_icon.name = "GunIcon"
	gun_icon.position = Vector2(14.0, 14.0)
	gun_icon.size = Vector2(64.0, 52.0)
	gun_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	gun_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	gun_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	gun_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gun_icon.texture = _load_clean_ui_tex("res://import/UI/gun_icon.png", false)
	yellow_badge.add_child(gun_icon)
	
	# 4. Ammo Count Label on the right side of the beige banner (NOT on the yellow badge)
	ammo_hud_label = Label.new()
	ammo_hud_label.name = "AmmoLabel"
	ammo_hud_label.position = Vector2(96.0, 16.0)
	ammo_hud_label.size = Vector2(128.0, 56.0)
	ammo_hud_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ammo_hud_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	ammo_hud_label.add_theme_font_size_override("font_size", 24)
	ammo_hud_label.add_theme_constant_override("outline_size", 6)
	ammo_hud_label.add_theme_color_override("font_outline_color", Color(0.14, 0.08, 0.04, 0.98))
	ammo_hud_label.add_theme_color_override("font_color", Color(1.0, 0.94, 0.72, 1.0))
	ammo_hud_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ammo_hud_container.add_child(ammo_hud_label)
	
	ammo_hud_container.visible = gun_equipped
	_update_ammo_hud()

func _update_ammo_hud() -> void:
	current_ammo = clip_ammo + reserve_ammo
	if not ammo_hud_label:
		return
	ammo_hud_label.text = "%d / %d" % [clip_ammo, reserve_ammo]
	if clip_ammo <= 0 and reserve_ammo <= 0:
		ammo_hud_label.add_theme_color_override("font_color", Color(1.0, 0.25, 0.22, 1.0))
	elif clip_ammo <= 3:
		ammo_hud_label.add_theme_color_override("font_color", Color(1.0, 0.68, 0.22, 1.0))
	else:
		ammo_hud_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.76, 1.0))

func add_ammo(amount: int) -> void:
	var remaining: int = amount
	if clip_ammo < MAGAZINE_SIZE:
		var to_clip: int = mini(MAGAZINE_SIZE - clip_ammo, remaining)
		clip_ammo += to_clip
		remaining -= to_clip
	if remaining > 0:
		reserve_ammo = clampi(reserve_ammo + remaining, 0, max_ammo)
	current_ammo = clip_ammo + reserve_ammo
	_update_ammo_hud()
	print("Player picked up Ammo +%d! Clip: %d / Reserve: %d" % [amount, clip_ammo, reserve_ammo])

func _setup_gunshot_sound() -> void:
	SFX_GUNSHOT = _find_gunshot_sound()
	if SFX_GUNSHOT:
		sfx_gunshot_player = AudioStreamPlayer.new()
		sfx_gunshot_player.name = "GunshotAudioPlayer"
		sfx_gunshot_player.stream = SFX_GUNSHOT
		sfx_gunshot_player.volume_db = -1.5
		add_child(sfx_gunshot_player)

func _find_gunshot_sound() -> AudioStream:
	var potential_paths := [
		"res://import/sound/universfield-pistol-shot-278821.mp3",
		"res://import/sound/pistol_shot.mp3",
		"res://import/sound/gunshot.mp3",
		"res://import/sound/pistol-shot.mp3"
	]
	for p in potential_paths:
		if ResourceLoader.exists(p):
			return load(p) as AudioStream
	return null
