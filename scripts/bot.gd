extends CharacterBody3D

const TracerScene := preload("res://scenes/tracer.tscn")

enum State { PATROL, CHASE, SEARCH }

@export var move_speed: float = 3.5
@export var patrol_speed: float = 1.8
@export var gravity: float = 9.8
@export var sight_range: float = 25.0
@export var fov_deg: float = 100.0
@export var attack_range: float = 18.0
@export var fire_interval: float = 0.9
@export var fire_damage: int = 12
@export var aim_error_deg: float = 3.0
@export var magazine_size: int = 10
@export var reload_time: float = 1.8
@export var patrol_radius: float = 7.0
@export var search_duration: float = 5.0

@onready var health: Health = $Health
@onready var eyes: Marker3D = $Eyes
@onready var vision_ray: RayCast3D = $Eyes/VisionRay
@onready var model: Node3D = $Model
@onready var leg_l: MeshInstance3D = $Model/LegL
@onready var leg_r: MeshInstance3D = $Model/LegR
@onready var arm_l: MeshInstance3D = $Model/ArmL
@onready var arm_r: MeshInstance3D = $Model/ArmR
@onready var gun_mesh: MeshInstance3D = $Model/ArmR/Gun
@onready var shot_sound: AudioStreamPlayer3D = $ShotSound

var player: Node3D = null
var _fire_cooldown: float = 0.0
var _last_known_player_pos: Vector3 = Vector3.ZERO
var _walk_phase: float = 0.0
var _recoil: float = 0.0
var _ammo: int
var _reloading: bool = false
var _reload_timer: float = 0.0

var state: State = State.PATROL
var _home: Vector3
var _patrol_target: Vector3
var _patrol_wait: float = 0.0
var _search_timer: float = 0.0
var _stuck_check_timer: float = 0.0
var _stuck_check_pos: Vector3

func _ready() -> void:
	add_to_group("bots")
	health.died.connect(_on_died)
	_ammo = magazine_size
	_home = global_transform.origin
	_stuck_check_pos = _home
	_pick_patrol_target()
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

	if _reloading:
		_reload_timer -= delta
		if _reload_timer <= 0.0:
			_reloading = false
			_ammo = magazine_size

	if player == null:
		_find_player()
		move_and_slide()
		_animate_walk(delta)
		return

	var can_see := _can_see_player()
	if can_see:
		_last_known_player_pos = player.global_transform.origin
		state = State.CHASE

	match state:
		State.CHASE:
			_do_chase(delta, can_see)
			if not can_see:
				state = State.SEARCH
				_search_timer = search_duration
		State.SEARCH:
			_search_timer -= delta
			_move_toward(_last_known_player_pos, patrol_speed, delta)
			if global_transform.origin.distance_to(_last_known_player_pos) < 1.5 or _search_timer <= 0.0:
				state = State.PATROL
				_home = global_transform.origin
				_pick_patrol_target()
		State.PATROL:
			_do_patrol(delta)

	if _fire_cooldown > 0.0:
		_fire_cooldown -= delta

	move_and_slide()
	_animate_walk(delta)
	_animate_gun(delta)
	_check_stuck(delta)

func _do_chase(delta: float, can_see: bool) -> void:
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
	if can_see and dist <= attack_range and not _reloading:
		_try_fire(delta)

func _do_patrol(delta: float) -> void:
	var dist := _move_toward(_patrol_target, patrol_speed, delta)
	if dist < 1.0:
		velocity.x = 0.0
		velocity.z = 0.0
		_patrol_wait -= delta
		if _patrol_wait <= 0.0:
			_pick_patrol_target()

func _move_toward(target: Vector3, speed: float, _delta: float) -> float:
	var to_target := target - global_transform.origin
	to_target.y = 0
	var dist := to_target.length()
	if dist > 0.3:
		var dir := to_target.normalized()
		velocity.x = dir.x * speed
		velocity.z = dir.z * speed
		look_at(Vector3(target.x, global_transform.origin.y, target.z), Vector3.UP)
	else:
		velocity.x = 0.0
		velocity.z = 0.0
	return dist

func _pick_patrol_target() -> void:
	var angle := randf() * TAU
	var r := randf_range(2.0, patrol_radius)
	_patrol_target = _home + Vector3(cos(angle) * r, 0, sin(angle) * r)
	_patrol_wait = randf_range(1.5, 3.5)

func _check_stuck(delta: float) -> void:
	if state != State.PATROL and state != State.SEARCH:
		_stuck_check_timer = 0.0
		_stuck_check_pos = global_transform.origin
		return
	_stuck_check_timer += delta
	if _stuck_check_timer >= 1.2:
		if global_transform.origin.distance_to(_stuck_check_pos) < 0.4:
			if state == State.PATROL:
				_pick_patrol_target()
			else:
				state = State.PATROL
				_home = global_transform.origin
				_pick_patrol_target()
		_stuck_check_timer = 0.0
		_stuck_check_pos = global_transform.origin

func _animate_walk(delta: float) -> void:
	var speed := Vector2(velocity.x, velocity.z).length()
	if speed > 0.3:
		_walk_phase += delta * speed * 3.2
		var swing := sin(_walk_phase) * 0.55
		leg_l.rotation.x = swing
		leg_r.rotation.x = -swing
	else:
		leg_l.rotation.x = move_toward(leg_l.rotation.x, 0, delta * 4.0)
		leg_r.rotation.x = move_toward(leg_r.rotation.x, 0, delta * 4.0)

func _animate_gun(delta: float) -> void:
	_recoil = move_toward(_recoil, 0.0, delta * 6.0)
	var reload_prog: float = 0.0
	if _reloading:
		reload_prog = 1.0 - (_reload_timer / reload_time)
	var dip := sin(clamp(reload_prog, 0.0, 1.0) * PI) * 0.22
	arm_r.rotation.x = -_recoil * 0.5 - dip
	arm_l.rotation.x = move_toward(arm_l.rotation.x, -dip * 0.7, delta * 6.0) if _reloading else arm_l.rotation.x

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
	if _ammo <= 0:
		_reloading = true
		_reload_timer = reload_time
		return
	_fire_cooldown = fire_interval
	_ammo -= 1
	_recoil = 1.0
	shot_sound.pitch_scale = randf_range(0.95, 1.08)
	shot_sound.play()
	if player and player.has_method("apply_hit"):
		var space_state := get_world_3d().direct_space_state
		var from := eyes.global_transform.origin
		var to := player.global_transform.origin + Vector3.UP * 0.9
		var query := PhysicsRayQueryParameters3D.create(from, to)
		query.exclude = [get_rid()]
		var result := space_state.intersect_ray(query)
		var impact := to
		if result:
			impact = result.get("position")
			if result.get("collider") == player or result.get("collider").is_in_group("player"):
				player.apply_hit(fire_damage, impact)
		_spawn_tracer(gun_mesh.global_transform.origin, impact)
		if _ammo == 0:
			_reloading = true
			_reload_timer = reload_time

func _spawn_tracer(from: Vector3, to: Vector3) -> void:
	var tracer := TracerScene.instantiate()
	get_tree().current_scene.add_child(tracer)
	tracer.setup(from, to)

func apply_hit(amount: int, _pos: Vector3) -> void:
	health.apply_damage(amount)

func _on_died() -> void:
	set_physics_process(false)
	if model:
		model.rotation.z = deg_to_rad(90)
		model.position.y -= 0.5
	collision_layer = 0
	collision_mask = 1
	await get_tree().create_timer(4.0).timeout
	queue_free()
