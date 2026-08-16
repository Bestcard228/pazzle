class_name LayerSystem
extends RefCounted

# Colour layers.
#
# A layer is a separate sheet of geometry on the same field. Every turn erases one quarter
# from EACH layer -- but a different quarter per layer, because each carries its own
# erasure walk. So the blade never removes "the red layer"; it removes red's quarter from
# red and green's quarter from green, in the same turn.
#
# That is the whole mechanic, and it is why nothing about the turn structure changes. From
# one layer's point of view it is erased exactly once per turn, one quarter at a time, and
# four turns clear it -- which is the single-layer game unchanged. The D/S sequences
# therefore carry over untouched: a layered turn is one row of
#
#     D(r) D(g)   S(r) S(g)   D(r) D(g)
#
# where both layers take the same action and differ only in what the blade takes from them.

const MAX_LAYERS := 4
const SINGLE_LAYER := 1

const LAYER_COLORS: Array[Color] = [
	Color(0.95, 0.35, 0.40),  # red
	Color(0.35, 0.90, 0.55),  # green
	Color(0.40, 0.65, 1.00),  # blue
	Color(0.95, 0.80, 0.30),  # yellow
]

const LAYER_NAMES: Array[String] = ["RED", "GREEN", "BLUE", "YELLOW"]

# The single-layer game keeps its original ink rather than becoming "the red layer".
const SINGLE_LAYER_COLOR := Color(0.95, 0.75, 0.20, 0.95)

static func get_layer_color(layer: int, layer_count: int = 2) -> Color:
	if layer_count <= SINGLE_LAYER:
		return SINGLE_LAYER_COLOR
	return LAYER_COLORS[posmod(layer, MAX_LAYERS)]

static func get_layer_name(layer: int) -> String:
	return LAYER_NAMES[posmod(layer, MAX_LAYERS)]

static func clamp_layer_count(count: int) -> int:
	return clampi(count, SINGLE_LAYER, MAX_LAYERS)

# Each layer needs its own walk, or the layers are the same puzzle drawn twice in
# different colours. Walks are handed out from the usable set for the board's eraser,
# spread as far apart as that set allows.
static func assign_layer_cycles(layer_count: int, shape: int, rng: RandomNumberGenerator) -> Array[int]:
	var usable := EraserSystem.get_usable_cycles(shape)
	var cycles: Array[int] = []

	if usable.is_empty():
		for i in range(layer_count):
			cycles.append(EraserSystem.CYCLE_CLOCKWISE)
		return cycles

	var pool := usable.duplicate()
	pool.shuffle()

	for i in range(layer_count):
		# More layers than distinct walks only happens under the half-plane eraser, where
		# just two survive; then the walks repeat and the start phases carry the difference.
		cycles.append(pool[i % pool.size()])

	return cycles

# Opening quarters, one per layer. Two layers that walk the same order but open on
# different quarters are still genuinely different puzzles, so this is what keeps them
# apart when the walk pool runs short.
static func assign_layer_start_phases(layer_count: int, rng: RandomNumberGenerator) -> Array[int]:
	var phases: Array[int] = []
	var pool: Array[int] = []
	for phase in range(EraserSystem.PHASE_COUNT):
		pool.append(phase)
	pool.shuffle()

	for i in range(layer_count):
		phases.append(pool[i % pool.size()])

	return phases
