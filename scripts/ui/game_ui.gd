class_name GameUI
extends Control

var current_puzzle: PuzzleData
var current_solution: PuzzleSolution
var current_turn: int = 0
var game_cleared: bool = false

var is_easy_mode: bool = false
var selected_turn_limit: int = 0 # 0 means random 4-7 turns

# Tapping the turns button steps through these
const TURN_CHOICES: Array[int] = [0, 4, 5, 6, 7]
var erasure_shape: int = EraserSystem.ErasureShape.DIAGONAL_WEDGE

@onready var drawing_board: DrawingBoard = $DrawingBoard
@onready var input_handler: InputHandler = $InputHandler
@onready var target_display: TargetDisplay = $HUD/TargetDisplay
@onready var turn_timeline: TurnTimeline = $HUD/TurnTimeline
@onready var label_status: Label = $HUD/StatusLabel
@onready var btn_reset: Button = $Controls/BtnReset
@onready var btn_skip: Button = $Controls/BtnSkip
@onready var btn_new_puzzle: Button = $Controls/BtnNewPuzzle
@onready var btn_mode: IconButton = $HUD/BtnModeToggle
@onready var btn_eraser: IconButton = $HUD/BtnEraserToggle
@onready var btn_turns: IconButton = $HUD/BtnTurns

func _ready() -> void:
	btn_reset.pressed.connect(_on_reset_pressed)
	btn_skip.pressed.connect(_on_skip_pressed)
	btn_new_puzzle.pressed.connect(_on_new_puzzle_pressed)
	btn_mode.pressed.connect(_on_mode_toggled)
	btn_eraser.pressed.connect(_on_eraser_toggled)
	btn_turns.pressed.connect(_on_turns_cycled)
	_refresh_selector_icons()

	input_handler.shape_drawn.connect(_on_shape_drawn)
	input_handler.active_path_changed.connect(_on_active_path_changed)

	load_new_puzzle()

func _on_turns_cycled() -> void:
	var next := (TURN_CHOICES.find(selected_turn_limit) + 1) % TURN_CHOICES.size()
	selected_turn_limit = TURN_CHOICES[next]
	_refresh_selector_icons()
	load_new_puzzle()

func _on_mode_toggled() -> void:
	is_easy_mode = not is_easy_mode
	_refresh_selector_icons()
	load_new_puzzle()

func _on_eraser_toggled() -> void:
	erasure_shape = (EraserSystem.ErasureShape.HALF_PLANE
		if erasure_shape == EraserSystem.ErasureShape.DIAGONAL_WEDGE
		else EraserSystem.ErasureShape.DIAGONAL_WEDGE)
	_refresh_selector_icons()
	load_new_puzzle()

func _refresh_selector_icons() -> void:
	btn_mode.set_icon_state(1 if is_easy_mode else 0)
	btn_turns.set_icon_state(selected_turn_limit)
	btn_eraser.set_icon_state(erasure_shape)

	# Tooltips carry the wording the buttons no longer show
	btn_mode.tooltip_text = "Difficulty: %s" % ("Easy" if is_easy_mode else "Normal")
	btn_turns.tooltip_text = ("Turns: random 4-7" if selected_turn_limit <= 0
		else "Turns: %d" % selected_turn_limit)
	btn_eraser.tooltip_text = "Eraser: %s" % EraserSystem.get_shape_name(erasure_shape)

func load_new_puzzle() -> void:
	var board_def := BoardDefinition.new(8, Vector2(64, 64), 0, erasure_shape)
	# The generator clamps this to the board's real survivable window, so the wedge eraser
	# gets genuine three-shape puzzles while the half-plane eraser still settles at two.
	var req_shapes := 2 if is_easy_mode else 3

	current_puzzle = PuzzleGenerator.generate_puzzle(board_def, selected_turn_limit, req_shapes, is_easy_mode)
	current_solution = PuzzleSolution.new(current_puzzle.max_turns)
	current_turn = 0
	game_cleared = false

	drawing_board.set_board_definition(current_puzzle.board_definition)
	drawing_board.set_cleared(false)
	input_handler.setup(current_puzzle.board_definition, drawing_board.node_screen_positions)
	target_display.set_target(current_puzzle.target_geometry, current_puzzle.board_definition)
	turn_timeline.setup(current_puzzle.board_definition, current_puzzle.max_turns)

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
		label_status.text = "★ SOLVED ★"
		label_status.modulate = Color(0.2, 0.95, 0.5)
		# The win reads off the board itself, not just the label
		drawing_board.set_cleared(true)
		drawing_board.set_erasure_phases(drawing_board.applied_erasure_phase, -1)
		target_display.set_matched(true)

func _on_reset_pressed() -> void:
	current_solution = PuzzleSolution.new(current_puzzle.max_turns)
	current_turn = 0
	game_cleared = false
	drawing_board.set_cleared(false)
	target_display.set_matched(false)
	_update_ui()

func _on_new_puzzle_pressed() -> void:
	load_new_puzzle()

func _on_active_path_changed(nodes: Array[int]) -> void:
	drawing_board.set_active_swipe(nodes)

func _update_ui() -> void:
	var board := current_puzzle.board_definition
	var max_t := current_puzzle.max_turns
	var turns_remain := current_turn < max_t

	# Which turns the player has already committed a shape on
	var drawn: Array[bool] = []
	for t in range(max_t):
		var act := current_solution.get_action(t)
		drawn.append(act != null and act.shape_instance != null)
	turn_timeline.set_progress(current_turn, drawn)

	# The board carries the state: what is already gone, and what goes next.
	var last_resolved_turn := current_turn - 1
	var applied_phase := -1
	if last_resolved_turn >= 0:
		applied_phase = EraserSystem.get_phase_for_turn(last_resolved_turn, board)

	var upcoming_phase := -1
	if turns_remain and not game_cleared:
		upcoming_phase = EraserSystem.get_phase_for_turn(current_turn, board)

	var current_geom := PuzzleSimulator.simulate_up_to_turn(current_solution, board, last_resolved_turn)
	drawing_board.set_surviving_geometry(current_geom)
	drawing_board.set_erasure_phases(applied_phase, upcoming_phase)

	btn_skip.disabled = game_cleared or not turns_remain

	if not game_cleared:
		label_status.text = ""
		label_status.modulate = Color.WHITE
