class_name GameUI
extends Control

var current_puzzle: PuzzleData
var current_solution: PuzzleSolution
var current_turn: int = 0
var game_cleared: bool = false

var is_easy_mode: bool = false
var selected_turn_limit: int = 0 # 0 means random 4-7 turns

@onready var drawing_board: DrawingBoard = $DrawingBoard
@onready var input_handler: InputHandler = $InputHandler
@onready var target_display: TargetDisplay = $HUD/TargetDisplay
@onready var label_turn: Label = $HUD/TurnLabel
@onready var label_erasure: Label = $HUD/ErasureLabel
@onready var label_status: Label = $HUD/StatusLabel
@onready var btn_reset: Button = $Controls/BtnReset
@onready var btn_skip: Button = $Controls/BtnSkip
@onready var btn_new_puzzle: Button = $Controls/BtnNewPuzzle
@onready var btn_mode: Button = $HUD/BtnModeToggle
@onready var option_turns: OptionButton = $HUD/OptionTurns

func _ready() -> void:
	btn_reset.pressed.connect(_on_reset_pressed)
	btn_skip.pressed.connect(_on_skip_pressed)
	btn_new_puzzle.pressed.connect(_on_new_puzzle_pressed)
	btn_mode.pressed.connect(_on_mode_toggled)

	_setup_turns_option()

	input_handler.shape_drawn.connect(_on_shape_drawn)
	input_handler.active_path_changed.connect(_on_active_path_changed)

	load_new_puzzle()

func _setup_turns_option() -> void:
	option_turns.clear()
	option_turns.add_item("Random (4-7)", 0)
	option_turns.add_item("4 Turns", 4)
	option_turns.add_item("5 Turns", 5)
	option_turns.add_item("6 Turns", 6)
	option_turns.add_item("7 Turns", 7)
	option_turns.select(0)
	option_turns.item_selected.connect(_on_turns_selected)

func _on_turns_selected(index: int) -> void:
	selected_turn_limit = option_turns.get_item_id(index)
	load_new_puzzle()

func _on_mode_toggled() -> void:
	is_easy_mode = not is_easy_mode
	btn_mode.text = "MODE: EASY" if is_easy_mode else "MODE: NORMAL"
	load_new_puzzle()

func load_new_puzzle() -> void:
	var board_def := BoardDefinition.new(8)
	var req_shapes := 2 if is_easy_mode else (3 if selected_turn_limit >= 5 else 2)

	current_puzzle = PuzzleGenerator.generate_puzzle(board_def, selected_turn_limit, req_shapes, is_easy_mode)
	current_solution = PuzzleSolution.new(current_puzzle.max_turns)
	current_turn = 0
	game_cleared = false

	drawing_board.set_board_definition(current_puzzle.board_definition)
	input_handler.setup(current_puzzle.board_definition, drawing_board.node_screen_positions)
	target_display.set_target(current_puzzle.target_geometry, current_puzzle.board_definition)

	_update_ui()

func _on_shape_drawn(node_ids: Array[int]) -> void:
	if game_cleared or current_turn >= current_puzzle.max_turns:
		return

	var shape_inst := ShapeDatabase.create_instance_from_path(node_ids, current_puzzle.board_definition)
	if shape_inst == null:
		return

	current_solution.set_action(current_turn, shape_inst)
	_advance_turn()

func _on_skip_pressed() -> void:
	if game_cleared or current_turn >= current_puzzle.max_turns:
		return

	current_solution.clear_action(current_turn)
	_advance_turn()

func _advance_turn() -> void:
	current_turn += 1
	_update_ui()
	_check_victory()

func _check_victory() -> void:
	var surviving := PuzzleSimulator.simulate_up_to_turn(current_solution, current_puzzle.board_definition, current_turn - 1)
	if surviving.is_equivalent_to(current_puzzle.target_geometry):
		game_cleared = true
		label_status.text = "★ PUZZLE SOLVED! ★"
		label_status.modulate = Color(0.2, 0.95, 0.5)

func _on_reset_pressed() -> void:
	current_solution = PuzzleSolution.new(current_puzzle.max_turns)
	current_turn = 0
	game_cleared = false
	_update_ui()

func _on_new_puzzle_pressed() -> void:
	load_new_puzzle()

func _on_active_path_changed(nodes: Array[int]) -> void:
	drawing_board.set_active_swipe(nodes)

func _update_ui() -> void:
	var max_t := current_puzzle.max_turns
	if current_turn < max_t:
		var current_erasure_name := EraserSystem.get_region_name_for_turn(current_turn, current_puzzle.board_definition)
		label_turn.text = "TURN %d / %d" % [current_turn + 1, max_t]
		label_erasure.text = "Next Erasure: %s" % current_erasure_name
	else:
		label_turn.text = "FINAL TURN"
		label_erasure.text = "Simulation Complete"

	# The per-turn prompt is gone; this label now only reports the win.
	if not game_cleared:
		label_status.text = ""
		label_status.modulate = Color.WHITE

	var last_resolved_turn := current_turn - 1
	var current_geom := PuzzleSimulator.simulate_up_to_turn(current_solution, current_puzzle.board_definition, last_resolved_turn)
	var active_erasure_phase := -1
	if last_resolved_turn >= 0:
		active_erasure_phase = EraserSystem.get_phase_for_turn(last_resolved_turn, current_puzzle.board_definition)
	drawing_board.set_surviving_geometry(current_geom, active_erasure_phase)
