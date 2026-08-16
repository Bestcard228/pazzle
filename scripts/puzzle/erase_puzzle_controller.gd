class_name ErasePuzzleController
extends RefCounted

# The playable half of ERASE mode, with no rendering and no input handling in it.
#
# The shapes and their timing are given -- they are the puzzle. What the player supplies
# is the schedule: which quarter is wiped at the end of each turn, and in what order. This
# holds that schedule, answers what is still legal, and reports what the board looks like
# after the turns committed so far.
#
# It deliberately owns no board of its own: `scheduled_board()` hands back the puzzle's
# board wearing the player's schedule, which every existing consumer -- PuzzleSimulator,
# DrawingBoard, TurnTimeline -- already knows how to read.

signal zone_committed(zone: int, turn: int)
signal zone_rejected(zone: int, reason: String)
signal schedule_changed()

var puzzle: PuzzleData
var solution: ErasureSolution
var hovered_zone: int = -1

func _init(p_puzzle: PuzzleData = null):
	setup(p_puzzle)

func setup(p_puzzle: PuzzleData) -> void:
	puzzle = p_puzzle
	solution = ErasureSolution.new(puzzle.max_turns if puzzle != null else 4)
	hovered_zone = -1

func reset() -> void:
	solution.clear()
	hovered_zone = -1
	schedule_changed.emit()

func current_turn() -> int:
	return solution.get_turn_count()

func is_complete() -> bool:
	return solution.is_full()

func legal_zones() -> Array[int]:
	return solution.legal_zones()

func can_select(zone: int) -> bool:
	return solution.can_add(zone)

# Why a zone is unavailable, in the terms the player is thinking in.
func rejection_reason(zone: int) -> String:
	if is_complete():
		return "NO TURNS LEFT"
	if solution.zones.has(zone):
		return "%s IS STILL COOLING DOWN" % EraserSystem.get_region_name(zone)
	return ""

func set_hovered_zone(zone: int) -> void:
	if hovered_zone == zone:
		return
	hovered_zone = zone
	schedule_changed.emit()

func select_zone(zone: int) -> bool:
	if not can_select(zone):
		zone_rejected.emit(zone, rejection_reason(zone))
		return false

	var turn := solution.get_turn_count()
	solution.add_zone(zone)
	zone_committed.emit(zone, turn)
	schedule_changed.emit()
	return true

func undo_last() -> int:
	var removed := solution.undo_last()
	if removed >= 0:
		schedule_changed.emit()
	return removed

# The puzzle's board erased the way the player has scheduled it so far.
func scheduled_board() -> BoardDefinition:
	if puzzle == null:
		return null
	return solution.apply_to(puzzle.board_definition)

# What is still standing after the turns committed so far.
func current_geometry() -> VectorGeometry:
	if puzzle == null:
		return VectorGeometry.new()
	return PuzzleSimulator.simulate_up_to_turn(
		puzzle.reference_solution, scheduled_board(), current_turn() - 1)

func geometry_after(zone: int) -> VectorGeometry:
	if puzzle == null or not can_select(zone):
		return current_geometry()
	var preview := solution.duplicate_solution()
	preview.add_zone(zone)
	return PuzzleSimulator.simulate_up_to_turn(
		puzzle.reference_solution, preview.apply_to(puzzle.board_definition),
		preview.get_turn_count() - 1)

# Whether the schedule so far still matches the one the puzzle was generated from. Used
# only to decide whether a hint can honestly point at the next intended zone -- a
# different schedule may still reach the target, so this is not a loss condition.
func follows_reference() -> bool:
	if puzzle == null or puzzle.erase_order.is_empty():
		return false
	for turn in range(solution.get_turn_count()):
		if turn >= puzzle.erase_order.size():
			return false
		if solution.get_zone(turn) != puzzle.erase_order[turn]:
			return false
	return true

func reference_zone_for_current_turn() -> int:
	var turn := current_turn()
	if puzzle == null or turn < 0 or turn >= puzzle.erase_order.size():
		return -1
	return puzzle.erase_order[turn]
