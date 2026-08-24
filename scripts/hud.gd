extends CanvasLayer

@onready var health_label: Label = $Margin/VBox/HealthLabel
@onready var ammo_label: Label = $Margin/VBox/AmmoLabel
@onready var bots_label: Label = $Margin/VBox/BotsLabel
@onready var kills_label: Label = $Margin/VBox/KillsLabel
@onready var death_overlay: ColorRect = $DeathOverlay
@onready var death_label: Label = $DeathOverlay/DeathLabel

func set_health(current: int, max_h: int) -> void:
	health_label.text = "HP: %d / %d" % [current, max_h]

func set_ammo(current: int, max_a: int) -> void:
	ammo_label.text = "AMMO: %d / %d" % [current, max_a]

func set_bots_alive(count: int) -> void:
	bots_label.text = "Enemies active: %d" % count

func set_kills(count: int) -> void:
	kills_label.text = "Kills: %d" % count

func show_death() -> void:
	death_overlay.visible = true

func hide_death() -> void:
	death_overlay.visible = false
