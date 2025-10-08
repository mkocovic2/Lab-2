extends CharacterBody2D

enum State {
	IDLE,
	SEEKING_RESOURCE,
	MOVING_TO_RESOURCE,
	PICKING_UP,
	SEEKING_HOUSE,
	MOVING_TO_HOUSE,
	DELIVERING
}

var current_state = State.IDLE
var speed = 80.0
var detection_radius = 400.0

var carrying_resource = false
var target_resource = null
var target_house = null
var committed_house = null 

@onready var animated_sprite = $AnimatedSprite2D

func _ready():
	# Add to builders group so we can find all builders later
	add_to_group("builders")
	# Small random offset so builders don't overlap exactly
	position += Vector2(randf_range(-10, 10), randf_range(-10, 10))

func _physics_process(delta):
	# Handles behavior based on current state (enum)
	match current_state:
		State.IDLE:
			handle_idle_state()
		
		State.SEEKING_RESOURCE:
			handle_seeking_resource_state()
		
		State.MOVING_TO_RESOURCE:
			handle_moving_to_resource_state(delta)
		
		State.PICKING_UP:
			handle_picking_up_state()
		
		State.SEEKING_HOUSE:
			handle_seeking_house_state()
		
		State.MOVING_TO_HOUSE:
			handle_moving_to_house_state(delta)
		
		State.DELIVERING:
			handle_delivering_state()
	
	# Update sprite based on movement and carrying status
	update_appearance()

func handle_idle_state():
	"""Decide what to do when idle"""
	velocity = Vector2.ZERO
	
	# If carrying something, look for a house to deliver to
	if carrying_resource:
		if committed_house and is_instance_valid(committed_house) and committed_house.has_method("needs_resources") and committed_house.needs_resources():
			target_house = committed_house
			current_state = State.MOVING_TO_HOUSE
		else:
			current_state = State.SEEKING_HOUSE
	else:
		# Not carrying anything, go look for resources
		current_state = State.SEEKING_RESOURCE

func handle_seeking_resource_state():
	"""Find the nearest available resource"""
	velocity = Vector2.ZERO
	target_resource = find_nearest_resource()
	
	if target_resource:
		# Found one, go get it
		current_state = State.MOVING_TO_RESOURCE
	else:
		# Nothing available right now
		current_state = State.IDLE

func handle_moving_to_resource_state(delta):
	"""Move toward the target resource"""
	# Check if target is still valid
	if not is_instance_valid(target_resource) or (target_resource.has_method("is_available") and not target_resource.is_available()):
		current_state = State.SEEKING_RESOURCE
		return
	
	# Calculate movement toward resource
	var desired_velocity = get_steering_toward_target(target_resource.global_position)
	velocity = desired_velocity
	velocity = velocity.limit_length(speed)
	
	move_and_slide()
	
	# Close enough to pick up
	if global_position.distance_to(target_resource.global_position) < 20.0:
		current_state = State.PICKING_UP

func handle_picking_up_state():
	velocity = Vector2.ZERO
	"""Pick up the resource"""
	if is_instance_valid(target_resource):
		if target_resource.has_method("pickup"):
			# Try to pick it up
			if target_resource.pickup():
				carrying_resource = true
				# Go straight to committed house if it still needs resources
				if committed_house and is_instance_valid(committed_house) and committed_house.has_method("needs_resources") and committed_house.needs_resources():
					target_house = committed_house
					current_state = State.MOVING_TO_HOUSE
				else:
					current_state = State.SEEKING_HOUSE
			else:
				# Pickup failed, find another resource
				target_resource = null
				current_state = State.SEEKING_RESOURCE
	else:
		current_state = State.SEEKING_RESOURCE

