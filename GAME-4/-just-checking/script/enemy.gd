extends CharacterBody3D
class_name ForestEnemy

signal enemy_died(enemy: ForestEnemy)

enum State {
	IDLE,
	PATROL,
	CHASE,
	ATTACK,
	HIT,
	DEAD
}

@export_group("Identity & Stats")
@export var enemy_name: String = "Forest Minion"
@export var is_boss: bool = false
@export var max_health: float = 100.0
@export var walk_speed: float = 0.65
@export var run_speed: float = 1.15
@export var attack_damage: float = 12.0
@export var attack_range: float = 0.95
@export var attack_cooldown: float = 1.45
@export var detection_range: float = 8.5
@export var lose_interest_range: float = 18.0
@export var patrol_radius: float = 3.0

@export_group("Animation Names")
@export var anim_library: String = "enemy"
@export var idle_anim: String = "idle"
@export var walk_anim: String = "walk"
@export var run_anim: String = "run"
@export var hit_anim: String = "hit-reaction"
@export var attack_anims: PackedStringArray = [
	"attack-1",
	"attack-2",
	"attack-3"
]
@export var death_anims: PackedStringArray = [
	"falling-back-death",
	"falling-forward-death",
	"flying-death"
]

const ENEMY_HIT_VFX_SCENE = preload("res://vfx/enemy_hit_vfx.tscn")
const ENEMY_DEATH_VFX_SCENE = preload("res://vfx/enemy_death_vfx.tscn")
const APPLE_SCENE = preload("res://scene/apple.tscn")
const KEY_PICKUP_SCENE = preload("res://scene/key_pickup.tscn")
var SFX_ENEMY_HIT: AudioStream = null
var SFX_ENEMY_DEATH: AudioStream = null

var current_health: float = 100.0
var state: State = State.IDLE
var player: CharacterBody3D = null

var visuals: Node3D = null
var skeleton: Skeleton3D = null
var anim_player: AnimationPlayer = null
var mesh_instances: Array[MeshInstance3D] = []

var spawn_origin: Vector3 = Vector3.ZERO
var patrol_target: Vector3 = Vector3.ZERO
var state_timer: float = 0.0
var attack_timer: float = 0.0
var hit_stun_timer: float = 0.0
var is_attacking: bool = false
var attack_anim_timer: float = 0.0
var damage_dealt_in_attack: bool = false

var invulnerable: bool = false
var story_frozen: bool = false
var is_retreating: bool = false
var retreat_target: Vector3 = Vector3.ZERO
var retreat_waypoints: Array[Vector3] = []
var current_waypoint_index: int = 0
var is_emerging: bool = false

# Obstacle avoidance & navigation steering
var stuck_check_timer: float = 0.0
var last_stuck_check_pos: Vector3 = Vector3.ZERO
var unstuck_sidestep_dir: Vector3 = Vector3.ZERO
var unstuck_timer: float = 0.0

var hit_audio_3d: AudioStreamPlayer3D = null
var death_audio_3d: AudioStreamPlayer3D = null

# 3D Overhead Health Bar nodes
var ui_pivot: Node3D = null
var hp_fill_mesh: MeshInstance3D = null
var hp_fill_mat: StandardMaterial3D = null
var hp_bg_mat: StandardMaterial3D = null
var name_label_3d: Label3D = null
var bar_full_width: float = 0.95

func _ready() -> void:
	add_to_group("enemies")
	current_health = max_health
	spawn_origin = global_position
	patrol_target = spawn_origin
	state_timer = randf_range(1.2, 3.0)
	
	_discover_model_nodes()
	_remap_animations_to_skeleton()
	_DuplicateMaterialsForHitFlash()
	_setup_overhead_ui()
	_setup_enemy_audio()
	_play_anim(idle_anim, true)


func _discover_model_nodes() -> void:
	for child in get_children():
		if child is Node3D and not (child is CollisionShape3D):
			visuals = child
			break
	if not visuals:
		visuals = self
	
	skeleton = find_child("Skeleton3D", true, false) as Skeleton3D
	anim_player = find_child("AnimationPlayer", true, false) as AnimationPlayer
	if anim_player:
		anim_player.playback_default_blend_time = 0.18
	
	_collect_meshes(visuals)

func _collect_meshes(node: Node) -> void:
	for child in node.get_children():
		if child is MeshInstance3D:
			mesh_instances.append(child)
		if child.get_child_count() > 0:
			_collect_meshes(child)

