extends "res://scripts/monza_scenery.gd"
## Metre-scale OSM venue footprints and SRTM terrain; stylized facade detail.
var terrain_points: Array
var columns: int
var rows: int
var bounds_min: Vector2
var bounds_max: Vector2
var feature_polygons: Array[PackedVector2Array] = []
var forest_polygons: Array[PackedVector2Array] = []

func build(track: Node3D) -> void:
	rng.seed = 1922 + track.circuit_key.hash()
	terrain_points = track.circuit_data.terrain_mesh.points
	columns = int(track.circuit_data.terrain_mesh.columns)
	rows = int(track.circuit_data.terrain_mesh.rows)
	bounds_min = Vector2(terrain_points[0][0], terrain_points[0][2])
	bounds_max = Vector2(terrain_points.back()[0], terrain_points.back()[2])
	_terrain(track)
	for feature: Dictionary in track.circuit_data.features:
		var poly := PackedVector2Array()
		for p: Array in feature.points:
			poly.append(Vector2(p[0], p[2]))
		if poly.size() > 1 and poly[0].is_equal_approx(poly[-1]):
			poly.remove_at(poly.size() - 1)
		if feature.kind == "forest":
			forest_polygons.append(poly)
		elif feature.kind == "building":
			feature_polygons.append(poly)
			_building(track, feature, poly)
		elif feature.kind == "pitlane":
			_pit_lane(track, poly)
	_forest(track)
	_facilities(track)
	_road_detail(track)
	_flush()

func _road_detail(track: Node3D) -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Twelve metre grid spacing; each slot fits a full-size GT car.
	for row in 12:
		var progress: float = fposmod(-(row * 12.0 + 8) / track.length, 1)
		for side in [-1.0, 1.0]:
			var lateral: float = side * track.half_width * .47
			_mark(surface, track, progress, .14, lateral - 1.45, lateral + 1.45, Color("d5d4c9"))
			_mark(surface, track, progress - 2.6 / track.length, 5.2, lateral - 1.45, lateral - 1.31, Color("d5d4c9"))
	# Rubber laid into braking zones; physical grip remains the assisted baseline.
	var last_zone := -200.0
	for metre in range(90, int(track.length) - 90, 12):
		var p: Dictionary = track.at_progress(float(metre) / track.length)
		var before: Dictionary = track.at_progress((metre - 20.0) / track.length)
		var after: Dictionary = track.at_progress((metre + 20.0) / track.length)
		if absf(before.tangent.signed_angle_to(after.tangent, Vector3.UP)) < .32 or metre - last_zone < 160:
			continue
		last_zone = metre
		for distance in [150, 100, 50]:
			var board: Dictionary = track.at_progress((metre - distance) / track.length)
			var right := Vector3(-board.tangent.z, 0, board.tangent.x).normalized()
			var position: Vector3 = board.point - right * (track.half_width + 3.0) + Vector3.UP * 1.2
			var yaw := atan2(board.tangent.x, board.tangent.z)
			track._box(position, Vector3(1.8, 1.1, .08), Color("e9e7da"), yaw)
			var label := Label3D.new()
			label.text = str(distance)
			label.font_size = 72
			label.pixel_size = .014
			label.position = position - board.tangent * .06
			label.rotation.y = yaw + PI
			label.modulate = Color("202b2c")
			label.visibility_range_end = 190
			add_child(label)
		for strip in 12:
			var lane := rng.randf_range(-track.half_width * .5, track.half_width * .5)
			var fraction: float = (metre - 30 - strip * 3) / track.length
			_mark(surface, track, fraction, rng.randf_range(6, 13), lane, lane + rng.randf_range(.10, .26), Color("363c3b"))
	surface.generate_normals()
	var instance := MeshInstance3D.new()
	instance.name = "Grid_and_braking_rubber"
	instance.mesh = surface.commit()
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.vertex_color_is_srgb = true
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.roughness = .94
	instance.material_override = material
	add_child(instance)

func _mark(surface: SurfaceTool, track: Node3D, progress: float, length: float, left: float, right: float, color: Color) -> void:
	var a: Dictionary = track.at_progress(progress - length / track.length * .5)
	var b: Dictionary = track.at_progress(progress + length / track.length * .5)
	var ar := Vector3(a.tangent.z, 0, -a.tangent.x).normalized()
	var br := Vector3(b.tangent.z, 0, -b.tangent.x).normalized()
	var vertices: Array[Vector3] = [a.point + ar * left, b.point + br * left, b.point + br * right, a.point + ar * right]
	surface.set_color(color)
	for i in [0, 2, 1, 0, 3, 2]:
		surface.add_vertex(vertices[i] + Vector3.UP * .016)

