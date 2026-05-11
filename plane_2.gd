extends Node2D

@export var plane_color: Color = Color(0.092, 0.314, 1.0, 1.0)

@onready var poly: Polygon2D = $Polygon2D

func _ready():
	poly.polygon = PackedVector2Array([
		Vector2(0, -22),
		Vector2(-6, -6),
		Vector2(-14, 4),
		Vector2(-5, 5),
		Vector2(-3, 16),
		Vector2(0, 10),
		Vector2(3, 16),
		Vector2(5, 5),
		Vector2(14, 4),
		Vector2(6, -6)
	])

	poly.color = plane_color
