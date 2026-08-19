class_name StoryRunner
extends RefCounted

# Where the player is in the run, and what that task asks for.
#
# The campaign itself (StoryCampaign) is the fixed list of chapters. This is the moving
# part: which task is current, whether it has been cleared, and reading the settings for
# it back out. Nothing here knows about buttons or boards -- it hands out a configuration
# and the UI applies it, which is what keeps the run from becoming a second copy of the
# game loop.

const SAVE_PATH := "user://story_progress.cfg"

var task_index: int = 0
var task_cleared: bool = false

func _init():
	load_progress()

func is_finished() -> bool:
	return StoryCampaign.is_finished(task_index)

func is_tutorial_task() -> bool:
	return StoryCampaign.is_tutorial_task(task_index)

func progress_label() -> String:
	return StoryCampaign.progress_label(task_index)

# Everything the current task pins down, in one bundle the UI can apply as a block.
func current_config() -> Dictionary:
	return {
		"difficulty": StoryCampaign.difficulty_for_task(task_index),
		"cycle": StoryCampaign.cycle_for_task(task_index),
		"input_mode": StoryCampaign.input_mode_for_task(task_index),
		"layers": StoryCampaign.layers_for_task(task_index),
		"clock": StoryCampaign.clock_for_task(task_index),
	}

func begin_task() -> void:
	task_cleared = false

func mark_cleared() -> void:
	task_cleared = true

# A finished run restarts rather than dead-ending on a screen with nothing to press.
func restart_if_finished() -> void:
	if is_finished():
		task_index = 0
		task_cleared = false

func advance() -> void:
	task_index += 1
	task_cleared = false
	save_progress()

func load_progress() -> void:
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) != OK:
		task_index = 0
		return
	task_index = clampi(int(config.get_value("story", "task", 0)), 0, StoryCampaign.total_tasks())

func save_progress() -> void:
	var config := ConfigFile.new()
	config.set_value("story", "task", task_index)
	config.save(SAVE_PATH)
