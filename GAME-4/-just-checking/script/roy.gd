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
const JUMP_KEEPS_MOMENTUM := false
var jump_velocity_xz := Vector3.ZERO
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

var can_fire := true
var fire_cooldown := 0.22
var fire_timer := 0.0
var is_firing := false
var recoil_timer := 0.0
var muzzle_flash_node: Node3D = null
var crosshair_layer: CanvasLayer = null

# ===== HEALTH / STAMINA =====
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

@export var toon_material: Material

func apply_toon_to_children(node: Node) -> void:
	for child in node.get_children():
		if child is MeshInstance3D:
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
	base_fov = camera.fov
	base_cam_pos = camera.position
	held_gun.visible = false
	print("PLAYER READY | hotbar_ui = ", hotbar_ui)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	apply_toon_to_children(self)
	
	# Instruction banner UI add karna
	if INSTRUCTION_BANNER_SCENE:
		instruction_banner = INSTRUCTION_BANNER_SCENE.instantiate()
		add_child(instruction_banner)
	
	# Hotbar signal se gun equip/unequip handle karna
	if hotbar_ui:
		hotbar_ui.item_selected.connect(_on_hotbar_item_selected)
	
	_setup_bars()
	_setup_gun_and_crosshair()

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(deg_to_rad(-event.relative.x * sens_horizontal))
		visuals.rotate_y(deg_to_rad(event.relative.x * sens_horizontal))
		camera_mount.rotation.x = clamp(camera_mount.rotation.x + deg_to_rad(event.relative.y * sens_vertical), deg_to_rad(-20.0),deg_to_rad(40.0))

func _physics_process(delta: float) -> void:
	_update_camera_effects(delta)
	_update_stamina(delta)
	if fire_timer > 0.0:
		fire_timer -= delta
	if recoil_timer > 0.0:
		recoil_timer -= delta
		if recoil_timer <= 0.0:
			is_firing = false
	if Input.is_action_just_pressed("drop"):
		drop_from_inventory()
	
	# ===== AGAR PLAYER PANI KE ANDAR HO (SWIMMING MODE) =====
	if is_swimming:
		var swim_input_dir := Input.get_vector("right", "left", "backward", "forward")
		var swim_direction := (transform.basis * Vector3(swim_input_dir.x, 0, swim_input_dir.y)).normalized()
		
		var cur_scale_y = global_basis.get_scale().y
		var player_height = 1.23 * cur_scale_y
		var target_y = water_surface_y - (player_height * 0.35)
		var current_y = global_position.y
		var y_diff = target_y - current_y
		
		if global_position.y > water_surface_y + (player_height * 0.4):
			exit_water()
			return
		
		var max_buoyancy = 3.0 * cur_scale_y
		var buoyancy_vel = clamp(y_diff * 5.0, -max_buoyancy, max_buoyancy)
		velocity.y = move_toward(velocity.y, buoyancy_vel, delta * 10.0 * cur_scale_y)
		
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
		else:
			velocity.x = move_toward(velocity.x, 0, SWIM_SPEED * 3.0)
			velocity.z = move_toward(velocity.z, 0, SWIM_SPEED * 3.0)
			
			visuals.position.y = move_toward(visuals.position.y, -0.2, delta * 5.0)
			
			if animation_player.current_animation != "NewLib/water_idle":
				animation_player.play("NewLib/water_idle", 0.2)
		
		move_and_slide()
		return
	
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
			
		if Input.is_action_pressed("run") and not stamina_exhausted:
			SPEED = RUN_SPEED
			running = true
		else:
			SPEED = WALK_SPEED
			running = false
	
	if not is_on_floor():
		velocity += get_gravity() * delta

	if Input.is_action_just_pressed("jump") and is_on_floor() and not is_crouching and not is_jumping:
		is_jumping = true
		in_air = false
		velocity.y = JUMP_VELOCITY
		if JUMP_KEEPS_MOMENTUM:
			jump_velocity_xz = Vector3(velocity.x, 0, velocity.z)
		else:
			jump_velocity_xz = Vector3.ZERO
		var jump_anim := animation_player.get_animation("NewLib/jump")
		var air_time := 3.4 * JUMP_VELOCITY / get_gravity().length()
		var anim_speed := jump_anim.length / air_time
		animation_player.play("NewLib/jump", 0.1, anim_speed)

	if is_jumping:
		velocity.x = jump_velocity_xz.x
		velocity.z = jump_velocity_xz.z
		move_and_slide()
		if not is_on_floor():
			in_air = true
		elif in_air:
			is_jumping = false
			in_air = false
		return

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
#ww					$Node3D/FootstepPlayer.play()
				
		velocity.x = direction.x * SPEED
		velocity.z = direction.z * SPEED
	else:
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

	move_and_slide()

