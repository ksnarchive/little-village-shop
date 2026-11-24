class_name FrontendUI
extends RefCounted

static func label(text: String, font_size: int = 16) -> Label:
	var item := Label.new()
	item.text = text
	item.add_theme_font_size_override("font_size", font_size)
	return item

static func button(text: String, action: Callable) -> Button:
	var item := Button.new()
	item.text = text
	item.custom_minimum_size = Vector2(44, 44)
	item.pressed.connect(action)
	return item

static func full(control: Control) -> void:
	control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
