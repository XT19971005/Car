extends Node3D
func _ready() -> void:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_texture = $Viewport.get_texture()
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	$Screen.material_override = material
func update_readout(gear: int, speed: float, rpm: float) -> void:
	$Viewport/Display.gear = gear
	$Viewport/Display.speed = int(absf(speed) * 3.6)
	$Viewport/Display.rpm = int(rpm)
	$Viewport/Display.queue_redraw()
