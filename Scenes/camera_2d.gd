extends Camera2D

var shake_intensity = 0.0
var shake_fade = 5.0

func _process(delta):
	if shake_intensity > 0:
		offset = Vector2(randf_range(-1, 1) * shake_intensity, randf_range(-1, 1) * shake_intensity)
		shake_intensity = lerp(shake_intensity, 0.0, shake_fade * delta)
	else:
		offset = Vector2.ZERO

func apply_shake(intensity: float):
	shake_intensity = intensity