func _remap_animations_to_skeleton() -> void:
	if not skeleton or not anim_player or skeleton.get_bone_count() == 0:
		return
	
	# Detect the bone prefix used by this character's Skeleton3D (e.g., "mixamorig_" on Boss vs "mixamorig1_" on Minions)
	var sample_bone: String = skeleton.get_bone_name(0)
	var target_prefix: String = ""
	if sample_bone.begins_with("mixamorig1_"):
		target_prefix = "mixamorig1_"
	elif sample_bone.begins_with("mixamorig_"):
		target_prefix = "mixamorig_"
	elif sample_bone.begins_with("mixamorig1:"):
		target_prefix = "mixamorig1:"
	elif sample_bone.begins_with("mixamorig:"):
		target_prefix = "mixamorig:"
	
	if target_prefix == "":
		return
	
	var prefixes_to_check: Array[String] = ["mixamorig1_", "mixamorig_", "mixamorig1:", "mixamorig:"]
	
	for lib_name in anim_player.get_animation_library_list():
		var orig_lib: AnimationLibrary = anim_player.get_animation_library(lib_name)
		if not orig_lib:
			continue
		var new_lib := AnimationLibrary.new()
		for anim_name in orig_lib.get_animation_list():
			var orig_anim: Animation = orig_lib.get_animation(anim_name)
			if not orig_anim:
				continue
			var dup_anim: Animation = orig_anim.duplicate()
			
			# Configure looping based on animation type
			var lower_name := String(anim_name).to_lower()
			if lower_name.contains("death") or lower_name.contains("hit") or lower_name.contains("attack"):
				dup_anim.loop_mode = Animation.LOOP_NONE
			else:
				dup_anim.loop_mode = Animation.LOOP_LINEAR
			
			# Fix track paths so they match this Skeleton3D's exact bone prefix
			var track_count := dup_anim.get_track_count()
			for t in range(track_count):
				var path_str := String(dup_anim.track_get_path(t))
				var changed := false
				for p in prefixes_to_check:
					if p != target_prefix and path_str.contains(p):
						path_str = path_str.replace(p, target_prefix)
						changed = true
				if changed:
					dup_anim.track_set_path(t, NodePath(path_str))
				
				# Keep Hips horizontal X/Z in-place for walk/run/attack so CharacterBody3D controls movement smoothly
				if (lower_name.contains("walk") or lower_name.contains("run") or lower_name.contains("attack")) and path_str.ends_with("Hips") and dup_anim.track_get_type(t) == Animation.TYPE_POSITION_3D:
					var key_count := dup_anim.track_get_key_count(t)
					if key_count > 0:
						var base_pos: Vector3 = dup_anim.track_get_key_value(t, 0)
						for k in range(key_count):
							var v: Vector3 = dup_anim.track_get_key_value(t, k)
							dup_anim.track_set_key_value(t, k, Vector3(base_pos.x, v.y, base_pos.z))
			
			new_lib.add_animation(anim_name, dup_anim)
		
		anim_player.remove_animation_library(lib_name)
		anim_player.add_animation_library(lib_name, new_lib)

func _DuplicateMaterialsForHitFlash() -> void:
	for m in mesh_instances:
		if not m or not m.mesh:
			continue
		var surf_count := m.mesh.get_surface_count()
		for s in range(surf_count):
			var mat := m.get_active_material(s)
			if mat:
				m.set_surface_override_material(s, mat.duplicate())