func ground_height(p: Vector3) -> float:
	var uv := (Vector2(p.x, p.z) - bounds_min) / (bounds_max - bounds_min)
	var x := clampf(uv.x * (columns - 1), 0, columns - 1.001)
	var z := clampf(uv.y * (rows - 1), 0, rows - 1.001)
	var i := floori(z) * columns + floori(x)
	return lerpf(lerpf(terrain_points[i][1], terrain_points[i + 1][1], fposmod(x, 1)), lerpf(terrain_points[i + columns][1], terrain_points[i + columns + 1][1], fposmod(x, 1)), fposmod(z, 1))

func _terrain(track: Node3D) -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for z in rows - 1:
		for x in columns - 1:
			var i := z * columns + x
			for index in [i, i + columns + 1, i + 1, i, i + columns, i + columns + 1]:
				var p: Array = terrain_points[index]
				surface.add_vertex(Vector3(p[0], p[1], p[2]))
	surface.generate_normals()
	var instance := MeshInstance3D.new()
	instance.name = "SRTM_Terrain_Metres"
	instance.mesh = surface.commit()
	instance.material_override = track.park_material
	add_child(instance)
	instance.create_trimesh_collision()

func _building(track: Node3D, data: Dictionary, poly: PackedVector2Array) -> void:
	if poly.size() < 3:
		return
	var center := Vector2.ZERO
	var longest := Vector2.ZERO
	for i in poly.size():
		center += poly[i]
		var edge := poly[(i + 1) % poly.size()] - poly[i]
		if edge.length_squared() > longest.length_squared():
			longest = edge
	center /= poly.size()
	var pos := Vector3(center.x, 0, center.y)
	var nearest: Dictionary = track.sample(pos)
	if float(nearest.distance) < track.half_width + 2:
		return
	pos.y = ground_height(pos)
	if float(nearest.distance) < 85:
		pos.y = nearest.point.y - .2
	# OSM level/layer=1 structures include pedestrian bridges above the roadway.
	pos.y += float(data.get("min_height", 0))
	var longitudinal := longest.normalized()
	var lateral := Vector2(longitudinal.y, -longitudinal.x)
	var minimum := Vector2(INF, INF)
	var maximum := Vector2(-INF, -INF)
	for p in poly:
		var local := Vector2((p - center).dot(lateral), (p - center).dot(longitudinal))
		minimum = minimum.min(local)
		maximum = maximum.max(local)
	var size := maximum - minimum
	var shift := (maximum + minimum) * .5
	pos += Vector3(lateral.x * shift.x + longitudinal.x * shift.y, 0, lateral.y * shift.x + longitudinal.y * shift.y)
	var yaw := atan2(longitudinal.x, longitudinal.y)
	var front := Vector3(lateral.x, 0, lateral.y)
	var toward_road: Vector3 = nearest.point - pos
	var building_name: String = data.name
	var pit := building_name in ["Palazzina Box", "Stand F1", "Stand Endurance", "Silverstone Wing"]
	if data.grandstand or pit:
		var asset := "ENV_Monza_Grandstand_30m"
		var nominal := Vector3(14, 8.3, 32)
		if pit:
			asset = "ENV_Monza_PitModule_24m" if track.circuit_key == "monza" else "ENV_Spa_PitModule_30m" if track.circuit_key == "spa" else "ENV_Silverstone_WingModule_30m"
			nominal = Vector3(13.2, 6.8, 25) if track.circuit_key == "monza" else Vector3(18, 9.3, 31) if track.circuit_key == "spa" else Vector3(25, 14, 32)
		if (toward_road.dot(front) < 0 and not pit) or (toward_road.dot(front) > 0 and pit):
			yaw += PI
		var count := maxi(1, roundi(size.y / nominal.z))
		for i in count:
			var along: float = (i - (count - 1) * .5) * size.y / count
			var loc := pos + Vector3(longitudinal.x, 0, longitudinal.y) * along
			_place(asset, loc, yaw, Vector3(size.x / nominal.x, clampf(float(data.height) / nominal.y, .6, 2.2), size.y / count / nominal.z))
		if pit:
			for i in range(0, int(size.y), 30):
				var loc := pos + Vector3(longitudinal.x, 0, longitudinal.y) * (i - size.y * .5) - toward_road.normalized() * (size.x * .5 + 12)
				loc.y = ground_height(loc)
				_place("ENV_Circuit_PaddockTent_01", loc, yaw)
				_place("ENV_Circuit_LightPole_01", loc + Vector3(6, 0, 0), yaw)
	else:
		_extrude_footprint(poly, pos.y, float(data.height), Color("d3cbb1") if track.circuit_key == "monza" else Color("939e9b"), "OSM_" + str(data.osm_id))
	if not building_name.is_empty() and (pit or data.grandstand):
		var label := Label3D.new()
		label.text = building_name.to_upper()
		label.font_size = 72
		label.pixel_size = .035
		label.position = pos + Vector3.UP * (float(data.height) + 1.0)
		label.rotation.y = atan2(toward_road.x, toward_road.z)
		label.modulate = Color("efebd6")
		label.visibility_range_end = 210
		add_child(label)

