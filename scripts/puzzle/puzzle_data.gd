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

func _init(p_board_def: BoardDefinition = null, p_target: VectorGeometry = null, p_max_turns: int = 4):
	self.board_definition = p_board_def if p_board_def != null else BoardDefinition.new()
	self.target_geometry = p_target if p_target != null else VectorGeometry.new()
	self.max_turns = p_max_turns
	self.final_erasure_zone = EraserSystem.get_final_phase(p_max_turns, self.board_definition)

func get_final_zone_name() -> String:
	return EraserSystem.get_region_name(final_erasure_zone)
