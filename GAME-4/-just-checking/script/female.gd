extends CharacterBody3D

@onready var camera_mount: Node3D = get_node_or_null("camera_mount")
@onready var visuals: Node3D = $jessica
@onready var animation_player: AnimationPlayer = $jessica/AnimationPlayer
@onready var collision_shape_3d: CollisionShape3D = $CollisionShape3D
@onready var hotbar_ui: Node = get_node_or_null("HotbarUI")

var SPEED = 3.0
const WALK_SPEED = 1.30
const RUN_SPEED = 2.65
const JUMP_VELOCITY = 4.5
const CROUCH_SPEED = 1.0
const SWIM_SPEED = 1.5

@export var sens_horizontal = 0.3
@export var sens_vertical = 0.1
@export var is_npc_companion: bool = true
@export var is_caged: bool = true
@export var is_following_roy: bool = false
@export var max_health: float = 100.0

var current_health: float = 100.0
var is_dead: bool = false
var hurt_sound: AudioStream = null
var hurt_player_3d: AudioStreamPlayer3D = null

var running = false
var is_crouching = false
var is_swimming = false
var water_surface_y: float = 0.0  # Pani ki surface height yaad rakhni hai
var target_roy: CharacterBody3D = null
var overhead_label: Label3D = null
var companion_is_moving: bool = false
var companion_is_running: bool = false

@export var toon_material: Material

func apply_toon_to_children(node: Node) -> void:
	if not toon_material:
		return
	for child in node.get_children():
		if child is MeshInstance3D:
			child.material_override = toon_material
		if child.get_child_count() > 0:
			apply_toon_to_children(child)

