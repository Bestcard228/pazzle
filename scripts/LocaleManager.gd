# LocaleManager.gd
# Autoload singleton to handle language changes via settings_applied signal.

extends Node

# Default locale
const DEFAULT_LOCALE := "English"
var current_locale: String = DEFAULT_LOCALE

# Cache loaded translations to avoid reloading
var translation_cache: Dictionary = {}

func _ready() -> void:
	# Connect to the global settings_applied signal from MainMenu.
	# We assume the scene tree has Main/MainMenu when the game is running.
	# Use a short defer to ensure the tree is ready.
	call_deferred("_connect_to_main_menu")
	# Load default locale
	_apply_locale(DEFAULT_LOCALE)

func _connect_to_main_menu() -> void:
	var main_menu = get_tree().root.get_node_or_null("Main/MainMenu")
	if main_menu:
		main_menu.settings_applied.connect(_on_settings_applied)
		print("LocaleManager: Connected to MainMenu.settings_applied")
	else:
		print("LocaleManager: Warning - MainMenu not found yet. Will retry in _process.")
		# Fallback: try again later via _process (but we can also rely on the fact that
		# MainMenu exists when the game starts; if not, we'll wait a bit.)
		set_process(true)

var _retry_timer := 0.0
func _process(delta: float) -> void:
	if not is_connected_to_main_menu():
		_retry_timer += delta
		if _retry_timer > 2.0:
			_connect_to_main_menu()
			_retry_timer = 0.0

func is_connected_to_main_menu() -> bool:
	var main_menu = get_tree().root.get_node_or_null("Main/MainMenu")
	return main_menu != null and main_menu.is_connected("settings_applied", Callable(self, "_on_settings_applied"))

func _on_settings_applied(language: String, mode: String, color_mode: bool, sound_enabled: bool) -> void:
	if language != current_locale:
		print("LocaleManager: Language changed from %s to %s" % [current_locale, language])
		current_locale = language
		_apply_locale(language)
		# Forward the signal so other listeners (e.g., MainMenu) still get it
		get_tree().root.get_node_or_null("Main/MainMenu")?.settings_applied.emit(language, mode, color_mode, sound_enabled)

func _apply_locale(lang: String) -> void:
	# If already cached, use it
	if translation_cache.has(lang):
		var translation = translation_cache[lang]
		TranslationServer.set_locale(translation)
		print("LocaleManager: Set locale to %s (cached)" % lang)
		return
	
	var translation_path = "res://translations/%s.translation" % lang
	var translation = TranslationServer.load_translation(translation_path)
	if translation:
		translation_cache[lang] = translation
		TranslationServer.set_locale(translation)
		print("LocaleManager: Loaded and set locale to %s" % lang)
	else:
		push_warning("LocaleManager: Translation file not found: %s" % translation_path)
		# Fallback to default locale
		if lang != DEFAULT_LOCALE:
			_apply_locale(DEFAULT_LOCALE)
		else:
			# Still nothing, set empty locale (English strings)
			TranslationServer.set_locale(null)
			print("LocaleManager: No translation files available, using original strings.")
