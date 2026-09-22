extends Node3D
var vehicle_body: Node3D
var camera_point := Vector3.ZERO
var side := 1.0
var surface: MeshInstance3D
var live_material: ShaderMaterial
func _ready() -> void:
	$Viewport.world_3d = get_world_3d()
func bind_surface(glass: MeshInstance3D) -> void:
	surface = glass
	glass.layers = 2
	glass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material := ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = "shader_type spatial; render_mode unshaded; uniform sampler2D mirror_image : source_color, filter_linear; void fragment(){ ALBEDO = texture(mirror_image, vec2(1.0-UV.x, UV.y)).rgb; }"
	material.shader = shader
	material.set_shader_parameter("mirror_image", $Viewport.get_texture())
	live_material = material
func update_view(active: bool) -> void:
	$Viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if active else SubViewport.UPDATE_DISABLED
	if surface: surface.material_override = live_material if active else null
	if not active or not vehicle_body: return
	var camera := $Viewport/Camera as Camera3D
	camera.global_position = vehicle_body.to_global(camera_point)
	camera.look_at(camera.global_position + vehicle_body.global_basis * Vector3(side*.22,-.015,-1.0), Vector3.UP)
