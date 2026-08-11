class_name EraserSystem
extends RefCounted

enum ErasureRegion {
	TOP = 0,
	RIGHT = 1,
	BOTTOM = 2,
	LEFT = 3
}




enum ErasureShape {
	# The circular field is cut by two diagonals crossing at the centre, forming an X.
	# Each erasure takes one 90-degree wedge. This is the default.
	DIAGONAL_WEDGE = 0,
	# The original eraser: each erasure takes a whole half of the board.
	HALF_PLANE = 1,
}

const PHASE_COUNT := 4

# Maps a turn index onto the erasure phase actually applied at the end of that turn.
# The board's `erasure_start_phase` rotates the whole cycle, so two puzzles with the
# same turn count can still finish on different zones.
static func get_phase_for_turn(turn: int, board_def: BoardDefinition) -> int:
	var offset: int = board_def.erasure_start_phase if board_def != null else 0
	return posmod(turn + offset, PHASE_COUNT)

# Unit vector from the board centre into the middle of a phase's region.
static func get_phase_axis(phase: int) -> Vector2:
	match posmod(phase, PHASE_COUNT):
		ErasureRegion.TOP: return Vector2(0, -1)
		ErasureRegion.RIGHT: return Vector2(1, 0)
		ErasureRegion.BOTTOM: return Vector2(0, 1)
		ErasureRegion.LEFT: return Vector2(-1, 0)
		_: return Vector2.ZERO

# The area wiped by an absolute phase (0..3), in the board's shape mode.
static func get_erasure_region_for_phase(phase: int, board_def: BoardDefinition) -> EraseArea:
	if board_def != null and board_def.erasure_shape == ErasureShape.DIAGONAL_WEDGE:
		return EraseArea.make_wedge(board_def.center, get_phase_axis(phase))
	return EraseArea.make_rect(get_erasure_rect_for_phase(phase, board_def))

# The area wiped at the end of `turn`, honouring the board's start phase and shape mode.
static func get_erasure_region_for_turn(turn: int, board_def: BoardDefinition) -> EraseArea:
	return get_erasure_region_for_phase(get_phase_for_turn(turn, board_def), board_def)

# Rect2 in quantized grid space for the HALF_PLANE eraser.
static func get_erasure_rect_for_phase(phase: int, board_def: BoardDefinition) -> Rect2:
	var c := board_def.center
	var res := board_def.resolution

	match posmod(phase, PHASE_COUNT):
		ErasureRegion.TOP:
			return Rect2(0, 0, res.x, c.y)
		ErasureRegion.RIGHT:
			return Rect2(c.x, 0, res.x - c.x, res.y)
		ErasureRegion.BOTTOM:
			return Rect2(0, c.y, res.x, res.y - c.y)
		ErasureRegion.LEFT:
			return Rect2(0, 0, c.x, res.y)
		_:
			return Rect2()

static func get_erasure_rect_for_turn(turn: int, board_def: BoardDefinition) -> Rect2:
	return get_erasure_rect_for_phase(get_phase_for_turn(turn, board_def), board_def)

static func get_region_name(phase: int) -> String:
	match posmod(phase, PHASE_COUNT):
		ErasureRegion.TOP: return "TOP"
		ErasureRegion.RIGHT: return "RIGHT"
		ErasureRegion.BOTTOM: return "BOTTOM"
		ErasureRegion.LEFT: return "LEFT"
		_: return "UNKNOWN"

static func get_region_name_for_turn(turn: int, board_def: BoardDefinition) -> String:
	return get_region_name(get_phase_for_turn(turn, board_def))

static func get_shape_name(shape: int) -> String:
	return "X-WEDGE" if shape == ErasureShape.DIAGONAL_WEDGE else "HALF"

# The phase erased on the final turn of a `max_turns` puzzle. The target drawing always
# lives outside this region, so it is what "which zone does the puzzle end on" means
# from the player's point of view.
static func get_final_phase(max_turns: int, board_def: BoardDefinition) -> int:
	return get_phase_for_turn(max_turns - 1, board_def)

# Inverse of get_final_phase: the start phase a board needs so that a `max_turns`
# puzzle finishes on `final_phase`.
static func start_phase_for_final(final_phase: int, max_turns: int) -> int:
	return posmod(final_phase - (max_turns - 1), PHASE_COUNT)

# For a board whose cycle starts at TOP, the turn count that finishes on `final_phase`.
# Only valid because `min_turns .. min_turns + 3` is exactly one full cycle, so each
# length maps to a different finishing zone.
static func turn_count_for_final_phase_from_top(final_phase: int, min_turns: int) -> int:
	return posmod(final_phase - (min_turns - 1), PHASE_COUNT) + min_turns
