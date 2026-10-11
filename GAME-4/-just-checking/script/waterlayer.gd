extends Node3D

func _ready() -> void:
	pass

func _process(_delta: float) -> void:
	pass

func _on_watervolume_body_entered(body: Node3D) -> void:
	if body is CharacterBody3D:
		print("Player pani mein enter ho gaya!")
		if body.has_method("enter_water"):
			# Water surface ki Y position pass karo
			# Node3D ka global_position.y water ke surface ke paas hogi
			var surface_y = global_position.y
			body.enter_water(surface_y)

func _on_watervolume_body_exited(body: Node3D) -> void:
	if body is CharacterBody3D:
		print("Player pani se bahar nikal gaya!")
		# Agar player ki script mein exit_water function hai toh usay call kar do
		if body.has_method("exit_water"):
			body.exit_water()
