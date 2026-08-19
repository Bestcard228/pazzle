class_name GameUI
extends Control

# The puzzle in play: its state and the rules for moving it forward. Everything here is
# presentation on top of it.
var session := PuzzleSession.new()

# The tier the player picked. MODE_AUTO is not a tier: it reshuffles the ladder every
# puzzle. `difficulty` is always the tier the puzzle in play was actually generated at.
const MODE_AUTO := -1
var selected_mode: int = PuzzleGenerator.Difficulty.EASY
var difficulty: int = PuzzleGenerator.Difficulty.EASY
var mode_cycle: Array[int] = []
var auto_bag: Array[int] = []

var selected_turn_limit: int = 0 # 0 means random 4-7 turns

# Seconds per turn, 0 for no clock. Running out is not a new outcome -- it is a skip, so
# the sequences the tree allows are the same with the clock on as with it off.
var turn_time_limit: float = PuzzleGenerator.NO_TURN_TIME_LIMIT
var turn_clock := TurnClock.new()

# The lesson. It plays through exactly the same code path as a generated puzzle -- the
# only difference is that a ghost keeps showing what to do until it is done.
# Which way in the player took. DEBUG is everything unlocked at once -- the game as it
# was before the run existed -- and STORY is the ordered set of tasks.
enum AppMode { MENU, STORY, DEBUG }

var app_mode: int = AppMode.MENU
var story := StoryRunner.new()

var tutorial: TutorialController
var tutorial_active: bool = false
var _tutorial_prompt_t: float = 0.0

# Tapping the turns button steps through these
const TURN_CHOICES: Array[int] = [0, 4, 5, 6, 7]
var erasure_shape: int = EraserSystem.ErasureShape.DIAGONAL_WEDGE

# Which of the six erasure walks to use. SHUFFLED lets the generator draw one per puzzle
# from its bag. This is an ordering of the same rules, so it stays available on every
# tier -- the sequences behind Easy through Medium do not change with it.
var erasure_cycle_id: int = PuzzleGenerator.SHUFFLED_ERASURE_CYCLE

# Which half of the puzzle the player supplies. DRAW_SHAPES is the original game; in
# CHOOSE_ERASURES the shapes are given and the erasure schedule is the puzzle.
var input_mode: int = PuzzleData.InputMode.DRAW_SHAPES

# How many colour layers to ask the generator for. Every layer draws on the same turns --
# D(r) D(g), S(r) S(g) -- and is eaten by its own walk.
var layer_count: int = 1

# Revealing the intended shapes and their order is an Easy-mode aid only.
var solution_revealed: bool = false

# The whole board is vector-drawn, so the pixel-art look is a full-screen resolve rather
# than an art change. It can be switched off to read fine detail.
var pixel_filter_enabled: bool = true

# A hint is offered only after the player has been stuck on the same turn for a while,
# so it never pre-empts someone who is still working the puzzle out.
var hints := HintDirector.new()
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
@onready var btn_direction: IconButton = $HUD/BtnDirection
@onready var btn_input_mode: IconButton = $HUD/BtnInputMode
@onready var btn_layers: IconButton = $HUD/BtnLayers
@onready var btn_timer: IconButton = $HUD/BtnTimer
@onready var btn_tutorial: IconButton = $HUD/BtnTutorial
@onready var btn_menu: IconButton = $HUD/BtnMenu
@onready var main_menu: MainMenu = $MainMenu
@onready var hud: Control = $HUD
@onready var controls: HBoxContainer = $Controls
@onready var title_label: Label = $HUD/TitleLabel
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
	btn_direction.pressed.connect(_on_direction_toggled)
	btn_input_mode.pressed.connect(_on_input_mode_toggled)
	btn_layers.pressed.connect(_on_layers_cycled)
	btn_timer.pressed.connect(_on_timer_cycled)
	btn_tutorial.pressed.connect(_on_tutorial_pressed)
	btn_menu.pressed.connect(_on_menu_pressed)
	main_menu.mode_chosen.connect(_on_mode_chosen)
	_refresh_pixel_filter()
	_refresh_selector_icons()
	_refresh_selector_availability()

	input_handler.shape_drawn.connect(_on_shape_drawn)
	input_handler.active_path_changed.connect(_on_active_path_changed)

	# Enhanced input feedback connections
	input_handler.node_pressed.connect(_on_input_node_pressed)
	input_handler.node_released.connect(_on_input_node_released)
	input_handler.hover_updated.connect(_on_input_hover_updated)
	input_handler.position_updated.connect(_on_input_position_updated)
	input_handler.preview_position_updated.connect(_on_input_preview_position_updated)
	input_handler.loop_closed_changed.connect(_on_loop_closed_changed)

	hints.session = session
	session.turn_advanced.connect(_on_turn_advanced)
	session.layer_advanced.connect(_on_layer_advanced)
	session.stage_cleared.connect(_on_stage_cleared)
	session.puzzle_cleared.connect(_on_puzzle_cleared)

	# Scaling a Control pivots on its top-left unless told otherwise, which makes a pop
	# animation slide instead of grow.
	label_status.pivot_offset = label_status.size / 2.0
	target_display.pivot_offset = target_display.size / 2.0
	checkpoint_display.pivot_offset = checkpoint_display.size / 2.0

	_show_menu()