func _ready() -> void:
	add_to_group("companion")
	add_to_group("player_allies")
	if ResourceLoader.exists("res://import/sound/msg box sounds/jessica_scream_roy.mp3"):
		hurt_sound = load("res://import/sound/msg box sounds/jessica_scream_roy.mp3")
	elif ResourceLoader.exists("res://import/sound/enemy/getting-hit.mp3"):
		hurt_sound = load("res://import/sound/enemy/getting-hit.mp3")
	if hurt_sound:
		hurt_player_3d = AudioStreamPlayer3D.new()
		hurt_player_3d.name = "JessicaHurtAudio"
		hurt_player_3d.stream = hurt_sound
		hurt_player_3d.volume_db = 2.0
		hurt_player_3d.max_distance = 25.0
		add_child(hurt_player_3d)
	apply_toon_to_children(self)
	_prepare_jessica_animations()
	if is_npc_companion:
		_setup_as_npc_companion()
	else:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _prepare_jessica_animations() -> void:
	if not animation_player or not visuals:
		return
	animation_player.playback_default_blend_time = 0.18
	var skeleton := visuals.find_child("Skeleton3D", true, false) as Skeleton3D
	if not skeleton or skeleton.get_bone_count() == 0:
		return
	
	var rest_hips_y: float = 0.665896
	var hips_idx: int = skeleton.find_bone("mixamorig_Hips")
	if hips_idx < 0:
		hips_idx = 0
	rest_hips_y = skeleton.get_bone_pose_position(hips_idx).y
	if rest_hips_y < 0.1:
		rest_hips_y = 0.665896
	
	var sample_bone: String = skeleton.get_bone_name(0)
	var target_prefix: String = "mixamorig_"
	if sample_bone.begins_with("mixamorig1_"):
		target_prefix = "mixamorig1_"
	elif sample_bone.begins_with("mixamorig_"):
		target_prefix = "mixamorig_"
	
	var prefixes_to_check: Array[String] = ["mixamorig1_", "mixamorig_", "mixamorig1:", "mixamorig:"]
	
	for lib_name in animation_player.get_animation_library_list():
		var orig_lib: AnimationLibrary = animation_player.get_animation_library(lib_name)
		if not orig_lib:
			continue
		var new_lib := AnimationLibrary.new()
		for anim_name in orig_lib.get_animation_list():
			var orig_anim: Animation = orig_lib.get_animation(anim_name)
			if not orig_anim:
				continue
			# Duplicate so shared resources (like slow_run.anim on Roy) are never modified
			var dup_anim: Animation = orig_anim.duplicate()
			var lower_name := String(anim_name).to_lower()
			if lower_name.contains("crouch_to_up") or lower_name.contains("jump"):
				dup_anim.loop_mode = Animation.LOOP_NONE
			else:
				dup_anim.loop_mode = Animation.LOOP_LINEAR
			
			# Check if this animation was imported at centimeter scale (like slow_run.anim from Roy)
			var is_cm_scale_anim: bool = false
			for t in range(dup_anim.get_track_count()):
				var p_str := String(dup_anim.track_get_path(t))
				if p_str.ends_with("Hips") and dup_anim.track_get_type(t) == Animation.TYPE_POSITION_3D:
					if dup_anim.track_get_key_count(t) > 0:
						var first_pos: Vector3 = dup_anim.track_get_key_value(t, 0)
						if absf(first_pos.y) < 0.1:
							is_cm_scale_anim = true
					break
			
			# Remap bone prefixes and fix Hips root motion / scale
			var tracks_to_remove: Array[int] = []
			for t in range(dup_anim.get_track_count()):
				var path_str := String(dup_anim.track_get_path(t))
				var changed := false
				for p in prefixes_to_check:
					if p != target_prefix and path_str.contains(p):
						path_str = path_str.replace(p, target_prefix)
						changed = true
				if changed:
					dup_anim.track_set_path(t, NodePath(path_str))
				
				var t_type := dup_anim.track_get_type(t)
				if path_str.ends_with("Hips") and t_type == Animation.TYPE_POSITION_3D:
					var key_count := dup_anim.track_get_key_count(t)
					if key_count > 0:
						var base_pos: Vector3 = dup_anim.track_get_key_value(t, 0)
						var scale_mult: float = (rest_hips_y / maxf(0.001, base_pos.y)) if is_cm_scale_anim else 1.0
						for k in range(key_count):
							var v: Vector3 = dup_anim.track_get_key_value(t, k)
							var locked_y: float = (rest_hips_y + (v.y - base_pos.y) * scale_mult) if is_cm_scale_anim else v.y
							dup_anim.track_set_key_value(t, k, Vector3(0.0, locked_y, 0.0))
				elif is_cm_scale_anim and (t_type == Animation.TYPE_POSITION_3D or t_type == Animation.TYPE_SCALE_3D):
					# Remove centimeter-scale bone translations/scales on non-Hips bones so Jessica keeps her rest bone lengths
					tracks_to_remove.append(t)
			
			# Remove in reverse index order
			tracks_to_remove.reverse()
			for idx in tracks_to_remove:
				dup_anim.remove_track(idx)
			
			new_lib.add_animation(anim_name, dup_anim)
		
		animation_player.remove_animation_library(lib_name)
		animation_player.add_animation_library(lib_name, new_lib)

func _update_collision_exceptions() -> void:
	var roy := _find_roy()
	if is_instance_valid(roy):
		add_collision_exception_with(roy)
	for e in get_tree().get_nodes_in_group("enemies"):
		if e is PhysicsBody3D and is_instance_valid(e):
			add_collision_exception_with(e)
			e.add_collision_exception_with(self)

func _setup_as_npc_companion() -> void:
	# Disable Jessica's internal camera and hotbar so Roy remains the active player
	if camera_mount:
		var cam := camera_mount.find_child("Camera3D", true, false) as Camera3D
		if cam:
			cam.current = false
			cam.queue_free()
	if hotbar_ui:
		hotbar_ui.visible = false
	
	overhead_label = Label3D.new()
	overhead_label.name = "JessicaNameLabel"
	overhead_label.text = "♥ Jessica (Trapped)" if is_caged else "♥ Jessica"
	overhead_label.font_size = 22
	overhead_label.pixel_size = 0.0020
	overhead_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	overhead_label.no_depth_test = true
	overhead_label.modulate = Color(1.0, 0.78, 0.90, 0.96)
	overhead_label.outline_size = 6
	overhead_label.outline_modulate = Color(0, 0, 0, 0.95)
	overhead_label.position = Vector3(0, 0.92, 0)
	add_child(overhead_label)
	
	_update_collision_exceptions()
	
	if animation_player and animation_player.has_animation("jessica/idle_2"):
		animation_player.play("jessica/idle_2", 0.2)

