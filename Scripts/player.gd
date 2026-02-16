extends CharacterBody2D

@export var point_scene: PackedScene = preload("res://Scenes/pressure_point.tscn")
var active_points: Array[Node2D] = []

var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")
var jump_velocity = -400.0

# Propulsion and Grace Period variables
var is_propelling = false
var propulsion_speed = 1200.0
var walk_speed = 250.0 
var grace_period_timer = 0.0

func _physics_process(delta):
	# Manage grace period timer
	if grace_period_timer > 0:
		grace_period_timer -= delta

	if not is_on_floor():
		velocity.y += gravity * delta

	var dir = Input.get_axis("left", "right")
	if not is_propelling:
		velocity.x = dir * walk_speed
	
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = jump_velocity

	# Robust collision and Slam Damage
	var collision = move_and_collide(velocity * delta)
	if collision:
		if is_propelling and velocity.length() > 600:
			take_slam_damage()
		velocity = Vector2.ZERO
		is_propelling = false

	move_and_slide()

	$TagRay.look_at(get_global_mouse_position())

	if Input.is_action_just_pressed("fire_tag"):
		place_tag()
	if Input.is_action_just_pressed("self_tag"):
		place_self_tag()
	if Input.is_action_just_pressed("execute"):
		collapse_tags()
		
	update_tethers()
	update_fling_indicators()

func place_tag():
	if $TagRay.is_colliding():
		var target = $TagRay.get_collider()
		var pos = $TagRay.get_collision_point()
		spawn_point(target, pos)

func place_self_tag():
	spawn_point(self, global_position)

func spawn_point(target: Node, pos: Vector2):
	var p = point_scene.instantiate()
	get_tree().current_scene.add_child(p)
	p.global_position = pos
	p.reparent(target)
	active_points.append(p)
	if active_points.size() > 3:
		active_points.pop_front().queue_free()

func collapse_tags():
	if active_points.size() < 2: return
	
	var center = Vector2.ZERO
	for p in active_points:
		center += p.global_position
	center /= active_points.size()
	
	for p in active_points:
		var parent = p.get_parent()
		if parent == self:
			is_propelling = true
			velocity = (center - global_position).normalized() * propulsion_speed
		elif parent.has_method("apply_yank"):
			var yank_dir = (center - p.global_position).normalized()
			parent.apply_yank(yank_dir * 1800)
		p.play_implode()
	
	active_points.clear()

func take_slam_damage():
	# Grace period prevents taking slam damage immediately after a kinetic strike
	if grace_period_timer > 0: return
	
	print("Player slammed into a wall! Ouch!")
	if has_node("Camera2D"):
		$Camera2D.apply_shake(10.0)

func update_tethers():
	var line = $Line2D
	line.clear_points()
	if active_points.size() < 2: return
	for p in active_points:
		if is_instance_valid(p):
			line.add_point(to_local(p.global_position))
	if active_points.size() == 3 and is_instance_valid(active_points[0]):
		line.add_point(to_local(active_points[0].global_position))

func update_fling_indicators():
	if not has_node("FlingLine"): return
	var fling_line = $FlingLine
	fling_line.clear_points()
	if active_points.size() < 2: return
	
	var center = Vector2.ZERO
	for p in active_points:
		center += p.global_position
	center /= active_points.size()
	
	# Visual Warning: Change line color if player is on path to hit a wall
	var player_tagged = false
	for p in active_points:
		if p.get_parent() == self:
			player_tagged = true
			break
	
	if player_tagged:
		var space_state = get_world_2d().direct_space_state
		var query = PhysicsRayQueryParameters2D.create(global_position, center)
		# Filter out the player's own collision
		query.exclude = [get_rid()]
		var result = space_state.intersect_ray(query)
		
		# If ray hits environment before reaching center, turn line red
		if result and result.collider is TileMapLayer:
			fling_line.default_color = Color(1, 0, 0, 0.7) # Red warning
		else:
			fling_line.default_color = Color(1, 1, 1, 0.5) # Default white
	
	for p in active_points:
		if is_instance_valid(p):
			fling_line.add_point(to_local(p.global_position))
			fling_line.add_point(to_local(center))
			fling_line.add_point(to_local(center))
