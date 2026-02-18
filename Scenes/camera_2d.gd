extends Camera2D

@export var follow_speed: float = 5.0
@export var max_cursor_pull: float = 150.0 
@onready var player = get_parent()

var shake_intensity = 0.0
var shake_fade = 5.0

func _process(delta):
	# 1. Handle Camera Shake
	if shake_intensity > 0:
		offset = Vector2(randf_range(-1, 1) * shake_intensity, randf_range(-1, 1) * shake_intensity)
		shake_intensity = lerp(shake_intensity, 0.0, shake_fade * delta)
	else:
		offset = Vector2.ZERO

	# 2. Handle Cursor-Focused Look-Ahead
	if player:
		var mouse_pos = get_local_mouse_position()
		
		var target_offset = mouse_pos.limit_length(max_cursor_pull)
		
		if player.get_real_velocity().length() > 500:
			target_offset *= 1.2 
		
		position = position.lerp(target_offset, follow_speed * delta)

func apply_shake(intensity: float):
	shake_intensity = intensity