func set_rescued() -> void:
	is_caged = false
	is_following_roy = true
	current_health = max_health
	_update_collision_exceptions()
	_update_overhead_label()

func take_damage(amount: float = 15.0, _hit_pos: Vector3 = Vector3.ZERO, _hit_normal: Vector3 = Vector3.UP) -> void:
	if is_dead or is_caged:
		return
	
	current_health = maxf(0.0, current_health - amount)
	_update_overhead_label()
	_flash_jessica_hit()
	
	var roy := _find_roy()
	if is_instance_valid(roy) and roy.has_method("show_tip_message"):
		roy.show_tip_message("⚠️ Jessica is taking damage! Protect her!", 2.0)
	
	if current_health <= 0.0:
		_die_companion()

func _flash_jessica_hit() -> void:
	if is_instance_valid(overhead_label):
		var orig_col := overhead_label.modulate
		overhead_label.modulate = Color(2.0, 0.25, 0.25, 1.0)
		var ft := create_tween()
		ft.tween_property(overhead_label, "modulate", orig_col, 0.28)
	
	if visuals:
		for m in visuals.find_children("*", "MeshInstance3D", true, false):
			if m is MeshInstance3D and m.mesh:
				for s in range(m.mesh.get_surface_count()):
					var mat := m.get_surface_override_material(s) as StandardMaterial3D
					if not mat:
						var orig_mat: Material = m.get_active_material(s)
						if orig_mat is StandardMaterial3D:
							mat = orig_mat.duplicate() as StandardMaterial3D
							m.set_surface_override_material(s, mat)
					if mat:
						mat.emission_enabled = true
						mat.emission = Color(1.0, 0.18, 0.18)
						mat.emission_energy_multiplier = 1.8
						var mt := create_tween()
						mt.tween_property(mat, "emission_energy_multiplier", 0.0, 0.22)

func _die_companion() -> void:
	if is_dead:
		return
	is_dead = true
	is_following_roy = false
	velocity = Vector3.ZERO
	_update_overhead_label()
	
	if animation_player:
		animation_player.stop()
		if animation_player.has_animation("jessica/crouch_idle"):
			animation_player.play("jessica/crouch_idle", 0.15)
	
	var roy := _find_roy()
	if is_instance_valid(roy) and roy.has_method("trigger_jessica_died"):
		roy.trigger_jessica_died()

func _update_overhead_label() -> void:
	if not is_instance_valid(overhead_label):
		return
	if is_caged:
		overhead_label.text = "♥ Jessica (Trapped)"
		overhead_label.modulate = Color(1.0, 0.78, 0.90, 0.96)
	elif is_dead:
		overhead_label.text = "✖ Jessica (Down)"
		overhead_label.modulate = Color(1.0, 0.18, 0.18, 1.0)
	else:
		var hp_pct: int = int(round((current_health / max_health) * 100.0))
		overhead_label.text = "♥ Jessica [%d%%]" % hp_pct
		if hp_pct > 60:
			overhead_label.modulate = Color(0.40, 1.0, 0.55, 0.98)
		elif hp_pct > 30:
			overhead_label.modulate = Color(1.0, 0.82, 0.22, 0.98)
		else:
			overhead_label.modulate = Color(1.0, 0.22, 0.22, 1.0)

func _find_roy() -> CharacterBody3D:
	if is_instance_valid(target_roy):
		return target_roy
	var scene := get_tree().current_scene
	if scene:
		target_roy = scene.find_child("Roy", true, false) as CharacterBody3D
	return target_roy

func _input(event: InputEvent) -> void:
	if is_npc_companion:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(deg_to_rad(-event.relative.x * sens_horizontal))
		visuals.rotate_y(deg_to_rad(event.relative.x * sens_horizontal))
		camera_mount.rotate_x(deg_to_rad(event.relative.y * sens_vertical))

