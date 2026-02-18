extends CharacterBody2D

# --- Cursor Assets ---
@export var cursor_normal: Texture2D = preload("res://Assets/cursor_normal.png")
@export var cursor_ready: Texture2D = preload("res://Assets/cursor_ready.png")

@export var point_scene: PackedScene = preload("res://Scenes/pressure_point.tscn")
@export var snap_radius: float = 50.0
@export var max_tether_distance: float = 600.0 

# --- HUD & Health Variables ---
@export var max_health: float = 100.0
var current_health: float = 100.0

@onready var health_bar = get_node_or_null("/root/Main/HUD/VBoxContainer/HealthBar")
@onready var focus_bar = get_node_or_null("/root/Main/HUD/VBoxContainer/FocusBar")

# --- Slow Motion Resource Variables ---
@export var max_slow_mo_energy: float = 100.0
@export var slow_mo_drain_rate: float = 50.0   
@export var slow_mo_recharge_rate: float = 20.0 
var current_slow_mo_energy: float = 100.0
var can_use_slow_mo: bool = true
@export var slow_mo_scale: float = 0.3 
var is_slow_mo: bool = false

# --- Physics & Movement Variables ---
var active_points: Array[Node2D] = []
var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")
var jump_velocity = -400.0

var is_propelling = false
var propulsion_speed = 1400.0 
var propulsion_active_timer = 0.0 

var walk_speed = 250.0
var grace_period_timer = 0.0
var is_cursor_ready_state: bool = false

# --- Hold-to-Self-Tag Variables ---
@export var self_tag_hold_time: float = 0.25
var tag_hold_timer: float = 0.0
var has_self_tagged_this_press: bool = false

func _ready():
	update_cursor_visuals(false)
	if health_bar: health_bar.max_value = max_health
	if focus_bar: focus_bar.max_value = max_slow_mo_energy

func _physics_process(delta):
	if health_bar: health_bar.value = current_health
	if focus_bar: focus_bar.value = current_slow_mo_energy

	handle_slow_mo_logic(delta)
	
	if grace_period_timer > 0:
		grace_period_timer -= delta

	# 1. Gravity Handling
	if not is_on_floor():
		if is_propelling:
			velocity.y += (gravity * 0.2) * delta 
			propulsion_active_timer -= delta
			if propulsion_active_timer <= 0:
				is_propelling = false 
		else:
			velocity.y += gravity * delta
	else:
		if propulsion_active_timer < 0.2:
			is_propelling = false
			propulsion_active_timer = 0.0

	# 2. Movement handling
	var dir = Input.get_axis("left", "right")
	
	if not is_propelling:
		var pushing_into_wall = is_on_wall() and sign(dir) == -sign(get_wall_normal().x)
		if dir != 0:
			if pushing_into_wall:
				velocity.x = 0
			else:
				velocity.x = dir * walk_speed
		else:
			velocity.x = move_toward(velocity.x, 0, walk_speed)
	
	# 3. Jump handling
	if Input.is_action_just_pressed("ui_accept"):
		if is_on_floor():
			is_propelling = false 
			velocity.y = jump_velocity

	move_and_slide()

	# 4. Impact Detection
	if get_real_velocity().length() > 800 and not is_on_floor() and is_on_wall_or_ceiling():
		take_slam_damage()
		is_propelling = false
		velocity = Vector2.ZERO

	check_tether_distances()

	$TagRay.look_at(get_global_mouse_position())
	update_cursor_visuals($TagRay.is_colliding())

	# 5. Tagging Logic
	if Input.is_action_pressed("fire_tag"):
		tag_hold_timer += delta
		if tag_hold_timer >= self_tag_hold_time and not has_self_tagged_this_press:
			place_self_tag()
			has_self_tagged_this_press = true
	
	if Input.is_action_just_released("fire_tag"):
		if tag_hold_timer < self_tag_hold_time:
			place_tag()
		tag_hold_timer = 0.0
		has_self_tagged_this_press = false

	if Input.is_action_just_pressed("execute"):
		collapse_tags()
		
	update_tethers()
	update_fling_indicators()

func is_on_wall_or_ceiling() -> bool:
	return is_on_wall() or is_on_ceiling()

func collapse_tags():
	if is_slow_mo:
		toggle_slow_mo()
	
	if active_points.size() < 2: return
	
	var center = Vector2.ZERO
	var valid_points = active_points.filter(func(p): return is_instance_valid(p))
	
	if valid_points.size() < 2: return
	
	for p in valid_points:
		center += p.global_position
	center /= valid_points.size()
	
	for p in valid_points:
		var parent = p.get_parent()
		if parent == self:
			velocity = Vector2.ZERO 
			is_propelling = true
			propulsion_active_timer = 0.5 
			var fling_direction = (center - global_position).normalized()
			velocity = fling_direction * propulsion_speed
		elif parent.has_method("apply_yank"):
			var yank_dir = (center - p.global_position).normalized()
			parent.apply_yank(yank_dir * 1800)
		if p.has_method("play_implode"):
			p.play_implode()
			
	active_points.clear()

