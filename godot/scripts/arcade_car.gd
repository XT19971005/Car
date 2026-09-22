extends CharacterBody3D
## Assisted arcade handling. Heading and lateral momentum are separate, with swept collisions.
const TOP_SPEED := 76.0
var surface_wetness := 0.0
var speed := 0.0
var heading := 0.0
var steering := 0.0
var throttle := 0.0
var brake := 0.0
var yaw_rate := 0.0
var rpm := 950.0
const RATIOS: Array[float] = [0.0, 3.10, 2.12, 1.55, 1.20, 0.98, 0.82]
var automatic_gears := true
var gear := 0
var shift_timer := 0.0
var chassis_collision: CollisionShape3D
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
var dashboard: Node3D
var acceleration_feedback := 0.0
var impact_feedback := 0.0
var shift_feedback := 0.0

func _ready() -> void:
	floor_snap_length = 1.2
	floor_max_angle = deg_to_rad(55)
	floor_constant_speed = true
	safe_margin = 0.025
	var collider := CollisionShape3D.new()
	chassis_collision = collider
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
	if chassis_collision:
		var hull := chassis_collision.shape as CapsuleShape3D
		hull.radius = float(profile.width) * .41
		hull.height = float(profile.length) - .24
		chassis_collision.position.y = hull.radius + .03
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
	dashboard = preload("res://scenes/CockpitDisplay.tscn").instantiate()
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
	gear = 1
	downshift_hold = 0.0
	shift_timer = 0.0
	impact_feedback = 0.0
	shift_feedback = 0.0
	acceleration_feedback = 0.0
	if body_visual:
		body_visual.rotation = Vector3.ZERO
	reset_physics_interpolation()

var downshift_hold := 0.0

func request_downshift() -> bool:
	if gear <= 1: return false
	if not shift_gear(-1): return false
	downshift_hold = 2.0
	return true

func shift_gear(direction: int) -> bool:
	if shift_timer > 0: return false
	var next := clampi(gear + direction, -1, 6)
	if next == gear: return false
	if next <= 0 and absf(speed) > 1.0: return false
	if speed < -1.0: return false
	if next > 0 and absf(speed) / 2.05 * 60.0 * RATIOS[next] * 3.4 > 7800: return false
	gear = next
	shift_timer = .18
	shift_feedback = 1.0
	return true

func drive(dt: float, gas: float, stopping: float, turn: float, handbrake: bool, offroad: bool) -> void:
	steering = move_toward(steering, turn, dt * (3.8 if absf(turn) > 0.05 else 10.0))
	throttle = move_toward(throttle, gas, dt * 2.8)
	brake = move_toward(brake, stopping, dt * 6.0)
	var forward := Vector3(sin(heading), 0, cos(heading))
	var right := Vector3(forward.z, 0, -forward.x)
	var longitudinal := velocity.dot(forward)
	var lateral := velocity.dot(right)
	var grip := (3.0 if offroad else float(profile.grip)) * lerpf(1.0, .74, surface_wetness)
	if handbrake:
		grip *= 0.32
	var max_velocity := 28.0 if offroad else float(profile.top_speed)
	if brake > 0.05:
		if not automatic_gears:
			longitudinal = move_toward(longitudinal, 0.0, brake * 22.0 * lerpf(1.0, .82, surface_wetness) * dt)
		elif longitudinal > 0.3:
			longitudinal = move_toward(longitudinal, 0.0, brake * 22.0 * lerpf(1.0, .82, surface_wetness) * dt)
		elif throttle < 0.05:
			longitudinal = move_toward(longitudinal, -9.0, brake * 6.0 * dt)
	elif throttle > 0.02 and (automatic_gears or gear != 0):
		if not automatic_gears and gear == -1:
			longitudinal = move_toward(longitudinal, -9.0, throttle * 6.0 * dt)
		elif longitudinal < -0.2:
			longitudinal = move_toward(longitudinal, 0.0, throttle * 18.0 * dt)
		else:
			var gear_limit := 7800.0 * 2.05 / (60.0 * RATIOS[maxi(gear, 1)] * 3.4)
			var drive_scale := clampf(RATIOS[maxi(gear, 1)] / RATIOS[1], .15, 1.0)
			var coupled_rpm := absf(longitudinal) / 2.05 * 60.0 * RATIOS[maxi(gear, 1)] * 3.4
			drive_scale *= lerpf(.25, 1.0, clampf(coupled_rpm / 2500.0, 0.0, 1.0)) if gear > 1 else 1.0
			if shift_timer > 0: drive_scale *= .18
			longitudinal = move_toward(longitudinal, minf(max_velocity, gear_limit), maxf(3.0, float(profile.acceleration) - longitudinal * 0.1) * throttle * drive_scale * dt)
	else:
		longitudinal = move_toward(longitudinal, 0.0, (0.7 + absf(longitudinal) * 0.025) * dt)
	if offroad and absf(longitudinal) > max_velocity:
		longitudinal = move_toward(longitudinal, signf(longitudinal) * max_velocity, dt * 12.0)
	if handbrake:
		longitudinal = move_toward(longitudinal, 0.0, dt * 9.0)
	var steering_angle := .55 / (1.0 + pow(absf(longitudinal) / 22.0, 2.0))
	# Model forward is +Z; a driver's right turn rotates toward -X.
	var desired_yaw := -steering * longitudinal / float(profile.wheelbase) * tan(steering_angle)
	var yaw_limit := minf(1.5, grip * 1.65 * (1.0 - brake * .20) / maxf(absf(longitudinal), 3.0))
	desired_yaw = clampf(desired_yaw, -yaw_limit, yaw_limit)
	yaw_rate = lerpf(yaw_rate, desired_yaw, 1.0 - exp(-dt * (12.0 if not offroad else 6.0)))
	heading += yaw_rate * dt
	# Resolve tyre forces in the updated vehicle frame, then damp sideslip.
	var momentum := forward * longitudinal + right * lateral
	forward = Vector3(sin(heading), 0, cos(heading))
	right = Vector3(forward.z, 0, -forward.x)
	longitudinal = momentum.dot(forward)
	lateral = momentum.dot(right) * exp(-grip * 2.0 * dt)
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
	downshift_hold = maxf(0, downshift_hold - dt)
	shift_feedback = move_toward(shift_feedback, 0, dt * 7)
	var old_gear := gear
	var ratio := RATIOS
	if automatic_gears:
		if speed < -0.3:
			gear = -1
		elif absf(speed) < 0.4 and throttle < 0.05:
			gear = 1
		else:
			gear = maxi(gear, 1)
			var predicted := absf(speed) / 2.05 * 60.0 * ratio[gear] * 3.4
			if shift_timer <= 0:
				if predicted > 7200 and gear < 6 and (downshift_hold <= 0 or predicted > 7700):
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
	body_visual.rotation.z = lerpf(body_visual.rotation.z, clampf(yaw_rate * speed * 0.001, -0.035, 0.035), 1 - exp(-dt * 6))
	wheel_roll += speed * dt / 0.34
	for i in wheel_nodes.size():
		wheel_nodes[i].rotation.x = wheel_rotations[i].x + wheel_roll
		if "front" in wheel_nodes[i].name:
			wheel_nodes[i].rotation.y = wheel_rotations[i].y - steering * steering_angle
	if steering_wheel:
		steering_wheel.rotation.z = -steering * 1.8
	if dashboard:
		dashboard.update_readout(gear, speed, rpm)

func is_on_floor_direction(forward: Vector3) -> float:
	var normal := get_floor_normal()
	return -normal.dot(forward) / maxf(normal.y, 0.2)
