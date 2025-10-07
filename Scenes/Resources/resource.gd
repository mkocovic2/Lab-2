extends Area2D

@export var resource_amount = 5
@export var respawn_time = 10.0
@export var respawn_amount = 5

var current_amount = resource_amount
var is_depleted = false

@onready var sprite = $Sprite2D

func _ready():
	add_to_group("resources")

func is_available() -> bool:
	"""Check if resource can be picked up"""
	return current_amount > 0 and not is_depleted

func pickup() -> bool:
	"""Attempt to pick up one unit of resource"""
	if not is_available():
		return false
	
	current_amount -= 1
	
	if current_amount <= 0:
		is_depleted = true
		handle_depletion()
	
	return true

func handle_depletion():
	"""Handle resource running out"""
	if respawn_time > 0:
		hide()
		await get_tree().create_timer(respawn_time).timeout
		respawn()
	else:
		hide()

func respawn():
	"""Respawn the resource"""
	current_amount = respawn_amount
	is_depleted = false
	show()