# ===== WATER FUNCTIONS =====
func enter_water(surface_y: float = 0.0) -> void:
	is_swimming = true
	water_surface_y = surface_y
	visuals.position.y = 0.0

func exit_water() -> void:
	is_swimming = false
	water_surface_y = 0.0
	visuals.position.y = 0.0

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

func _on_hotbar_item_selected(slot_index: int, item_data: Dictionary) -> void:
	var item_id = item_data.get("id", "")
	var item_type = item_data.get("type", "")
	
	if item_id == "gun" or item_type == "weapon":
		return
	_unequip_gun()

func _equip_gun() -> void:
	if gun_equipped:
		return
	gun_equipped = true
	held_gun.visible = true
	if crosshair_layer:
		crosshair_layer.visible = true
	animation_player.play("NewLib/pistol_idle_main", 0.25)

func _unequip_gun() -> void:
	if not gun_equipped:
		return
	gun_equipped = false
	held_gun.visible = false
	is_firing = false
	if crosshair_layer:
		crosshair_layer.visible = false
	animation_player.play("NewLib/idle_2", 0.2)

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
	
	# ENTER = inventory se selected apple khana (agar zameen par apple paas na ho)
	if event is InputEventKey and event.pressed and not event.echo \
			and (event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER):
		if is_instance_valid(nearby_apple):
			return # zameen wala apple khud handle karega
		eat_selected_from_inventory()

func fire_gun() -> void:
	if not gun_equipped or fire_timer > 0.0:
		return
	
	fire_timer = fire_cooldown
	is_firing = true
	recoil_timer = 0.22
	
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
	
	# Camera recoil kickback
	camera_mount.rotation.x = clamp(camera_mount.rotation.x - deg_to_rad(1.2), deg_to_rad(-20.0), deg_to_rad(40.0))
	
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
	var scene_root = get_tree().current_scene
	if scene_root:
		scene_root.add_child(tracer)
	else:
		get_parent().add_child(tracer)
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
	# Ensure pistol_idle_main and player_hit_reaction are in NewLib
	var lib = animation_player.get_animation_library("NewLib")
	if lib:
		if not lib.has_animation("pistol_idle_main"):
			lib.add_animation("pistol_idle_main", PISTOL_IDLE_MAIN_ANIM)
		if not lib.has_animation("player_hit_reaction"):
			lib.add_animation("player_hit_reaction", PLAYER_HIT_REACTION_ANIM)
	
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

# ===== HEALTH =====
func heal(amount: float) -> bool:
	if health >= MAX_HEALTH:
		return false
	health = min(MAX_HEALTH, health + amount)
	_update_health_bar()
	return true

func take_damage(amount: float) -> void:
	health = max(0.0, health - amount)
	_update_health_bar()
	# Hit reaction animation
	if animation_player.has_animation("NewLib/player_hit_reaction") and health > 0.0:
		animation_player.play("NewLib/player_hit_reaction", 0.08)

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

func show_tip_message(text: String) -> void:
	if instruction_banner and instruction_banner.has_method("show_message"):
		instruction_banner.show_message(text, 2.0)