func _setup_overhead_ui() -> void:
	ui_pivot = Node3D.new()
	ui_pivot.name = "OverheadUI"
	var top_y := 2.05 if is_boss else 1.92
	ui_pivot.position = Vector3(0, top_y, 0)
	add_child(ui_pivot)
	
	bar_full_width = 1.15 if is_boss else 0.82
	var bar_height := 0.10 if is_boss else 0.075
	
	# Background bar
	var bg_mesh_inst := MeshInstance3D.new()
	var bg_quad := QuadMesh.new()
	bg_quad.size = Vector2(bar_full_width + 0.04, bar_height + 0.03)
	hp_bg_mat = StandardMaterial3D.new()
	hp_bg_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	hp_bg_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	hp_bg_mat.albedo_color = Color(0.08, 0.05, 0.05, 0.88)
	hp_bg_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bg_quad.material = hp_bg_mat
	bg_mesh_inst.mesh = bg_quad
	ui_pivot.add_child(bg_mesh_inst)
	
	# Foreground HP fill bar
	hp_fill_mesh = MeshInstance3D.new()
	var fill_quad := QuadMesh.new()
	fill_quad.size = Vector2(bar_full_width, bar_height)
	hp_fill_mat = StandardMaterial3D.new()
	hp_fill_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	hp_fill_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	hp_fill_mat.no_depth_test = true
	hp_fill_mat.albedo_color = Color(0.95, 0.18, 0.12, 1.0) if is_boss else Color(0.9, 0.28, 0.18, 1.0)
	fill_quad.material = hp_fill_mat
	hp_fill_mesh.mesh = fill_quad
	hp_fill_mesh.position = Vector3(0, 0, 0.01)
	ui_pivot.add_child(hp_fill_mesh)
	
	# Name label above HP bar
	name_label_3d = Label3D.new()
	name_label_3d.text = ("★ " + enemy_name + " ★") if is_boss else enemy_name
	name_label_3d.font_size = 38 if is_boss else 28
	name_label_3d.pixel_size = 0.0035
	name_label_3d.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	name_label_3d.no_depth_test = true
	name_label_3d.modulate = Color(1.0, 0.82, 0.25, 1.0) if is_boss else Color(0.95, 0.9, 0.85, 0.92)
	name_label_3d.outline_size = 10
	name_label_3d.outline_modulate = Color(0, 0, 0, 0.95)
	name_label_3d.position = Vector3(0, bar_height + 0.11, 0)
	ui_pivot.add_child(name_label_3d)

func _update_overhead_ui() -> void:
	if not hp_fill_mesh:
		return
	var ratio := clampf(current_health / maxf(1.0, max_health), 0.0, 1.0)
	var quad := hp_fill_mesh.mesh as QuadMesh
	if quad:
		quad.size.x = maxf(0.001, bar_full_width * ratio)
	if hp_fill_mat:
		if ratio > 0.5:
			hp_fill_mat.albedo_color = Color(0.92, 0.22, 0.15) if is_boss else Color(0.88, 0.3, 0.18)
		elif ratio > 0.25:
			hp_fill_mat.albedo_color = Color(1.0, 0.55, 0.12)
		else:
			hp_fill_mat.albedo_color = Color(1.0, 0.1, 0.1)

func _find_player() -> CharacterBody3D:
	if is_instance_valid(player):
		return player
	var scene := get_tree().current_scene
	if scene:
		var roy := scene.find_child("Roy", true, false) as CharacterBody3D
		if roy:
			player = roy
			return player
	return null

