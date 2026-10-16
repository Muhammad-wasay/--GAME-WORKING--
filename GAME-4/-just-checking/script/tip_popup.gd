extends CanvasLayer
class_name TipPopup

# ===== TUTORIAL / TIP POPUP =====
# show_tip(title, body, image) se popup aata hai, ESC dabane par band hota hai.
# image optional hai (Texture2D) - baad mein picture tutorial ke liye use hoga.

const FONT = preload("res://import/font-text/ballad_of_dwight_frye/Ballad of Dwight Frye.ttf")

var panel: PanelContainer
var title_label: Label
var body_label: Label
var image_rect: TextureRect
var close_label: Label
var queue: Array = []
var tween: Tween = null

func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	
	panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(520, 0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.09, 0.06, 0.04, 0.92)
	style.border_color = Color(0.85, 0.65, 0.25, 1)
	style.set_border_width_all(3)
	style.set_corner_radius_all(10)
	style.content_margin_left = 28
	style.content_margin_right = 28
	style.content_margin_top = 20
	style.content_margin_bottom = 20
	panel.add_theme_stylebox_override("panel", style)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(panel)
	
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)
	
	title_label = _make_label(38, Color(1, 0.85, 0.4))
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title_label)
	
	image_rect = TextureRect.new()
	image_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image_rect.custom_minimum_size = Vector2(0, 220)
	image_rect.visible = false
	box.add_child(image_rect)
	
	body_label = _make_label(24, Color(0.95, 0.92, 0.85), false)
	body_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(body_label)
	
	close_label = _make_label(18, Color(0.7, 0.7, 0.7), false)
	close_label.text = "Press ESC to close"
	close_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(close_label)
	
	panel.modulate.a = 0.0
	panel.visible = false

func _make_label(size: int, color: Color, use_title_font: bool = true) -> Label:
	var l := Label.new()
	if use_title_font:
		l.add_theme_font_override("font", FONT)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	l.add_theme_constant_override("shadow_offset_x", 2)
	l.add_theme_constant_override("shadow_offset_y", 2)
	return l

func show_tip(title: String, body: String, image: Texture2D = null) -> void:
	queue.append({"title": title, "body": body, "image": image})
	if not panel.visible:
		_show_next()

func is_open() -> bool:
	return panel != null and panel.visible

func _show_next() -> void:
	if queue.is_empty():
		return
	var tip: Dictionary = queue.pop_front()
	title_label.text = tip["title"]
	body_label.text = tip["body"]
	image_rect.texture = tip["image"]
	image_rect.visible = tip["image"] != null
	panel.visible = true
	if tween and tween.is_valid():
		tween.kill()
	tween = create_tween()
	tween.tween_property(panel, "modulate:a", 1.0, 0.3)

func close_tip() -> void:
	if not panel.visible:
		return
	if tween and tween.is_valid():
		tween.kill()
	tween = create_tween()
	tween.tween_property(panel, "modulate:a", 0.0, 0.2)
	tween.tween_callback(func():
		panel.visible = false
		_show_next())

func _input(event: InputEvent) -> void:
	if panel.visible and event.is_action_pressed("ui_cancel"):
		close_tip()
		get_viewport().set_input_as_handled()
