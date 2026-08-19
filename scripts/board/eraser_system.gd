class_name EraserSystem
extends RefCounted

enum ErasureRegion {
	TOP = 0,
	RIGHT = 1,
	BOTTOM = 2,
	LEFT = 3
}




# The order the blade walks the four quarters. Every entry here is a permutation of all
# four regions, which is the whole invariant the puzzle rests on:
#
#     any four consecutive erasures clear the entire field
#
# so at most the last three turns can still be showing when the target is read. That is
# what makes the six EASY sequences (D S D / D D S / D D D, each optionally after one
# leading Skip) correct, and it stays true under every cycle below -- reordering the
# quarters changes which geometry survives, never how many turns can survive.
#
# Fixing TOP first is not a restriction: `erasure_start_phase` rotates the opening, so the
# rotations of a cycle are already reachable. That leaves 3! = 6 genuinely distinct walks,
# and all six are here.
#
# GDScript has no nested typed arrays, so this stays an untyped Array of Arrays.
const ERASURE_CYCLES := [
	[ErasureRegion.TOP, ErasureRegion.RIGHT, ErasureRegion.BOTTOM, ErasureRegion.LEFT],
	[ErasureRegion.TOP, ErasureRegion.LEFT, ErasureRegion.BOTTOM, ErasureRegion.RIGHT],
	[ErasureRegion.TOP, ErasureRegion.BOTTOM, ErasureRegion.LEFT, ErasureRegion.RIGHT],
	[ErasureRegion.TOP, ErasureRegion.BOTTOM, ErasureRegion.RIGHT, ErasureRegion.LEFT],
	[ErasureRegion.TOP, ErasureRegion.RIGHT, ErasureRegion.LEFT, ErasureRegion.BOTTOM],
	[ErasureRegion.TOP, ErasureRegion.LEFT, ErasureRegion.RIGHT, ErasureRegion.BOTTOM],
]

const CYCLE_CLOCKWISE := 0
const CYCLE_COUNTER_CLOCKWISE := 1
const CYCLE_COUNT := 6

const CYCLE_NAMES := [
	"CLOCKWISE",
	"COUNTER-CLOCKWISE",
	"ACROSS-LEFT",
	"ACROSS-RIGHT",
	"ZIGZAG-RIGHT",
	"ZIGZAG-LEFT",
]

enum ErasureShape {
	# The circular field is cut by two diagonals crossing at the centre, forming an X.
	# Each erasure takes one 90-degree wedge. This is the default.
	DIAGONAL_WEDGE = 0,
	# The original eraser: each erasure takes a whole half of the board.
	HALF_PLANE = 1,
}

const PHASE_COUNT := 4

# The four regions in the order the given cycle walks them.
static func get_cycle(cycle_id: int) -> Array[int]:
	var raw: Array = ERASURE_CYCLES[posmod(cycle_id, CYCLE_COUNT)]
	var order: Array[int] = []
	for region in raw:
		order.append(int(region))
	return order

static func get_erasure_order(board_def: BoardDefinition) -> Array[int]:
	var cycle_id: int = board_def.erasure_cycle_id if board_def != null else CYCLE_CLOCKWISE
	return get_cycle(cycle_id)

# The invariant every cycle has to hold: four steps, all four quarters, so four turns
# always clear the whole field.
static func is_valid_cycle(cycle: Array) -> bool:
	if cycle.size() != PHASE_COUNT:
		return false
	var seen := {}
	for region in cycle:
		seen[posmod(int(region), PHASE_COUNT)] = true
	return seen.size() == PHASE_COUNT

# Where in that walk a board starts. `erasure_start_phase` names a region, not a step
# index, so it means the same opening quarter under every cycle.
static func get_start_index(board_def: BoardDefinition) -> int:
	var start_region: int = board_def.erasure_start_phase if board_def != null else ErasureRegion.TOP
	var index := get_erasure_order(board_def).find(posmod(start_region, PHASE_COUNT))
	return index if index >= 0 else 0

# Maps a turn index onto the erasure phase actually applied at the end of that turn.
# The board's `erasure_start_phase` rotates the whole cycle, so two puzzles with the
# same turn count can still finish on different zones, and its `erasure_cycle_id`
# decides which of the six walks that cycle follows.
static func get_phase_for_turn(turn: int, board_def: BoardDefinition) -> int:
	# An explicit schedule wins over the cycle for the turns it covers; past its end the
	# board falls back to its own cycle, so a partially played board still answers.
	if board_def != null and turn >= 0 and turn < board_def.erasure_override.size():
		return posmod(board_def.erasure_override[turn], PHASE_COUNT)

	var order := get_erasure_order(board_def)
	return order[posmod(get_start_index(board_def) + turn, PHASE_COUNT)]

