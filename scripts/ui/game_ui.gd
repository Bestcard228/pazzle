class_name GameUI
extends Control

var current_puzzle: PuzzleData
var current_solution: PuzzleSolution
var current_turn: int = 0
var game_cleared: bool = false

# Which stage of a chained (MEDIUM) puzzle is currently on show.
var current_stage: int = 0

# The tier the player picked. MODE_AUTO is not a tier: it reshuffles the ladder every
# puzzle. `difficulty` is always the tier the puzzle in play was actually generated at.
const MODE_AUTO := -1
var selected_mode: int = PuzzleGenerator.Difficulty.EASY
var difficulty: int = PuzzleGenerator.Difficulty.EASY
var mode_cycle: Array[int] = []
var auto_bag: Array[int] = []

var selected_turn_limit: int = 0 # 0 means random 4-7 turns

# Tapping the turns button steps through these
const TURN_CHOICES: Array[int] = [0, 4, 5, 6, 7]
var erasure_shape: int = EraserSystem.ErasureShape.DIAGONAL_WEDGE

# Revealing the intended shapes and their order is an Easy-mode aid only.
var solution_revealed: bool = false

# The whole board is vector-drawn, so the pixel-art look is a full-screen resolve rather
# than an art change. It can be switched off to read fine detail.
var pixel_filter_enabled: bool = true

# A hint is offered only after the player has been stuck on the same turn for a while,
# so it never pre-empts someone who is still working the puzzle out.
const HINT_IDLE_TIME := 20.0
var idle_time: float = 0.0
var hint_offered: bool = false
var _hint_pulse_t: float = 0.0
var _status_override_time: float = 0.0

@onready var drawing_board: DrawingBoard = $DrawingBoard
@onready var input_handler: InputHandler = $InputHandler
@onready var target_display: TargetDisplay = $HUD/TargetDisplay
@onready var checkpoint_display: TargetDisplay = $HUD/CheckpointDisplay
@onready var checkpoint_title: Label = $HUD/CheckpointDisplay/CheckpointTitle
@onready var turn_timeline: TurnTimeline = $HUD/TurnTimeline
@onready var solution_strip: SolutionStrip = $HUD/SolutionStrip
@onready var btn_reveal: IconButton = $HUD/BtnReveal
@onready var btn_hint: IconButton = $HUD/BtnHint
@onready var btn_pixel: IconButton = $HUD/BtnPixel
@onready var pixel_filter: CanvasLayer = $PixelFilter
@onready var label_status: Label = $HUD/StatusLabel
@onready var btn_reset: Button = $Controls/BtnReset
@onready var btn_skip: Button = $Controls/BtnSkip
@onready var btn_new_puzzle: Button = $Controls/BtnNewPuzzle
@onready var btn_mode: IconButton = $HUD/BtnModeToggle
@onready var btn_eraser: IconButton = $HUD/BtnEraserToggle
@onready var btn_turns: IconButton = $HUD/BtnTurns

func _ready() -> void:
	mode_cycle = [MODE_AUTO]
	for tier in PuzzleGenerator.DIFFICULTY_ORDER:
		mode_cycle.append(int(tier))

	btn_reset.pressed.connect(_on_reset_pressed)
	btn_skip.pressed.connect(_on_skip_pressed)
	btn_new_puzzle.pressed.connect(_on_new_puzzle_pressed)
	btn_mode.pressed.connect(_on_mode_toggled)
	btn_eraser.pressed.connect(_on_eraser_toggled)
	btn_turns.pressed.connect(_on_turns_cycled)
	btn_reveal.pressed.connect(_on_reveal_toggled)
	btn_hint.pressed.connect(_on_hint_pressed)
	btn_pixel.pressed.connect(_on_pixel_toggled)
	_refresh_pixel_filter()
	_refresh_selector_icons()

	input_handler.shape_drawn.connect(_on_shape_drawn)
	input_handler.active_path_changed.connect(_on_active_path_changed)

	# Enhanced input feedback connections
	input_handler.node_pressed.connect(_on_input_node_pressed)
	input_handler.node_released.connect(_on_input_node_released)
	input_handler.hover_updated.connect(_on_input_hover_updated)
	input_handler.position_updated.connect(_on_input_position_updated)
	input_handler.preview_position_updated.connect(_on_input_preview_position_updated)
	input_handler.loop_closed_changed.connect(_on_loop_closed_changed)

	# Scaling a Control pivots on its top-left unless told otherwise, which makes a pop
	# animation slide instead of grow.
	label_status.pivot_offset = label_status.size / 2.0
	target_display.pivot_offset = target_display.size / 2.0
	checkpoint_display.pivot_offset = checkpoint_display.size / 2.0

	load_new_puzzle()

