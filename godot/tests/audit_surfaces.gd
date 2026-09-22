extends SceneTree
var failures := 0
var probes := 0
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var report: Dictionary = {}
	for key: String in preload("res://scripts/real_track_catalog.gd").new().get_tracks():
		var track = load("res://scenes/circuits/" + key + ".tscn").instantiate()
		root.add_child(track)
		await physics_frame
		await physics_frame
		var errors: Array = []
		var total := 0
		var sample_errors := 0
		for metre in range(0, int(track.length), 20):
			var progress: float = float(metre) / track.length
			var route: Dictionary = track.at_progress(progress)
			var right := Vector3(route.tangent.z, 0, -route.tangent.x).normalized()
			for fraction in [-.8, 0.0, .8]:
				var p: Vector3 = route.point + right * track.half_width * fraction
				var query := PhysicsRayQueryParameters3D.create(p + Vector3.UP * 1.9, p - Vector3.UP * 1.0)
				var hit: Dictionary = track.get_world_3d().direct_space_state.intersect_ray(query)
				total += 1
				probes += 1
				if hit.is_empty() or absf(hit.position.y - p.y) > .20 or hit.normal.y < .5:
					failures += 1
					errors.append({"metre": metre, "lane": fraction, "delta_y": 999 if hit.is_empty() else hit.position.y-p.y, "node": "missing" if hit.is_empty() else str(hit.collider.get_path())})
			var located: Dictionary = track.sample(route.point + Vector3.UP * .14)
			var error: float = absf(float(located.progress) - progress)
			if minf(error, 1-error) > .005:
				sample_errors += 1
				failures += 1
		report[key] = {"road_probes": total, "surface_errors": errors, "route_selection_errors": sample_errors}
		print("SURFACE AUDIT: ", key, " probes=", total, " surface_errors=", errors.size(), " route_errors=", sample_errors)
		for i in mini(errors.size(), 4): print("SURFACE DETAIL: ", errors[i])
		track.queue_free()
		await process_frame
	var file := FileAccess.open("res://test-output/surface-audit.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "  "))
	print("SURFACE AUDIT COMPLETE probes=", probes, " failures=", failures)
	quit(1 if failures else 0)
