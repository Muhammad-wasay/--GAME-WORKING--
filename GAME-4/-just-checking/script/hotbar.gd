extends CanvasLayer
class_name HotbarUI

signal item_selected(slot_index: int, item_data: Dictionary)
signal item_dropped(item_data: Dictionary)

const SLOT_COUNT: int = 4

@onready var slots_container: HBoxContainer = find_child("SlotsContainer", true, false)

var slots: Array = []
var selected_index: int = 0

func _ready() -> void:
	slots.clear()
	for i in range(slots_container.get_child_count()):
		var child = slots_container.get_child(i)
		if child.has_method("set_slot_number"):
			slots.append(child)
			child.set_slot_number(i + 1)
	
	select_slot(0)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.is_pressed() and not event.is_echo():
		match event.keycode:
			KEY_1:
				select_slot(0)
			KEY_2:
				select_slot(1)
			KEY_3:
				select_slot(2)
			KEY_4:
				select_slot(3)
	
	if event is InputEventMouseButton and event.is_pressed():
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			select_slot((selected_index - 1 + SLOT_COUNT) % SLOT_COUNT)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			select_slot((selected_index + 1) % SLOT_COUNT)

func select_slot(idx: int) -> void:
	if idx < 0 or idx >= slots.size():
		return
	
	selected_index = idx
	for i in range(slots.size()):
		slots[i].set_selected(i == selected_index)
	
	item_selected.emit(selected_index, get_selected_item())

func add_item(item_data: Dictionary) -> bool:
	var item_id = item_data.get("id", "")
	var amount = item_data.get("count", 1)
	
	# 1. Pehle dekho agar kisi slot mein ye item pehle se mojood hai (Stacking)
	for slot in slots:
		if not slot.is_empty() and slot.get_item_id() == item_id:
			slot.add_count(amount)
			item_selected.emit(selected_index, get_selected_item())
			return true
	
	# 2. Agar nahi mila toh pehle khaali (empty) slot mein daal do
	for slot in slots:
		if slot.is_empty():
			slot.set_item(item_data)
			item_selected.emit(selected_index, get_selected_item())
			return true
	
	# Inventory full hai
	print("Inventory is Full!")
	return false

func get_selected_item() -> Dictionary:
	if selected_index >= 0 and selected_index < slots.size():
		return slots[selected_index].item_data
	return {}

func drop_selected_item(amount: int = 1) -> Dictionary:
	if selected_index >= 0 and selected_index < slots.size():
		var dropped = slots[selected_index].remove_count(amount)
		item_selected.emit(selected_index, get_selected_item())
		if not dropped.is_empty():
			item_dropped.emit(dropped)
		return dropped
	return {}

func consume_selected_item(amount: int = 1) -> Dictionary:
	if selected_index >= 0 and selected_index < slots.size():
		var used = slots[selected_index].remove_count(amount)
		item_selected.emit(selected_index, get_selected_item())
		return used
	return {}

func has_item(item_id: String) -> bool:
	for slot in slots:
		if slot.get_item_id() == item_id:
			return true
	return false

func remove_item_by_id(item_id: String, amount: int = 1) -> bool:
	for slot in slots:
		if slot.get_item_id() == item_id:
			slot.remove_count(amount)
			item_selected.emit(selected_index, get_selected_item())
			return true
	return false
