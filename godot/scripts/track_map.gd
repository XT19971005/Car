extends Control
var points := PackedVector2Array()
var driver := Vector2.ZERO
var direction := Vector2.DOWN
var minimum := Vector2.ZERO
var span := Vector2.ONE

func configure(world_points: PackedVector3Array) -> void:
	points.clear()
	minimum = Vector2(INF, INF)
	var maximum := Vector2(-INF, -INF)
	for point in world_points:
		var flat := Vector2(point.x, point.z)
		points.append(flat)
		minimum = minimum.min(flat)
		maximum = maximum.max(flat)
	span = maximum - minimum
	queue_redraw()

func project(point: Vector2) -> Vector2:
	var scale_value := minf((size.x - 32) / maxf(span.x, 1), (size.y - 32) / maxf(span.y, 1))
	return (point - minimum - span * 0.5) * scale_value + size * 0.5

func _draw() -> void:
	if points.size() < 2:
		return
	var display := PackedVector2Array()
	for point in points:
		display.append(project(point))
	display.append(display[0])
	draw_polyline(display, Color("415463"), 7, true)
	draw_polyline(display, Color("d6e3e9"), 2, true)
	draw_circle(display[0], 4, Color("f6ca72"))
	var player := project(driver)
	draw_circle(player, 6, Color("ff8051"))
	draw_line(player, player + direction * 13, Color.WHITE, 2, true)