func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		if not is_on_floor():
			velocity += get_gravity() * delta
			move_and_slide()
		return
	
	# Void fall-through safety: If an enemy clips through the terrain or falls into void
	if global_position.y < -2.5:
		take_damage(9999.0)
		return
	
	if is_emerging:
		return
	
	if is_retreating:
		if not is_on_floor():
			velocity += get_gravity() * delta
		
		var active_target := retreat_target
		if current_waypoint_index < retreat_waypoints.size():
			active_target = retreat_waypoints[current_waypoint_index]
			
		var to_target := active_target - global_position
		to_target.y = 0.0
		var dist_to_active := to_target.length()
		
		# If near current waypoint, advance to next or finish
		if dist_to_active < 1.75:
			current_waypoint_index += 1
			if current_waypoint_index >= retreat_waypoints.size():
				is_retreating = false
				story_frozen = true
				velocity = Vector3.ZERO
				var p := _find_player()
				if is_instance_valid(p):
					var face_p := p.global_position - global_position
					face_p.y = 0.0
					if face_p.length_squared() > 0.001:
						_face_direction(face_p.normalized(), 1.0)
				_play_anim(idle_anim, true)
				return
			else:
				active_target = retreat_waypoints[current_waypoint_index]
				to_target = active_target - global_position
				to_target.y = 0.0
		
		var raw_dir := to_target.normalized()
		_update_stuck_detector(delta, run_speed * 2.2, raw_dir)
		var steer_dir := _calculate_nav_steering(raw_dir, 2.4)
		
		_face_direction(steer_dir, delta * 12.0)
		velocity.x = steer_dir.x * (run_speed * 2.1)
		velocity.z = steer_dir.z * (run_speed * 2.1)
		_play_anim(run_anim, false, 1.35)
		move_and_slide()
		return
	
	if story_frozen:
		velocity.x = move_toward(velocity.x, 0.0, delta * 8.0)
		velocity.z = move_toward(velocity.z, 0.0, delta * 8.0)
		if not is_on_floor():
			velocity += get_gravity() * delta
		var p := _find_player()
		if is_instance_valid(p):
			var face_p := p.global_position - global_position
			face_p.y = 0.0
			if face_p.length_squared() > 0.001:
				_face_direction(face_p.normalized(), delta * 8.0)
		_play_anim(idle_anim, false)
		move_and_slide()
		return
	
	if not is_on_floor():
		velocity += get_gravity() * delta
	
	if attack_timer > 0.0:
		attack_timer -= delta
	
	var target_player := _find_player()
	var dist_to_player := INF
	if is_instance_valid(target_player):
		dist_to_player = global_position.distance_to(target_player.global_position)
	
	match state:
		State.HIT:
			hit_stun_timer -= delta
			velocity.x = move_toward(velocity.x, 0.0, delta * 6.0)
			velocity.z = move_toward(velocity.z, 0.0, delta * 6.0)
			if hit_stun_timer <= 0.0:
				is_attacking = false
				state = State.CHASE
				_play_anim(run_anim, true)
		
		State.IDLE:
			velocity.x = move_toward(velocity.x, 0.0, delta * 5.0)
			velocity.z = move_toward(velocity.z, 0.0, delta * 5.0)
			_play_anim(idle_anim, false)
			
			if dist_to_player <= detection_range:
				alert_group()
				return
			
			state_timer -= delta
			if state_timer <= 0.0:
				_pick_new_patrol_point()
				state = State.PATROL
				state_timer = randf_range(3.0, 5.5)
				_play_anim(walk_anim, true)
		
		State.PATROL:
			if dist_to_player <= detection_range:
				alert_group()
				return
			
			state_timer -= delta
			var to_patrol := patrol_target - global_position
			to_patrol.y = 0.0
			if to_patrol.length() < 0.35 or state_timer <= 0.0:
				state = State.IDLE
				state_timer = randf_range(2.0, 4.0)
				_play_anim(idle_anim, true)
			else:
				var raw_dir := to_patrol.normalized()
				var steer_dir := _calculate_nav_steering(raw_dir, 1.5)
				_face_direction(steer_dir, delta * 7.0)
				velocity.x = steer_dir.x * walk_speed
				velocity.z = steer_dir.z * walk_speed
				_play_anim(walk_anim, false)
		
		State.CHASE:
			if not is_instance_valid(target_player) or dist_to_player > lose_interest_range:
				state = State.IDLE
				state_timer = 2.0
				_play_anim(idle_anim, true)
				return
			
			if dist_to_player <= attack_range:
				state = State.ATTACK
				velocity.x = 0.0
				velocity.z = 0.0
				return
			
			var to_player := target_player.global_position - global_position
			to_player.y = 0.0
			if to_player.length_squared() > 0.001:
				var raw_dir := to_player.normalized()
				_update_stuck_detector(delta, run_speed, raw_dir)
				var steer_dir := _calculate_nav_steering(raw_dir, 1.9)
				_face_direction(steer_dir, delta * 10.0)
				velocity.x = steer_dir.x * run_speed
				velocity.z = steer_dir.z * run_speed
			_play_anim(run_anim, false)
		
		State.ATTACK:
			velocity.x = move_toward(velocity.x, 0.0, delta * 8.0)
			velocity.z = move_toward(velocity.z, 0.0, delta * 8.0)
			
			if not is_instance_valid(target_player):
				is_attacking = false
				state = State.IDLE
				return
			
			var to_player := target_player.global_position - global_position
			to_player.y = 0.0
			if to_player.length_squared() > 0.001:
				_face_direction(to_player.normalized(), delta * 12.0)
			
			if is_attacking:
				attack_anim_timer -= delta
				# Deal damage mid-swing (when 55% of the attack animation has elapsed)
				if not damage_dealt_in_attack and attack_anim_timer <= 0.45:
					damage_dealt_in_attack = true
					if is_instance_valid(target_player) and global_position.distance_to(target_player.global_position) <= attack_range * 1.45:
						if target_player.has_method("take_damage"):
							target_player.take_damage(attack_damage)
						var target_scale: float = target_player.global_basis.get_scale().y if "global_basis" in target_player else 0.3
						var hit_center := target_player.global_position + Vector3(0.0, 0.95 * target_scale, 0.0)
						_spawn_hit_vfx(hit_center, (target_player.global_position - global_position).normalized())
				
				if attack_anim_timer <= 0.0:
					is_attacking = false
					if dist_to_player > attack_range * 1.2:
						state = State.CHASE
						_play_anim(run_anim, true)
					else:
						_play_anim(idle_anim, true)
				return
			
			if dist_to_player > attack_range * 1.25:
				state = State.CHASE
				_play_anim(run_anim, true)
				return
			
			if attack_timer <= 0.0:
				_perform_melee_attack(target_player)
			else:
				_play_anim(idle_anim, false)
	
	move_and_slide()