func _process(delta: float) -> void:
	if session.puzzle == null or app_mode == AppMode.MENU:
		return

	if _status_override_time > 0.0:
		_status_override_time -= delta
		if _status_override_time <= 0.0:
			_restore_status_text()

	if session.cleared or session.turn >= session.puzzle.max_turns:
		return

	if turn_clock.tick(delta):
		_on_turn_time_expired()
		return
	drawing_board.set_clock_fraction(turn_clock.fraction())

	if tutorial_active:
		_tick_tutorial(delta)
		return

	if hints.tick(delta):
		_raise_hint_lamp()

	# The lamp breathes while it is waiting to be noticed
	if hints.is_offered:
		var pulse := hints.pulse()
		btn_hint.modulate = Color(1.0, 1.0, 1.0, pulse)
		btn_hint.scale = Vector2.ONE * (0.97 + 0.05 * pulse)

# ERASE mode taps land here rather than in the InputHandler, which stands down entirely.
func _input(event: InputEvent) -> void:
	if not uses_erase_input() or session.puzzle == null or session.cleared:
		return
	if session.erase == null or session.erase.is_complete():
		return

	if event is InputEventMouseMotion:
		_update_zone_hover(event.position)
	elif event is InputEventScreenDrag:
		_update_zone_hover(event.position)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_update_zone_hover(event.position)
		_try_pick_zone(drawing_board.zone_at_position(event.position))
	elif event is InputEventScreenTouch and event.pressed:
		_update_zone_hover(event.position)
		_try_pick_zone(drawing_board.zone_at_position(event.position))

func _update_zone_hover(pos: Vector2) -> void:
	var zone := drawing_board.zone_at_position(pos)
	session.erase.set_hovered_zone(zone)
	drawing_board.set_hovered_zone(zone, zone >= 0 and session.erase.can_select(zone))

func _try_pick_zone(zone: int) -> void:
	if zone < 0:
		return

	if not session.can_pick_zone(zone):
		_flash_status(session.rejection_reason(zone), Color(1.0, 0.45, 0.4), 1.6)
		return

	drawing_board.set_hovered_zone(-1, true)
	session.pick_zone(zone)

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

func uses_clock() -> bool:
	return session.puzzle != null and session.puzzle.turn_time_limit > 0.0 and not session.cleared

func _on_timer_cycled() -> void:
	var choices := PuzzleGenerator.TURN_TIME_CHOICES
	var next := (choices.find(turn_time_limit) + 1) % choices.size()
	turn_time_limit = choices[next]
	_refresh_selector_icons()
	load_new_puzzle()

func _restart_turn_clock() -> void:
	turn_clock.set_limit(session.puzzle.turn_time_limit if session.puzzle != null else 0.0)
	if uses_clock():
		turn_clock.start()
	else:
		turn_clock.stop()
	drawing_board.set_clock_fraction(turn_clock.fraction())

# A turn nobody acted on is a skip, which is a move the rules already have.
func _on_turn_time_expired() -> void:
	drawing_board.flash_clock_expiry()
	_flash_status("OUT OF TIME", Color(1.0, 0.35, 0.30), 1.2)

	if uses_erase_input():
		# There is no "skip" that keeps a schedule well formed, so the clock only ever
		# nudges here: the turn is handed back rather than lost.
		_restart_turn_clock()
		return

	session.skip_turn()

func uses_layers() -> bool:
	return session.uses_layers()

