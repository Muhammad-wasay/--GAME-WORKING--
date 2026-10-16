@tool
extends SceneTree

func _init():
	var scn = load("res://import/models/gun/fbx/pistolidel.fbx")
	var inst = scn.instantiate()
	pr(inst, 0)
	quit()

func pr(n: Node, ind: int):
	var sp = "  ".repeat(ind)
	var extra = ""
	if n is Node3D:
		extra = " pos=" + str(n.position) + " rot=" + str(n.rotation) + " sc=" + str(n.scale)
	print(sp, n.name, " (", n.get_class(), ")", extra)
	for c in n.get_children():
		pr(c, ind + 1)
