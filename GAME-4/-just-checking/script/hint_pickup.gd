extends Node3D
class_name HintPickup

@export var hint_index: int = 1
@export var hint_title: String = "CLUE #1 — THE FOREST TRAIL"
@export_multiline var hint_body: String = "Looking for your precious Jessica?\nShe cried out your name as my puppets dragged her into the mist.\nFollow the trail past the wooden crates toward the river... if you dare."
@export var snap_to_ground_on_start: bool = true
@export var pickup_range: float = 2.2
@export var spin_speed: float = 1.15
@export var bob_height: float = 0.045
@export var bob_speed: float = 2.4

var player: Node3D = null
var visual_root: Node3D = null
var prompt_label: Label3D = null
var marker_label: Label3D = null
var omni_light: OmniLight3D = null
var halo_ring: MeshInstance3D = null
var halo_mat: StandardMaterial3D = null
var time_passed: float = 0.0
var base_y: float = 0.0
var is_read: bool = false

static var _cached_parchment_tex: Texture2D = null

static func get_clean_parchment_texture() -> Texture2D:
	if _cached_parchment_tex:
		return _cached_parchment_tex
	
	if ResourceLoader.exists("res://import/hint_paper_bg.png"):
		var loaded_tex := load("res://import/hint_paper_bg.png") as Texture2D
		if loaded_tex:
			var img := loaded_tex.get_image()
			if img:
				img = img.duplicate()
				if img.is_compressed():
					img.decompress()
				img.convert(Image.FORMAT_RGBA8)
				# Make any white / near-white outer background pixels transparent so torn edges look authentic
				for y in range(img.get_height()):
					for x in range(img.get_width()):
						var c := img.get_pixel(x, y)
						if c.r > 0.94 and c.g > 0.94 and c.b > 0.94:
							img.set_pixel(x, y, Color(c.r, c.g, c.b, 0.0))
				_cached_parchment_tex = ImageTexture.create_from_image(img)
				return _cached_parchment_tex
			_cached_parchment_tex = loaded_tex
			return _cached_parchment_tex
	return null

func _ready() -> void:
	visual_root = get_node_or_null("VisualRoot")
	if not visual_root:
		visual_root = Node3D.new()
		visual_root.name = "VisualRoot"
		add_child(visual_root)
	
	if snap_to_ground_on_start:
		_snap_to_ground()
	base_y = visual_root.position.y
	
	# Apply clean transparent-corner parchment texture to PaperMesh if present
	var paper_mesh_inst := visual_root.get_node_or_null("PropPivot/PaperMesh") as MeshInstance3D
	var clean_tex := get_clean_parchment_texture()
	if paper_mesh_inst and clean_tex:
		var mat := StandardMaterial3D.new()
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.albedo_texture = clean_tex
		mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		mat.roughness = 0.65
		mat.emission_enabled = true
		mat.emission = Color(0.85, 0.72, 0.45, 1.0)
		mat.emission_energy_multiplier = 0.22
		paper_mesh_inst.material_override = mat
	
	omni_light = get_node_or_null("OmniLight3D") as OmniLight3D
	halo_ring = get_node_or_null("HaloRing") as MeshInstance3D
	if halo_ring:
		halo_mat = StandardMaterial3D.new()
		halo_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		halo_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		halo_mat.albedo_color = Color(1.0, 0.80, 0.22, 0.65)
		halo_ring.material_override = halo_mat
	
	marker_label = get_node_or_null("MarkerLabel") as Label3D
	if marker_label:
		marker_label.text = "📜 Clue #%d" % hint_index
		marker_label.visible = false
	
	prompt_label = get_node_or_null("PromptLabel") as Label3D
	if prompt_label:
		prompt_label.text = "[E] Read Clue #%d" % hint_index
		prompt_label.visible = false

func _snap_to_ground() -> void:
	var space_state := get_world_3d().direct_space_state
	if not space_state:
		return
	var ray_from := global_position + Vector3(0.0, 5.0, 0.0)
	var ray_to := global_position + Vector3(0.0, -6.0, 0.0)
	var query := PhysicsRayQueryParameters3D.create(ray_from, ray_to)
	var hit := space_state.intersect_ray(query)
	if hit and hit.has("position"):
		global_position.y = hit.position.y + 0.03

func _process(delta: float) -> void:
	time_passed += delta
	if visual_root:
		visual_root.rotate_y(spin_speed * delta)
		visual_root.position.y = base_y + sin(time_passed * bob_speed) * bob_height
	if halo_ring:
		var s: float = 1.0 + sin(time_passed * 3.8) * 0.08
		halo_ring.scale = Vector3(s, 1.0, s)
	
	if not is_instance_valid(player):
		var scene := get_tree().current_scene
		if scene:
			player = scene.find_child("Roy", true, false) as Node3D
	
	if is_instance_valid(player):
		var dist := global_position.distance_to(player.global_position)
		if dist <= pickup_range:
			if prompt_label:
				prompt_label.visible = true
			if marker_label:
				marker_label.visible = false
			if Input.is_action_just_pressed("interact"):
				var roy_locked: bool = ("dialogue_locked" in player and player.dialogue_locked)
				if not roy_locked:
					_open_hint()
		else:
			if prompt_label:
				prompt_label.visible = false
			if marker_label:
				marker_label.visible = (dist <= 13.5 and not is_read)

func _open_hint() -> void:
	is_read = true
	if prompt_label:
		prompt_label.text = "[E] Read Clue #%d Again" % hint_index
		prompt_label.modulate = Color(0.55, 1.0, 0.65, 1.0)
	if halo_mat:
		halo_mat.albedo_color = Color(0.35, 0.95, 0.50, 0.45)
	if omni_light:
		omni_light.light_color = Color(0.4, 0.95, 0.55, 1.0)
		omni_light.light_energy = 0.85
	
	var sqm := get_tree().current_scene.find_child("StoryQuestManager", true, false)
	if sqm and sqm.has_method("open_hint_reader"):
		sqm.open_hint_reader(hint_index, hint_title, hint_body)
