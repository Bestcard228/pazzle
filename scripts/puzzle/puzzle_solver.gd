class_name PuzzleSolver
extends RefCounted

static func solve(
	target_geometry: VectorGeometry,
	board_def: BoardDefinition,
	max_turns: int,
	candidate_shapes: Array[ShapeInstance],
	max_solutions_to_find: int = 100
) -> Array[PuzzleSolution]:
	var solutions: Array[PuzzleSolution] = []
	var current_solution := PuzzleSolution.new(max_turns)
	_solve_recursive(0, max_turns, current_solution, candidate_shapes, target_geometry, board_def, solutions, max_solutions_to_find)
	return solutions

static func _solve_recursive(
	turn: int,
	max_turns: int,
	current_sol: PuzzleSolution,
	candidates: Array[ShapeInstance],
	target: VectorGeometry,
	board_def: BoardDefinition,
	solutions: Array[PuzzleSolution],
	max_solutions: int
) -> void:
	if solutions.size() >= max_solutions:
		return

	if turn == max_turns:
		var result := PuzzleSimulator.simulate(current_sol, board_def)
		if result.is_equivalent_to(target):
			solutions.append(current_sol.duplicate_solution())
		return

	# Option 1: Draw nothing on this turn
	current_sol.set_action(turn, null)
	_solve_recursive(turn + 1, max_turns, current_sol, candidates, target, board_def, solutions, max_solutions)

	# Option 2: Try each candidate shape
	for shape in candidates:
		if solutions.size() >= max_solutions:
			break
		current_sol.set_action(turn, shape)
		_solve_recursive(turn + 1, max_turns, current_sol, candidates, target, board_def, solutions, max_solutions)
