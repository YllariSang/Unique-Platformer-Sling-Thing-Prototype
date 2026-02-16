extends Node2D

@onready var particles = $GPUParticles2D

func _ready():
	scale = Vector2.ZERO
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector2(1.2, 1.2), 0.1)
	tween.tween_property(self, "scale", Vector2.ONE, 0.05)

func play_implode():
	particles.amount_ratio = 2.0
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.1)
	tween.finished.connect(queue_free)