func _process(delta: float) -> void:
	if current_puzzle == null:
		return

	if _status_override_time > 0.0:
		_status_override_time -= delta
		if _status_override_time <= 0.0:
			_restore_status_text()

	if game_cleared or current_turn >= current_puzzle.max_turns:
		return

	idle_time += delta
	if not hint_offered and idle_time >= HINT_IDLE_TIME:
		_offer_hint()

	# The lamp breathes while it is waiting to be noticed
	if hint_offered:
		_hint_pulse_t += delta
		var pulse := 0.75 + 0.25 * sin(_hint_pulse_t * 3.0)
		btn_hint.modulate = Color(1.0, 1.0, 1.0, pulse)
		btn_hint.scale = Vector2.ONE * (0.97 + 0.05 * pulse)

func _on_input_node_pressed(node_id: int, touch_pos: Vector2) -> void:
	drawing_board._on_node_pressed(node_id, touch_pos)

func _on_input_node_released(node_id: int) -> void:
	drawing_board._on_node_released(node_id)

func _on_input_hover_updated(node_id: int) -> void:
	drawing_board._on_hover_updated(node_id)

func _on_input_position_updated(position: Vector2, is_dragging: bool) -> void:
	drawing_board._on_input_position_updated(position, is_dragging)

func _on_input_preview_position_updated(position: Vector2) -> void:
	drawing_board._on_input_preview_position_updated(position)

func _on_turns_cycled() -> void:
	var next := (TURN_CHOICES.find(selected_turn_limit) + 1) % TURN_CHOICES.size()
	selected_turn_limit = TURN_CHOICES[next]
	_refresh_selector_icons()
	load_new_puzzle()

func _on_mode_toggled() -> void:
	var next := (mode_cycle.find(selected_mode) + 1) % mode_cycle.size()
	selected_mode = mode_cycle[next]
	auto_bag.clear()
	_refresh_selector_icons()
	load_new_puzzle()

func is_easy_mode() -> bool:
	return PuzzleGenerator.uses_sequence_tree(difficulty)

func is_auto_mode() -> bool:
	return selected_mode == MODE_AUTO

# Auto draws from a bag rather than rolling each time, so all four tiers come round
# before any of them repeats.
func _resolve_difficulty() -> int:
	if not is_auto_mode():
		return selected_mode
	if auto_bag.is_empty():
		for tier in PuzzleGenerator.DIFFICULTY_ORDER:
			auto_bag.append(int(tier))
		auto_bag.shuffle()
	return auto_bag.pop_back()

func _on_eraser_toggled() -> void:
	erasure_shape = (EraserSystem.ErasureShape.HALF_PLANE
		if erasure_shape == EraserSystem.ErasureShape.DIAGONAL_WEDGE
		else EraserSystem.ErasureShape.DIAGONAL_WEDGE)
	_refresh_selector_icons()
	load_new_puzzle()

func _on_reveal_toggled() -> void:
	solution_revealed = not solution_revealed
	_refresh_reveal()

func _refresh_reveal() -> void:
	# Easy-mode aid only: outside Easy the control is hidden and the strip stays dark.
	btn_reveal.visible = is_easy_mode()
	solution_strip.visible = is_easy_mode()

	if not is_easy_mode():
		solution_revealed = false

	btn_reveal.set_icon_state(1 if solution_revealed else 0)
	btn_reveal.tooltip_text = ("Hide the intended solution" if solution_revealed
		else "Show the intended solution")
	solution_strip.set_revealed(solution_revealed)

func _refresh_selector_icons() -> void:
	if is_auto_mode():
		btn_mode.set_icon_state(0)
		btn_mode.tooltip_text = "Difficulty: Auto -- shuffles Easy, Easy+, Easy++ and Medium"
	else:
		btn_mode.set_icon_state(PuzzleGenerator.get_difficulty_rank(selected_mode))
		btn_mode.tooltip_text = "Difficulty: %s" % PuzzleGenerator.get_difficulty_name(selected_mode)

	# Every selectable tier is fully described by its Draw/Skip sequences: they fix the
	# turn count, and they only hold together under the X-wedge eraser. Neither control
	# has anything left to decide, so both are hidden rather than shown dead.
	var tier_driven := is_easy_mode()
	btn_turns.disabled = tier_driven
	btn_eraser.disabled = tier_driven
	btn_turns.visible = not tier_driven
	btn_eraser.visible = not tier_driven

	if tier_driven:
		btn_turns.set_icon_state(0)
		btn_eraser.set_icon_state(EraserSystem.ErasureShape.DIAGONAL_WEDGE)
		return

	btn_turns.set_icon_state(selected_turn_limit)
	btn_turns.tooltip_text = ("Turns: random 4-7" if selected_turn_limit <= 0
		else "Turns: %d" % selected_turn_limit)
	btn_eraser.set_icon_state(erasure_shape)
	btn_eraser.tooltip_text = "Eraser: %s" % EraserSystem.get_shape_name(erasure_shape)

