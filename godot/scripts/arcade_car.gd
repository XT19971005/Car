extends CharacterBody3D
## Assisted arcade handling. Heading and lateral momentum are separate, with swept collisions.
const TOP_SPEED := 76.0
var speed := 0.0
var heading := 0.0
var steering := 0.0
var throttle := 0.0
var brake := 0.0
var yaw_rate := 0.0
var rpm := 950.0
var gear := 0
var shift_timer := 0.0
var body_visual: Node3D
var wheel_nodes: Array[Node3D] = []
var wheel_rotations: Array[Vector3] = []
var wheel_roll := 0.0
var previous_speed := 0.0
var slip := 0.0
var vehicle_key := "v8"
var profile: Dictionary = preload("res://scripts/car_catalog.gd").CARS.v8
var cockpit_anchor: Node3D
var steering_wheel: Node3D
var dashboard: Label3D
var acceleration_feedback := 0.0
var impact_feedback := 0.0
var shift_feedback := 0.0

func _ready() -> void:
	floor_snap_length = 1.2
	floor_max_angle = deg_to_rad(55)
	floor_constant_speed = true
	safe_margin = 0.025
	var collider := CollisionShape3D.new()
	# Rounded underbody avoids box corners snagging on shallow road seams.
	var shape := CapsuleShape3D.new()
	shape.radius = 0.75
	shape.height = 3.5
	collider.shape = shape
	collider.rotation.x = PI / 2
	collider.position.y = 0.82
	add_child(collider)
	body_visual = Node3D.new()
	add_child(body_visual)
	configure_vehicle(vehicle_key)

func configure_vehicle(key: String) -> void:
	vehicle_key = key
	profile = preload("res://scripts/car_catalog.gd").CARS[key]
	for child in body_visual.get_children():
		body_visual.remove_child(child)
		child.queue_free()
	wheel_nodes.clear()
	wheel_rotations.clear()
	var model: Node3D = load("res://assets/cars/" + str(profile.asset) + ".glb").instantiate()
	body_visual.add_child(model)
	# Source models use metres. Preserve physical dimensions at import.
	for node in model.find_children("*", "Node3D", true, false):
		if node.name.to_lower().begins_with("wheel_front_") or node.name.to_lower().begins_with("wheel_rear_"):
			wheel_nodes.append(node)
			wheel_rotations.append(node.rotation)
	cockpit_anchor = model.find_child("cockpit_camera", true, false)
	steering_wheel = model.find_child("steering_wheel", true, false)
	var screen := model.find_child("dash_display", true, false) as Node3D
	dashboard = Label3D.new()
	dashboard.font_size = 50
	dashboard.pixel_size = .00075
	dashboard.rotation.y = PI
	dashboard.modulate = Color("9fffcf")
	dashboard.outline_size = 0
	dashboard.text = "N   000\nRPM 0950"
	screen.add_child(dashboard)

func reset_at(point: Vector3, direction: Vector3) -> void:
	position = point + Vector3.UP * 0.14
	heading = atan2(direction.x, direction.z)
	rotation = Vector3(0, heading, 0)
	velocity = Vector3.ZERO
	speed = 0.0
	previous_speed = 0.0
	steering = 0.0
	yaw_rate = 0.0
	throttle = 0.0
	brake = 0.0
	rpm = 950.0
	gear = 0
	shift_timer = 0.0
	impact_feedback = 0.0
	shift_feedback = 0.0
	acceleration_feedback = 0.0
	if body_visual:
		body_visual.rotation = Vector3.ZERO
	reset_physics_interpolation()