# ERASE mode asks for a schedule, and with several layers there would be one schedule per
# colour per turn. That is a mode of its own; until it exists the two settings do not mix,
# and choosing erase input plays the single-layer puzzle.
func effective_layer_count() -> int:
	return LayerSystem.SINGLE_LAYER if uses_erase_input() else layer_count

func _on_layers_cycled() -> void:
	layer_count = LayerSystem.SINGLE_LAYER if layer_count >= LayerSystem.MAX_LAYERS else layer_count + 1
	_refresh_selector_icons()
	load_new_puzzle()

func uses_erase_input() -> bool:
	return input_mode == PuzzleData.InputMode.CHOOSE_ERASURES

func _on_input_mode_toggled() -> void:
	input_mode = (PuzzleData.InputMode.DRAW_SHAPES if uses_erase_input()
		else PuzzleData.InputMode.CHOOSE_ERASURES)
	_refresh_selector_icons()
	load_new_puzzle()

func is_cycle_shuffled() -> bool:
	return erasure_cycle_id == PuzzleGenerator.SHUFFLED_ERASURE_CYCLE

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

# Steps through the six walks and back to Shuffle, so the player can pin one down to
# learn it or leave it varying.
func _on_direction_toggled() -> void:
	if is_cycle_shuffled():
		erasure_cycle_id = 0
	elif erasure_cycle_id >= EraserSystem.CYCLE_COUNT - 1:
		erasure_cycle_id = PuzzleGenerator.SHUFFLED_ERASURE_CYCLE
	else:
		erasure_cycle_id += 1
	_refresh_selector_icons()
	load_new_puzzle()

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
	# ERASE mode swaps which half is the aid. The shapes are what the player is handed --
	# they are the puzzle, so the strip is always up and always showing them. What is
	# hidden there is the erasure order, because that is the answer.
	if uses_erase_input():
		btn_reveal.visible = true
		solution_strip.visible = true
		solution_strip.set_revealed(true)
		solution_strip.set_erase_order(session.puzzle.erase_order if solution_revealed
			else ([] as Array[int]))
		btn_reveal.set_icon_state(1 if solution_revealed else 0)
		btn_reveal.tooltip_text = ("Hide the intended erasure order" if solution_revealed
			else "Show the intended erasure order")
		return

	# Easy-mode aid only: outside Easy the control is hidden and the strip stays dark.
	btn_reveal.visible = is_easy_mode()
	solution_strip.visible = is_easy_mode()
	solution_strip.set_erase_order([] as Array[int])

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

	btn_timer.set_icon_state(PuzzleGenerator.TURN_TIME_CHOICES.find(turn_time_limit))
	btn_timer.tooltip_text = ("Turn clock: off" if turn_time_limit <= 0.0
		else "Turn clock: %d seconds -- running out counts as a skip" % int(turn_time_limit))

	btn_layers.set_icon_state(effective_layer_count())
	btn_layers.disabled = uses_erase_input()
	btn_layers.tooltip_text = ("Colours: one (the original game)" if layer_count <= 1
		else "Colours: %d -- every colour is erased by its own order" % layer_count)

	btn_input_mode.set_icon_state(input_mode)
	btn_input_mode.tooltip_text = ("Mode: choose the erasures (the shapes are given)"
		if uses_erase_input() else "Mode: draw the shapes (the erasures are fixed)")

	# -1 is the shuffle face; otherwise the icon draws that walk literally
	btn_direction.set_icon_state(erasure_cycle_id)
	if is_cycle_shuffled():
		btn_direction.tooltip_text = "Erasure order: shuffled -- one of the six per puzzle"
	else:
		btn_direction.tooltip_text = "Erasure order: %s (%s)" % [
			EraserSystem.get_cycle_name(erasure_cycle_id),
			EraserSystem.get_cycle_description(erasure_cycle_id)]

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

	var board_cycle: int = (EraserSystem.CYCLE_CLOCKWISE if is_cycle_shuffled()
		else erasure_cycle_id)
	var board_def := BoardDefinition.new(8, Vector2(64, 64), 0, erasure_shape, board_cycle)
	var req_shapes := 2 if is_easy_mode() else 3

	var puzzle: PuzzleData
	if effective_layer_count() > LayerSystem.SINGLE_LAYER:
		puzzle = PuzzleGenerator.generate_layered_puzzle(
			board_def, difficulty, effective_layer_count(), 200, input_mode, turn_time_limit)
	else:
		puzzle = PuzzleGenerator.generate_puzzle(
			board_def, selected_turn_limit, req_shapes, difficulty, 400, erasure_cycle_id,
			input_mode, turn_time_limit)

	session.setup(puzzle)
	drawing_board.set_board_definition(session.puzzle.board_definition)
	drawing_board.set_layer_count(session.puzzle.layer_count)
	drawing_board.set_active_layer(0)
	drawing_board.set_cleared(false)
	drawing_board.clear_hint()
	input_handler.setup(session.puzzle.board_definition, drawing_board.node_screen_positions)
	turn_timeline.setup(session.puzzle.board_definition, session.puzzle.max_turns)
	# ERASE mode reads the strip the other way round: the shapes are given, the schedule
	# is the answer and stays off it until the player commits each turn.
	turn_timeline.set_shape_mode(uses_erase_input(), session.puzzle.reference_solution)
	turn_timeline.set_committed_zones([] as Array[int])

	# The plan stays concealed in both modes: showing it is always a deliberate tap on
	# the eye, never something the mode does for the player.
	solution_revealed = false
	input_handler.set_enabled(not uses_erase_input())
	drawing_board.set_zone_picking(uses_erase_input())
	drawing_board.set_picked_zones([])
	solution_strip.set_solution(session.puzzle.reference_solution, session.puzzle.board_definition)
	# A layered plan is several shapes per turn, so the strip is handed all the colours
	# rather than layer 0 standing in for the rest.
	solution_strip.set_layered_solution(
		session.puzzle.layered_solution if uses_layers() else null,
		session.puzzle.layer_count)
	_refresh_reveal()
	_refresh_selector_icons()

	checkpoint_display.visible = false
	_withdraw_hint()
	_restart_turn_clock()
	_refresh_stage_targets()
	_update_ui()

