extends Node3D
## Stylized interpretation of Monza's parkland and main-straight facilities.
## Placement follows the prototype centreline; not a surveyed reconstruction.
const ASSET_ROOT := "res://assets/environment/circuit_kit/"
var batches: Dictionary = {}
var meshes: Dictionary = {}
var poses: Dictionary = {}
var batch_assets: Dictionary = {}
var batch_origins: Dictionary = {}
var rng := RandomNumberGenerator.new()

func build(track: Node3D) -> void:
	rng.seed = 1922
	# Layered deciduous parkland, deliberately open beside the pit complex.
	for metre in range(0, int(track.length), 22):
		var p: Dictionary = track.at_progress(float(metre) / track.length)
		var right := Vector3(-p.tangent.z, 0, p.tangent.x).normalized()
		for side in [-1.0, 1.0]:
			for row in 3:
				var lateral: float = 27 + row * 23 + rng.randf_range(-4, 6)
				if metre < 370:
					lateral += 38
				var pos: Vector3 = p.point + right * side * lateral + p.tangent * rng.randf_range(-7, 7)
				if float(track.sample(pos).distance) < 21:
					continue
				pos.y = p.point.y - 0.3 if row == 0 and metre >= 370 else -1.0
				var tree := "ENV_Monza_Oak_%02d" % rng.randi_range(1, 3)
				if row == 2 and metre % 66 == 0:
					tree = "ENV_Monza_Poplar_01"
				_place(tree, pos, rng.randf() * TAU, Vector3.ONE * rng.randf_range(.85, 1.4))
				if row == 0:
					_place("ENV_Monza_Shrub_01", pos + right * side * 4, rng.randf() * TAU, Vector3.ONE * rng.randf_range(.8, 1.5))
	# Guardrails and debris fences frame the track, beyond the grass run-off.
	var barrier_body := StaticBody3D.new()
	barrier_body.name = "GuardrailCollision"
	add_child(barrier_body)
	var barrier_shape := BoxShape3D.new()
	barrier_shape.size = Vector3(.22, 1.1, 8.2)
	for metre in range(0, int(track.length), 8):
		var p: Dictionary = track.at_progress(float(metre) / track.length)
		var right := Vector3(-p.tangent.z, 0, p.tangent.x).normalized()
		var yaw := atan2(p.tangent.x, p.tangent.z)
		for side in [-1.0, 1.0]:
			var offset := 14.5 if side < 0 or metre > 370 else 10.5
			var pos: Vector3 = p.point + right * offset * side
			if float(track.sample(pos).distance) < 12 and metre > 370:
				continue
			_place("ENV_Circuit_Guardrail_8m", pos, yaw)
			_place("ENV_Circuit_SafetyFence_8m", pos + right * side * .3, yaw)
			var collider := CollisionShape3D.new()
			collider.shape = barrier_shape
			collider.position = pos + Vector3.UP * .55
			collider.rotation.y = yaw
			barrier_body.add_child(collider)
	# Driver's right: pit lane and modular garages. Driver's left: main stands.
	for metre in range(0, 216, 24):
		var p: Dictionary = track.at_progress(float(metre) / track.length)
		var right := Vector3(-p.tangent.z, 0, p.tangent.x).normalized()
		var yaw := atan2(p.tangent.x, p.tangent.z)
		_place("ENV_Monza_PitModule_24m", p.point + right * 34, yaw + PI)
		track._box(p.point + right * 18 + Vector3.DOWN * .035, Vector3(15, .045, 24.5), Color("777d77"), yaw)
		track._box(p.point + right * 12 + Vector3.UP * .008, Vector3(.16, .02, 24.5), Color("efebe0"), yaw)
	for metre in [15, 47, 79, 145, 177, 209]:
		var p: Dictionary = track.at_progress(float(metre) / track.length)
		var right := Vector3(-p.tangent.z, 0, p.tangent.x).normalized()
		_place("ENV_Monza_Grandstand_30m", p.point - right * 30, atan2(p.tangent.x, p.tangent.z) + PI)
	# Main straight, first chicane, Roggia and Ascari visual braking references.
	for braking_point in [620.0, 1870.0, 3710.0, 4870.0]:
		for distance in [150, 100, 50]:
			var p: Dictionary = track.at_progress((braking_point - distance) / track.length)
			var right := Vector3(-p.tangent.z, 0, p.tangent.x).normalized()
			var yaw := atan2(p.tangent.x, p.tangent.z)
			track._box(p.point - right * 12 + Vector3.UP * 1.2, Vector3(1.9, 1.2, .12), Color("f2eedb"), yaw)
			var label := Label3D.new()
			label.text = str(distance)
			label.font_size = 80
			label.pixel_size = .012
			label.modulate = Color("233531")
			label.no_depth_test = false
			label.position = p.point - right * 12 + Vector3.UP * 1.2 - p.tangent * .075
			label.rotation.y = yaw + PI
			add_child(label)
	_flush()

func _place(asset: String, position: Vector3, yaw: float, size := Vector3.ONE) -> void:
	if not meshes.has(asset):
		var packed := load(ASSET_ROOT + asset + ".glb") as PackedScene
		if not packed:
			return
		var root := packed.instantiate()
		var nodes := root.find_children("*", "MeshInstance3D", true, false)
		if nodes.is_empty():
			root.free()
			return
		var node := nodes[0] as MeshInstance3D
		var pose := node.transform
		var parent := node.get_parent()
		while parent is Node3D:
			pose = parent.transform * pose
			parent = parent.get_parent()
		meshes[asset] = node.mesh
		poses[asset] = pose
		root.free()
	var pose := Transform3D(Basis(Vector3.UP, yaw) * Basis.from_scale(size), position)
	var cell := Vector2i(floori(position.x / 200), floori(position.z / 200))
	var group := "%s_%d_%d" % [asset, cell.x, cell.y]
	if not batches.has(group):
		batches[group] = []
		batch_assets[group] = asset
		batch_origins[group] = Vector3(cell.x * 200 + 100, 0, cell.y * 200 + 100)
	var local_pose: Transform3D = pose * poses[asset]
	local_pose.origin -= batch_origins[group]
	batches[group].append(local_pose)

func _flush() -> void:
	for group: String in batches:
		var asset: String = batch_assets[group]
		var multi := MultiMesh.new()
		multi.transform_format = MultiMesh.TRANSFORM_3D
		multi.mesh = meshes[asset]
		multi.instance_count = batches[group].size()
		for i in multi.instance_count:
			multi.set_instance_transform(i, batches[group][i])
		var instance := MultiMeshInstance3D.new()
		instance.name = group
		instance.multimesh = multi
		instance.position = batch_origins[group]
		instance.visibility_range_end = 850
		instance.visibility_range_end_margin = 70
		add_child(instance)
