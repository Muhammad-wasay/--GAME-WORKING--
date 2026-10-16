@tool
extends SceneTree

func _init():
	var scn = load("res://scene/Roy.tscn")
	var inst = scn.instantiate()
	var person = inst.get_node("visuals/person")
	for c in person.get_children():
		print("person child: ", c.name, " (", c.get_class(), ")")
		for cc in c.get_children():
			print("  grandchild: ", cc.name, " (", cc.get_class(), ")")
	quit()
