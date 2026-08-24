extends Node3D

const SPEED: float = 140.0

var _from: Vector3
var _to: Vector3
var _t: float = 0.0
var _duration: float = 0.05

func setup(from: Vector3, to: Vector3) -> void:
	_from = from
	_to = to
	var dist := from.distance_to(to)
	_duration = max(0.02, dist / SPEED)
	global_transform.origin = from

func _process(delta: float) -> void:
	_t += delta
	var f: float = clamp(_t / _duration, 0.0, 1.0)
	global_transform.origin = _from.lerp(_to, f)
	if f >= 1.0:
		queue_free()
