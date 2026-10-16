extends RigidBody3D

@export var max_health: float = 100.0
var current_health: float = 100.0
var is_destroyed := false

@onready var mesh_instance: MeshInstance3D = $MeshInstance3D
@onready var collision_shape: CollisionShape3D = $CollisionShape3D

const WOOD_DEBRIS_COUNT = 6

func _ready() -> void:
	$"../AudioStreamPlayer2D".play()
	current_health = max_health

func take_damage(amount: float, hit_position: Vector3 = Vector3.ZERO, hit_normal: Vector3 = Vector3.UP) -> void:
	if is_destroyed:
		return
	
	current_health -= amount
	
	# Visual hit flash (brief red tint)
	if mesh_instance:
		var mat = mesh_instance.get_active_material(0)
		if mat is StandardMaterial3D:
			var orig_color = mat.albedo_color
			var t = create_tween()
			t.tween_property(mat, "albedo_color", Color(1.5, 0.4, 0.3), 0.05)
			t.tween_property(mat, "albedo_color", orig_color, 0.1)
	
	if current_health <= 0.0:
		destroy(hit_normal)

func destroy(hit_normal: Vector3) -> void:
	if is_destroyed or not is_inside_tree():
		return
	is_destroyed = true
	
	var parent_scene = get_parent()
	var box_pos = global_position # Cache before queue_free
	
	# Spawn small splinter debris
	if parent_scene:
		for i in range(WOOD_DEBRIS_COUNT):
			var piece = RigidBody3D.new()
			piece.mass = 1.5
			var col = CollisionShape3D.new()
			var box_s = BoxShape3D.new()
			var sz = randf_range(0.12, 0.22)
			box_s.size = Vector3(sz, sz, sz)
			col.shape = box_s
			piece.add_child(col)
			
			var m = MeshInstance3D.new()
			var bm = BoxMesh.new()
			bm.size = box_s.size
			var b_mat = StandardMaterial3D.new()
			b_mat.albedo_color = Color(0.48, 0.32, 0.18)
			bm.material = b_mat
			m.mesh = bm
			piece.add_child(m)
			
			# MUST add to scene tree FIRST before setting global_position!
			parent_scene.add_child(piece)
			piece.global_position = box_pos + Vector3(randf_range(-0.25, 0.25), randf_range(0.1, 0.4), randf_range(-0.25, 0.25))
			
			var impulse = (hit_normal + Vector3(randf_range(-0.8, 0.8), randf_range(0.5, 1.5), randf_range(-0.8, 0.8))).normalized() * randf_range(3.0, 6.0)
			piece.apply_central_impulse(impulse)
			
			# Auto-clean debris after 3s
			var dt = piece.create_tween()
			dt.tween_interval(2.5)
			dt.tween_property(m, "transparency", 1.0, 0.5)
			dt.tween_callback(piece.queue_free)
	
	queue_free()