func handle_seeking_house_state():
	"""Find a house to commit to"""
	velocity = Vector2.ZERO
	
	# Check if we need a new house commitment
	if not committed_house or not is_instance_valid(committed_house) or (committed_house.has_method("needs_resources") and not committed_house.needs_resources()):
		committed_house = find_nearest_incomplete_house()
		target_house = committed_house
	
	if target_house:
		current_state = State.MOVING_TO_HOUSE
	else:
		# No houses need resources right now
		current_state = State.IDLE

func handle_moving_to_house_state(delta):
	"""Move toward the committed house"""
	# Validate house still needs resources
	if not is_instance_valid(committed_house) or (committed_house.has_method("needs_resources") and not committed_house.needs_resources()):
		committed_house = null
		target_house = null
		current_state = State.SEEKING_HOUSE
		return
	
	# Make sure we're targeting our committed house
	if target_house != committed_house:
		target_house = committed_house
	
	# Move toward house
	var desired_velocity = get_steering_toward_target(target_house.global_position)
	velocity = desired_velocity
	velocity = velocity.limit_length(speed)
	
	move_and_slide()
	
	# Close enough to deliver
	if global_position.distance_to(target_house.global_position) < 25.0:
		current_state = State.DELIVERING

func handle_delivering_state():
	"""Deliver the resource to the house"""
	velocity = Vector2.ZERO
	
	if is_instance_valid(target_house):
		if target_house.has_method("deliver_resource"):
			# Drop off the resource
			target_house.deliver_resource()
			carrying_resource = false
			
			# Check if house needs more resources
			if target_house.has_method("needs_resources") and target_house.needs_resources():
				current_state = State.SEEKING_RESOURCE
			else:
				# House is complete, find a new one
				committed_house = null
				target_house = null
				current_state = State.SEEKING_HOUSE
	else:
		# House disappeared somehow
		carrying_resource = false
		committed_house = null
		target_house = null
		current_state = State.SEEKING_HOUSE

func get_steering_toward_target(target_pos: Vector2) -> Vector2:
	"""Calculate steering force toward a target position"""
	var desired_direction = (target_pos - global_position).normalized()
	return desired_direction * speed

func find_nearest_resource():
	"""Find closest resource within detection radius"""
	var resources = get_tree().get_nodes_in_group("resources")
	var nearest = null
	var nearest_distance = detection_radius
	
	for resource in resources:
		# Only consider available resources
		if resource.has_method("is_available") and resource.is_available():
			var distance = global_position.distance_to(resource.global_position)
			if distance < nearest_distance:
				nearest = resource
				nearest_distance = distance
	
	return nearest

func find_nearest_incomplete_house():
	"""Find closest house that needs resources - first check nearby, then check everywhere"""
	var houses = get_tree().get_nodes_in_group("houses")
	var nearest = null
	var nearest_distance = INF
	
	# First pass: look for houses within detection radius
	for house in houses:
		if house.has_method("needs_resources") and house.needs_resources():
			var distance = global_position.distance_to(house.global_position)
			
			if distance <= detection_radius:
				if nearest == null or distance < nearest_distance:
					nearest = house
					nearest_distance = distance
	
	# Second pass: if nothing nearby, search the whole map
	if nearest == null:
		for house in houses:
			if house.has_method("needs_resources") and house.needs_resources():
				var distance = global_position.distance_to(house.global_position)
				if nearest == null or distance < nearest_distance:
					nearest = house
					nearest_distance = distance
	
	return nearest

func update_appearance():
	"""Change animation based on state"""
	if not animated_sprite:
		return
	
	# Check if we're moving
	var is_moving = velocity.length() > 10.0 
	
	# Play appropriate animation
	if carrying_resource:
		if is_moving:
			animated_sprite.play("run_carry")
		else:
			animated_sprite.play("idle_carry")
	else:
		if is_moving:
			animated_sprite.play("run")
		else:
			animated_sprite.play("idle")
	
	# Face the direction we're moving
	if velocity.x < 0:
		animated_sprite.flip_h = true
	elif velocity.x > 0:
		animated_sprite.flip_h = false
