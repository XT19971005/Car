extends Node3D
## Persistent circuit scene. Geometry and collisions live in the .tscn, not _ready().
@export var points := PackedVector3Array()
@export var half_width := 8.0
@export var circuit_key := ""
const HALF_WIDTH := 8.0
var distances := PackedFloat32Array()
var length := 0.0

func _ready() -> void:
	distances.append(0.0)
	for i in points.size():
		length += points[i].distance_to(points[(i + 1) % points.size()])
		distances.append(length)

func tangent(index: int) -> Vector3:
	return (points[(index + 1) % points.size()] - points[posmod(index - 1, points.size())]).normalized()

func edge(index: int, offset: float, lift: float) -> Vector3:
	var t := tangent(index)
	return points[index] + Vector3(t.z, 0, -t.x).normalized() * offset + Vector3.UP * lift

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
