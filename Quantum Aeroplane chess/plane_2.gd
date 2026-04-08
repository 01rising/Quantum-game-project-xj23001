extends Node2D

@onready var poly: Polygon2D = $Polygon2D

func _ready():
	poly.polygon = PackedVector2Array([
		Vector2(0, -22),   # nose
		Vector2(-6, -6),
		Vector2(-14, 4),   # left wing tip
		Vector2(-5, 5),
		Vector2(-3, 16),   # left tail
		Vector2(0, 10),    # tail center
		Vector2(3, 16),    # right tail
		Vector2(5, 5),
		Vector2(14, 4),    # right wing tip
		Vector2(6, -6)
	])
	poly.color = Color(0.85, 0.9, 1.0)
