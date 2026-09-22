extends Node3D
const KEYS := ["clear", "overcast", "rain", "sunset"]
var mode := "clear"
var target_rain := 0.0
var rain_amount := 0.0
var camera_position := Vector3.ZERO
@onready var world: WorldEnvironment = $WorldEnvironment
@onready var sun: DirectionalLight3D = $Sun
@onready var rain: GPUParticles3D = $Rain

func set_weather(key: String) -> void:
	if key not in KEYS: return
	mode = key
	target_rain = 1.0 if key == "rain" else 0.0
	var material: ShaderMaterial = world.environment.sky.sky_material
	material.set_shader_parameter("cloud_cover", .43 if key in ["clear", "sunset"] else 1.0)
	material.set_shader_parameter("horizon_warmth", 1.0 if key == "sunset" else 0.0)
	sun.rotation_degrees = Vector3(-11 if key == "sunset" else -24, -48, 0)
	material.set_shader_parameter("storm", 1.0 if key == "rain" else .62 if key == "overcast" else 0.0)
	sun.light_energy = 1.15 if key == "clear" else .32 if key == "overcast" else .16
	sun.light_color = Color("ffe5bd") if key == "clear" else Color("c7d9ee")
	world.environment.fog_density = .00014 if key == "clear" else .00028 if key == "overcast" else .00065
	world.environment.ambient_light_energy = .55 if key == "clear" else .72
	world.environment.fog_light_color = Color("9cafba") if key == "clear" else Color("7e909f") if key == "overcast" else Color("667c8c")
	world.environment.ambient_light_color = Color("99b5d3") if key == "clear" else Color("a2b4c7")
	world.environment.ssr_enabled = key == "rain"
	if key == "sunset":
		sun.light_energy = 1.3
		sun.light_color = Color("ffd09a")
		world.environment.fog_density = .00020
		world.environment.fog_light_color = Color("b2a092")
		world.environment.ambient_light_energy = .62
		world.environment.ambient_light_color = Color("aeb6d1")
	rain.emitting = key == "rain"
	RenderingServer.global_shader_parameter_set("weather_wetness", 1.0 if key == "rain" else 0.0)

func _process(dt: float) -> void:
	rain_amount = move_toward(rain_amount, target_rain, dt * .7)
	rain.global_position = camera_position + Vector3.UP * 7
	rain.visible = camera_position.x < 9000
