class_name TestSolverGenerator
extends RefCounted

static func run_all_tests() -> int:
	var passed := 0
	print("--- Running TestSolverGenerator ---")

	if test_puzzle_generation():
		passed += 1
		print("  [PASS] test_puzzle_generation")
	else:
		print("  [FAIL] test_puzzle_generation")

	if test_necessity_validation():
		passed += 1
		print("  [PASS] test_necessity_validation")
	else:
		print("  [FAIL] test_necessity_validation")

	if test_easy_mode_generation():
		passed += 1
		print("  [PASS] test_easy_mode_generation")
	else:
		print("  [FAIL] test_easy_mode_generation")

	if test_hard_mode_7_turns():
		passed += 1
		print("  [PASS] test_hard_mode_7_turns")
	else:
		print("  [FAIL] test_hard_mode_7_turns")

	if test_not_last_turn_only():
		passed += 1
		print("  [PASS] test_not_last_turn_only")
	else:
		print("  [FAIL] test_not_last_turn_only")

	if test_default_turn_range():
		passed += 1
		print("  [PASS] test_default_turn_range")
	else:
		print("  [FAIL] test_default_turn_range")

	if test_final_zone_variety():
		passed += 1
		print("  [PASS] test_final_zone_variety")
	else:
		print("  [FAIL] test_final_zone_variety")

	if test_fixed_turn_count_still_varies_zone():
		passed += 1
		print("  [PASS] test_fixed_turn_count_still_varies_zone")
	else:
		print("  [FAIL] test_fixed_turn_count_still_varies_zone")

	if test_star_excluded_from_puzzles():
		passed += 1
		print("  [PASS] test_star_excluded_from_puzzles")
	else:
		print("  [FAIL] test_star_excluded_from_puzzles")

	if test_easy_starts_at_top_and_varies_zone():
		passed += 1
		print("  [PASS] test_easy_starts_at_top_and_varies_zone")
	else:
		print("  [FAIL] test_easy_starts_at_top_and_varies_zone")

	if test_never_completed_on_first_turn():
		passed += 1
		print("  [PASS] test_never_completed_on_first_turn")
	else:
		print("  [FAIL] test_never_completed_on_first_turn")

	if test_last_draw_not_always_final_turn():
		passed += 1
		print("  [PASS] test_last_draw_not_always_final_turn")
	else:
		print("  [FAIL] test_last_draw_not_always_final_turn")

	return passed

static func test_puzzle_generation() -> bool:
	var board_def := BoardDefinition.new(8)
	var puzzle := PuzzleGenerator.generate_puzzle(board_def, 0, 2, false) # 0 means default 4-7 turns
	if puzzle == null or puzzle.target_geometry == null or puzzle.target_geometry.is_empty():
		return false
	if puzzle.max_turns < 4 or puzzle.max_turns > 7:
		return false

	# The generator rotates the erasure cycle, so replays must use the puzzle's own board
	var sim_target := PuzzleSimulator.simulate(puzzle.reference_solution, puzzle.board_definition)
	return sim_target.is_equivalent_to(puzzle.target_geometry)

static func test_necessity_validation() -> bool:
	var board_def := BoardDefinition.new(8)
	var puzzle := PuzzleGenerator.generate_puzzle(board_def, 4, 2, false)
	if puzzle == null or puzzle.reference_solution == null:
		return false

	return PuzzleValidator.validate_necessary_contributions(puzzle.reference_solution, puzzle.target_geometry, puzzle.board_definition)

static func test_easy_mode_generation() -> bool:
	var board_def := BoardDefinition.new(8)
	var puzzle := PuzzleGenerator.generate_puzzle(board_def, 3, 2, true)
	if puzzle == null or puzzle.target_geometry == null or puzzle.target_geometry.is_empty():
		return false
	return true

static func test_hard_mode_7_turns() -> bool:
	var board_def := BoardDefinition.new(8)
	var puzzle := PuzzleGenerator.generate_puzzle(board_def, 7, 3, false)
	if puzzle == null or puzzle.target_geometry == null or puzzle.target_geometry.is_empty():
		return false

	var candidates := PuzzleGenerator.generate_candidate_pool(puzzle.board_definition)
	return PuzzleValidator.validate_not_solvable_in_one_turn(puzzle.target_geometry, puzzle.board_definition, candidates, 7)

static func test_not_last_turn_only() -> bool:
	var board_def := BoardDefinition.new(8)
	var puzzle := PuzzleGenerator.generate_puzzle(board_def, 5, 2, false)
	if puzzle == null or puzzle.reference_solution == null:
		return false

	return PuzzleValidator.validate_not_last_turn_only(puzzle.reference_solution, puzzle.target_geometry, puzzle.board_definition)

# Default generation (max_turns = 0) must stay inside 4-7 turns and actually use the range.
static func test_default_turn_range() -> bool:
	var board_def := BoardDefinition.new(8)
	var seen := {}

	for i in range(12):
		var puzzle := PuzzleGenerator.generate_puzzle(board_def, 0, 2, false)
		if puzzle.max_turns < PuzzleGenerator.DEFAULT_MIN_TURNS or puzzle.max_turns > PuzzleGenerator.DEFAULT_MAX_TURNS:
			return false
		seen[puzzle.max_turns] = true

	return seen.size() >= 2