func load_new_puzzle() -> void:
	difficulty = _resolve_difficulty()

	var board_def := BoardDefinition.new(8, Vector2(64, 64), 0, erasure_shape)
	var req_shapes := 2 if is_easy_mode() else 3

	current_puzzle = PuzzleGenerator.generate_puzzle(board_def, selected_turn_limit, req_shapes, difficulty)
	current_solution = PuzzleSolution.new(current_puzzle.max_turns)
	current_turn = 0
	current_stage = 0
	game_cleared = false

	drawing_board.set_board_definition(current_puzzle.board_definition)
	drawing_board.set_cleared(false)
	drawing_board.clear_hint()
	input_handler.setup(current_puzzle.board_definition, drawing_board.node_screen_positions)
	turn_timeline.setup(current_puzzle.board_definition, current_puzzle.max_turns)

	# A new puzzle starts concealed, so the aid is always a deliberate tap
	solution_revealed = false
	solution_strip.set_solution(current_puzzle.reference_solution, current_puzzle.board_definition)
	_refresh_reveal()
	_refresh_selector_icons()

	checkpoint_display.visible = false
	_withdraw_hint()
	_refresh_stage_targets()
	_update_ui()

# A chained puzzle reveals one goal at a time. The stage already banked is celebrated and
# then cleared away: leaving "STEP 1" parked on screen makes it look like it is still
# something to solve.
func _refresh_stage_targets() -> void:
	target_display.set_target(current_puzzle.get_stage_target(current_stage), current_puzzle.board_definition)
	target_display.set_matched(false)
	_refresh_stage_label()

func _refresh_stage_label() -> void:
	if not current_puzzle.is_multi_stage() or game_cleared:
		return
	label_status.text = "STEP %d / %d" % [current_stage + 1, current_puzzle.get_stage_count()]
	label_status.modulate = Color(0.4, 0.7, 1.0)

func _on_shape_drawn(node_ids: Array[int]) -> void:
	if game_cleared or current_turn >= current_puzzle.max_turns:
		return

	var shape_inst := ShapeDatabase.create_instance_from_path(node_ids, current_puzzle.board_definition)
	if shape_inst == null:
		return

	# The turn resolves instantly, so the shape gets an echo on its way out
	drawing_board.flash_committed_shape(node_ids)
	current_solution.set_action(current_turn, shape_inst)
	_advance_turn()

func _on_skip_pressed() -> void:
	if game_cleared or current_turn >= current_puzzle.max_turns:
		return

	current_solution.clear_action(current_turn)
	_advance_turn()

func _advance_turn() -> void:
	current_turn += 1
	_withdraw_hint()
	_update_ui()
	_check_victory()

func _check_victory() -> void:
	var surviving := PuzzleSimulator.simulate_up_to_turn(
		current_solution, current_puzzle.board_definition, current_turn - 1)

	if not surviving.is_equivalent_to(current_puzzle.get_stage_target(current_stage)):
		return

	# A middle stage clears into the next one instead of ending the puzzle
	if current_stage < current_puzzle.get_stage_count() - 1:
		_celebrate_stage()
		return

	game_cleared = true
	label_status.text = "★ SOLVED ★"
	label_status.modulate = Color(0.2, 0.95, 0.5)
	_pop(label_status, 1.35, 0.45)
	# The win reads off the board itself, not just the label
	drawing_board.set_cleared(true)
	drawing_board.set_erasure_phases(drawing_board.applied_erasure_phase, -1)
	drawing_board.clear_hint()
	target_display.set_matched(true)
	_pop(target_display, 1.18, 0.4)

# The finished step goes green, is held up for a beat on the checkpoint card, and then
# fades away -- the next goal only arrives once it is gone.
func _celebrate_stage() -> void:
	var finished_stage := current_stage

	target_display.set_matched(true)
	_pop(target_display, 1.15, 0.3)
	target_display.start_fade_out()
	if not target_display.fade_out_finished.is_connected(_advance_stage):
		target_display.fade_out_finished.connect(_advance_stage, CONNECT_ONE_SHOT)

	checkpoint_title.text = "STEP %d" % (finished_stage + 1)
	checkpoint_display.set_target(current_puzzle.get_stage_target(finished_stage), current_puzzle.board_definition)
	checkpoint_display.set_matched(true)
	checkpoint_display.visible = true
	checkpoint_display.start_fade_out()
	if not checkpoint_display.fade_out_finished.is_connected(_on_checkpoint_faded):
		checkpoint_display.fade_out_finished.connect(_on_checkpoint_faded, CONNECT_ONE_SHOT)
	_pop(checkpoint_display, 1.2, 0.35)

	_flash_status("STEP %d COMPLETE" % (finished_stage + 1), Color(0.2, 0.95, 0.5), 1.2)

