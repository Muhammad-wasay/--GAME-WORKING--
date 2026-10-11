extends PanelContainer
class_name InventorySlot

@onready var icon_rect: TextureRect = find_child("Icon", true, false)
@onready var count_label: Label = find_child("CountLabel", true, false)
@onready var slot_num_label: Label = find_child("SlotNum", true, false)

@export var normal_style: StyleBoxFlat
@export var selected_style: StyleBoxFlat

var item_data: Dictionary = {}
var is_selected: bool = false
var slot_index: int = 0

func _ready() -> void:
	update_display()
	set_selected(false)

func set_slot_number(num: int) -> void:
	slot_index = num - 1
	if slot_num_label:
		slot_num_label.text = str(num)

func set_item(data: Dictionary) -> void:
	item_data = data
	update_display()

func clear_slot() -> void:
	item_data = {}
	update_display()

func is_empty() -> bool:
	return item_data.is_empty()

func get_item_id() -> String:
	return item_data.get("id", "")

func get_count() -> int:
	return item_data.get("count", 0)

func add_count(amount: int = 1) -> void:
	if not item_data.is_empty():
		item_data["count"] = item_data.get("count", 0) + amount
		update_display()

func remove_count(amount: int = 1) -> Dictionary:
	if item_data.is_empty():
		return {}
	
	var cur_count = item_data.get("count", 0)
	if cur_count <= amount:
		var dropped = item_data.duplicate()
		clear_slot()
		return dropped
	else:
		item_data["count"] = cur_count - amount
		var dropped = item_data.duplicate()
		dropped["count"] = amount
		update_display()
		return dropped

func update_display() -> void:
	if not icon_rect or not count_label:
		return
		
	if item_data.is_empty():
		icon_rect.texture = null
		icon_rect.visible = false
		count_label.text = ""
	else:
		icon_rect.texture = item_data.get("icon", null)
		icon_rect.visible = (icon_rect.texture != null)
		var count = item_data.get("count", 1)
		if count > 1:
			count_label.text = str(count)
		else:
			count_label.text = ""

func set_selected(selected: bool) -> void:
	is_selected = selected
	if selected and selected_style:
		add_theme_stylebox_override("panel", selected_style)
	elif normal_style:
		add_theme_stylebox_override("panel", normal_style)