# A chained puzzle reveals one goal at a time. The stage already banked is celebrated and
# then cleared away: leaving "STEP 1" parked on screen makes it look like it is still
# something to solve.
func _refresh_stage_targets() -> void:
	target_display.set_target(session.puzzle.get_stage_target(session.stage), session.puzzle.board_definition)
	target_display.set_layer_targets(
		session.puzzle.get_layer_stage_targets(session.stage) if uses_layers()
			else ([] as Array[VectorGeometry]),
		session.puzzle.layer_count)
	target_display.set_matched(false)
	_refresh_stage_label()

func _refresh_stage_label() -> void:
	if session.cleared:
		return

	var parts: Array[String] = []
	if session.puzzle.is_multi_stage():
		parts.append("STEP %d / %d" % [session.stage + 1, session.puzzle.get_stage_count()])

	# Which colour the next swipe lands in. The swipe itself is already drawn in that
	# colour, so this is a confirmation rather than the only cue.
	if uses_layers() and session.turn < session.puzzle.max_turns:
		parts.append("PAINT %s" % LayerSystem.get_layer_name(session.active_layer))

	if parts.is_empty():
		return

	label_status.text = "  -  ".join(parts)
	label_status.modulate = (LayerSystem.get_layer_color(session.active_layer, session.puzzle.layer_count)
		if uses_layers() else Color(0.4, 0.7, 1.0))

func _on_shape_drawn(node_ids: Array[int]) -> void:
	if session.cleared or session.turn >= session.puzzle.max_turns:
		return

	var shape_inst := ShapeDatabase.create_instance_from_path(node_ids, session.puzzle.board_definition)
	if shape_inst == null:
		return

	# A lesson only accepts the shape it is showing; anything else replays the ghost
	# rather than being committed, so the player cannot wander off the rails.
	if tutorial_active and not tutorial.accepts(node_ids, session.turn):
		drawing_board.clear_hint()
		_tutorial_prompt_t = 0.0
		return

	# The turn resolves instantly, so the shape gets an echo on its way out
	drawing_board.flash_committed_shape(node_ids)
	session.commit_shape(shape_inst)

func _on_skip_pressed() -> void:
	if session.cleared:
		return

	# During the lesson the button only works on the turn the lesson is pointing at it
	if tutorial_active and not tutorial.is_skip_turn(session.turn):
		return

	if uses_erase_input():
		_undo_last_pick()
		return

	session.skip_turn()

func _undo_last_pick() -> void:
	if not session.undo_pick():
		return

	drawing_board.set_picked_zones(session.erase.solution.zones)
	checkpoint_display.visible = false
	_withdraw_hint()
	_refresh_stage_targets()
	_update_ui()