# Puzzles must not all finish on the same erasure zone.
static func test_final_zone_variety() -> bool:
	var board_def := BoardDefinition.new(8)
	PuzzleGenerator.reset_zone_rotation()

	var zones := {}
	var prev := -1

	for i in range(8):
		var puzzle := PuzzleGenerator.generate_puzzle(board_def, 0, 2, false)
		var zone := puzzle.final_erasure_zone

		# The stored zone must be what the simulation actually erases last
		if zone != EraserSystem.get_final_phase(puzzle.max_turns, puzzle.board_definition):
			return false
		if zone == prev:
			return false # same zone twice in a row

		zones[zone] = true
		prev = zone

	# Two full bag draws must cover all four zones
	return zones.size() == EraserSystem.PHASE_COUNT

# Even with the turn count pinned, the final zone must still rotate.
static func test_fixed_turn_count_still_varies_zone() -> bool:
	var board_def := BoardDefinition.new(8)
	PuzzleGenerator.reset_zone_rotation()

	var zones := {}
	for i in range(4):
		var puzzle := PuzzleGenerator.generate_puzzle(board_def, 5, 2, false)
		if puzzle.max_turns != 5:
			return false
		zones[puzzle.final_erasure_zone] = true

	return zones.size() == EraserSystem.PHASE_COUNT

# The 8-point star must never reach a puzzle: not via the Normal candidate pool, not via
# the Easy-mode shape buttons (which double as the Easy candidate pool), and not as a
# reference solution shape.
static func test_star_excluded_from_puzzles() -> bool:
	var board_def := BoardDefinition.new(8)
	var star := ShapeDatabase.create_instance_from_path([0, 3, 6, 1, 4, 7, 2, 5, 0], board_def)
	if star == null:
		return false

	for is_easy in [false, true]:
		for candidate in PuzzleGenerator.generate_candidate_pool(board_def, is_easy):
			if candidate.geometry.is_equivalent_to(star.geometry):
				return false

	for shape_data in ShapeDatabase.get_easy_mode_predefined_shapes(board_def):
		if str(shape_data["name"]).to_lower() == "star":
			return false

	# And no generated solution should contain it
	for is_easy in [false, true]:
		for i in range(4):
			var puzzle := PuzzleGenerator.generate_puzzle(board_def, 0, 2, is_easy)
			for t in range(puzzle.max_turns):
				var act := puzzle.reference_solution.get_action(t)
				if act != null and act.shape_instance != null:
					if act.shape_instance.geometry.is_equivalent_to(star.geometry):
						return false

	return true

# Easy mode always begins erasing at TOP, yet must still spread its finishing zone. It
# does that by varying the turn count instead of rotating the cycle.
static func test_easy_starts_at_top_and_varies_zone() -> bool:
	var board_def := BoardDefinition.new(8)
	PuzzleGenerator.reset_zone_rotation()

	var zones := {}
	for i in range(4):
		var puzzle := PuzzleGenerator.generate_puzzle(board_def, 0, 2, true)

		if puzzle.board_definition.erasure_start_phase != EraserSystem.ErasureRegion.TOP:
			return false
		if EraserSystem.get_phase_for_turn(0, puzzle.board_definition) != EraserSystem.ErasureRegion.TOP:
			return false
		if puzzle.max_turns < PuzzleGenerator.DEFAULT_MIN_TURNS or puzzle.max_turns > PuzzleGenerator.DEFAULT_MAX_TURNS:
			return false

		zones[puzzle.final_erasure_zone] = true

	return zones.size() == EraserSystem.PHASE_COUNT

# The target must never already be on screen after the opening turn.
static func test_never_completed_on_first_turn() -> bool:
	var board_def := BoardDefinition.new(8)

	for is_easy in [true, false]:
		for i in range(4):
			var puzzle := PuzzleGenerator.generate_puzzle(board_def, 0, 2, is_easy)
			if puzzle.completion_turn < 1:
				return false

			# No opening shape may hand the player the target either
			var candidates := PuzzleGenerator.generate_candidate_pool(puzzle.board_definition, is_easy)
			if not PuzzleValidator.validate_not_completable_on_first_turn(
					puzzle.reference_solution, puzzle.target_geometry, puzzle.board_definition, candidates):
				return false

	return true

# Puzzles must not all require drawing right up to the final turn.
static func test_last_draw_not_always_final_turn() -> bool:
	var board_def := BoardDefinition.new(8)
	PuzzleGenerator.reset_zone_rotation()

	var early_finishes := 0
	for i in range(8):
		var puzzle := PuzzleGenerator.generate_puzzle(board_def, 0, 2, true)

		var last_draw := -1
		for t in range(puzzle.max_turns):
			var act := puzzle.reference_solution.get_action(t)
			if act != null and act.shape_instance != null:
				last_draw = t

		if last_draw < 0:
			return false
		if last_draw < puzzle.max_turns - 1:
			early_finishes += 1

	return early_finishes > 0
