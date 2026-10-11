extends CharacterBody3D


const SPEED = 5.0
const JUMP_VELOCITY = 4.5

@export var toon_material: Material

func apply_toon_to_children(node: Node) -> void:
	for child in node.get_children():
		if child is MeshInstance3D:
			child.material_override = toon_material
		
		if child.get_child_count() > 0:
			apply_toon_to_children(child)

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	apply_toon_to_children(self)
func _physics_process(delta: float) -> void:
	# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Handle jump.
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	# Get the input direction and handle the movement/deceleration.
	# As good practice, you should replace UI actions with custom gameplay actions.
	var input_dir := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	if direction:
		velocity.x = direction.x * SPEED
		velocity.z = direction.z * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.z = move_toward(velocity.z, 0, SPEED)

	move_and_slide()