# The colour in hand moved on, but the turn has not: D(r) is down, D(g) is still to come.
func _on_layer_advanced(layer: int) -> void:
	drawing_board.set_active_layer(layer)
	_update_ui()

func _on_turn_advanced(_turn: int) -> void:
	_withdraw_hint()
	_restart_turn_clock()
	drawing_board.set_active_layer(session.active_layer)
	if uses_erase_input():
		drawing_board.set_picked_zones(session.erase.solution.zones)
	_update_ui()

	# In ERASE mode running out of turns is not a loss -- the schedule is right there to
	# be taken apart and rebuilt.
	if uses_erase_input() and not session.cleared and not session.turns_remain():
		_flash_status("NOT THE GOAL -- UNDO A PICK OR RESET", Color(1.0, 0.6, 0.35), 3.0)

func _on_puzzle_cleared() -> void:
	if tutorial_active:
		tutorial_active = false
		tutorial = null
		drawing_board.clear_hint()
		_refresh_selector_availability()
	if app_mode == AppMode.STORY:
		story.mark_cleared()
		_refresh_selector_availability()

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
func _on_stage_cleared(finished_stage: int) -> void:

	target_display.set_matched(true)
	_pop(target_display, 1.15, 0.3)
	target_display.start_fade_out()
	if not target_display.fade_out_finished.is_connected(_advance_stage):
		target_display.fade_out_finished.connect(_advance_stage, CONNECT_ONE_SHOT)

	checkpoint_title.text = "STEP %d" % (finished_stage + 1)
	checkpoint_display.set_target(session.puzzle.get_stage_target(finished_stage), session.puzzle.board_definition)
	checkpoint_display.set_layer_targets(
		session.puzzle.get_layer_stage_targets(finished_stage) if uses_layers()
			else ([] as Array[VectorGeometry]),
		session.puzzle.layer_count)
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
	session.advance_stage()
	_refresh_stage_targets()
	_update_ui()

func _on_reset_pressed() -> void:
	# Rewinds the whole chain, not just the stage in progress
	if session.erase != null:
		session.erase.reset()
		drawing_board.set_picked_zones([])
		drawing_board.set_hovered_zone(-1, true)
	session.solution = PuzzleSolution.new(session.puzzle.max_turns)
	session.layered = LayeredSolution.new(
		maxi(1, session.puzzle.layer_count), session.puzzle.max_turns)
	session.active_layer = 0
	drawing_board.set_active_layer(0)
	session.turn = 0
	session.stage = 0
	session.cleared = false
	_restart_turn_clock()
	drawing_board.set_cleared(false)
	drawing_board.clear_hint()
	checkpoint_display.visible = false
	_withdraw_hint()
	_refresh_stage_targets()
	_update_ui()

func _on_new_puzzle_pressed() -> void:
	if app_mode == AppMode.STORY:
		if story.task_cleared:
			_advance_story_task()
		else:
			# Same task, fresh puzzle: a retry, not a way to skip past it
			_start_story_task()
		return

	load_new_puzzle()

func _on_active_path_changed(nodes: Array[int]) -> void:
	drawing_board.set_active_swipe(nodes)

func _update_ui() -> void:
	var board := session.active_board()
	var turns_remain := session.turns_remain()

	turn_timeline.set_progress(session.turn, session.drawn_turn_flags())
	turn_timeline.set_committed_zones(session.erase.solution.zones
		if uses_erase_input() else ([] as Array[int]))

	# The board carries the state: what is already gone, and what goes next.
	var last_resolved_turn := session.last_resolved_turn()
	var applied_phase := -1
	if last_resolved_turn >= 0:
		applied_phase = EraserSystem.get_phase_for_turn(last_resolved_turn, board)

	# Nothing is coming next in ERASE mode until the player says what it is, so the
	# warning overlay stays off and the hover preview does that job instead.
	var upcoming_phase := -1
	if turns_remain and not session.cleared and not uses_erase_input():
		upcoming_phase = EraserSystem.get_phase_for_turn(session.turn, board)

	if uses_layers():
		drawing_board.set_layer_geometry(session.layer_geometry())
		# One warning per colour: each layer loses a different quarter this turn.
		var showing_next := turns_remain and not session.cleared
		drawing_board.set_layer_erasure_phases(
			session.layer_phases(last_resolved_turn),
			session.layer_phases(session.turn) if showing_next else session.layer_phases(-1))
	else:
		drawing_board.set_surviving_geometry(session.surviving_geometry())
		drawing_board.set_erasure_phases(applied_phase, upcoming_phase)

	# Every turn in ERASE mode erases something, so there is no turn to skip; what the
	# button is good for there is taking back the last quarter.
	btn_skip.text = "UNDO PICK" if uses_erase_input() else "SKIP TURN"
	if uses_erase_input():
		btn_skip.disabled = session.cleared or session.turn <= 0
	else:
		btn_skip.disabled = session.cleared or not turns_remain

	if not session.cleared and _status_override_time <= 0.0:
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

