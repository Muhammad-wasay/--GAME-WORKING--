@tool
extends SceneTree

func _init():
	var world = load("res://scene/world.tscn").instantiate()
	var terrain = world.get_node("Terrain")
	var waterlayer = terrain.get_node("waterlayer")
	var water_mesh = waterlayer.get_node("water")
	var watervolume = waterlayer.get_node("watervolume")
	var cs = watervolume.get_node("CollisionShape3D")
	
	print("waterlayer global_position: ", waterlayer.global_position)
	print("water_mesh global_position: ", water_mesh.global_position)
	print("watervolume global_position: ", watervolume.global_position)
	print("cs global_position: ", cs.global_position)
	if cs.shape is BoxShape3D:
		var top_y = cs.global_position.y + (cs.shape.size.y / 2.0)
		var bot_y = cs.global_position.y - (cs.shape.size.y / 2.0)
		print("Water volume top Y: ", top_y, " bottom Y: ", bot_y)
	
	quit()
