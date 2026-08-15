class_name PuzzleData
extends RefCounted

var board_definition: BoardDefinition
var target_geometry: VectorGeometry
var max_turns: int = 4
var required_shape_count: int = 2
var reference_solution: PuzzleSolution
var difficulty_rating: float = 1.0

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

func get_final_zone_name() -> String:
	return EraserSystem.get_region_name(final_erasure_zone)
