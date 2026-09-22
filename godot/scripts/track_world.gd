extends Node3D
## Continuous ribbon geometry shared by display and collision; metres throughout.
const HALF_WIDTH := 8.0
var points := PackedVector3Array()
var distances := PackedFloat32Array()
var length := 0.0
var road_material: StandardMaterial3D
var segment_grid: Dictionary = {}

func build(source: PackedVector3Array) -> void:
	# Corner cutting avoids Catmull-Rom overshoot at sparse hairpins. Overshoot can
	# fold a 16m ribbon back into itself and create an invisible collision wedge.
	points = source.duplicate()
	for iteration in 3:
		var rounded := PackedVector3Array()
		for i in points.size():
			var a := points[i]
			var b := points[(i + 1) % points.size()]
			rounded.append(a.lerp(b, 0.33))
			rounded.append(a.lerp(b, 0.67))
		points = rounded
	distances.append(0.0)
	for i in points.size():
		length += points[i].distance_to(points[(i + 1) % points.size()])
		distances.append(length)
	_build_segment_grid()
	_ribbon(-HALF_WIDTH, HALF_WIDTH, Color("343d45"), 0.0, true)
	_ribbon(-HALF_WIDTH - 0.85, -HALF_WIDTH, Color("eee6d7"), 0.035, true, true)
	_ribbon(HALF_WIDTH, HALF_WIDTH + 0.85, Color("eee6d7"), 0.035, true, true)
	# Small verge cells can be omitted where a neighbouring bend needs clearance.
	for side in [-1.0, 1.0]:
		for strip in 7:
			var inner: float = (HALF_WIDTH + 0.85 + strip * 3.8) * side
			var outer: float = (HALF_WIDTH + 0.85 + (strip + 1) * 3.8) * side
			_ribbon(minf(inner, outer), maxf(inner, outer), Color("687b68"), -0.06, true, false, true)
	_ribbon(-7.8, -7.65, Color("e8e6d6"), 0.02, false)
	_ribbon(7.65, 7.8, Color("e8e6d6"), 0.02, false)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(6000, 6000)
	ground.mesh = plane
	ground.position.y = -1.0
	ground.material_override = material(Color("576d60"))
	add_child(ground)
	var floor_body := StaticBody3D.new()
	var floor_shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(6000, 1, 6000)
	floor_shape.shape = box
	floor_shape.position.y = -1.5
	floor_body.add_child(floor_shape)
	add_child(floor_body)
	_decorate()

func tangent(index: int) -> Vector3:
	return (points[(index + 1) % points.size()] - points[posmod(index - 1, points.size())]).normalized()

func edge(index: int, offset: float, lift: float) -> Vector3:
	var t := tangent(index)
	return points[index] + Vector3(t.z, 0, -t.x).normalized() * offset + Vector3.UP * lift

func _ribbon(left: float, right: float, color: Color, lift: float, collides: bool, curb := false, verge := false) -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var faces := 0
	for i in points.size():
		var j := (i + 1) % points.size()
		var a := edge(i, left, lift)
		var b := edge(j, left, lift)
		var c := edge(j, right, lift)
		var d := edge(i, right, lift)
		if verge:
			var blocked := false
			for probe in [a, b, c, d, (a + b + c + d) * 0.25]:
				if _over_other_road(probe, i):
					blocked = true
					break
			if blocked:
				continue
		surface.set_color(Color("d95237") if curb and i % 2 == 0 else color)
		# Godot clockwise front faces when viewed from above.
		for vertex in [a, c, b, a, d, c]:
			surface.add_vertex(vertex)
		faces += 1
	if faces == 0:
		return
	surface.generate_normals()
	var mesh := surface.commit()
	var instance := MeshInstance3D.new()
	instance.name = "Ribbon_%s_%s" % [str(left).replace(".", "_"), str(right).replace(".", "_")]
	instance.mesh = mesh
	var mat := material(Color.WHITE)
	mat.vertex_color_use_as_albedo = true
	mat.vertex_color_is_srgb = true
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	instance.material_override = mat
	add_child(instance)
	if collides:
		instance.create_trimesh_collision()

func _build_segment_grid() -> void:
	for i in points.size():
		var a := points[i]
		var b := points[(i + 1) % points.size()]
		var low := Vector2i(floori(minf(a.x, b.x) / 32), floori(minf(a.z, b.z) / 32))
		var high := Vector2i(floori(maxf(a.x, b.x) / 32), floori(maxf(a.z, b.z) / 32))
		for x in range(low.x - 1, high.x + 2):
			for z in range(low.y - 1, high.y + 2):
				var key := Vector2i(x, z)
				if not segment_grid.has(key):
					segment_grid[key] = []
				segment_grid[key].append(i)

func _over_other_road(position: Vector3, own_segment: int) -> bool:
	var key := Vector2i(floori(position.x / 32), floori(position.z / 32))
	for index: int in segment_grid.get(key, []):
		var separation := absi(index - own_segment)
		if mini(separation, points.size() - separation) <= 10:
			continue
		var a := Vector2(points[index].x, points[index].z)
		var b3 := points[(index + 1) % points.size()]
		var b := Vector2(b3.x, b3.z)
		var offset := Vector2(position.x, position.z) - a
		var line := b - a
		var fraction := clampf(offset.dot(line) / maxf(line.length_squared(), 0.001), 0, 1)
		if (offset - line * fraction).length_squared() < pow(HALF_WIDTH + 1.8, 2):
			return true
	return false

