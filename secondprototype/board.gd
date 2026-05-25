extends Node2D

var points: Array[Vector2] = []

func _draw():
	if points.size() < 2:
		return

	for i in range(points.size() - 1):
		draw_line(points[i], points[i + 1], Color(0.85, 0.9, 1.0), 4.0)

	draw_line(points[points.size() - 1], points[0], Color(0.85, 0.9, 1.0), 4.0)
