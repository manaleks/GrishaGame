extends CharacterBody3D

@export var move_speed: float = 3.5
@export var gravity: float = 9.8
@export var sight_range: float = 25.0
@export var fov_deg: float = 100.0
@export var attack_range: float = 18.0
@export var fire_interval: float = 0.9
@export var fire_damage: int = 12
@export var aim_error_deg: float = 3.0

@onready var health: Health = $Health
@onready var eyes: Marker3D = $Eyes
@onready var vision_ray: RayCast3D = $Eyes/VisionRay
@onready var mesh: MeshInstance3D = $Mesh
@onready var shot_sound: AudioStreamPlayer3D = $ShotSound

var player: Node3D = null
var _fire_cooldown: float = 0.0
var _last_known_player_pos: Vector3 = Vector3.ZERO
var _has_seen_player: bool = false

func _ready() -> void:
	add_to_group("bots")
	health.died.connect(_on_died)
	call_deferred("_find_player")

func _find_player() -> void:
	var players := get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		player = players[0]

func _physics_process(delta: float) -> void:
	if health.is_dead():
		return
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = 0.0

	if player == null:
		_find_player()
		move_and_slide()
		return

	var can_see := _can_see_player()
	if can_see:
		_has_seen_player = true
		_last_known_player_pos = player.global_transform.origin

	if _has_seen_player:
		var to_target := _last_known_player_pos - global_transform.origin
		to_target.y = 0
		var dist := to_target.length()
		if dist > 0.1:
			look_at(Vector3(_last_known_player_pos.x, global_transform.origin.y, _last_known_player_pos.z), Vector3.UP)
		if dist > attack_range * 0.6:
			var dir := to_target.normalized()
			velocity.x = dir.x * move_speed
			velocity.z = dir.z * move_speed
		else:
			velocity.x = move_toward(velocity.x, 0, move_speed * 8.0 * delta)
			velocity.z = move_toward(velocity.z, 0, move_speed * 8.0 * delta)

		if can_see and dist <= attack_range:
			_try_fire(delta)
	else:
		velocity.x = move_toward(velocity.x, 0, move_speed * 8.0 * delta)
		velocity.z = move_toward(velocity.z, 0, move_speed * 8.0 * delta)

	if _fire_cooldown > 0.0:
		_fire_cooldown -= delta

	move_and_slide()

func _can_see_player() -> bool:
	if player == null:
		return false
	var to_player := player.global_transform.origin - eyes.global_transform.origin
	var dist := to_player.length()
	if dist > sight_range:
		return false
	var forward := -eyes.global_transform.basis.z
	var angle := rad_to_deg(forward.angle_to(to_player.normalized()))
	if angle > fov_deg * 0.5:
		return false
	vision_ray.target_position = vision_ray.to_local(player.global_transform.origin + Vector3.UP * 0.9)
	vision_ray.force_raycast_update()
	if vision_ray.is_colliding():
		var collider = vision_ray.get_collider()
		if collider != player and not collider.is_in_group("player"):
			return false
	return true

func _try_fire(delta: float) -> void:
	if _fire_cooldown > 0.0:
		return
	_fire_cooldown = fire_interval
	shot_sound.pitch_scale = randf_range(0.95, 1.08)
	shot_sound.play()
	if player and player.has_method("apply_hit"):
		var space_state := get_world_3d().direct_space_state
		var from := eyes.global_transform.origin
		var to := player.global_transform.origin + Vector3.UP * 0.9
		var query := PhysicsRayQueryParameters3D.create(from, to)
		query.exclude = [get_rid()]
		var result := space_state.intersect_ray(query)
		if result and (result.get("collider") == player or result.get("collider").is_in_group("player")):
			player.apply_hit(fire_damage, to)

func apply_hit(amount: int, _pos: Vector3) -> void:
	health.apply_damage(amount)

func _on_died() -> void:
	set_physics_process(false)
	if mesh:
		mesh.rotation.z = deg_to_rad(90)
	collision_layer = 0
	collision_mask = 1
	await get_tree().create_timer(3.0).timeout
	queue_free()
