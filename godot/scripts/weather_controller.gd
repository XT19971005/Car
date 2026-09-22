extends Node3D
var mode := "clear"
var target_rain := 0.0
var rain_amount := 0.0
var camera_position := Vector3.ZERO
@onready var world: WorldEnvironment = $WorldEnvironment
@onready var sun: DirectionalLight3D = $Sun
@onready var rain: GPUParticles3D = $Rain

func set_weather(key: String) -> void:
	mode = key
	target_rain = 1.0 if key == "rain" else 0.0
	var material: ShaderMaterial = world.environment.sky.sky_material
	material.set_shader_parameter("cloud_cover", .26 if key == "clear" else .94)
	material.set_shader_parameter("storm", 1.0 if key == "rain" else .38 if key == "overcast" else 0.0)
	sun.light_energy = 1.25 if key == "clear" else .28 if key == "overcast" else .13
	sun.light_color = Color("fff1d1") if key == "clear" else Color("c7d9ee")
	world.environment.fog_density = .00005 if key == "clear" else .00018 if key == "overcast" else .00045
	world.environment.ambient_light_energy = .38 if key == "clear" else .65
	world.environment.ssr_enabled = key == "rain"
	rain.emitting = key == "rain"
	RenderingServer.global_shader_parameter_set("weather_wetness", 1.0 if key == "rain" else 0.0)

func _process(dt: float) -> void:
	rain_amount = move_toward(rain_amount, target_rain, dt * .7)
	rain.global_position = camera_position + Vector3.UP * 7
	rain.visible = camera_position.x < 9000
