extends Node3D

@onready var player: CharacterBody3D = $Player
@onready var hud: CanvasLayer = $HUD
@onready var bot_spawns: Node3D = $BotSpawns

const BOT_SCENE := preload("res://scenes/bot.tscn")

func _ready() -> void:
	player.add_to_group("player")
	player.health_changed.connect(hud.set_health)
	player.ammo_changed.connect(hud.set_ammo)
	player.died.connect(_on_player_died)
	hud.set_health(player.health.max_health, player.health.max_health)
	_spawn_bots()

func _spawn_bots() -> void:
	for spawn in bot_spawns.get_children():
		var bot := BOT_SCENE.instantiate()
		bot.global_transform = spawn.global_transform
		add_child(bot)
		bot.health.died.connect(_update_bot_count)
	_update_bot_count()

func _update_bot_count() -> void:
	await get_tree().process_frame
	var alive := 0
	for bot in get_tree().get_nodes_in_group("bots"):
		if not bot.health.is_dead():
			alive += 1
	hud.set_bots_alive(alive)

func _on_player_died() -> void:
	hud.show_death()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and player.health.is_dead():
		get_tree().reload_current_scene()
