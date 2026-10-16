@tool
extends SceneTree

func _init():
	var walk = load("res://animations/jessica_walk.anim")
	var run = load("res://animations/slow_run.anim")
	print("jessica_walk loop_mode: ", walk.loop_mode if walk else "null")
	print("slow_run loop_mode: ", run.loop_mode if run else "null")
	quit()
