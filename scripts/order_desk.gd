extends Interactable
## Original ledger, linen and wooden desk; interaction and collision stay in the scene.

func _draw() -> void:
	draw_texture(preload("res://assets/shop/order_desk.png"), Vector2(-24, -22))
