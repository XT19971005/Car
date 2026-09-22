extends RefCounted
func get_tracks() -> Dictionary:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/circuits/real_circuits.json"))
	for key: String in data:
		var points := PackedVector3Array()
		for p: Array in data[key].points:
			points.append(Vector3(p[0], p[1], p[2]))
		data[key].points = points
	return data