func _pick_new_patrol_point() -> void:
	var angle := randf() * TAU
	var radius := randf_range(1.2, patrol_radius)
	patrol_target = spawn_origin + Vector3(cos(angle) * radius, 0.0, sin(angle) * radius)

func _face_direction(dir: Vector3, weight: float) -> void:
	if not visuals or dir.length_squared() < 0.0001:
		return
	var cur_scale := visuals.scale
	var target_basis := Basis.looking_at(-dir, Vector3.UP)
	var cur_quat := visuals.global_transform.basis.get_rotation_quaternion()
	var target_quat := target_basis.get_rotation_quaternion()
	visuals.global_transform.basis = Basis(cur_quat.slerp(target_quat, clampf(weight, 0.0, 1.0)))
	visuals.scale = cur_scale

func _perform_melee_attack(_target: CharacterBody3D) -> void:
	is_attacking = true
	damage_dealt_in_attack = false
	
	# Pick one of the attack animations (e.g. attack-1, attack-2, attack-3)
	var chosen_attack := "attack-1"
	if attack_anims.size() > 0:
		chosen_attack = attack_anims[randi() % attack_anims.size()]
	
	if anim_player:
		anim_player.stop()
	var anim_len := _get_anim_length(chosen_attack)
	var play_speed := 1.25
	attack_anim_timer = maxf(0.65, anim_len / play_speed)
	attack_timer = attack_anim_timer + 0.35
	_play_anim(chosen_attack, true, play_speed)

func _get_anim_length(anim_short_name: String) -> float:
	if not anim_player:
		return 1.0
	var full_name := anim_library + "/" + anim_short_name if anim_library != "" else anim_short_name
	if anim_player.has_animation(full_name):
		var a := anim_player.get_animation(full_name)
		if a:
			return a.length
	for lib in anim_player.get_animation_library_list():
		var candidate := (String(lib) + "/" + anim_short_name) if String(lib) != "" else anim_short_name
		if anim_player.has_animation(candidate):
			var a := anim_player.get_animation(candidate)
			if a:
				return a.length
	return 1.1

func alert_group() -> void:
	if state == State.DEAD or story_frozen or is_retreating:
		return
	if state == State.IDLE or state == State.PATROL:
		state = State.CHASE
		_play_anim(run_anim, true)
	
	for node in get_tree().get_nodes_in_group("enemies"):
		if node is ForestEnemy and node != self and node.state != State.DEAD and not node.story_frozen and not node.is_retreating:
			if node.global_position.distance_to(global_position) <= 16.0:
				if node.state == State.IDLE or node.state == State.PATROL:
					node.state = State.CHASE
					node._play_anim(node.run_anim, true)

func take_damage(amount: float, hit_position: Vector3 = Vector3.ZERO, hit_normal: Vector3 = Vector3.UP) -> void:
	if state == State.DEAD:
		return
	
	if invulnerable or is_retreating:
		_flash_meshes_on_hit()
		var p := _find_player()
		if is_instance_valid(p) and p.has_method("show_tip_message"):
			if is_retreating:
				p.show_tip_message("Follow the Boss to Jessica's Cage!", 2.5)
			else:
				p.show_tip_message("Boss is shielded! Defeat his Mannequin Minions first!", 2.5)
		return
	
	current_health = maxf(0.0, current_health - amount)
	_update_overhead_ui()
	
	if hit_audio_3d:
		hit_audio_3d.pitch_scale = randf_range(0.92, 1.08)
		hit_audio_3d.play()
	
	# 1. Spawn Toon Puff Hit VFX at bullet impact point
	var vfx_pos := hit_position if hit_position != Vector3.ZERO else (global_position + Vector3(0, 0.5, 0))
	_spawn_hit_vfx(vfx_pos, hit_normal)
	
	# 2. Flash enemy mesh briefly
	_flash_meshes_on_hit()
	
	# 3. Alert Boss and Chaheete
	alert_group()
	
	# 4. Check Death vs Hit Reaction
	if current_health <= 0.0:
		_die(hit_normal)
	else:
		state = State.HIT
		is_attacking = false
		hit_stun_timer = 0.45
		
		var knock_dir := -hit_normal
		knock_dir.y = 0.0
		if knock_dir.length_squared() > 0.01:
			velocity = knock_dir.normalized() * (0.75 if is_boss else 1.35)
		
		if anim_player:
			anim_player.stop()
		_play_anim(hit_anim, true, 1.35)

