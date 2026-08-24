extends CanvasLayer

@onready var overlay: ColorRect = $Overlay
@onready var main_panel: VBoxContainer = $Overlay/MainPanel
@onready var settings_panel: VBoxContainer = $Overlay/SettingsPanel
@onready var resume_button: Button = $Overlay/MainPanel/ResumeButton
@onready var settings_button: Button = $Overlay/MainPanel/SettingsButton
@onready var quit_button: Button = $Overlay/MainPanel/QuitButton
@onready var sens_slider: HSlider = $Overlay/SettingsPanel/SensSlider
@onready var vol_slider: HSlider = $Overlay/SettingsPanel/VolSlider
@onready var fullscreen_check: CheckButton = $Overlay/SettingsPanel/FullscreenCheck
@onready var back_button: Button = $Overlay/SettingsPanel/BackButton

var player: Node = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	overlay.visible = false
	resume_button.pressed.connect(close)
	settings_button.pressed.connect(_on_settings_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	back_button.pressed.connect(_on_back_pressed)
	sens_slider.value_changed.connect(_on_sensitivity_changed)
	vol_slider.value_changed.connect(_on_volume_changed)
	fullscreen_check.toggled.connect(_on_fullscreen_toggled)
	fullscreen_check.button_pressed = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN

func is_open() -> bool:
	return overlay.visible

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if is_open():
			close()
		else:
			open()

func open() -> void:
	overlay.visible = true
	main_panel.visible = true
	settings_panel.visible = false
	if player:
		sens_slider.value = player.mouse_sensitivity
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func close() -> void:
	overlay.visible = false
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _on_settings_pressed() -> void:
	main_panel.visible = false
	settings_panel.visible = true

func _on_back_pressed() -> void:
	settings_panel.visible = false
	main_panel.visible = true

func _on_quit_pressed() -> void:
	get_tree().quit()

func _on_sensitivity_changed(value: float) -> void:
	if player:
		player.mouse_sensitivity = value

func _on_volume_changed(value: float) -> void:
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Master"), linear_to_db(max(value, 0.0001)))

func _on_fullscreen_toggled(pressed: bool) -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if pressed else DisplayServer.WINDOW_MODE_WINDOWED)
