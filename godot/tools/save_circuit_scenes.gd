extends SceneTree
## Explicit authoring tool only. The game never calls this script or CircuitBuilder.
var resources: Dictionary = {}
var serial := 0
var folder := ""
func _initialize() -> void:
	run.call_deferred()
func externalize(resource: Resource) -> void:
	if not resource or resources.has(resource.get_instance_id()): return
	resources[resource.get_instance_id()] = true
	if not resource.resource_path.is_empty() and not "::" in resource.resource_path: return
	serial += 1
	var path := folder + "/geometry_%04d.res" % serial
	var error := ResourceSaver.save(resource, path, ResourceSaver.FLAG_COMPRESS)
	assert(error == OK, "Cannot save geometry")
	resource.take_over_path(path)
func own(node: Node, owner_node: Node) -> void:
	if node != owner_node:
		node.owner = owner_node
		node.set_script(null)
	if node is MeshInstance3D and node.mesh is ArrayMesh: externalize(node.mesh)
	if node is MultiMeshInstance3D:
		assert(node.multimesh.buffer.size() == node.multimesh.instance_count * 12, "Missing instance transforms")
		externalize(node.multimesh)
	if node is CollisionShape3D and node.shape is ConcavePolygonShape3D: externalize(node.shape)
	for child in node.get_children(): own(child, owner_node)
func run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Scene authoring requires a real rendering device to serialize MultiMesh buffers")
		quit(1)
		return
	var catalog: Dictionary = preload("res://scripts/real_track_catalog.gd").new().get_tracks()
	DirAccess.make_dir_recursive_absolute("res://scenes/circuits")
	for key: String in catalog:
		folder = "res://scenes/circuits/geometry/" + key
		DirAccess.make_dir_recursive_absolute(folder)
		resources.clear()
		serial = 0
		var track = preload("res://tools/circuit_builder.gd").new()
		track.name = key.capitalize().replace(" ", "") + "Circuit"
		root.add_child(track)
		track.build(catalog[key].points, key, catalog[key])
		await process_frame
		await process_frame
		await RenderingServer.frame_post_draw
		var baked_points: PackedVector3Array = track.points
		var width: float = track.half_width
		# Nodes are retained as editable scene children; meshes are binary resources
		# to keep text scenes small. Foliage remains spatially batched for performance.
		own(track, track)
		track.set_script(preload("res://scripts/track_world.gd"))
		track.points = baked_points
		track.half_width = width
		track.circuit_key = key
		var packed := PackedScene.new()
		assert(packed.pack(track) == OK)
		assert(ResourceSaver.save(packed, "res://scenes/circuits/" + key + ".tscn") == OK)
		print("SCENE SAVED: ", key, " resources=", serial, " nodes=", track.find_children("*", "", true, false).size())
		track.queue_free()
		await process_frame
	print("NINE CIRCUIT SCENES SAVED")
	quit()
