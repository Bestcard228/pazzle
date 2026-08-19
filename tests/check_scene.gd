extends SceneTree

# Instantiates main.tscn so that broken node paths (@onready lookups) and script parse
# errors surface here instead of only when the game is launched.
#
# The game now opens on the menu rather than straight into a puzzle, so this walks the
# real startup: menu first, then each of the two ways in. The puzzle-side assertions run
# against the debug entry, which is where they always ran -- they just have to be reached
# by choosing it now.
var _main: Node = null
var _phase: int = 0
var _problems: Array[String] = []

func _init():
	var packed: PackedScene = load("res://scenes/main.tscn")
	if packed == null:
		print("[FAIL] main.tscn failed to load")
		quit(1)
		return

	_main = packed.instantiate()
	if _main == null:
		print("[FAIL] main.tscn failed to instantiate")
		quit(1)
		return

func _check(condition: bool, problem: String) -> void:
	if not condition:
		_problems.append(problem)

# Assertions run a frame later, once the tree has delivered _ready and the @onready
# lookups have actually resolved.
func _process(_delta: float) -> bool:
	if _main == null:
		return true

	if _main.get_parent() == null:
		root.add_child(_main)
		return false

	var ui := _main as GameUI
	if ui == null:
		print("[FAIL] root node is not a GameUI")
		quit(1)
		return true

	match _phase:
		0: _check_menu(ui)
		1: _check_debug_entry(ui)
		2: _check_story_entry(ui)

	_phase += 1
	if _phase <= 2:
		return false

	if _problems.is_empty():
		print("[PASS] main.tscn wiring OK (turns=%d, first erasure=%s)" % [
			ui.session.puzzle.max_turns,
			EraserSystem.get_region_name(ui.drawing_board.upcoming_erasure_phase)])
		quit(0)
	else:
		for problem in _problems:
			print("[FAIL] " + problem)
		quit(1)
	return true

# The game opens on the menu: nothing generated, nothing playing.
func _check_menu(ui: GameUI) -> void:
	_check(ui.drawing_board != null, "drawing_board not resolved")
	_check(ui.input_handler != null, "input_handler not resolved")
	_check(ui.target_display != null, "target_display not resolved")
	_check(ui.turn_timeline != null, "turn_timeline not resolved")
	_check(ui.solution_strip != null, "solution_strip not resolved")
	_check(ui.label_status != null, "label_status not resolved")
	_check(ui.main_menu != null, "main_menu not resolved")
	_check(ui.btn_reset != null, "btn_reset not resolved")
	_check(ui.btn_skip != null, "btn_skip not resolved")
	_check(ui.btn_new_puzzle != null, "btn_new_puzzle not resolved")
	_check(ui.btn_mode != null, "btn_mode not resolved")
	_check(ui.btn_turns != null, "btn_turns not resolved")
	_check(ui.btn_eraser != null, "btn_eraser not resolved")
	_check(ui.btn_reveal != null, "btn_reveal not resolved")
	_check(ui.btn_hint != null, "btn_hint not resolved")
	_check(ui.btn_pixel != null, "btn_pixel not resolved")
	_check(ui.btn_direction != null, "btn_direction not resolved")
	_check(ui.btn_input_mode != null, "btn_input_mode not resolved")
	_check(ui.btn_layers != null, "btn_layers not resolved")
	_check(ui.btn_timer != null, "btn_timer not resolved")
	_check(ui.btn_tutorial != null, "btn_tutorial not resolved")
	_check(ui.btn_menu != null, "btn_menu not resolved")

	if ui.main_menu != null:
		_check(ui.main_menu.visible, "menu is not showing on startup")
	_check(not ui.hud.visible, "HUD is showing behind the menu")
	_check(not ui.drawing_board.visible, "board is showing behind the menu")
	_check(ui.session.puzzle == null, "a puzzle was generated before a mode was chosen")

# DEBUG is the game as it was: everything unlocked, a puzzle ready to play.
func _check_debug_entry(ui: GameUI) -> void:
	ui._on_mode_chosen(false)

	_check(not ui.main_menu.visible, "menu still showing after choosing a mode")
	_check(ui.hud.visible, "HUD hidden after choosing a mode")
	_check(ui.drawing_board.visible, "board hidden after choosing a mode")

	# The icon buttons must reflect the state they were initialised with
	_check(ui.btn_eraser.icon_state == ui.erasure_shape, "eraser icon out of sync with erasure_shape")
	_check(ui.btn_turns.icon_state == ui.selected_turn_limit, "turns icon out of sync with selected_turn_limit")

	# The solution aid is Easy-only and must start concealed
	_check(not ui.solution_revealed, "solution revealed before the player asked")
	_check(not ui.solution_strip.is_revealed, "solution strip drawing while concealed")
	_check(ui.btn_reveal.visible == ui.is_easy_mode(), "reveal button visibility does not track easy mode")
	_check(ui.solution_strip.solution != null, "solution strip has no reference solution")

	# Nothing is locked in the sandbox
	_check(not ui.btn_mode.disabled, "difficulty locked in debug mode")
	_check(not ui.btn_timer.disabled, "clock locked in debug mode")

	if ui.session.puzzle == null:
		_problems.append("no puzzle generated on entering debug mode")
		return

	_check(ui.turn_timeline.max_turns == ui.session.puzzle.max_turns,
		"timeline turn count out of sync with puzzle")
	_check(ui.drawing_board.upcoming_erasure_phase >= 0,
		"board is not showing an upcoming erasure on turn 0")
	_check(ui.drawing_board.upcoming_erasure_phase ==
		EraserSystem.get_phase_for_turn(0, ui.session.puzzle.board_definition),
		"upcoming erasure phase does not match turn 0")
	_check(ui.drawing_board.applied_erasure_phase == -1,
		"board shows a dead zone before any turn resolved")

# STORY starts on the lesson, with the settings it owns taken out of the player's hands.
func _check_story_entry(ui: GameUI) -> void:
	# Driven from a known point rather than from whatever progress is on disk
	ui.story.task_index = 0
	ui._on_mode_chosen(true)

	_check(ui.app_mode == GameUI.AppMode.STORY, "story mode not entered")
	_check(StoryCampaign.is_tutorial_task(0), "the run does not open on the lesson")
	_check(ui.tutorial_active, "the lesson is not running on the first task")
	_check(ui.session.puzzle != null, "no lesson puzzle built")
	if ui.session.puzzle != null:
		_check(ui.session.puzzle.turn_time_limit == 0.0, "the lesson is on a clock")

	# The run picks the settings, so they are on show but not on offer
	_check(ui.btn_mode.disabled, "difficulty selectable during the run")
	_check(ui.btn_timer.disabled, "clock selectable during the run")
	_check(ui.btn_layers.disabled, "colours selectable during the run")
	_check(ui.title_label.text != "", "the run does not say where it is")
