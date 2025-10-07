extends Area2D

@export var resources_needed = 10
@export var construction_complete_scene: PackedScene

var resources_collected = 0
var is_complete = false

@onready var sprite = $AnimatedSprite2D

func _ready():
	add_to_group("houses")

func needs_resources() -> bool:
	"""Check if house still needs resources"""
	return not is_complete and resources_collected < resources_needed

func deliver_resource():
	"""Accept a delivered resource"""
	if not needs_resources():
		return
	
	resources_collected += 1
	
	if resources_collected >= resources_needed:
		complete_construction()

func complete_construction():
	"""Handle construction completion"""
	is_complete = true
	
	if sprite:
		sprite.play("built")
	
	print("House completed at: ", global_position)

func get_progress() -> float:
	"""Returns progress as 0.0 to 1.0"""
	return float(resources_collected) / float(resources_needed)
