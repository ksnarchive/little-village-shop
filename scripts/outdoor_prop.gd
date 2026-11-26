@tool
class_name OutdoorProp
extends Node2D
## Independent art + ground footprint. Its anchor is the ground sorting point.
@export var texture: Texture2D
@export var footprint := Rect2(-8, -8, 16, 12)
@export var wind := false
@export var shadow: Texture2D
var sprite: Sprite2D
var elapsed := 0.0

func _ready() -> void:
	if shadow != null:
		var shade := Sprite2D.new()
		shade.texture = shadow
		shade.position = Vector2(24, 3)
		shade.z_index = -5
		add_child(shade)
	sprite = Sprite2D.new()
	sprite.texture = texture
	sprite.centered = false
	if texture != null:
		sprite.position = Vector2(-texture.get_width() / 2.0, -texture.get_height())
	add_child(sprite)
	if not Engine.is_editor_hint() and footprint.has_area():
		var body := StaticBody2D.new()
		body.collision_layer = 2
		body.collision_mask = 0
		var shape := CollisionShape2D.new()
		var box := RectangleShape2D.new()
		box.size = footprint.size
		shape.shape = box
		shape.position = footprint.get_center()
		body.add_child(shape)
		add_child(body)
	set_process(wind and not Engine.is_editor_hint())

func _process(delta: float) -> void:
	if texture == null:
		return
	if CharacterArt.motion_enabled(self):
		elapsed += delta
	sprite.position.x = -texture.get_width() / 2.0 + (roundf(sin(elapsed * 0.8 + position.x) * 0.7) if CharacterArt.motion_enabled(self) else 0.0)