func _on_checkpoint_faded() -> void:
	checkpoint_display.visible = false

func _advance_stage() -> void:
	current_stage += 1
	_refresh_stage_targets()
	_update_ui()

func _on_reset_pressed() -> void:
	# Rewinds the whole chain, not just the stage in progress
	current_solution = PuzzleSolution.new(current_puzzle.max_turns)
	current_turn = 0
	current_stage = 0
	game_cleared = false
	drawing_board.set_cleared(false)
	drawing_board.clear_hint()
	checkpoint_display.visible = false
	_withdraw_hint()
	_refresh_stage_targets()
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

	if not game_cleared and _status_override_time <= 0.0:
		label_status.text = ""
		label_status.modulate = Color.WHITE
		_refresh_stage_label()

func _on_loop_closed_changed(closed: bool) -> void:
	drawing_board.set_loop_closed(closed)

# --- Pixel filter ------------------------------------------------------------------

func _on_pixel_toggled() -> void:
	pixel_filter_enabled = not pixel_filter_enabled
	_refresh_pixel_filter()

func _refresh_pixel_filter() -> void:
	pixel_filter.visible = pixel_filter_enabled
	btn_pixel.set_icon_state(1 if pixel_filter_enabled else 0)
	btn_pixel.tooltip_text = ("Pixel-art filter: on" if pixel_filter_enabled
		else "Pixel-art filter: off")

# --- Hints -------------------------------------------------------------------------

func _offer_hint() -> void:
	hint_offered = true
	_hint_pulse_t = 0.0
	btn_hint.visible = true
	btn_hint.pivot_offset = btn_hint.size / 2.0
	btn_hint.set_icon_state(1)
	btn_hint.tooltip_text = "Stuck? Show what this turn wants"
	btn_hint.modulate = Color(1, 1, 1, 0)
	var tween := create_tween()
	tween.tween_property(btn_hint, "modulate:a", 1.0, 0.4)

# Any resolved turn earns a fresh idle window: the player is making progress again.
func _withdraw_hint() -> void:
	idle_time = 0.0
	hint_offered = false
	btn_hint.visible = false
	btn_hint.set_icon_state(0)
	btn_hint.modulate = Color.WHITE
	btn_hint.scale = Vector2.ONE

func _on_hint_pressed() -> void:
	idle_time = 0.0

	# A hint reads off the intended solution, which is only meaningful while the player
	# is still on that line. Once they have diverged, the honest hint is to start over.
	if not _follows_reference():
		_flash_status("HINT: THIS LINE CAN'T REACH THE GOAL -- RESET", Color(1.0, 0.6, 0.35), 3.0)
		_pop(btn_reset, 1.2, 0.4)
		_withdraw_hint()
		return

	var action := current_puzzle.reference_solution.get_action(current_turn)
	var shape: ShapeInstance = action.shape_instance if action != null else null

	if shape == null:
		_flash_status("HINT: SKIP THIS TURN", Color(1.0, 0.85, 0.35), 3.0)
		_pop(btn_skip, 1.2, 0.4)
	else:
		drawing_board.show_hint_path(shape.node_ids)
		_flash_status("HINT: DRAW THIS", Color(1.0, 0.85, 0.35), 2.0)

	_withdraw_hint()

# True while every turn the player has resolved matches the intended solution, which is
# what makes the next intended action a usable hint.
func _follows_reference() -> bool:
	var reference := current_puzzle.reference_solution
	if reference == null:
		return false

	for t in range(current_turn):
		var mine := current_solution.get_action(t)
		var theirs := reference.get_action(t)
		var mine_shape: ShapeInstance = mine.shape_instance if mine != null else null
		var their_shape: ShapeInstance = theirs.shape_instance if theirs != null else null

		if (mine_shape == null) != (their_shape == null):
			return false
		if mine_shape != null and not mine_shape.geometry.is_equivalent_to(their_shape.geometry):
			return false

	return true

# --- Small feedback helpers --------------------------------------------------------

func _flash_status(text: String, color: Color, hold: float) -> void:
	label_status.text = text
	label_status.modulate = color
	_status_override_time = hold
	_pop(label_status, 1.15, 0.3)

func _restore_status_text() -> void:
	if game_cleared:
		return
	label_status.text = ""
	label_status.modulate = Color.WHITE
	_refresh_stage_label()

# A short overshoot-and-settle, used wherever something is worth noticing.
func _pop(node: Control, amount: float, duration: float) -> void:
	node.pivot_offset = node.size / 2.0
	node.scale = Vector2.ONE
	var tween := create_tween()
	tween.tween_property(node, "scale", Vector2.ONE * amount, duration * 0.35)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(node, "scale", Vector2.ONE, duration * 0.65)\
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
