@tool
extends SceneTree

func _init():
	print("Rendering 9mm pistol icon...")
	var vp = SubViewport.new()
	vp.size = Vector2i(256, 256)
	vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	
	var cam = Camera3D.new()
	cam.position = Vector3(0.15, 0.1, 0.3)
	cam.look_at(Vector3(0, 0, 0), Vector3.UP)
	vp.add_child(cam)
	
	var light = DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-35, 45, 0)
	light.light_energy = 1.2
	vp.add_child(light)
	
	var light2 = DirectionalLight3D.new()
	light2.rotation_degrees = Vector3(20, -135, 0)
	light2.light_energy = 0.6
	vp.add_child(light2)
	
	var gun = load("res://scene/equipped_pistol.tscn").instantiate()
	# Center it and scale up for icon
	gun.scale = Vector3(1.0, 1.0, 1.0)
	gun.rotation_degrees = Vector3(0, 75, 5)
	vp.add_child(gun)
	
	# Wait for frames to render
	for i in range(5):
		await process_frame
		
	var tex = vp.get_texture()
	var img = tex.get_image()
	img.save_png("c:/Users/hania/Downloads/LOST IN THE FOREST/--GAME-WORKING--/GAME-4/-just-checking/import/UI/gun_icon.png")
	print("Saved res://import/UI/gun_icon.png successfully!")
	quit()
