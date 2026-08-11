extends SceneTree

# Instantiates main.tscn so that broken node paths (@onready lookups) and script parse
# errors surface here instead of only when the game is launched.
var _main: Node = null

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

# Assertions run a frame later, once the tree has delivered _ready and the @onready
# lookups have actually resolved.
func _process(_delta: float) -> bool:
	if _main == null:
		return true

	if _main.get_parent() == null:
		root.add_child(_main)
		return false

	var ui := _main as GameUI
	var problems: Array[String] = []

	if ui == null:
		problems.append("root node is not a GameUI")
	else:
		if ui.drawing_board == null: problems.append("drawing_board not resolved")
		if ui.input_handler == null: problems.append("input_handler not resolved")
		if ui.target_display == null: problems.append("target_display not resolved")
		if ui.turn_timeline == null: problems.append("turn_timeline not resolved")
		if ui.label_status == null: problems.append("label_status not resolved")
		if ui.btn_reset == null: problems.append("btn_reset not resolved")
		if ui.btn_skip == null: problems.append("btn_skip not resolved")
		if ui.btn_new_puzzle == null: problems.append("btn_new_puzzle not resolved")
		if ui.btn_mode == null: problems.append("btn_mode not resolved")
		if ui.option_turns == null: problems.append("option_turns not resolved")
		if ui.current_puzzle == null: problems.append("no puzzle generated on ready")
		else:
			if ui.turn_timeline.max_turns != ui.current_puzzle.max_turns:
				problems.append("timeline turn count out of sync with puzzle")
			if ui.drawing_board.upcoming_erasure_phase < 0:
				problems.append("board is not showing an upcoming erasure on turn 0")
			var expected := EraserSystem.get_phase_for_turn(0, ui.current_puzzle.board_definition)
			if ui.drawing_board.upcoming_erasure_phase != expected:
				problems.append("upcoming erasure phase does not match turn 0")
			if ui.drawing_board.applied_erasure_phase != -1:
				problems.append("board shows a dead zone before any turn resolved")

	if problems.is_empty():
		print("[PASS] main.tscn wiring OK (turns=%d, first erasure=%s)" % [
			ui.current_puzzle.max_turns,
			EraserSystem.get_region_name(ui.drawing_board.upcoming_erasure_phase)])
		quit(0)
	else:
		for p in problems:
			print("[FAIL] " + p)
		quit(1)
	return true