func _extrude_footprint(poly: PackedVector2Array, base: float, height: float, color: Color, feature_name: String) -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in poly.size():
		var a := Vector3(poly[i].x, base, poly[i].y)
		var b := Vector3(poly[(i + 1) % poly.size()].x, base, poly[(i + 1) % poly.size()].y)
		for p in [a, b, b + Vector3.UP * height, a, b + Vector3.UP * height, a + Vector3.UP * height]:
			surface.add_vertex(p)
	var indices := Geometry2D.triangulate_polygon(poly)
	for i in indices:
		surface.add_vertex(Vector3(poly[i].x, base + height, poly[i].y))
	surface.generate_normals()
	var instance := MeshInstance3D.new()
	instance.name = feature_name
	instance.mesh = surface.commit()
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.roughness = .8
	instance.material_override = material
	add_child(instance)
	instance.create_trimesh_collision()

func _pit_lane(track: Node3D, poly: PackedVector2Array) -> void:
	for i in poly.size() - 1:
		var a := Vector3(poly[i].x, 0, poly[i].y)
		var b := Vector3(poly[i + 1].x, 0, poly[i + 1].y)
		a.y = track.sample(a).point.y - .05
		b.y = track.sample(b).point.y - .05
		var center := (a + b) * .5
		track._box(center, Vector3(7.0, .08, a.distance_to(b) + .15), Color("777c78"), atan2(b.x - a.x, b.z - a.z), true)

func _forest(track: Node3D) -> void:
	for p: Array in terrain_points:
		if float(p[3]) < 25 or float(p[3]) > 650:
			continue
		var point := Vector2(p[0] + rng.randf_range(-7, 7), p[2] + rng.randf_range(-7, 7))
		var wooded := false
		for poly in forest_polygons:
			if Geometry2D.is_point_in_polygon(point, poly):
				wooded = true
				break
		if not wooded:
			continue
		var in_building := false
		for poly in feature_polygons:
			if Geometry2D.is_point_in_polygon(point, poly):
				in_building = true
				break
		if in_building:
			continue
		var loc := Vector3(point.x, 0, point.y)
		loc.y = ground_height(loc)
		var asset := "ENV_Monza_Oak_%02d" % rng.randi_range(1, 3)
		if track.circuit_key == "spa" and rng.randf() < .65:
			asset = "ENV_Spa_Conifer_01"
		_place(asset, loc, rng.randf() * TAU, Vector3.ONE * rng.randf_range(.8, 1.25))
		if rng.randf() < .45:
			_place("ENV_Monza_Shrub_01", loc + Vector3(3, 0, 2), rng.randf() * TAU)

func _facilities(track: Node3D) -> void:
	var barrier_body := StaticBody3D.new()
	barrier_body.name = "SafetyBarriers"
	add_child(barrier_body)
	var shape := BoxShape3D.new()
	shape.size = Vector3(.25, 1.05, 8.1)
	for metre in range(0, int(track.length), 8):
		var p: Dictionary = track.at_progress(float(metre) / track.length)
		var right := Vector3(-p.tangent.z, 0, p.tangent.x).normalized()
		var yaw := atan2(p.tangent.x, p.tangent.z)
		for side in [-1.0, 1.0]:
			var loc: Vector3 = p.point + right * side * (track.half_width + 8)
			if float(track.sample(loc).distance) < track.half_width + 4:
				continue
			_place("ENV_Circuit_Guardrail_8m", loc, yaw)
			_place("ENV_Circuit_SafetyFence_8m", loc + right * side * .3, yaw)
			var collision := CollisionShape3D.new()
			collision.shape = shape
			collision.position = loc + Vector3.UP * .525
			collision.rotation.y = yaw
			barrier_body.add_child(collision)
		if metre % 400 == 0:
			var loc: Vector3 = p.point + right * (track.half_width + 12)
			_place("ENV_Circuit_MarshalPost_01", loc, yaw)
			_place("ENV_Circuit_TyreBarrier_3m", loc - right * 3, yaw)
