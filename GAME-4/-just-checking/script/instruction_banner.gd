extends CanvasLayer

# ===== ANIMATED INSTRUCTION BANNER =====
@onready var banner_container: CenterContainer = $BannerContainer
@onready var banner_label: Label = $BannerContainer/BannerPanel/BannerLabel

var tween: Tween = null
var auto_hide_timer: Timer = null

func _ready() -> void:
	# Shuru mein completely hide aur chota kardo
	banner_container.modulate.a = 0.0
	banner_container.scale = Vector2(0.7, 0.7)
	banner_container.pivot_offset = banner_container.size / 2.0
	banner_container.visible = false

func show_message(text: String, duration: float = 4.0) -> void:
	if banner_label:
		banner_label.text = text
	
	if tween and tween.is_valid():
		tween.kill()
	if auto_hide_timer and not auto_hide_timer.is_stopped():
		auto_hide_timer.stop()
	
	# Pivot Center set karein taake beech mein se scale ho
	banner_container.pivot_offset = banner_container.size / 2.0
	banner_container.visible = true
	
	# Transition Animation (Fade-in + Elastic Scale Pop-in)
	tween = create_tween().set_parallel(true)
	tween.tween_property(banner_container, "modulate:a", 1.0, 0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(banner_container, "scale", Vector2(1.0, 1.0), 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	
	# Auto-hide timer
	if auto_hide_timer == null:
		auto_hide_timer = Timer.new()
		auto_hide_timer.one_shot = true
		add_child(auto_hide_timer)
		auto_hide_timer.timeout.connect(_fade_out)
	
	auto_hide_timer.wait_time = duration
	auto_hide_timer.start()

func hide_banner() -> void:
	_fade_out()

func _fade_out() -> void:
	if tween and tween.is_valid():
		tween.kill()
		
	# Out Transition (Shrink + Fade-out)
	tween = create_tween().set_parallel(true)
	tween.tween_property(banner_container, "modulate:a", 0.0, 0.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.tween_property(banner_container, "scale", Vector2(0.8, 0.8), 0.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	
	# Animation khatam hone par hide karein
	var chain_tween = create_tween()
	chain_tween.tween_interval(0.3)
	chain_tween.tween_callback(func(): banner_container.visible = false)
