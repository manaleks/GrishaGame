extends Node
class_name Health

signal died
signal changed(current: int, max: int)

@export var max_health: int = 100
var current_health: int

func _ready() -> void:
	current_health = max_health

func apply_damage(amount: int) -> void:
	if current_health <= 0:
		return
	current_health = max(0, current_health - amount)
	changed.emit(current_health, max_health)
	if current_health == 0:
		died.emit()

func heal(amount: int) -> void:
	current_health = min(max_health, current_health + amount)
	changed.emit(current_health, max_health)

func is_dead() -> bool:
	return current_health <= 0
