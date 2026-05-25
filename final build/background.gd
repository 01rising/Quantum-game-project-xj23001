extends Node2D

@export var top_color: Color = Color(0.03, 0.08, 0.18, 1.0)
@export var bottom_color: Color = Color(0.02, 0.16, 0.32, 1.0)

@export var show_grid: bool = true
@export var grid_spacing: int = 64
@export var grid_color: Color = Color(0.35, 0.75, 1.0, 0.12)

@export var show_radar: bool = true
@export var radar_color: Color = Color(0.35, 1.0, 0.9, 0.16)

@export var show_clouds: bool = true
@export var cloud_color: Color = Color(1.0, 1.0, 1.0, 0.10)

@export var show_vignette: bool = true
@export var vignette_color: Color = Color(0.0, 0.0, 0.0, 0.22)


func _ready():
	z_index = -100

	if get_viewport() != null:
		get_viewport().size_changed.connect(queue_redraw)

	queue_redraw()


func _draw():
	var size = get_viewport_rect().size

	draw_gradient_background(size)

	if show_grid:
		draw_grid(size)

	if show_radar:
		draw_radar(size)

	if show_clouds:
		draw_clouds(size)

	if show_vignette:
		draw_vignette(size)


func draw_gradient_background(size: Vector2):
	var steps = 40

	for i in range(steps):
		var t = float(i) / float(steps - 1)
		var color = top_color.lerp(bottom_color, t)

		var y = size.y * t
		var h = size.y / steps + 1

		draw_rect(
			Rect2(0, y, size.x, h),
			color
		)


func draw_grid(size: Vector2):
	for x in range(0, int(size.x) + grid_spacing, grid_spacing):
		draw_line(
			Vector2(x, 0),
			Vector2(x, size.y),
			grid_color,
			1.0
		)

	for y in range(0, int(size.y) + grid_spacing, grid_spacing):
		draw_line(
			Vector2(0, y),
			Vector2(size.x, y),
			grid_color,
			1.0
		)


func draw_radar(size: Vector2):
	var center = size / 2.0
	var max_radius = min(size.x, size.y) * 0.42

	for i in range(1, 5):
		var radius = max_radius * float(i) / 4.0
		draw_arc(
			center,
			radius,
			0,
			TAU,
			96,
			radar_color,
			2.0
		)

	draw_line(
		Vector2(center.x - max_radius, center.y),
		Vector2(center.x + max_radius, center.y),
		radar_color,
		1.5
	)

	draw_line(
		Vector2(center.x, center.y - max_radius),
		Vector2(center.x, center.y + max_radius),
		radar_color,
		1.5
	)

	draw_arc(
		center,
		max_radius * 0.85,
		deg_to_rad(-25),
		deg_to_rad(25),
		32,
		Color(radar_color.r, radar_color.g, radar_color.b, radar_color.a * 1.8),
		3.0
	)


func draw_clouds(size: Vector2):
	draw_cloud(size * Vector2(0.18, 0.22), 1.0)
	draw_cloud(size * Vector2(0.72, 0.18), 0.85)
	draw_cloud(size * Vector2(0.82, 0.72), 1.15)
	draw_cloud(size * Vector2(0.28, 0.78), 0.75)


func draw_cloud(pos: Vector2, scale_value: float):
	draw_circle(pos + Vector2(-30, 5) * scale_value, 28 * scale_value, cloud_color)
	draw_circle(pos + Vector2(0, -8) * scale_value, 36 * scale_value, cloud_color)
	draw_circle(pos + Vector2(35, 6) * scale_value, 26 * scale_value, cloud_color)
	draw_circle(pos + Vector2(5, 16) * scale_value, 32 * scale_value, cloud_color)


func draw_vignette(size: Vector2):
	var border = 40

	draw_rect(
		Rect2(0, 0, size.x, border),
		vignette_color
	)

	draw_rect(
		Rect2(0, size.y - border, size.x, border),
		vignette_color
	)

	draw_rect(
		Rect2(0, 0, border, size.y),
		vignette_color
	)

	draw_rect(
		Rect2(size.x - border, 0, border, size.y),
		vignette_color
	)