func take_damage(amount: float):
	current_health -= amount
	if has_node("Camera2D"):
		$Camera2D.apply_shake(5.0)
	if current_health <= 0:
		get_tree().reload_current_scene()

func take_slam_damage():
	if grace_period_timer > 0: return
	take_damage(15.0) 
	if has_node("Camera2D"):
		$Camera2D.apply_shake(10.0)

func handle_slow_mo_logic(delta):
	if Input.is_action_just_pressed("slow_mo") and can_use_slow_mo:
		toggle_slow_mo()
	if is_slow_mo:
		current_slow_mo_energy -= slow_mo_drain_rate * (delta / Engine.time_scale)
		if current_slow_mo_energy <= 0:
			current_slow_mo_energy = 0
			toggle_slow_mo()
			can_use_slow_mo = false 
	else:
		current_slow_mo_energy += slow_mo_recharge_rate * delta
		current_slow_mo_energy = clamp(current_slow_mo_energy, 0, max_slow_mo_energy)
		if current_slow_mo_energy >= 20.0:
			can_use_slow_mo = true

func toggle_slow_mo():
	is_slow_mo = !is_slow_mo
	Engine.time_scale = slow_mo_scale if is_slow_mo else 1.0
	modulate = Color(0.7, 0.8, 1.0) if is_slow_mo else Color.WHITE

func restore_slow_mo_energy(amount: float):
	current_slow_mo_energy = clamp(current_slow_mo_energy + amount, 0, max_slow_mo_energy)
	var tween = create_tween()
	tween.tween_property(self, "modulate", Color.GREEN, 0.05)
	tween.tween_property(self, "modulate", Color.WHITE if not is_slow_mo else Color(0.7, 0.8, 1.0), 0.1)

func check_tether_distances():
	var points_to_remove = []
	for p in active_points:
		if is_instance_valid(p):
			if global_position.distance_to(p.global_position) > max_tether_distance:
				points_to_remove.append(p)
	for p in points_to_remove:
		if p.has_method("play_implode"):
			p.play_implode()
		active_points.erase(p)

func update_cursor_visuals(can_place: bool):
	if can_place == is_cursor_ready_state:
		return
	is_cursor_ready_state = can_place
	var texture = cursor_ready if can_place else cursor_normal
	Input.set_custom_mouse_cursor(texture, Input.CURSOR_ARROW, Vector2(16, 16))

func place_tag():
	var mouse_pos = get_global_mouse_position()
	var target = null
	var pos = Vector2.ZERO
	var normal = Vector2.ZERO
	if $TagRay.is_colliding():
		target = $TagRay.get_collider()
		pos = $TagRay.get_collision_point()
		normal = $TagRay.get_collision_normal()
	if target == null:
		var space_state = get_world_2d().direct_space_state
		var query = PhysicsShapeQueryParameters2D.new()
		var circle = CircleShape2D.new()
		circle.radius = snap_radius
		query.shape = circle
		query.transform = Transform2D(0, mouse_pos)
		var results = space_state.intersect_shape(query)
		for result in results:
			if result.collider.has_method("apply_yank"):
				target = result.collider
				pos = target.global_position
				break
	if target != null:
		var final_pos = pos + (normal * 2.0)
		spawn_point(target, final_pos)

func place_self_tag():
	spawn_point(self, global_position)

func spawn_point(target: Node, pos: Vector2):
	if point_scene == null: return
	var p = point_scene.instantiate()
	get_tree().current_scene.add_child(p)
	p.global_position = pos
	p.reparent(target)
	active_points.append(p)
	if active_points.size() > 3:
		active_points.pop_front().queue_free()

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
		if is_instance_valid(p):
			center += p.global_position
	center /= active_points.size()
	
	var player_tagged = false
	for p in active_points:
		if is_instance_valid(p) and p.get_parent() == self:
			player_tagged = true
			break
	if player_tagged:
		var space_state = get_world_2d().direct_space_state
		var query = PhysicsRayQueryParameters2D.create(global_position, center)
		query.exclude = [get_rid()]
		var result = space_state.intersect_ray(query)
		if result and result.collider is TileMapLayer:
			fling_line.default_color = Color(1, 0, 0, 0.7)
		else:
			fling_line.default_color = Color(1, 1, 1, 0.5)
	for p in active_points:
		if is_instance_valid(p):
			fling_line.add_point(to_local(p.global_position))
			fling_line.add_point(to_local(center))