func _physics_process(delta: float) -> void:
	if is_npc_companion:
		_process_companion_ai(delta)
		return
	#if Input.is_action_just_pressed("drop"):
		#drop_from_inventory()
	
	# ===== AGAR PLAYER PANI KE ANDAR HO (SWIMMING MODE) =====
	if is_swimming:
		var swim_input_dir := Input.get_vector("right", "left", "backward", "forward")
		var swim_direction := (transform.basis * Vector3(swim_input_dir.x, 0, swim_input_dir.y)).normalized()
		
		# === BUOYANCY (Scale-Adaptive) ===
		var cur_scale_y = global_basis.get_scale().y
		var player_height = 1.23 * cur_scale_y
		var target_y = water_surface_y - (0.66 * cur_scale_y)
		var current_y = global_position.y
		var y_diff = target_y - current_y
		
		# Terrain edges / zameen par aane par exit
		if is_on_floor() and global_position.y > water_surface_y - 0.08:
			exit_water()
			return
		
		if global_position.y > water_surface_y + (player_height * 0.5):
			exit_water()
			return
		
		# Buoyancy: smooth spring force
		var max_buoyancy = 4.2 * cur_scale_y
		var buoyancy_vel = clamp(y_diff * 8.0, -max_buoyancy, max_buoyancy)
		velocity.y = move_toward(velocity.y, buoyancy_vel, delta * 16.0 * cur_scale_y)
		
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
			
			visuals.position.y = move_toward(visuals.position.y, 0.12, delta * 5.0)
			
			if animation_player.current_animation != "jessica/swimming":
				animation_player.play("jessica/swimming", 0.2)
		else:
			# Idle in water - XZ velocity zero karo
			velocity.x = move_toward(velocity.x, 0, SWIM_SPEED * 3.0)
			velocity.z = move_toward(velocity.z, 0, SWIM_SPEED * 3.0)
			
			visuals.position.y = move_toward(visuals.position.y, 0.02, delta * 5.0)
			
			if animation_player.current_animation != "jessica/water_idle":
				animation_player.play("jessica/water_idle", 0.2)
		
		move_and_slide()
		if not is_on_floor() and global_position.y < target_y - 0.04:
			global_position.y = move_toward(global_position.y, target_y, delta * 1.8)
		return # Zameen wala code skip kar dega taake conflict na ho
	
	# ===== ZAMEEN WALI PHYSICS & ANIMATIONS (NORMAL MODE) =====
	if Input.is_action_pressed("crouch"):
		is_crouching = true
		SPEED = CROUCH_SPEED
		running = false
		if collision_shape_3d and collision_shape_3d.shape:
			collision_shape_3d.shape.height = 0.6
			collision_shape_3d.position.y = 0.3
	else:
		if is_crouching:
			is_crouching = false
			SPEED = WALK_SPEED
			if collision_shape_3d and collision_shape_3d.shape:
				collision_shape_3d.shape.height = 1.0
				collision_shape_3d.position.y = 0.5
			animation_player.play("jessica/crouch_to_up", 0.2)
			
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
			if animation_player.current_animation != "jessica/slow_run":
				animation_player.play("jessica/slow_run", 0.2)
		elif is_crouching:
			if animation_player.current_animation != "jessica/crouch_walking":
				animation_player.play("jessica/crouch_walking", 0.2)
		else:
			if animation_player.current_animation != "jessica/jessica_walk":
				animation_player.play("jessica/jessica_walk", 0.2)
				
		velocity.x = direction.x * SPEED
		velocity.z = direction.z * SPEED
	else:
		if is_crouching:
			if animation_player.current_animation != "jessica/crouch_idle":
				animation_player.play("jessica/crouch_idle", 0.2)
		else:
			if animation_player.current_animation != "jessica/idle_2":
				animation_player.play("jessica/idle_2", 0.2)

		velocity.x = move_toward(velocity.x, 0, WALK_SPEED)
		velocity.z = move_toward(velocity.z, 0, WALK_SPEED)

	move_and_slide()

