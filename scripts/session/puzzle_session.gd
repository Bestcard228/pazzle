class_name PuzzleSession
extends RefCounted

# One puzzle being played: the state, and the rules for moving it forward.
#
# The three input modes used to be `if`s scattered through the UI -- what to simulate,
# which board to simulate it on, what a skip does, when a turn is over. They differ in
# only two things:
#
#     playing_solution()   whose shapes are on the board
#     active_board()       what gets erased, and when
#
# so those are the pair everything else is written against, and the branching collapses
# into this file instead of running through the whole of game_ui.
#
# Nothing here touches a node. The UI reacts to the signals and does the drawing, which is
# also what makes the flow testable without a scene.

signal turn_advanced(turn: int)
signal layer_advanced(layer: int)
signal stage_cleared(stage: int)
signal puzzle_cleared()
signal schedule_changed()

# What committing a shape did, so the caller knows whether the turn is over.
enum Commit { REJECTED, LAYER_DONE, TURN_DONE }

var puzzle: PuzzleData
var solution: PuzzleSolution
var layered: LayeredSolution
var erase: ErasePuzzleController

var turn: int = 0
var stage: int = 0
var active_layer: int = 0
var cleared: bool = false

func setup(p_puzzle: PuzzleData) -> void:
	puzzle = p_puzzle
	solution = PuzzleSolution.new(puzzle.max_turns)
	layered = LayeredSolution.new(maxi(1, puzzle.layer_count), puzzle.max_turns)
	erase = ErasePuzzleController.new(puzzle)
	reset()

# Back to turn zero on the same puzzle, keeping nothing the player did.
func reset() -> void:
	solution = PuzzleSolution.new(puzzle.max_turns)
	layered = LayeredSolution.new(maxi(1, puzzle.layer_count), puzzle.max_turns)
	erase.reset()
	turn = 0
	stage = 0
	active_layer = 0
	cleared = false

# --- What kind of puzzle this is ----------------------------------------------------

func is_ready() -> bool:
	return puzzle != null

func uses_erase_input() -> bool:
	return puzzle != null and puzzle.uses_erase_input()

func uses_layers() -> bool:
	return puzzle != null and puzzle.uses_layers()

func layer_count() -> int:
	return maxi(1, puzzle.layer_count) if puzzle != null else 1

func turns_remain() -> bool:
	return puzzle != null and turn < puzzle.max_turns

func last_resolved_turn() -> int:
	return turn - 1

# --- The pair everything else is written against -------------------------------------

# Whose shapes are on the board: the player's in DRAW mode, the given plan in ERASE.
func playing_solution() -> PuzzleSolution:
	if uses_erase_input():
		return puzzle.reference_solution
	return solution

# What gets erased and when: the puzzle's own schedule, or the one the player is building.
func active_board() -> BoardDefinition:
	if uses_erase_input():
		return erase.scheduled_board()
	return puzzle.board_definition

# --- Moves ---------------------------------------------------------------------------

# A shape goes into the colour currently in hand. A layered turn is over only once every
# colour has acted -- D(r) then D(g) -- so this reports which of the two happened.
func commit_shape(shape: ShapeInstance) -> int:
	if cleared or not turns_remain() or shape == null:
		return Commit.REJECTED

	if uses_layers():
		layered.set_action(turn, active_layer, shape)
		active_layer += 1
		if active_layer < layer_count():
			layer_advanced.emit(active_layer)
			return Commit.LAYER_DONE
		active_layer = 0
		advance_turn()
		return Commit.TURN_DONE

	solution.set_action(turn, shape)
	advance_turn()
	return Commit.TURN_DONE

# S(r) S(g): a skipped turn is skipped in every colour at once, which is what the
# sequences say -- the layers never diverge on whether a turn acts.
func skip_turn() -> bool:
	if cleared or not turns_remain() or uses_erase_input():
		return false

	if uses_layers():
		for layer in range(layer_count()):
			layered.clear_action(turn, layer)
		active_layer = 0
	else:
		solution.clear_action(turn)

	advance_turn()
	return true

func pick_zone(zone: int) -> bool:
	if cleared or not uses_erase_input() or not erase.select_zone(zone):
		return false
	schedule_changed.emit()
	advance_turn()
	return true

func can_pick_zone(zone: int) -> bool:
	return uses_erase_input() and erase.can_select(zone)

func rejection_reason(zone: int) -> String:
	return erase.rejection_reason(zone)

# Taking back the last quarter, which is the only way back out of a finished schedule.
func undo_pick() -> bool:
	if not uses_erase_input() or erase.undo_last() < 0:
		return false

	turn = erase.current_turn()
	stage = puzzle.get_stage_for_turn(turn) if puzzle.is_multi_stage() else 0
	cleared = false
	schedule_changed.emit()
	return true

func advance_turn() -> void:
	turn += 1
	turn_advanced.emit(turn)
	_check_victory()

func advance_stage() -> void:
	stage += 1

# --- Reading the board ---------------------------------------------------------------

func surviving_geometry() -> VectorGeometry:
	return PuzzleSimulator.simulate_up_to_turn(playing_solution(), active_board(), last_resolved_turn())

func layer_geometry() -> Array[VectorGeometry]:
	return PuzzleSimulator.simulate_layers_up_to_turn(layered, puzzle.layer_boards, last_resolved_turn())

# The quarter each layer loses on `at_turn`, for the warnings the board draws.
func layer_phases(at_turn: int) -> Array[int]:
	var phases: Array[int] = []
	for board in puzzle.layer_boards:
		phases.append(EraserSystem.get_phase_for_turn(at_turn, board) if at_turn >= 0 else -1)
	return phases

# Which turns have a shape committed on them, for the timeline.
func drawn_turn_flags() -> Array[bool]:
	var drawn: Array[bool] = []
	for t in range(puzzle.max_turns):
		if uses_layers():
			drawn.append(layered.is_draw_turn(t))
		else:
			var action := playing_solution().get_action(t)
			drawn.append(action != null and action.shape_instance != null)
	return drawn

# Colour for colour when there are layers, and against the one goal when there are not.
# Comparing the merged picture instead would let a red line answer for a green one, which
# is the distinction the layered mode exists to draw.
func stage_target_reached() -> bool:
	if uses_layers():
		return PuzzleSimulator.layers_are_equivalent(
			layer_geometry(), puzzle.get_layer_stage_targets(stage))
	return surviving_geometry().is_equivalent_to(puzzle.get_stage_target(stage))

func _check_victory() -> void:
	if not stage_target_reached():
		return

	# A middle stage clears into the next one instead of ending the puzzle
	if stage < puzzle.get_stage_count() - 1:
		stage_cleared.emit(stage)
		return

	cleared = true
	puzzle_cleared.emit()