func sample(position: Vector3) -> Dictionary:
	var closest := INF
	var result := {"point": points[0], "tangent": tangent(0), "progress": 0.0, "distance": 0.0, "index": 0}
	for i in points.size():
		var a := points[i]
		var b := points[(i + 1) % points.size()]
		var flat := Vector2(b.x - a.x, b.z - a.z)
		var fraction := clampf(Vector2(position.x - a.x, position.z - a.z).dot(flat) / maxf(flat.length_squared(), 0.001), 0.0, 1.0)
		var point := a.lerp(b, fraction)
		var metric := Vector2(position.x - point.x, position.z - point.z).length_squared()
		# Prefer same-height roadway at crossings, while allowing airborne recovery.
		metric += pow(maxf(0.0, absf(position.y - point.y) - 2.0), 2.0)
		if metric < closest:
			closest = metric
			result = {"point": point, "tangent": (b - a).normalized(), "progress": (distances[i] + a.distance_to(b) * fraction) / length, "distance": Vector2(position.x - point.x, position.z - point.z).length(), "index": i}
	return result

func at_progress(progress: float) -> Dictionary:
	var metres := fposmod(progress, 1.0) * length
	for i in points.size():
		if distances[i + 1] >= metres:
			var t := (metres - distances[i]) / maxf(distances[i + 1] - distances[i], 0.001)
			return {"point": points[i].lerp(points[(i + 1) % points.size()], t), "tangent": (points[(i + 1) % points.size()] - points[i]).normalized()}
	return {"point": points[0], "tangent": tangent(0)}

static func material(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.85
	return mat

func _box(location: Vector3, size: Vector3, color: Color, yaw := 0.0, collision := false) -> void:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.material_override = material(color)
	mesh.position = location
	mesh.rotation.y = yaw
	add_child(mesh)
	if collision:
		mesh.create_convex_collision()

func _decorate() -> void:
	var start := points[0]
	var t := tangent(0)
	var yaw := atan2(t.x, t.z)
	var right := Vector3(t.z, 0, -t.x).normalized()
	for row in 2:
		for column in 16:
			_box(start + right * (column - 7.5) + t * (row * 0.65) + Vector3.UP * 0.035, Vector3(1, 0.025, 0.65), Color.WHITE if (row + column) % 2 == 0 else Color("151e28"), yaw)
	var gantry := start + t * 18.0
	for side in [-1, 1]:
		_box(gantry + right * 10.0 * side + Vector3.UP * 3, Vector3(0.4, 6, 0.4), Color("273746"), yaw, true)
	_box(gantry + Vector3.UP * 6.2, Vector3(20.5, 1.1, 0.5), Color("192532"), yaw)
	var banner := Label3D.new()
	banner.text = "APEX  /  CIRCUIT"
	banner.font_size = 100
	banner.pixel_size = 0.012
	banner.position = gantry + Vector3.UP * 6.2 - t * 0.28
	banner.rotation.y = yaw + PI
	add_child(banner)
	var rng := RandomNumberGenerator.new()
	rng.seed = 2718
	for i in range(0, points.size(), 10):
		var side := -1.0 if i % 20 == 0 else 1.0
		var place := edge(i, side * rng.randf_range(24, 33), 0)
		if float(sample(place).distance) < 20.0:
			continue
		_box(place + Vector3.UP * 1.4, Vector3(0.45, 2.8, 0.45), Color("695645"))
		var crown := MeshInstance3D.new()
		var cone := CylinderMesh.new()
		cone.top_radius = 0
		cone.bottom_radius = rng.randf_range(2.0, 3.0)
		cone.height = rng.randf_range(4.0, 6.0)
		cone.radial_segments = 7
		crown.mesh = cone
		crown.position = place + Vector3.UP * 4.0
		crown.material_override = material(Color("294b46") if i % 30 else Color("496559"))
		add_child(crown)
		if i % 30 == 0:
			_rock(place + Vector3(4, -0.5, 3), Vector3(4, 3, 3), Color("67756e"), rng.randf() * TAU)
	# Direction boards every ~100m, safely outside the roadway.
	for i in range(0, points.size(), 18):
		var heading := tangent(i)
		var board := Label3D.new()
		board.text = "> > >"
		board.font_size = 80
		board.pixel_size = 0.018
		board.modulate = Color("ffd06a")
		board.position = edge(i, 11.0, 1.8)
		board.rotation.y = atan2(heading.x, heading.z) + PI
		add_child(board)
	var bounds := AABB(points[0], Vector3.ZERO)
	for point in points:
		bounds = bounds.expand(point)
	var center := bounds.get_center()
	for i in 28:
		var angle := float(i) / 28.0 * TAU
		var place := center + Vector3(cos(angle) * (bounds.size.x * 0.65 + 240), 0, sin(angle) * (bounds.size.z * 0.65 + 240))
		place.y = -8
		_rock(place, Vector3(rng.randf_range(140, 250), rng.randf_range(90, 220), rng.randf_range(140, 230)), Color("526965") if i % 2 else Color("627775"), angle)

func _rock(location: Vector3, scale_value: Vector3, color: Color, yaw: float) -> void:
	var mesh := MeshInstance3D.new()
	var prism := CylinderMesh.new()
	prism.top_radius = 0.15
	prism.bottom_radius = 1.0
	prism.height = 1.0
	prism.radial_segments = 5
	prism.rings = 1
	mesh.mesh = prism
	mesh.position = location + Vector3.UP * scale_value.y * 0.5
	mesh.scale = scale_value
	mesh.rotation.y = yaw
	mesh.material_override = material(color)
	add_child(mesh)
