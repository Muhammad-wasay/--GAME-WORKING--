extends Node3D

# Simple luminous tracer beam from start_pos to end_pos
func init_tracer(from_pos: Vector3, to_pos: Vector3) -> void:
	global_position = from_pos
	look_at(to_pos, Vector3.UP)
	var dist = from_pos.distance_to(to_pos)
	$MeshInstance3D.scale.z = dist
	$MeshInstance3D.position.z = -dist * 0.5
	
	var tween = create_tween()
	tween.tween_property($MeshInstance3D, "transparency", 1.0, 0.08)
	tween.tween_callback(queue_free)
