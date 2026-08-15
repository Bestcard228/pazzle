class_name PuzzleValidator
extends RefCounted

# Checks if every drawn shape in a candidate solution makes a necessary contribution to the final target
static func validate_necessary_contributions(solution: PuzzleSolution, target: VectorGeometry, board_def: BoardDefinition) -> bool:
	if solution == null or target == null or target.is_empty():
		return false

	var total_drawn := 0
	for turn in range(solution.get_turn_count()):
		var action := solution.get_action(turn)
		if action != null and action.shape_instance != null:
			total_drawn += 1

			# Create test solution with this shape removed
			var test_sol := solution.duplicate_solution()
			test_sol.clear_action(turn)

			var test_target := PuzzleSimulator.simulate(test_sol, board_def)

			# If removing this shape still yields the exact same target, it was NOT necessary!
			if test_target.is_equivalent_to(target):
				return false

	return total_drawn > 0

# Necessity restricted to one stage of a chained puzzle.
#
# In a two-stage puzzle the first half's shapes are wiped long before the final target is
# read, so they can never satisfy validate_necessary_contributions(). What they must do
# instead is matter to the state at the seam. This checks exactly that: every shape drawn
# in [from_turn, to_turn] must change the drawing as it stands at `to_turn`.
static func validate_stage_contributions(
	solution: PuzzleSolution,
	board_def: BoardDefinition,
	from_turn: int,
	to_turn: int
) -> bool:
	if solution == null or board_def == null or from_turn > to_turn:
		return false

	var stage_state := PuzzleSimulator.simulate_up_to_turn(solution, board_def, to_turn)
	if stage_state.is_empty():
		return false

	var drawn := 0
	for turn in range(from_turn, to_turn + 1):
		var action := solution.get_action(turn)
		if action == null or action.shape_instance == null:
			continue

		drawn += 1

		var test_sol := solution.duplicate_solution()
		test_sol.clear_action(turn)

		# Removing it must change the state at the seam, or it was never needed
		if PuzzleSimulator.simulate_up_to_turn(test_sol, board_def, to_turn).is_equivalent_to(stage_state):
			return false

	return drawn > 0

# Verifies that a target CANNOT be solved by a single shape on a single turn.
# `turns_to_test` limits the search to turns that can actually survive; pass an empty
# array to test every turn.
static func validate_not_solvable_in_one_turn(
	target: VectorGeometry,
	board_def: BoardDefinition,
	candidates: Array[ShapeInstance],
	max_turns: int,
	turns_to_test: Array[int] = []
) -> bool:
	var turns := turns_to_test
	if turns.is_empty():
		turns = []
		for t in range(max_turns):
			turns.append(t)

	var single_turn_sol := PuzzleSolution.new(max_turns)
	for t in turns:
		for shape in candidates:
			single_turn_sol.set_action(t, shape)
			var sim_res := PuzzleSimulator.simulate(single_turn_sol, board_def)
			if sim_res.is_equivalent_to(target):
				return false # Target IS solvable in 1 turn -> REJECT
			single_turn_sol.clear_action(t)
	return true

# Verifies that target geometry spans across at least 2 different quadrants of the board
static func validate_spans_multiple_quadrants(target: VectorGeometry, board_def: BoardDefinition) -> bool:
	if target == null or target.is_empty():
		return false

	var c := board_def.center
	var quadrants := {}

	for seg in target.segments:
		var mid := (seg.p1 + seg.p2) / 2.0
		var q_x := 1 if mid.x >= c.x else -1
		var q_y := 1 if mid.y >= c.y else -1
		var q_key := "%d,%d" % [q_x, q_y]
		quadrants[q_key] = true

	return quadrants.size() >= 2

# Verifies that WHEN each shape is drawn actually matters.
#
# The solution must use at least two distinct turns, and moving any one shape to a
# different free turn must change the outcome. Otherwise the puzzle is just "draw these
# shapes in any order", not a timing puzzle.
static func validate_multi_turn_timing(solution: PuzzleSolution, target: VectorGeometry, board_def: BoardDefinition) -> bool:
	if solution == null or target == null or target.is_empty():
		return false

	var drawn_turns: Array[int] = []
	for t in range(solution.get_turn_count()):
		var act := solution.get_action(t)
		if act != null and act.shape_instance != null:
			drawn_turns.append(t)

	if drawn_turns.size() < 2:
		return false

	for turn in drawn_turns:
		var shape := solution.get_action(turn).shape_instance
		for other in range(solution.get_turn_count()):
			if other == turn or drawn_turns.has(other):
				continue

			var test_sol := solution.duplicate_solution()
			test_sol.clear_action(turn)
			test_sol.set_action(other, shape)

			# Same result from a different turn -> the timing of this shape is irrelevant
			if PuzzleSimulator.simulate(test_sol, board_def).is_equivalent_to(target):
				return false

	return true

# Verifies the target cannot already be on screen at the end of the first turn — neither
# from the intended solution nor from any single shape the player might open with.
static func validate_not_completable_on_first_turn(
	solution: PuzzleSolution,
	target: VectorGeometry,
	board_def: BoardDefinition,
	candidates: Array[ShapeInstance]
) -> bool:
	if solution == null or target == null or target.is_empty():
		return false

	if PuzzleSimulator.simulate_up_to_turn(solution, board_def, 0).is_equivalent_to(target):
		return false

	var opening := PuzzleSolution.new(solution.get_turn_count())
	for shape in candidates:
		opening.set_action(0, shape)
		if PuzzleSimulator.simulate_up_to_turn(opening, board_def, 0).is_equivalent_to(target):
			return false

	return true

# Verifies that the puzzle is NOT solved solely by a shape drawn on the last turn
static func validate_not_last_turn_only(solution: PuzzleSolution, target: VectorGeometry, board_def: BoardDefinition) -> bool:
	if solution == null or target == null or target.is_empty():
		return false

	var max_t := solution.get_turn_count()
	var last_turn_index := max_t - 1

	# Create a test solution with ONLY the last turn shape
	var last_turn_only_sol := PuzzleSolution.new(max_t)
	var last_act := solution.get_action(last_turn_index)
	if last_act != null and last_act.shape_instance != null:
		last_turn_only_sol.set_action(last_turn_index, last_act.shape_instance)

	var last_only_target := PuzzleSimulator.simulate(last_turn_only_sol, board_def)

	# If target is identical to last-turn-only target, then earlier shapes contributed nothing! REJECT!
	if last_only_target.is_equivalent_to(target):
		return false

	# Ensure at least one shape was drawn BEFORE the last turn
	var early_drawn := false
	for t in range(last_turn_index):
		var act := solution.get_action(t)
		if act != null and act.shape_instance != null:
			early_drawn = true
			break

	return early_drawn
