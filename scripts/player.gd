extends CharacterBody3D

@export var walk_speed: float = 5.0
@export var sprint_speed: float = 8.0
@export var crouch_speed: float = 2.5
@export var jump_velocity: float = 4.5
@export var mouse_sensitivity: float = 0.0025
@export var gravity: float = 9.8

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D
@onready var collision: CollisionShape3D = $Collision
@onready var weapon: Weapon = $Head/Camera3D/WeaponHolder/Weapon
@onready var health: Health = $Health

var _crouching: bool = false
var standing_height: float
var crouch_height: float = 1.0
var _spawn_transform: Transform3D

signal died
signal health_changed(current: int, max: int)
signal ammo_changed(current: int, max: int)

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_spawn_transform = global_transform
	standing_height = (collision.shape as CapsuleShape3D).height
	weapon.owner_body = self
	weapon.fired.connect(_on_weapon_fired)
	weapon.reloaded.connect(_on_weapon_reloaded)
	health.changed.connect(func(c, m): health_changed.emit(c, m))
	health.died.connect(func(): died.emit())
	ammo_changed.emit(weapon.ammo, weapon.magazine_size)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * mouse_sensitivity)
		head.rotate_x(-event.relative.y * mouse_sensitivity)
		head.rotation.x = clamp(head.rotation.x, deg_to_rad(-89), deg_to_rad(89))

func _physics_process(delta: float) -> void:
	if health.is_dead():
		return

	if not is_on_floor():
		velocity.y -= gravity * delta
	elif Input.is_action_just_pressed("jump") and not _crouching:
		velocity.y = jump_velocity

	_crouching = Input.is_action_pressed("crouch")
	collision.shape.height = crouch_height if _crouching else standing_height
	collision.position.y = collision.shape.height / 2.0

	var speed := crouch_speed if _crouching else (sprint_speed if Input.is_action_pressed("sprint") else walk_speed)
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()

	if direction:
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
	else:
		velocity.x = move_toward(velocity.x, 0, speed * 8.0 * delta)
		velocity.z = move_toward(velocity.z, 0, speed * 8.0 * delta)

	move_and_slide()

	var is_moving := Vector2(velocity.x, velocity.z).length() > 0.5
	if Input.is_action_pressed("fire"):
		weapon.try_fire(is_moving, camera)
	if Input.is_action_just_pressed("reload"):
		weapon.start_reload()

func apply_hit(amount: int, _pos: Vector3) -> void:
	health.apply_damage(amount)

func respawn() -> void:
	global_transform = _spawn_transform
	velocity = Vector3.ZERO
	health.revive()
	weapon.reset_ammo()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _on_weapon_fired(ammo_left: int) -> void:
	ammo_changed.emit(ammo_left, weapon.magazine_size)

func _on_weapon_reloaded(ammo_left: int) -> void:
	ammo_changed.emit(ammo_left, weapon.magazine_size)