# --- Menu and the story run ----------------------------------------------------------

func _show_menu() -> void:
	app_mode = AppMode.MENU
	main_menu.visible = true
	main_menu.set_story_progress(story.task_index)
	hud.visible = false
	controls.visible = false
	drawing_board.visible = false
	input_handler.set_enabled(false)

func _on_menu_pressed() -> void:
	if tutorial_active:
		tutorial_active = false
		tutorial = null
		drawing_board.clear_hint()
	_show_menu()

func _on_mode_chosen(start_story: bool) -> void:
	app_mode = AppMode.STORY if start_story else AppMode.DEBUG
	main_menu.visible = false
	hud.visible = true
	controls.visible = true
	drawing_board.visible = true

	if app_mode == AppMode.STORY:
		story.restart_if_finished()
		_start_story_task()
	else:
		title_label.text = ""
		_refresh_selector_availability()
		load_new_puzzle()

# A story task is the same generated puzzle as any other -- the run only decides what to
# ask the generator for.
# The run owns the settings for its task, so this applies them as a block and then loads
# the puzzle exactly the way the sandbox does.
func _start_story_task() -> void:
	story.begin_task()

	var config := story.current_config()
	difficulty = int(config["difficulty"])
	erasure_cycle_id = int(config["cycle"])
	input_mode = int(config["input_mode"])
	layer_count = int(config["layers"])
	turn_time_limit = float(config["clock"])
	selected_mode = difficulty
	title_label.text = story.progress_label()

	if story.is_tutorial_task():
		_start_tutorial()
		return

	_refresh_selector_availability()
	load_new_puzzle()

func _advance_story_task() -> void:
	story.advance()

	if story.is_finished():
		title_label.text = "STORY COMPLETE"
		_flash_status("★ STORY COMPLETE ★", Color(0.2, 0.95, 0.5), 4.0)
		return

	_start_story_task()

# --- Tutorial ------------------------------------------------------------------------

func _on_tutorial_pressed() -> void:
	if tutorial_active:
		_end_tutorial()
		return
	_start_tutorial()

func _start_tutorial() -> void:
	tutorial = TutorialController.new()
	var lesson_puzzle := tutorial.build_puzzle()
	if lesson_puzzle == null:
		return

	tutorial_active = true
	_tutorial_prompt_t = 0.0

	session.setup(lesson_puzzle)

	drawing_board.set_board_definition(session.puzzle.board_definition)
	drawing_board.set_layer_count(1)
	drawing_board.set_active_layer(0)
	drawing_board.set_cleared(false)
	drawing_board.set_zone_picking(false)
	drawing_board.clear_hint()
	input_handler.setup(session.puzzle.board_definition, drawing_board.node_screen_positions)
	input_handler.set_enabled(true)
	turn_timeline.setup(session.puzzle.board_definition, session.puzzle.max_turns)
	turn_timeline.set_shape_mode(false, null)
	turn_timeline.set_committed_zones([] as Array[int])

	# Nothing to read, nothing to fiddle with: while the lesson runs the only things that
	# do anything are the board and the one button it asks for.
	solution_revealed = false
	solution_strip.set_solution(session.puzzle.reference_solution, session.puzzle.board_definition)
	solution_strip.set_layered_solution(null, 1)
	solution_strip.set_erase_order([] as Array[int])
	solution_strip.visible = false
	btn_reveal.visible = false
	checkpoint_display.visible = false
	_withdraw_hint()
	_restart_turn_clock()
	_refresh_selector_availability()
	_refresh_stage_targets()
	_update_ui()

func _end_tutorial() -> void:
	tutorial_active = false
	tutorial = null
	drawing_board.clear_hint()
	_refresh_selector_availability()
	load_new_puzzle()