func _process_companion_ai(delta: float) -> void:
	var roy := _find_roy()
	if not is_on_floor() and not is_swimming:
		velocity += get_gravity() * delta
	
	if is_caged or not is_following_roy or not is_instance_valid(roy):
		velocity.x = move_toward(velocity.x, 0.0, WALK_SPEED * 3.0)
		velocity.z = move_toward(velocity.z, 0.0, WALK_SPEED * 3.0)
		if is_instance_valid(roy):
			var look_dir := roy.global_position - global_position
			look_dir.y = 0.0
			if look_dir.length_squared() > 0.001 and visuals:
				var c_scale := visuals.scale
				var t_basis := Basis.looking_at(look_dir.normalized(), Vector3.UP).rotated(Vector3.UP, PI)
				var c_quat := visuals.global_transform.basis.get_rotation_quaternion()
				visuals.global_transform.basis = Basis(c_quat.slerp(t_basis.get_rotation_quaternion(), delta * 8.0))
				visuals.scale = c_scale
		if animation_player:
			var captive_anim := "jessica/crouch_idle" if is_caged else "jessica/idle_2"
			if animation_player.current_animation != captive_anim:
				animation_player.play(captive_anim, 0.25)
		move_and_slide()
		return
	
	var to_roy := roy.global_position - global_position
	var flat_to_roy := Vector3(to_roy.x, 0.0, to_roy.z)
	var dist := flat_to_roy.length()
	
	if is_swimming:
		var cur_scale_y = global_basis.get_scale().y
		var target_y = water_surface_y - (0.66 * cur_scale_y)
		var y_diff = target_y - global_position.y
		if is_on_floor() and global_position.y > water_surface_y - 0.08:
			exit_water()
			return
		var max_buoyancy = 4.2 * cur_scale_y
		velocity.y = move_toward(velocity.y, clamp(y_diff * 8.0, -max_buoyancy, max_buoyancy), delta * 16.0 * cur_scale_y)
		if dist > 1.7:
			var s_dir := flat_to_roy.normalized()
			_face_companion_dir(s_dir, delta * 12.0)
			velocity.x = s_dir.x * SWIM_SPEED
			velocity.z = s_dir.z * SWIM_SPEED
			visuals.position.y = move_toward(visuals.position.y, 0.12, delta * 5.0)
			if animation_player.current_animation != "jessica/swimming":
				animation_player.play("jessica/swimming", 0.2)
		else:
			velocity.x = move_toward(velocity.x, 0.0, SWIM_SPEED * 3.0)
			velocity.z = move_toward(velocity.z, 0.0, SWIM_SPEED * 3.0)
			visuals.position.y = move_toward(visuals.position.y, 0.02, delta * 5.0)
			if animation_player.current_animation != "jessica/water_idle":
				animation_player.play("jessica/water_idle", 0.2)
		move_and_slide()
		if not is_on_floor() and global_position.y < target_y - 0.04:
			global_position.y = move_toward(global_position.y, target_y, delta * 1.8)
		return
	
	# If Jessica gets stuck very far behind Roy (> 14m), bring her close behind Roy
	if dist > 14.0 and not is_swimming:
		global_position = roy.global_position + Vector3(-1.2, 0.25, -1.2)
		velocity = Vector3.ZERO
		return
	
	# Hysteresis for starting/stopping movement so she never rapid-toggles between walk and idle
	if not companion_is_moving and dist > 1.50:
		companion_is_moving = true
	elif companion_is_moving and dist < 0.95:
		companion_is_moving = false
		companion_is_running = false
	
	if companion_is_moving and dist > 0.05:
		var move_dir := flat_to_roy.normalized()
		if is_on_wall():
			var wn := get_wall_normal()
			wn.y = 0.0
			if wn.length_squared() > 0.01:
				move_dir = (move_dir.slide(wn.normalized()) + wn.normalized() * 0.35).normalized()
		
		_face_companion_dir(move_dir, delta * 12.0)
		
		var roy_running: bool = (roy.running if "running" in roy else false) and roy.velocity.length() > 0.4
		
		# Start running immediately if Roy is running or if she has fallen behind
		if not companion_is_running and (dist > 2.2 or (roy_running and dist > 1.05)):
			companion_is_running = true
		elif companion_is_running and dist < 1.30 and not roy_running:
			companion_is_running = false
		
		var target_spd: float = WALK_SPEED
		if companion_is_running:
			if dist > 4.5:
				target_spd = 3.3  # Catch-up sprint!
			elif dist > 2.4:
				target_spd = 2.85 # Matching Roy's running speed effortlessly!
			else:
				target_spd = RUN_SPEED
		
		velocity.x = move_toward(velocity.x, move_dir.x * target_spd, delta * 10.0)
		velocity.z = move_toward(velocity.z, move_dir.z * target_spd, delta * 10.0)
		
		var target_anim := "jessica/slow_run" if companion_is_running else "jessica/jessica_walk"
		var anim_spd: float = 1.25 if companion_is_running else 1.0
		if animation_player and (animation_player.current_animation != target_anim or not animation_player.is_playing()):
			animation_player.play(target_anim, 0.18, anim_spd)
	else:
		velocity.x = move_toward(velocity.x, 0.0, delta * 8.0)
		velocity.z = move_toward(velocity.z, 0.0, delta * 8.0)
		if animation_player and (animation_player.current_animation != "jessica/idle_2" or not animation_player.is_playing()):
			animation_player.play("jessica/idle_2", 0.22)
	
	move_and_slide()

