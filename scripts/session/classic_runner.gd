class_name ClassicRunner
extends RefCounted

# The moving part of the classical ladder: which level is current, whether it has been
# cleared, and the settings for it. Saves to disk so the player can resume.

const SAVE_PATH := "user://classic_progress.cfg"

var level: int = 1
var level_cleared: bool = false

func _init():
	load_progress()

func is_finished() -> bool:
	return false  # Classic mode never ends

func is_tutorial_level() -> bool:
	return ClassicCampaign.is_tutorial_level(level)

func progress_label() -> String:
	return ClassicCampaign.progress_label(level)

func current_config() -> Dictionary:
	var difficulty := ClassicCampaign.difficulty_for_level(level)
	return {
		"difficulty": difficulty,
		"cycle": ClassicCampaign.cycle_for_level(level, difficulty),
		"input_mode": ClassicCampaign.input_mode_for_level(level, difficulty),
		"layers": ClassicCampaign.layers_for_level(level, difficulty),
		"clock": ClassicCampaign.clock_for_level(level, difficulty),
		"level": level,
		"tutorial": ClassicCampaign.is_tutorial_level(level),
	}

func begin_level() -> void:
	level_cleared = false

func mark_cleared() -> void:
	level_cleared = true

func advance() -> void:
	level += 1
	level_cleared = false
	save_progress()

func load_progress() -> void:
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) != OK:
		level = 1
		return
	level = maxi(1, int(config.get_value("classic", "level", 1)))

func save_progress() -> void:
	var config := ConfigFile.new()
	config.set_value("classic", "level", level)
	config.save(SAVE_PATH)