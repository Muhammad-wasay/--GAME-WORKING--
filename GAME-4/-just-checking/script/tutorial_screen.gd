extends CanvasLayer
class_name TutorialScreen

# ===== START TUTORIAL SCREEN =====
# Game background mein dikhta hai, saamne stacked tutorial cards.
# Left/Right arrow keys ya side arrows se pages badlo, Skip se band karo.
# Tutorial khulte waqt game pause hota hai aur mouse visible hota hai.

signal finished

const TITLE_FONT = preload("res://import/font-text/ballad_of_dwight_frye/Ballad of Dwight Frye.ttf")

const CARD_SIZE := Vector2(540, 434)

const PAGES := [
	{
		"image": "res://import/UI/tutorial/tut_pickup.jpg",
		"title": "PICK UP THE APPLE",
		"text": "Walk close to an apple and press  E  to put it in your bag."
	},
	{
		"image": "res://import/UI/tutorial/tut_eat.jpg",
		"title": "EAT TO GET HEALTH",
		"text": "Press  ENTER  to eat an apple. It fills your health bar.\nYou can eat it from the ground or from your bag."
	},
	{
		"image": "res://import/UI/tutorial/tut_stamina.jpg",
		"title": "WATCH YOUR STAMINA",
		"text": "Running uses up your stamina bar. When it gets low, walk.\nThe bar slowly fills up again."
	},
	{
		"image": "res://import/UI/tutorial/tut_gun.jpg",
		"title": "USE THE GUN",
		"text": "After you pick up a gun, press  TAB  to hold it.\nPress  TAB  again to put it away."
	},
]

var cards: Array = []
var current := 0
var left_btn: Button
var right_btn: Button
var skip_btn: Button
var page_label: Label
var tween: Tween = null
var closing := false

func _ready() -> void:
	layer = 50
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	# Background dim (game peeche dikhta rahe)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	
	# Cards area: screen ke center se thora upar (neeche skip button ke liye jagah)
	var stage := Control.new()
	stage.anchor_left = 0.5
	stage.anchor_right = 0.5
	stage.anchor_top = 0.424
	stage.anchor_bottom = 0.424
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(stage)
	
	# Cards ko reverse order mein add karo taake pehla sabse upar ho
	for i in range(PAGES.size() - 1, -1, -1):
		var card := _build_card(PAGES[i])
		stage.add_child(card)
		cards.push_front(card)
	
	# Side arrows
	left_btn = _make_arrow_button("<")
	left_btn.position = Vector2(CARD_SIZE.x / -2.0 - 90, -35)
	left_btn.pressed.connect(_go_prev)
	stage.add_child(left_btn)
	
	right_btn = _make_arrow_button(">")
	right_btn.position = Vector2(CARD_SIZE.x / 2.0 + 20, -35)
	right_btn.pressed.connect(_go_next)
	stage.add_child(right_btn)
	
	# Neeche: page number + skip
	page_label = Label.new()
	page_label.add_theme_font_size_override("font_size", 20)
	page_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	page_label.size = Vector2(200, 30)
	page_label.position = Vector2(-100, CARD_SIZE.y / 2.0 + 10)
	stage.add_child(page_label)
	
	skip_btn = Button.new()
	skip_btn.focus_mode = Control.FOCUS_NONE
	skip_btn.add_theme_font_size_override("font_size", 22)
	skip_btn.custom_minimum_size = Vector2(190, 44)
	skip_btn.position = Vector2(-95, CARD_SIZE.y / 2.0 + 44)
	skip_btn.pressed.connect(_close)
	stage.add_child(skip_btn)
	
	_layout_cards(false)
	
	# Mouse enable + game pause
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _build_card(page: Dictionary) -> Control:
	var card := PanelContainer.new()
	card.custom_minimum_size = CARD_SIZE
	card.size = CARD_SIZE
	card.position = CARD_SIZE / -2.0
	card.pivot_offset = CARD_SIZE / 2.0
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.09, 0.06, 0.04, 1.0)
	style.border_color = Color(0.85, 0.65, 0.25, 1)
	style.set_border_width_all(3)
	style.set_corner_radius_all(12)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 14
	style.content_margin_bottom = 14
	card.add_theme_stylebox_override("panel", style)
	
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	card.add_child(box)
	
	var img := TextureRect.new()
	img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	img.custom_minimum_size = Vector2(CARD_SIZE.x - 28, (CARD_SIZE.x - 28) * 9.0 / 16.0)
	if ResourceLoader.exists(page["image"]):
		img.texture = load(page["image"])
	box.add_child(img)
	
	var title := Label.new()
	title.text = page["title"]
	title.add_theme_font_override("font", TITLE_FONT)
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", Color(1, 0.85, 0.4))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	
	# Description: saaf readable default font
	var text := Label.new()
	text.text = page["text"]
	text.add_theme_font_size_override("font_size", 22)
	text.add_theme_color_override("font_color", Color(0.95, 0.93, 0.88))
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.custom_minimum_size = Vector2(CARD_SIZE.x - 28, 56)
	box.add_child(text)
	
	return card

func _make_arrow_button(label: String) -> Button:
	var b := Button.new()
	b.text = label
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(70, 70)
	b.size = Vector2(70, 70)
	b.add_theme_font_size_override("font_size", 40)
	return b

# Stack layout: current upar, baqi peeche halke chote, purane screen se bahar
func _layout_cards(animate: bool) -> void:
	if tween and tween.is_valid():
		tween.kill()
	if animate:
		tween = create_tween().set_parallel(true)
	
	for i in range(cards.size()):
		var card: Control = cards[i]
		var rel := i - current
		var target_pos: Vector2
		var target_scale: Vector2
		var target_alpha: float
		if rel < 0:
			target_pos = Vector2(-CARD_SIZE.x / 2.0 - 900, -CARD_SIZE.y / 2.0)
			target_scale = Vector2.ONE
			target_alpha = 0.0
		else:
			var depth := mini(rel, 3)
			target_pos = Vector2(CARD_SIZE.x / -2.0 + depth * 14, CARD_SIZE.y / -2.0 - depth * 12)
			var s := 1.0 - depth * 0.04
			target_scale = Vector2(s, s)
			target_alpha = 1.0 - depth * 0.25
		
		if animate:
			tween.tween_property(card, "position", target_pos, 0.35).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			tween.tween_property(card, "scale", target_scale, 0.35).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			tween.tween_property(card, "modulate:a", target_alpha, 0.35)
		else:
			card.position = target_pos
			card.scale = target_scale
			card.modulate.a = target_alpha
	
	left_btn.disabled = current <= 0
	right_btn.disabled = current >= PAGES.size() - 1
	page_label.text = "%d / %d" % [current + 1, PAGES.size()]
	skip_btn.text = "Start Game" if current >= PAGES.size() - 1 else "Skip Tutorial"

func _go_next() -> void:
	if current < PAGES.size() - 1:
		current += 1
		_layout_cards(true)

func _go_prev() -> void:
	if current > 0:
		current -= 1
		_layout_cards(true)

func _close() -> void:
	if closing:
		return
	closing = true
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	finished.emit()
	queue_free()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_right"):
		_go_next()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_left"):
		_go_prev()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel"):
		_close()
		get_viewport().set_input_as_handled()
