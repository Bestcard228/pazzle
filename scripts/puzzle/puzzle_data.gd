class_name PuzzleData
extends RefCounted

# Which half of the puzzle the player is given, and which half they supply.
#
#   DRAW_SHAPES     the schedule is fixed, the player draws  (the original mode)
#   CHOOSE_ERASURES the shapes are given, the player schedules the erasures
#
# Both are the same generated puzzle; only the open half differs.
enum InputMode {
	DRAW_SHAPES = 0,
	CHOOSE_ERASURES = 1,
}

var board_definition: BoardDefinition
var target_geometry: VectorGeometry
var max_turns: int = 4
var required_shape_count: int = 2
var reference_solution: PuzzleSolution
var difficulty_rating: float = 1.0

var input_mode: int = InputMode.DRAW_SHAPES

# Seconds allowed per turn, or 0 for no clock. A turn that runs out is a turn the player
# did not act on, which the rules already have a name for: a skip. So the clock adds
# pressure without adding a new outcome -- it can only ever produce sequences the tree
# already contains.
var turn_time_limit: float = 0.0

# Colour layers. A single-layer puzzle leaves all of this empty and behaves exactly as it
# always has; the fields below are the layered mod's parallel of the fields above.
#
#   layer_boards      one board per layer -- same field, its own erasure walk
#   layer_targets     the goal for each layer, compared colour for colour
#   layered_solution  the reference shapes, one PuzzleSolution per layer
var layer_count: int = 1
var layer_boards: Array[BoardDefinition] = []
var layer_targets: Array[VectorGeometry] = []
var layered_solution: LayeredSolution

# Chained (MEDIUM) layered puzzles: one entry per stage, each holding one goal per layer.
var layer_stage_targets: Array = []

# The zone erased on each turn by the puzzle as generated. In DRAW mode this is just a
# readout of the board's own cycle; in ERASE mode it is the answer the player is looking
# for -- though not necessarily the only one, since different schedules can leave the
# same geometry standing.
var erase_order: Array[int] = []

# The erasure zone wiped on the final turn. The target always lives in the complement of
# this region, so it is effectively "which side of the board this puzzle ends on".
var final_erasure_zone: int = EraserSystem.ErasureRegion.TOP

# Earliest turn at which the reference solution matches the target, i.e. when the puzzle
# is actually won. Never 0, and not always max_turns - 1.
var completion_turn: int = -1

# Chained (MEDIUM) puzzles only. Each stage ends on a seam turn, and its target is what
# must be on the board at that moment -- the leftovers the next pattern builds from. The
# last entry is the final target. Empty for single-stage puzzles.
var stage_boundary_turns: Array[int] = []
var stage_targets: Array[VectorGeometry] = []

func is_multi_stage() -> bool:
	return stage_targets.size() > 1

func get_stage_count() -> int:
	return maxi(1, stage_targets.size())

# The goal to show while playing `stage`; falls back to the final target.
func get_stage_target(stage: int) -> VectorGeometry:
	if stage >= 0 and stage < stage_targets.size():
		return stage_targets[stage]
	return target_geometry

# The stage a given turn belongs to.
func get_stage_for_turn(turn: int) -> int:
	for i in range(stage_boundary_turns.size()):
		if turn <= stage_boundary_turns[i]:
			return i
	return maxi(0, stage_targets.size() - 1)

func _init(p_board_def: BoardDefinition = null, p_target: VectorGeometry = null, p_max_turns: int = 4):
	self.board_definition = p_board_def if p_board_def != null else BoardDefinition.new()
	self.target_geometry = p_target if p_target != null else VectorGeometry.new()
	self.max_turns = p_max_turns
	self.final_erasure_zone = EraserSystem.get_final_phase(p_max_turns, self.board_definition)

func uses_layers() -> bool:
	return layer_count > 1 and layered_solution != null

func get_layer_board(layer: int) -> BoardDefinition:
	if layer >= 0 and layer < layer_boards.size():
		return layer_boards[layer]
	return board_definition

# The per-layer goals for `stage`, falling back to the final ones.
func get_layer_stage_targets(stage: int) -> Array[VectorGeometry]:
	if stage >= 0 and stage < layer_stage_targets.size():
		var targets: Array[VectorGeometry] = []
		for geom in layer_stage_targets[stage]:
			targets.append(geom)
		return targets
	return layer_targets

func uses_erase_input() -> bool:
	return input_mode == InputMode.CHOOSE_ERASURES

func get_final_zone_name() -> String:
	return EraserSystem.get_region_name(final_erasure_zone)
