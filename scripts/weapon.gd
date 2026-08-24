extends Node3D
class_name Weapon

@export var damage: int = 25
@export var fire_rate: float = 0.11 # seconds between shots
@export var magazine_size: int = 30
@export var reload_time: float = 1.6
@export var range: float = 100.0
@export var base_spread_deg: float = 0.6
@export var move_spread_deg: float = 2.5
@export var recoil_kick: float = 0.6

@onready var muzzle: Marker3D = $Muzzle
@onready var raycast: RayCast3D = $Muzzle/RayCast3D
@onready var muzzle_flash: OmniLight3D = $Muzzle/MuzzleFlash
@onready var flash_mesh: MeshInstance3D = $Muzzle/FlashMesh
@onready var shot_sound: AudioStreamPlayer3D = $ShotSound

var ammo: int
var _cooldown: float = 0.0
var _reloading: bool = false
var _reload_timer: float = 0.0
var _flash_timer: float = 0.0

signal fired(ammo_left: int)
signal reloaded(ammo_left: int)
signal hit_target(body: Node, damage: int)

var owner_body: Node3D = null

func _ready() -> void:
	ammo = magazine_size
	raycast.target_position = Vector3(0, 0, -range)

func _process(delta: float) -> void:
	if _cooldown > 0.0:
		_cooldown -= delta
	if _reloading:
		_reload_timer -= delta
		if _reload_timer <= 0.0:
			_reloading = false
			ammo = magazine_size
			reloaded.emit(ammo)
	if _flash_timer > 0.0:
		_flash_timer -= delta
		if _flash_timer <= 0.0:
			muzzle_flash.visible = false
			flash_mesh.visible = false

func can_fire() -> bool:
	return not _reloading and _cooldown <= 0.0 and ammo > 0

func try_fire(is_moving: bool, camera: Camera3D) -> void:
	if not can_fire():
		if ammo <= 0 and not _reloading:
			start_reload()
		return
	_cooldown = fire_rate
	ammo -= 1
	fired.emit(ammo)
	_flash_timer = 0.05
	muzzle_flash.visible = true
	flash_mesh.visible = true
	flash_mesh.rotation.z = randf() * TAU
	shot_sound.pitch_scale = randf_range(0.95, 1.08)
	shot_sound.play()

	var spread_deg := base_spread_deg + (move_spread_deg if is_moving else 0.0)
	var spread_rad := deg_to_rad(spread_deg)
	var forward := -camera.global_transform.basis.z
	var right := camera.global_transform.basis.x
	var up := camera.global_transform.basis.y
	var rand_angle := randf() * TAU
	var rand_radius := randf() * spread_rad
	var dir := (forward + right * cos(rand_angle) * rand_radius + up * sin(rand_angle) * rand_radius).normalized()

	var space_state := get_world_3d().direct_space_state
	var from := camera.global_transform.origin
	var to := from + dir * range
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.exclude = [owner_body.get_rid()] if owner_body else []
	var result := space_state.intersect_ray(query)
	if result:
		var collider = result.get("collider")
		if collider and collider.has_method("apply_hit"):
			collider.apply_hit(damage, result.get("position"))
		hit_target.emit(collider, damage)

	if ammo == 0:
		start_reload()

func start_reload() -> void:
	if _reloading or ammo == magazine_size:
		return
	_reloading = true
	_reload_timer = reload_time