func drive(dt: float, gas: float, stopping: float, turn: float, handbrake: bool, offroad: bool) -> void:
	steering = move_toward(steering, turn, dt * (4.5 if absf(turn) > 0.05 else 6.0))
	throttle = move_toward(throttle, gas, dt * 2.8)
	brake = move_toward(brake, stopping, dt * 6.0)
	var forward := Vector3(sin(heading), 0, cos(heading))
	var right := Vector3(forward.z, 0, -forward.x)
	var longitudinal := velocity.dot(forward)
	var lateral := velocity.dot(right)
	var grip := 3.0 if offroad else float(profile.grip)
	if handbrake:
		grip *= 0.32
	var max_velocity := 28.0 if offroad else float(profile.top_speed)
	if brake > 0.05:
		if longitudinal > 0.3:
			longitudinal = move_toward(longitudinal, 0.0, brake * 22.0 * dt)
		elif throttle < 0.05:
			longitudinal = move_toward(longitudinal, -9.0, brake * 6.0 * dt)
	elif throttle > 0.02:
		if longitudinal < -0.2:
			longitudinal = move_toward(longitudinal, 0.0, throttle * 18.0 * dt)
		else:
			longitudinal = move_toward(longitudinal, max_velocity, maxf(3.0, float(profile.acceleration) - longitudinal * 0.1) * throttle * dt)
	else:
		longitudinal = move_toward(longitudinal, 0.0, (0.7 + absf(longitudinal) * 0.025) * dt)
	if offroad and absf(longitudinal) > max_velocity:
		longitudinal = move_toward(longitudinal, signf(longitudinal) * max_velocity, dt * 12.0)
	if handbrake:
		longitudinal = move_toward(longitudinal, 0.0, dt * 9.0)
	var steering_angle := lerpf(0.55, 0.045, clampf(absf(longitudinal) / TOP_SPEED, 0, 1))
	# Model forward is +Z; a driver's right turn rotates toward -X.
	var desired_yaw := -steering * longitudinal / float(profile.wheelbase) * tan(steering_angle)
	desired_yaw = clampf(desired_yaw, -1.5, 1.5)
	yaw_rate = lerpf(yaw_rate, desired_yaw, 1.0 - exp(-dt * 7.0))
	heading += yaw_rate * dt
	lateral *= exp(-grip * dt)
	# Preserve inertia in world space while steering; tyre grip draws it back next step.
	var vertical := velocity.y
	velocity = forward * longitudinal + right * lateral
	# Floor snapping handles grounded adhesion. Forcing gravity into a floor every
	# tick can repeatedly cancel low-speed uphill motion at contact recovery.
	velocity.y = 0.0 if is_on_floor() else vertical - 24.0 * dt
	rotation.y = heading
	move_and_slide()
	impact_feedback = move_toward(impact_feedback, 0, dt * 3)
	for i in get_slide_collision_count():
		var hit := get_slide_collision(i)
		if absf(hit.get_normal().y) < .5:
			impact_feedback = maxf(impact_feedback, clampf(absf(longitudinal) / 25, 0, 1))
	speed = Vector2(velocity.x, velocity.z).length() * (-1.0 if longitudinal < -0.1 else 1.0)
	slip = absf(lateral)
	shift_timer = maxf(0, shift_timer - dt)
	shift_feedback = move_toward(shift_feedback, 0, dt * 7)
	var old_gear := gear
	var ratio: Array[float] = [0.0, 3.10, 2.12, 1.55, 1.20, 0.98, 0.82]
	if speed < -0.3:
		gear = -1
	elif absf(speed) < 0.4 and throttle < 0.05:
		gear = 0
	else:
		gear = maxi(gear, 1)
		var predicted := absf(speed) / 2.05 * 60.0 * ratio[gear] * 3.4
		if shift_timer <= 0:
			if predicted > 7200 and gear < 6:
				gear += 1
				shift_timer = 0.35
			elif predicted < 2600 and gear > 1:
				gear -= 1
				shift_timer = 0.25
	var target_rpm := 950.0 + throttle * 1700.0 if gear <= 0 else maxf(1100.0, absf(speed) / 2.05 * 60 * ratio[gear] * 3.4)
	rpm = lerpf(rpm, clampf(target_rpm, 950, 7900), 1.0 - exp(-dt * 12))
	if old_gear != gear and old_gear > 0:
		shift_feedback = 1.0
	var acceleration := (speed - previous_speed) / maxf(dt, 0.001)
	acceleration_feedback = lerpf(acceleration_feedback, clampf(acceleration, -22, 14), 1 - exp(-dt * 5))
	previous_speed = speed
	var floor_pitch := 0.0
	if is_on_floor():
		floor_pitch = -atan2(is_on_floor_direction(forward), 1.0)
	body_visual.rotation.x = lerp_angle(body_visual.rotation.x, floor_pitch - clampf(acceleration * 0.002, -0.045, 0.045), 1 - exp(-dt * 6))
	body_visual.rotation.z = lerpf(body_visual.rotation.z, clampf(yaw_rate * speed * 0.002, -0.07, 0.07), 1 - exp(-dt * 6))
	wheel_roll += speed * dt / 0.34
	for i in wheel_nodes.size():
		wheel_nodes[i].rotation.x = wheel_rotations[i].x + wheel_roll
		if "front" in wheel_nodes[i].name:
			wheel_nodes[i].rotation.y = wheel_rotations[i].y - steering * steering_angle
	if steering_wheel:
		steering_wheel.rotation.z = -steering * 1.8
	if dashboard:
		dashboard.text = "%s   %03d\nRPM %04d" % ["R" if gear < 0 else "N" if gear == 0 else str(gear), roundi(absf(speed) * 3.6), roundi(rpm)]

func is_on_floor_direction(forward: Vector3) -> float:
	var normal := get_floor_normal()
	return -normal.dot(forward) / maxf(normal.y, 0.2)
