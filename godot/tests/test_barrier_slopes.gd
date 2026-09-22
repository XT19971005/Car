extends "res://tools/fit_barrier_slopes.gd"
func run():
	var catalog: Dictionary = Catalog.new().get_tracks()
	var failures:=0
	var sections:=0
	var collisions:=0
	var max_error:=0.0
	var assets: Dictionary={}
	for asset in ["ENV_Circuit_Guardrail_8m","ENV_Circuit_SafetyFence_8m"]:
		var model=load("res://assets/environment/circuit_kit/"+asset+".glb").instantiate()
		var mesh=model.find_children("*","MeshInstance3D",true,false)[0]
		var pose: Transform3D=mesh.transform
		var parent=mesh.get_parent()
		while parent is Node3D:
			pose=parent.transform*pose
			parent=parent.get_parent()
		assets[asset]=pose
		model.free()
	for key in catalog:
		var track=load("res://scenes/circuits/"+key+".tscn").instantiate()
		root.add_child(track)
		var ground=Ground.new()
		ground.terrain_points=catalog[key].terrain_mesh.points
		ground.columns=int(catalog[key].terrain_mesh.columns)
		ground.rows=int(catalog[key].terrain_mesh.rows)
		ground.bounds_min=Vector2(ground.terrain_points[0][0],ground.terrain_points[0][2])
		ground.bounds_max=Vector2(ground.terrain_points.back()[0],ground.terrain_points.back()[2])
		for node in track.find_children("*","MultiMeshInstance3D",true,false):
			var asset: String="ENV_Circuit_Guardrail_8m" if node.name.begins_with("ENV_Circuit_Guardrail_8m") else "ENV_Circuit_SafetyFence_8m" if node.name.begins_with("ENV_Circuit_SafetyFence_8m") else ""
			if asset.is_empty():continue
			for i in node.multimesh.instance_count:
				var pose: Transform3D=node.global_transform*node.multimesh.get_instance_transform(i)*assets[asset].affine_inverse()
				for sign_value in [-1.0,1.0]:
					var endpoint: Vector3=pose.origin+pose.basis.z*4.0*sign_value
					var error:=absf(endpoint.y-height_at(track,ground,endpoint))
					max_error=maxf(max_error,error)
					if error>.03:failures+=1
				sections+=1
		for node in track.find_children("*","CollisionShape3D",true,false):
			if not (str(node.get_parent().name).begins_with("MappedBarrier_") or node.get_parent().name=="SafetyBarriers"):continue
			if not node.shape is BoxShape3D:continue
			for sign_value in [-1.0,1.0]:
				var endpoint: Vector3=node.global_position-node.global_basis.y*node.shape.size.y*.5+node.global_basis.z*node.shape.size.z*.5*sign_value
				var error:=absf(endpoint.y-height_at(track,ground,endpoint))
				max_error=maxf(max_error,error)
				if error>.03:failures+=1
			collisions+=1
		print("SLOPE AUDIT ",key," accumulated failures=",failures)
		track.queue_free()
		ground.free()
		await process_frame
	print("SLOPE AUDIT RESULT visual=",sections," collision=",collisions," max_endpoint_error=",max_error," failures=",failures)
	quit(1 if failures else 0)