# Which zones may still be taken after `picks`, under the one rule that keeps any
# schedule well-formed: a zone cannot come round again until the other three have been
# used. For a puzzle of four turns or fewer that is exactly "never the same zone twice";
# for longer ones it is what keeps four consecutive erasures clearing the whole field,
# which is the property the whole sequence tree rests on.
static func legal_zones_after(picks: Array[int]) -> Array[int]:
	var blocked := {}
	var lookback: int = mini(picks.size(), PHASE_COUNT - 1)
	for i in range(picks.size() - lookback, picks.size()):
		blocked[posmod(picks[i], PHASE_COUNT)] = true

	var legal: Array[int] = []
	for zone in range(PHASE_COUNT):
		if not blocked.has(zone):
			legal.append(zone)
	return legal

static func is_legal_next_zone(picks: Array[int], zone: int) -> bool:
	return legal_zones_after(picks).has(posmod(zone, PHASE_COUNT))

# Whether a walk collapses under a given eraser shape.
#
# The four-step cycle is only worth four steps if no two of its erasures already cover the
# whole field between them. Two opposite half-planes do exactly that -- TOP and BOTTOM
# leave nothing -- so a walk that puts opposite quarters next to each other clears the
# field in two turns instead of four under the half-plane eraser, and the three turns of
# history the sequence tree relies on are gone with it. The X-wedge never has this
# problem: three quarters always leave a fourth standing, whatever order they go in.
#
# This is the same fact that already forces the wedge for the EASY tiers.
static func cycle_clears_field_early(cycle_id: int, shape: int) -> bool:
	if shape != ErasureShape.HALF_PLANE:
		return false

	var order := get_cycle(cycle_id)
	for i in range(PHASE_COUNT):
		var here := get_phase_axis(order[i])
		var next := get_phase_axis(order[(i + 1) % PHASE_COUNT])
		if here.dot(next) < 0.0:
			return true
	return false

# The walks that survive a given eraser shape. All six under the wedge; only the two
# rotations under the half-plane.
static func get_usable_cycles(shape: int) -> Array[int]:
	var usable: Array[int] = []
	for cycle_id in range(CYCLE_COUNT):
		if not cycle_clears_field_early(cycle_id, shape):
			usable.append(cycle_id)
	return usable

static func is_cycle_usable(cycle_id: int, shape: int) -> bool:
	return not cycle_clears_field_early(cycle_id, shape)

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

static func get_region_name(phase: int) -> String:
	match posmod(phase, PHASE_COUNT):
		ErasureRegion.TOP: return "TOP"
		ErasureRegion.RIGHT: return "RIGHT"
		ErasureRegion.BOTTOM: return "BOTTOM"
		ErasureRegion.LEFT: return "LEFT"
		_: return "UNKNOWN"

static func get_shape_name(shape: int) -> String:
	return "X-WEDGE" if shape == ErasureShape.DIAGONAL_WEDGE else "HALF"

# The phase erased on the final turn of a `max_turns` puzzle. The target drawing always
# lives outside this region, so it is what "which zone does the puzzle end on" means
# from the player's point of view.
static func get_final_phase(max_turns: int, board_def: BoardDefinition) -> int:
	return get_phase_for_turn(max_turns - 1, board_def)

# Inverse of get_final_phase: the start phase a board needs so that a `max_turns`
# puzzle finishes on `final_phase`. Walking back is walking the same order backwards,
# so the direction has to match the board this will be applied to.
static func start_phase_for_final(final_phase: int, max_turns: int,
		cycle_id: int = CYCLE_CLOCKWISE) -> int:
	var order := get_cycle(cycle_id)
	var final_index := order.find(posmod(final_phase, PHASE_COUNT))
	if final_index < 0:
		final_index = 0
	return order[posmod(final_index - (max_turns - 1), PHASE_COUNT)]

static func get_cycle_name(cycle_id: int) -> String:
	return CYCLE_NAMES[posmod(cycle_id, CYCLE_COUNT)]

# The walk spelled out, for tooltips: "TOP > BOTTOM > LEFT > RIGHT".
static func get_cycle_description(cycle_id: int) -> String:
	var parts: Array[String] = []
	for region in get_cycle(cycle_id):
		parts.append(get_region_name(region))
	return " > ".join(parts)
