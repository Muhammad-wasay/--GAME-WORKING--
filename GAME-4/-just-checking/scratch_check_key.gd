@tool
extends SceneTree

func _init() -> void:
	var f := FileAccess.open("res://key_info.txt", FileAccess.WRITE)
	if ResourceLoader.exists("res://KEY.scn"):
		var scn: PackedScene = load("res://KEY.scn")
		var inst = scn.instantiate()
		f.store_line("KEY.scn instance: " + str(inst))
		_print_node(inst, 0, f)
	else:
		f.store_line("KEY.scn does not exist!")
	f.close()
	quit()

func _print_node(n: Node, indent: int, f: FileAccess) -> void:
	var prefix := "  ".repeat(indent)
	var extra := ""
	if n is Node3D:
		extra = " pos=" + str(n.position) + " scale=" + str(n.scale)
	if n is VisualInstance3D:
		extra += " aabb=" + str(n.get_aabb())
	f.store_line(prefix + n.name + " (" + n.get_class() + ")" + extra)
	for c in n.get_children():
		_print_node(c, indent + 1, f)
