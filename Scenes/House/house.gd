extends Area2D

@export var resources_needed = 10
@export var construction_complete_scene: PackedScene

var resources_collected = 0
var is_complete = false

@onready var sprite = $AnimatedSprite2D
@onready var audio = $AudioStreamPlayer2D

func _ready():
	# Register with houses group so builders can find us
	add_to_group("houses")
	set_process_input(true)

func needs_resources() -> bool:
	"""Check if house still needs resources"""
	return not is_complete and resources_collected < resources_needed

func deliver_resource():
	"""Accept a delivered resource"""
	# Don't accept if already complete
	if not needs_resources():
		return
	
	# Increment resource count
	resources_collected += 1
	
	# Check if construction is finished
	if resources_collected >= resources_needed:
		complete_construction()

func complete_construction():
	"""Handle construction completion"""
	is_complete = true
	
	# Show completed building sprite
	sprite.play("built")
	
	# Play completion sound
	audio.stream = load("res://Assets/Audio/thankyou!.wav")
	audio.play()
	
	print("House completed at: ", global_position)

func get_progress() -> float:
	"""Returns progress as 0.0 to 1.0"""
	return float(resources_collected) / float(resources_needed)

func _input(event):
	# Check for left mouse clicks
	if event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			# Allow clicking completed houses to reset them
			if is_mouse_over() && is_complete:
				is_complete = false
				resources_collected = 0
				sprite.play("construction")
				# Play destruction sound
				audio.stream = load("res://Assets/Audio/noo!.wav")
				audio.play()

func is_mouse_over() -> bool:
	"""Check if mouse is hovering over this house"""
	var mouse_pos = get_global_mouse_position()
	var distance = global_position.distance_to(mouse_pos)
	# Simple radius check
	return distance < 20.0
