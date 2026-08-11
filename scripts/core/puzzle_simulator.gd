class_name PuzzleSimulator
extends RefCounted

# Authoritative simulation function
static func simulate(solution: PuzzleSolution, board_def: BoardDefinition) -> VectorGeometry:
	if solution == null or board_def == null:
		return VectorGeometry.new()

	return simulate_up_to_turn(solution, board_def, solution.get_turn_count() - 1)

# Simulates up to turn `up_to_turn` (0-indexed inclusive), returning the intermediate surviving geometry
static func simulate_up_to_turn(solution: PuzzleSolution, board_def: BoardDefinition, up_to_turn: int) -> VectorGeometry:
	if solution == null or board_def == null:
		return VectorGeometry.new()

	var current_drawing := VectorGeometry.new()
	var end_turn: int = int(min(up_to_turn, solution.get_turn_count() - 1))

	for t in range(end_turn + 1):
		var action := solution.get_action(t)
		if action != null and action.shape_instance != null and action.shape_instance.geometry != null:
			current_drawing.merge(action.shape_instance.geometry)

		var erased_area := EraserSystem.get_erasure_region_for_turn(t, board_def)
		current_drawing = GeometryClipper.clip_geometry_out(current_drawing, erased_area)

	return current_drawing.canonicalize()

# The earliest turn at which the running drawing already equals `target`, or -1 if it
# never does. This is the same comparison the game's victory check makes each turn, so it
# is the authoritative answer to "when does this puzzle actually finish".
static func get_completion_turn(solution: PuzzleSolution, board_def: BoardDefinition, target: VectorGeometry) -> int:
	if solution == null or board_def == null or target == null:
		return -1

	for t in range(solution.get_turn_count()):
		if simulate_up_to_turn(solution, board_def, t).is_equivalent_to(target):
			return t
	return -1

# Which turns of a `max_turns` puzzle can still leave anything behind at the end.
#
# A shape drawn on turn t is clipped by every erasure from t to max_turns - 1. Once
# those regions cover the whole board the shape is gone no matter what it was, so the
# late turns are the only ones that can contribute to the target. This is derived by
# running the real erasure regions rather than hardcoded, so it stays correct if the
# region geometry is ever changed.
static func get_survivable_turns(board_def: BoardDefinition, max_turns: int) -> Array[int]:
	var result: Array[int] = []
	if board_def == null or max_turns <= 0:
		return result

	var probe := _build_board_probe_geometry(board_def)

	for t in range(max_turns):
		var geom := probe.duplicate_geometry()
		for u in range(t, max_turns):
			geom = GeometryClipper.clip_geometry_out(geom, EraserSystem.get_erasure_region_for_turn(u, board_def))
			if geom.is_empty():
				break
		if not geom.is_empty():
			result.append(t)

	return result

# A maximally spread-out drawing: the full node ring plus every long diagonal. If this
# cannot survive a run of erasures, nothing can — which also means the window it yields
# is an upper bound, not a promise that ordinary shapes reach every turn in it. Under the
# half-plane eraser in particular, the diameters sit exactly on the centre axis and slip
# through, so the window reads one turn wider than most shapes can actually use.
static func _build_board_probe_geometry(board_def: BoardDefinition) -> VectorGeometry:
	var geom := VectorGeometry.new()
	var n := board_def.node_count
	for i in range(n):
		geom.add_line(board_def.get_node_position(i), board_def.get_node_position((i + 1) % n))
		geom.add_line(board_def.get_node_position(i), board_def.get_node_position((i + n / 2) % n))
	return geom
