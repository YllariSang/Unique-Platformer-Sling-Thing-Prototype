extends CharacterBody2D

var health = 100
var is_yanked = false
var speed = 100.0
var direction = 1
var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")
var yank_safety_timer = 0.0

func _ready():
	if has_node("Area2D"):
		$Area2D.body_entered.connect(_on_body_entered)

func _on_body_entered(body):
	if body.name == "Player":
		if body.velocity.length() > 600:
			body.grace_period_timer = 0.2
			if body.has_method("restore_slow_mo_energy"):
				body.restore_slow_mo_energy(25.0)
			die()
		else:
			if body.has_method("take_damage"):
				body.take_damage(20.0)
				print("Enemy damaged player!")

func _physics_process(delta):
	if not is_on_floor() and not is_yanked:
		velocity.y += gravity * delta

	if not is_yanked:
		velocity.x = direction * speed
		move_and_slide()
		if is_on_wall():
			direction *= -1
	else:
		if yank_safety_timer > 0:
			yank_safety_timer -= delta
		
		var collision = move_and_collide(velocity * delta)
		if collision:
			if yank_safety_timer <= 0 and velocity.length() > 600:
				die()
			velocity = Vector2.ZERO
			is_yanked = false

func die():
	Engine.time_scale = 0.05
	var camera = get_viewport().get_camera_2d()
	if camera and camera.has_method("apply_shake"):
		camera.apply_shake(15.0)
	await get_tree().create_timer(0.1, true, false, true).timeout
	Engine.time_scale = 1.0
	queue_free()

func apply_yank(force_vector: Vector2):
	is_yanked = true
	velocity = force_vector
	yank_safety_timer = 0.032