func _spawn_hit_vfx(pos: Vector3, normal: Vector3) -> void:
	if not ENEMY_HIT_VFX_SCENE:
		return
	var vfx := ENEMY_HIT_VFX_SCENE.instantiate() as Node3D
	var root := get_tree().current_scene
	if root:
		root.add_child(vfx)
	else:
		get_parent().add_child(vfx)
	vfx.global_position = pos
	if normal.length_squared() > 0.01:
		var up_vec := Vector3.UP if absf(normal.y) < 0.9 else Vector3.FORWARD
		vfx.look_at(pos + normal, up_vec)

func _flash_meshes_on_hit() -> void:
	for m in mesh_instances:
		if not is_instance_valid(m) or not m.mesh:
			continue
		var surf_count := m.mesh.get_surface_count()
		for s in range(surf_count):
			var mat := m.get_surface_override_material(s) as StandardMaterial3D
			if mat:
				var t := create_tween()
				mat.emission_enabled = true
				mat.emission = Color(0.98, 0.85, 0.55)
				mat.emission_energy_multiplier = 1.6
				t.tween_property(mat, "emission_energy_multiplier", 0.0, 0.14)

func _die(_hit_normal: Vector3) -> void:
	if state == State.DEAD:
		return
	state = State.DEAD
	is_attacking = false
	velocity = Vector3.ZERO
	
	if death_audio_3d:
		death_audio_3d.pitch_scale = randf_range(0.92, 1.05)
		death_audio_3d.play()
	
	var col := get_node_or_null("CollisionShape3D") as CollisionShape3D
	if col:
		col.set_deferred("disabled", true)
	
	if ui_pivot:
		ui_pivot.visible = false
	
	# Pick 1 of the 3 death animations randomly!
	var chosen_death: String = "falling-back-death"
	if death_anims.size() > 0:
		chosen_death = death_anims[randi() % death_anims.size()]
	
	if anim_player:
		anim_player.stop()
	_play_anim(chosen_death, true, 1.0)
	
	# Spawn Toon Cloud Poof VFX immediately + big cloud poof when body hits ground
	_spawn_death_vfx(global_position + Vector3(0, 0.25, 0))
	
	# Drop Key immediately when Boss dies so player doesn't wait
	if is_boss and KEY_PICKUP_SCENE and get_tree().current_scene:
		var key_drop := KEY_PICKUP_SCENE.instantiate() as Node3D
		get_tree().current_scene.add_child(key_drop)
		key_drop.global_position = global_position + Vector3(0, 0.05, 0)
	
	enemy_died.emit(self)
	
	var death_tween := create_tween()
	death_tween.tween_interval(0.70)
	death_tween.tween_callback(func():
		_spawn_death_vfx(global_position + Vector3(0, 0.05, 0))
	)
	death_tween.tween_interval(2.5)
	death_tween.tween_callback(func():
		# Final Toon Cloud Poof right as the body vanishes!
		_spawn_death_vfx(global_position + Vector3(0, 0.15, 0))
		if is_boss and APPLE_SCENE and get_tree().current_scene:
			var reward := APPLE_SCENE.instantiate() as Node3D
			get_tree().current_scene.add_child(reward)
			reward.scale = Vector3(0.05, 0.05, 0.05)
			reward.global_position = global_position + Vector3(0.5, 0.45, 0)
		
		var sink := create_tween()
		sink.tween_property(self, "scale", Vector3(0.01, 0.01, 0.01), 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		sink.tween_callback(queue_free)
	)

func _spawn_death_vfx(pos: Vector3) -> void:
	if not ENEMY_DEATH_VFX_SCENE:
		return
	var vfx := ENEMY_DEATH_VFX_SCENE.instantiate() as Node3D
	var root := get_tree().current_scene
	if root:
		root.add_child(vfx)
	else:
		get_parent().add_child(vfx)
	vfx.global_position = pos
	if is_boss:
		vfx.scale = Vector3(0.85, 0.85, 0.85)
	else:
		vfx.scale = Vector3(0.45, 0.45, 0.45)

func _play_anim(anim_short_name: String, force_restart: bool = false, custom_speed: float = 1.0) -> void:
	if not anim_player or anim_short_name == "":
		return
	
	var full_name := anim_library + "/" + anim_short_name if anim_library != "" else anim_short_name
	if not anim_player.has_animation(full_name):
		var found := ""
		for lib in anim_player.get_animation_library_list():
			var candidate := (String(lib) + "/" + anim_short_name) if String(lib) != "" else anim_short_name
			if anim_player.has_animation(candidate):
				found = candidate
				break
		if found == "":
			return
		full_name = found
	
	if not force_restart and anim_player.current_animation == full_name and anim_player.is_playing():
		return
	
	anim_player.play(full_name, 0.18, custom_speed)

func _setup_enemy_audio() -> void:
	if ResourceLoader.exists("res://import/sound/enemy/getting-hit (2).mp3"):
		SFX_ENEMY_HIT = load("res://import/sound/enemy/getting-hit (2).mp3")
	if ResourceLoader.exists("res://import/sound/enemy/enemy-death-sound.mp3"):
		SFX_ENEMY_DEATH = load("res://import/sound/enemy/enemy-death-sound.mp3")

	if SFX_ENEMY_HIT:
		hit_audio_3d = AudioStreamPlayer3D.new()
		hit_audio_3d.name = "EnemyHitAudio3D"
		hit_audio_3d.stream = SFX_ENEMY_HIT
		hit_audio_3d.unit_size = 6.0
		hit_audio_3d.max_distance = 28.0
		add_child(hit_audio_3d)
	
	if SFX_ENEMY_DEATH:
		death_audio_3d = AudioStreamPlayer3D.new()
		death_audio_3d.name = "EnemyDeathAudio3D"
		death_audio_3d.stream = SFX_ENEMY_DEATH
		death_audio_3d.unit_size = 7.0
		death_audio_3d.max_distance = 32.0
		add_child(death_audio_3d)

func retreat_to_position(target_pos: Vector3, waypoints: Array[Vector3] = []) -> void:
	story_frozen = false
	invulnerable = true
	is_retreating = true
	retreat_target = target_pos
	spawn_origin = target_pos
	
	if waypoints.is_empty():
		# Automatically generate intermediate safe waypoints along natural terrain
		var step1 := global_position.lerp(target_pos, 0.35) + Vector3(2.5, 0.0, 1.5)
		var step2 := global_position.lerp(target_pos, 0.70) - Vector3(1.5, 0.0, 1.2)
		retreat_waypoints = [step1, step2, target_pos]
	else:
		retreat_waypoints = waypoints
		
	current_waypoint_index = 0
	_play_anim(run_anim, true, 1.35)

func _is_water_or_pit(test_point: Vector3, space_state: PhysicsDirectSpaceState3D, exclude_list: Array[RID]) -> bool:
	var down_start := test_point + Vector3(0.0, 1.5, 0.0)
	var down_end := test_point + Vector3(0.0, -3.5, 0.0)
	var q_down := PhysicsRayQueryParameters3D.create(down_start, down_end)
	q_down.exclude = exclude_list
	var res_down := space_state.intersect_ray(q_down)
	if res_down.is_empty():
		return true # Cliff/void
	var ground_y: float = res_down.position.y
	# Water surface is ~0.0 to 0.2; terrain riverbed is < 0.45. Dry ground is >= 0.55!
	return ground_y < 0.46

func _calculate_nav_steering(desired_dir: Vector3, check_distance: float = 2.4) -> Vector3:
	if desired_dir.length_squared() < 0.001:
		return Vector3.ZERO
	desired_dir = desired_dir.normalized()
	
	# If currently executing an unstuck sidestep maneuver, prioritize it
	if unstuck_timer > 0.0 and unstuck_sidestep_dir.length_squared() > 0.001:
		return unstuck_sidestep_dir
		
	var space_state := get_world_3d().direct_space_state
	var ray_origin := global_position + Vector3(0.0, 0.55, 0.0)
	
	# Exclude self and player from obstacle raycast
	var exclude_list: Array[RID] = [get_rid()]
	if is_instance_valid(player):
		exclude_list.append(player.get_rid())
		
	# Check if desired direction leads straight into the river
	var check_ahead := global_position + desired_dir * 1.6
	var desired_is_water := _is_water_or_pit(check_ahead, space_state, exclude_list)
	
	var center_end := ray_origin + desired_dir * check_distance
	var query_center := PhysicsRayQueryParameters3D.create(ray_origin, center_end)
	query_center.exclude = exclude_list
	var hit_center := space_state.intersect_ray(query_center)
	
	if hit_center.is_empty() and not desired_is_water:
		# Path ahead is clear and dry! Check slight wall slide if touching collider
		if is_on_wall():
			var wn := get_wall_normal()
			wn.y = 0.0
			if wn.length_squared() > 0.01:
				return (desired_dir.slide(wn.normalized()) + wn.normalized() * 0.4).normalized()
		return desired_dir
		
	# Obstacle or river detected ahead! Test left and right angles to find open, dry ground
	var angles: Array[float] = [35.0, -35.0, 65.0, -65.0, 90.0, -90.0, 120.0, -120.0]
	var best_dir := desired_dir
	var best_clearance := -1.0
	
	for a in angles:
		var test_dir := desired_dir.rotated(Vector3.UP, deg_to_rad(a)).normalized()
		var candidate_pt := global_position + test_dir * 1.6
		if _is_water_or_pit(candidate_pt, space_state, exclude_list):
			continue # Reject river/water directions!
			
		var test_end := ray_origin + test_dir * check_distance
		var q := PhysicsRayQueryParameters3D.create(ray_origin, test_end)
		q.exclude = exclude_list
		var res := space_state.intersect_ray(q)
		if res.is_empty():
			# Found a completely open and dry direction!
			best_dir = test_dir
			break
		else:
			var dist: float = ray_origin.distance_to(res.position)
			if dist > best_clearance:
				best_clearance = dist
				best_dir = test_dir
				
	if is_on_wall():
		var wn := get_wall_normal()
		wn.y = 0.0
		if wn.length_squared() > 0.01:
			best_dir = (best_dir + wn.normalized() * 0.6).normalized()
			
	return best_dir

func enter_water(_surface_y: float = 0.0) -> void:
	# Enemies should not swim or stay in water! Bounce out towards dry land
	velocity.y = 5.5
	var to_dry := (Vector3(1.67, 0.85, 7.5) - global_position)
	to_dry.y = 0.0
	if to_dry.length_squared() > 0.01:
		velocity.x = to_dry.normalized().x * 3.5
		velocity.z = to_dry.normalized().z * 3.5

func _update_stuck_detector(delta: float, target_spd: float, intended_dir: Vector3) -> void:
	if target_spd <= 0.1:
		stuck_check_timer = 0.0
		return
	
	if unstuck_timer > 0.0:
		unstuck_timer -= delta
		if unstuck_timer <= 0.0:
			unstuck_sidestep_dir = Vector3.ZERO
		return
		
	stuck_check_timer += delta
	if stuck_check_timer >= 0.35:
		var moved_dist := global_position.distance_to(last_stuck_check_pos)
		# If enemy was trying to move fast but moved barely anything (< 0.12m)
		if moved_dist < 0.12:
			var perp := intended_dir.cross(Vector3.UP).normalized()
			unstuck_sidestep_dir = (perp if randf() > 0.5 else -perp).normalized()
			unstuck_timer = 0.55
		last_stuck_check_pos = global_position
		stuck_check_timer = 0.0

func emerge_from_ground(duration: float = 1.15) -> void:
	is_emerging = true
	var final_pos := global_position
	_spawn_death_vfx(final_pos + Vector3(0.0, 0.08, 0.0))
	_play_anim(idle_anim, true)
	
	# Keep the root CharacterBody3D safe on the floor so physics collider never penetrates the terrain!
	# Animate only the visual mesh node rising up from the dirt
	if visuals:
		var orig_vis_y := visuals.position.y
		visuals.position.y = orig_vis_y - 0.75
		var t := create_tween()
		t.tween_property(visuals, "position:y", orig_vis_y, duration).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		t.tween_callback(func():
			is_emerging = false
			state = State.CHASE
			_play_anim(run_anim, true)
		)
	else:
		is_emerging = false
		state = State.CHASE
		_play_anim(run_anim, true)

