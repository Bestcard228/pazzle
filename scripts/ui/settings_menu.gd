class_name SettingsMenu
extends Control

# Signals
signal settings_applied(language: String, mode: String, color_mode: bool, sound_enabled: bool)
signal settings_cancelled

# UI references
@onready var lang_option: OptionButton = $VBoxContainer/HBoxContainerLang/LangOption
@onready var mode_option: OptionButton = $VBoxContainer/HBoxContainerMode/ModeOption
@onready var color_mode_check: CheckBox = $VBoxContainer/HBoxContainerColor/ColorModeCheck
@onready var sound_check: CheckBox = $VBoxContainer/HBoxContainerSound/SoundCheck
@onready var apply_btn: Button = $VBoxContainer/HBoxContainerButtons/ApplyBtn
@onready var cancel_btn: Button = $VBoxContainer/HBoxContainerButtons/CancelBtn
@onready var lang_label: Label = $VBoxContainer/HBoxContainerLang/LangLabel
@onready var mode_label: Label = $VBoxContainer/HBoxContainerMode/ModeLabel
@onready var color_label: Label = $VBoxContainer/HBoxContainerColor/ColorLabel
@onready var sound_label: Label = $VBoxContainer/HBoxContainerSound/SoundLabel

# Default settings
var _language: String = "English"
var _mode: String = "Story"
var _color_mode: bool = false
var _sound_enabled: bool = true

func _ready() -> void:
	# Populate language options
	lang_option.clear()
	lang_option.add_item("English")
	lang_option.add_item("Russian")
	lang_option.add_item("Ukrainian")
	lang_option.add_item("German")
	lang_option.select(0)  # English by default
	
	# Populate mode options
	mode_option.clear()
	mode_option.add_item("Story")
	mode_option.add_item("History")
	mode_option.add_item("Color Mode")
	mode_option.select(0)  # Story by default
	
	# Connect buttons
	apply_btn.pressed.connect(_on_apply_pressed)
	cancel_btn.pressed.connect(_on_cancel_pressed)
	
	# Load saved settings if any
	_load_settings()

func _on_apply_pressed() -> void:
	_language = lang_option.get_item_text(lang_option.get_selected())
	_mode = mode_option.get_item_text(mode_option.get_selected())
	_color_mode = color_mode_check.button_pressed
	_sound_enabled = sound_check.button_pressed
	
	# Save to disk
	var cfg = ConfigFile.new()
	var err = cfg.load("user://settings.cfg")
	if err != OK:
		# If file doesn't exist, that's fine; we'll create it
		pass
	cfg.setvalue("Settings", "language", _language)
	cfg.setvalue("Settings", "mode", _mode)
	cfg.setvalue("Settings", "color_mode", _color_mode)
	cfg.setvalue("Settings", "sound_enabled", _sound_enabled)
	cfg.save("user://settings.cfg")
	
	# Emit signal
	settings_applied.emit(_language, _mode, _color_mode, _sound_enabled)
	hide()
	# Apply sound setting immediately
	var audio_manager = Engine.get_singleton("AudioManager")
	if audio_manager:
		audio_manager.set_sound_enabled(_sound_enabled)
		audio_manager.play_click()
func _on_cancel_pressed() -> void:
	settings_cancelled.emit()
	hide()

func _load_settings() -> void:
	var cfg = ConfigFile.new()
	if cfg.load("user://settings.cfg") == OK:
		_language = cfg.getvalue("Settings", "language", "English")
		_mode = cfg.getvalue("Settings", "mode", "Story")
		_color_mode = cfg.getvalue("Settings", "color_mode", false)
		_sound_enabled = cfg.getvalue("Settings", "sound_enabled", true)
		
		# Update UI to reflect loaded settings
		lang_option.select(_find_option_index(lang_option, _language))
		mode_option.select(_find_option_index(mode_option, _mode))
		color_mode_check.button_pressed = _color_mode
		sound_check.button_pressed = _sound_enabled
	
	# Update labels (and option items if we were translating them) based on the loaded locale
	_update_ui_labels()

func _find_option_index(option: OptionButton, text: String) -> int:
	for i in range(option.get_item_count()):
		if option.get_item_text(i) == text:
			return i
	return 0  # fallback to first item

func _update_ui_labels() -> void:
	# Update the text of the labels using translation keys
	lang_label.text = tr("Language")
	mode_label.text = tr("Mode")
	color_label.text = tr("Color Mode")
	sound_label.text = tr("Sound")
	
	# Note: We are not translating the OptionButton items (language names and mode names) for simplicity.
	# If you wish to translate them, you would need to replace the items with translated strings.
	# For now, we leave them as they are (English).