func _face_companion_dir(dir: Vector3, weight: float) -> void:
	if not visuals or dir.length_squared() < 0.0001:
		return
	var current_scale := visuals.scale
	var target_basis := Basis.looking_at(dir, Vector3.UP).rotated(Vector3.UP, PI)
	var current_quat := visuals.global_transform.basis.get_rotation_quaternion()
	var target_quat := target_basis.get_rotation_quaternion()
	visuals.global_transform.basis = Basis(current_quat.slerp(target_quat, clampf(weight, 0.0, 1.0)))
	visuals.scale = current_scale

func enter_water(surface_y: float = 0.0) -> void:
	is_swimming = true
	water_surface_y = surface_y
	visuals.position.y = 0.0
	print("Player (Jessica) pani ke andar enter ho gayi - Swimming started! Surface Y: ", surface_y)

func exit_water() -> void:
	is_swimming = false
	water_surface_y = 0.0
	visuals.position.y = 0.0
	print("Player (Jessica) pani se bahar nikal gayi!")


## ===== INVENTORY FUNCTIONS =====
#func add_to_inventory(item_data: Dictionary) -> bool:
	#if hotbar_ui:
		#return hotbar_ui.add_item(item_data)
	#return false
#
#func drop_from_inventory() -> void:
	#if not hotbar_ui:
		#return
	#var dropped_data = hotbar_ui.drop_selected_item(1)
	#if not dropped_data.is_empty():
		#spawn_dropped_item(dropped_data)
#
#func spawn_dropped_item(item_data: Dictionary) -> void:
	#var item_scene = item_data.get("scene", null)
	#if not item_scene:
		#return
	#
	#var item_inst = item_scene.instantiate()
	#var current_scene = get_tree().current_scene
	#if current_scene:
		#current_scene.add_child(item_inst)
	#else:
		#get_parent().add_child(item_inst)
	#
	#var forward_dir = global_transform.basis.z
	#item_inst.global_position = global_position + (forward_dir * 0.5) + Vector3(0, 0.4, 0)
	#
	#if item_inst is RigidBody3D:
		#item_inst.freeze = false
		#var throw_impulse = (forward_dir * 0.5) + Vector3(0, 1.2, 0)
		#item_inst.apply_central_impulse(throw_impulse)
		#item_inst.angular_velocity = Vector3(randf_range(-2.0, 2.0), randf_range(-2.0, 2.0), randf_range(-2.0, 2.0))
	#print("Item dropped from inventory:", item_data.get("name", "Item"))