# The lesson buttons are the only ones live while it runs, so a stray tap on a selector
# cannot swap the puzzle out from under the lesson.
func _refresh_selector_availability() -> void:
	btn_tutorial.set_icon_state(1 if tutorial_active else 0)

	# The run picks the settings for each task, so they are on show but not on offer;
	# during the lesson nothing is, except the button it is pointing at.
	var locked := tutorial_active or app_mode == AppMode.STORY
	for button in [btn_mode, btn_turns, btn_eraser, btn_direction, btn_input_mode,
			btn_layers, btn_timer]:
		button.disabled = locked
	btn_tutorial.disabled = app_mode == AppMode.STORY
	btn_new_puzzle.disabled = tutorial_active
	btn_new_puzzle.text = "NEXT" if (app_mode == AppMode.STORY and story.task_cleared) else "NEW PUZZLE"

# The prompt repeats for as long as it is not obeyed. A ghost that keeps retracing the
# shape is the whole instruction -- there is nothing to read and nothing to dismiss.
func _tick_tutorial(delta: float) -> void:
	_tutorial_prompt_t += delta

	if session.turn >= session.puzzle.max_turns:
		return

	if tutorial.is_skip_turn(session.turn):
		# Nothing to draw this turn: the only thing moving on screen is the button that
		# passes it, so that is where the eye goes.
		drawing_board.clear_hint()
		if _tutorial_prompt_t >= 1.1:
			_tutorial_prompt_t = 0.0
			_pop(btn_skip, 1.25, 0.5)
		return

	if not drawing_board.is_hint_showing():
		drawing_board.show_hint_path(tutorial.expected_path(session.turn))

# --- Hints -------------------------------------------------------------------------

func _raise_hint_lamp() -> void:
	btn_hint.visible = true
	btn_hint.pivot_offset = btn_hint.size / 2.0
	btn_hint.set_icon_state(1)
	btn_hint.tooltip_text = "Stuck? Show what this turn wants"
	btn_hint.modulate = Color(1, 1, 1, 0)
	var tween := create_tween()
	tween.tween_property(btn_hint, "modulate:a", 1.0, 0.4)

func _withdraw_hint() -> void:
	hints.withdraw()
	btn_hint.visible = false
	btn_hint.set_icon_state(0)
	btn_hint.modulate = Color.WHITE
	btn_hint.scale = Vector2.ONE

# The director decides what the hint is; this is only how it is put on screen.
func _on_hint_pressed() -> void:
	var hint := hints.request()

	match int(hint["kind"]):
		HintDirector.Kind.DRAW_PATH:
			drawing_board.show_hint_path(hint["path"])
			_flash_status("HINT: DRAW THIS IN %s" % LayerSystem.get_layer_name(int(hint["layer"]))
				if uses_layers() else "HINT: DRAW THIS", Color(1.0, 0.85, 0.35), 2.0)

		HintDirector.Kind.SKIP_TURN:
			_flash_status("HINT: SKIP THIS TURN", Color(1.0, 0.85, 0.35), 3.0)
			_pop(btn_skip, 1.2, 0.4)

		HintDirector.Kind.ERASE_ZONE:
			var zone := int(hint["zone"])
			drawing_board.set_hovered_zone(zone, true)
			_flash_status("HINT: ERASE %s NEXT" % EraserSystem.get_region_name(zone),
				Color(1.0, 0.85, 0.35), 2.5)

		HintDirector.Kind.SCHEDULE_DONE:
			_flash_status("HINT: NOTHING LEFT TO SCHEDULE", Color(1.0, 0.85, 0.35), 2.0)

		HintDirector.Kind.OFF_PLAN:
			_flash_status("HINT: %s -- %s" % [
				"THIS SCHEDULE HAS LEFT THE ONE I KNOW" if uses_erase_input()
					else "THIS LINE CAN'T REACH THE GOAL",
				"UNDO OR RESET" if uses_erase_input() else "RESET"],
				Color(1.0, 0.6, 0.35), 3.0)
			_pop(btn_reset, 1.2, 0.4)

	_withdraw_hint()

# --- Small feedback helpers --------------------------------------------------------

func _flash_status(text: String, color: Color, hold: float) -> void:
	label_status.text = text
	label_status.modulate = color
	_status_override_time = hold
	_pop(label_status, 1.15, 0.3)

func _restore_status_text() -> void:
	if session.cleared:
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
