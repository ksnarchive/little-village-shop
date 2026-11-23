class_name ItemData
extends Resource
## Immutable product definition shared by inventories and future shop systems.

@export var id: StringName
@export var display_name: String
@export_multiline var description: String
@export var icon: Texture2D
@export var purchase_price: int = 0
@export var selling_price: int = 0
@export var category: StringName
@export_range(1, 9999) var max_stack_size: int = 99

func is_valid() -> bool:
	var id_pattern := RegEx.create_from_string("^[a-z][a-z0-9_]*$")
	return (id_pattern.search(String(id)) != null
		and not display_name.strip_edges().is_empty()
		and not category.is_empty()
		and purchase_price >= 0 and selling_price >= 0 and max_stack_size > 0)
