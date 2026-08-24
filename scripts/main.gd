extends Node3D

const BOT_SCENE := preload("res://scenes/bot.tscn")
const MAX_ALIVE := 5
const RESPAWN_DELAY := 3.0
const MIN_SPAWN_DIST_FROM_PLAYER := 14.0

@onready var player: CharacterBody3D = $Player
@onready var hud: CanvasLayer = $HUD
@onready var bot_spawns: Node3D = $BotSpawns

var _alive_count: int = 0
var _kills: int = 0
var _game_over: bool = false

func _ready() -> void:
	player.add_to_group("player")
	player.health_changed.connect(hud.set_health)
	player.ammo_changed.connect(hud.set_ammo)
	player.died.connect(_on_player_died)
	hud.set_health(player.health.max_health, player.health.max_health)
	hud.set_kills(_kills)
	for i in range(MAX_ALIVE):
		_spawn_one_bot()

func _pick_spawn_point() -> Marker3D:
	var candidates := bot_spawns.get_children()
	candidates.shuffle()
	for spawn in candidates:
		if spawn.global_transform.origin.distance_to(player.global_transform.origin) >= MIN_SPAWN_DIST_FROM_PLAYER:
			return spawn
	return candidates[0]

func _spawn_one_bot() -> void:
	if _game_over:
		return
	var spawn := _pick_spawn_point()
	var bot := BOT_SCENE.instantiate()
	bot.global_transform = spawn.global_transform
	add_child(bot)
	_alive_count += 1
	hud.set_bots_alive(_alive_count)
	bot.health.died.connect(_on_bot_died)

func _on_bot_died() -> void:
	_alive_count -= 1
	_kills += 1
	hud.set_bots_alive(_alive_count)
	hud.set_kills(_kills)
	if not _game_over:
		var t := get_tree().create_timer(RESPAWN_DELAY)
		t.timeout.connect(_spawn_one_bot)

func _on_player_died() -> void:
	_game_over = true
	hud.show_death()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and player.health.is_dead():
		get_tree().reload_current_scene()
