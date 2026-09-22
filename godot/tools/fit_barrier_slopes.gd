extends SceneTree
const Catalog = preload("res://scripts/real_track_catalog.gd")
const Ground = preload("res://scripts/venue_scenery.gd")
var changed := 0
var checked := 0
var worst_error := 0.0
func _initialize(): run.call_deferred()
func height_at(track: Node3D, ground: Node3D, point: Vector3) -> float:
	return ground.barrier_height(track, point)

func nearest_flat(track: Node3D, p: Vector3) -> Vector3:
	var route: PackedVector3Array=track.points
	var closest:=INF
	var result:=Vector3.ZERO
	for i in route.size():
		var a:=route[i]
		var b:=route[(i+1)%route.size()]
		var delta:=Vector2(b.x-a.x,b.z-a.z)
		var t:=clampf(Vector2(p.x-a.x,p.z-a.z).dot(delta)/maxf(delta.length_squared(),.001),0,1)
		var point:=a.lerp(b,t)
		var distance:=Vector2(p.x-point.x,p.z-point.z).length_squared()
		if distance<closest:
			closest=distance
			result=point
	return result

func fitted(track: Node3D, ground: Node3D, base: Vector3, direction: Vector3, span: float) -> Transform3D:
	var z := Vector3(direction.x,0,direction.z).normalized()
	# Keep complete barrier sections outside the drivable width on tight bends.
	for iteration in 4:
		var displacement:=Vector3.ZERO
		var deepest:=0.0
		for fraction in [-.5,0.0,.5]:
			var point: Vector3=base+z*span*fraction
			var road:=nearest_flat(track,point)
			var away:=Vector3(point.x-road.x,0,point.z-road.z)
			var penetration: float=track.half_width+1.0-away.length()
			if penetration>deepest:
				deepest=penetration
				displacement=away.normalized()*(penetration+.1)
		if deepest<=0:break
		base+=displacement
	var a := base-z*span*.5
	var b := base+z*span*.5
	a.y = height_at(track,ground,a)
	b.y = height_at(track,ground,b)
	var axis := (b-a).normalized()
	var x := Vector3.UP.cross(axis).normalized()
	var y := axis.cross(x).normalized()
	var pose := Transform3D(Basis(x,y,axis), (a+b)*.5)
	pose.basis.z *= a.distance_to(b)/span
	return pose
func run():
	if DisplayServer.get_name()=="headless": quit(1);return
	var catalog: Dictionary = Catalog.new().get_tracks()
	var assets := {}
	for asset in ["ENV_Circuit_Guardrail_8m","ENV_Circuit_SafetyFence_8m"]:
		var model=load("res://assets/environment/circuit_kit/"+asset+".glb")
		if not model:
			push_error("Missing asset "+asset);quit(1);return
		var instance=model.instantiate()
		var mesh=instance.find_children("*","MeshInstance3D",true,false)[0]
		var pose: Transform3D = mesh.transform
		var parent=mesh.get_parent()
		while parent is Node3D:
			pose=parent.transform*pose
			parent=parent.get_parent()
		assets[asset]=pose
		instance.free()
	for key in catalog:
		var only := ""
		for argument in OS.get_cmdline_user_args():
			if argument.begins_with("--track="): only = argument.trim_prefix("--track=")
		if not only.is_empty() and only != key: continue
		var track=load("res://scenes/circuits/"+key+".tscn").instantiate()
		root.add_child(track)
		var ground=Ground.new()
		ground.terrain_points=catalog[key].terrain_mesh.points
		ground.columns=int(catalog[key].terrain_mesh.columns)
		ground.rows=int(catalog[key].terrain_mesh.rows)
		ground.bounds_min=Vector2(ground.terrain_points[0][0],ground.terrain_points[0][2])
		ground.bounds_max=Vector2(ground.terrain_points.back()[0],ground.terrain_points.back()[2])
		var resources: Array[MultiMesh]=[]
		var count:=0
		for node in track.find_children("*","MultiMeshInstance3D",true,false):
			var asset: String = "ENV_Circuit_Guardrail_8m" if node.name.begins_with("ENV_Circuit_Guardrail_8m") else "ENV_Circuit_SafetyFence_8m" if node.name.begins_with("ENV_Circuit_SafetyFence_8m") else ""
			if asset.is_empty():continue
			var source: Transform3D = assets[asset]
			for i in node.multimesh.instance_count:
				var original: Transform3D = node.global_transform*node.multimesh.get_instance_transform(i)*source.affine_inverse()
				var span := 8.0*Vector2(original.basis.z.x,original.basis.z.z).length()
				var pose := fitted(track,ground,original.origin,original.basis.z,span)
				pose.basis.x *= original.basis.x.length()
				pose.basis.y *= original.basis.y.length()
				pose.basis.z *= span/8.0
				node.multimesh.set_instance_transform(i,node.global_transform.affine_inverse()*pose*source)
				checked+=1
				if absf(pose.basis.z.y)>.001:changed+=1
				count+=1
			resources.append(node.multimesh)
		for node in track.find_children("*","CollisionShape3D",true,false):
			if not (str(node.get_parent().name).begins_with("MappedBarrier_") or node.get_parent().name=="SafetyBarriers"):continue
			if not node.shape is BoxShape3D:continue
			var old: Transform3D = node.global_transform
			var box: BoxShape3D = node.shape.duplicate()
			var base := old.origin-old.basis.y.normalized()*box.size.y*.5
			var span := box.size.z*Vector2(old.basis.z.x,old.basis.z.z).length()/old.basis.z.length()
			var pose := fitted(track,ground,base,old.basis.z,span)
			box.size.z = span*pose.basis.z.length()
			pose.basis=pose.basis.orthonormalized()
			pose.origin+=pose.basis.y*box.size.y*.5
			node.shape=box
			node.global_transform=pose
		await process_frame
		await RenderingServer.frame_post_draw
		for resource in resources: assert(ResourceSaver.save(resource,resource.resource_path,ResourceSaver.FLAG_COMPRESS)==OK)
		var packed:=PackedScene.new()
		assert(packed.pack(track)==OK)
		assert(ResourceSaver.save(packed,"res://scenes/circuits/"+key+".tscn")==OK)
		print("SLOPE SAVED ",key," sections=",count)
		track.queue_free()
		ground.free()
		await process_frame
	print("SLOPE COMPLETE sections=",checked," sloped=",changed)
	quit()

