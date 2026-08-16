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

	if test_easy_board_is_fixed():
		passed += 1
		print("  [PASS] test_easy_board_is_fixed")
	else:
		print("  [FAIL] test_easy_board_is_fixed")

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

	if test_both_eraser_shapes_generate():
		passed += 1
		print("  [PASS] test_both_eraser_shapes_generate")
	else:
		print("  [FAIL] test_both_eraser_shapes_generate")

	if test_easy_sequence_set_is_exactly_six():
		passed += 1
		print("  [PASS] test_easy_sequence_set_is_exactly_six")
	else:
		print("  [FAIL] test_easy_sequence_set_is_exactly_six")

	if test_easy_covers_all_six_sequences():
		passed += 1
		print("  [PASS] test_easy_covers_all_six_sequences")
	else:
		print("  [FAIL] test_easy_covers_all_six_sequences")

	if test_easy_plus_rotates_opening():
		passed += 1
		print("  [PASS] test_easy_plus_rotates_opening")
	else:
		print("  [FAIL] test_easy_plus_rotates_opening")

	if test_easy_plus_plus_uses_harder_shapes():
		passed += 1
		print("  [PASS] test_easy_plus_plus_uses_harder_shapes")
	else:
		print("  [FAIL] test_easy_plus_plus_uses_harder_shapes")

	if test_medium_chain_structure():
		passed += 1
		print("  [PASS] test_medium_chain_structure")
	else:
		print("  [FAIL] test_medium_chain_structure")

	if test_medium_stages_are_progressive():
		passed += 1
		print("  [PASS] test_medium_stages_are_progressive")
	else:
		print("  [FAIL] test_medium_stages_are_progressive")

	if test_every_erasure_cycle_generates_every_tier():
		passed += 1
		print("  [PASS] test_every_erasure_cycle_generates_every_tier")
	else:
		print("  [FAIL] test_every_erasure_cycle_generates_every_tier")

	return passed

# The erasure order is an ordering, not a tier: every difficulty must still generate a
# puzzle whose reference solution replays to its own target, under every one of the six
# walks. If any of this needed new sequences, it would fail here.
static func test_every_erasure_cycle_generates_every_tier() -> bool:
	for difficulty in PuzzleGenerator.DIFFICULTY_ORDER:
		for cycle_id in range(EraserSystem.CYCLE_COUNT):
			var board_def := BoardDefinition.new(8)
			var puzzle := PuzzleGenerator.generate_puzzle(board_def, 0, 2, difficulty, 400, cycle_id)

			if puzzle == null or puzzle.target_geometry == null or puzzle.target_geometry.is_empty():
				return false
			if puzzle.board_definition.erasure_cycle_id != cycle_id:
				return false

			var replay := PuzzleSimulator.simulate(puzzle.reference_solution, puzzle.board_definition)
			if not replay.is_equivalent_to(puzzle.target_geometry):
				return false

			# The puzzle has to finish where it says it does, walking its own order
			if EraserSystem.get_final_phase(puzzle.max_turns, puzzle.board_definition) != puzzle.final_erasure_zone:
				return false

	return true

static func test_puzzle_generation() -> bool:
	var board_def := BoardDefinition.new(8)
	var puzzle := PuzzleGenerator.generate_puzzle(board_def, 0, 2, PuzzleGenerator.Difficulty.NORMAL) # 0 means default 4-7 turns
	if puzzle == null or puzzle.target_geometry == null or puzzle.target_geometry.is_empty():
		return false
	if puzzle.max_turns < 4 or puzzle.max_turns > 7:
		return false

	# The generator rotates the erasure cycle, so replays must use the puzzle's own board
	var sim_target := PuzzleSimulator.simulate(puzzle.reference_solution, puzzle.board_definition)
	return sim_target.is_equivalent_to(puzzle.target_geometry)

static func test_necessity_validation() -> bool:
	var board_def := BoardDefinition.new(8)
	var puzzle := PuzzleGenerator.generate_puzzle(board_def, 4, 2, PuzzleGenerator.Difficulty.NORMAL)
	if puzzle == null or puzzle.reference_solution == null:
		return false

	return PuzzleValidator.validate_necessary_contributions(puzzle.reference_solution, puzzle.target_geometry, puzzle.board_definition)

static func test_easy_mode_generation() -> bool:
	var board_def := BoardDefinition.new(8)
	var puzzle := PuzzleGenerator.generate_puzzle(board_def, 3, 2, PuzzleGenerator.Difficulty.EASY)
	if puzzle == null or puzzle.target_geometry == null or puzzle.target_geometry.is_empty():
		return false
	return true

static func test_hard_mode_7_turns() -> bool:
	var board_def := BoardDefinition.new(8)
	var puzzle := PuzzleGenerator.generate_puzzle(board_def, 7, 3, PuzzleGenerator.Difficulty.NORMAL)
	if puzzle == null or puzzle.target_geometry == null or puzzle.target_geometry.is_empty():
		return false

	var candidates := PuzzleGenerator.generate_candidate_pool(puzzle.board_definition)
	return PuzzleValidator.validate_not_solvable_in_one_turn(puzzle.target_geometry, puzzle.board_definition, candidates, 7)

static func test_not_last_turn_only() -> bool:
	var board_def := BoardDefinition.new(8)
	var puzzle := PuzzleGenerator.generate_puzzle(board_def, 5, 2, PuzzleGenerator.Difficulty.NORMAL)
	if puzzle == null or puzzle.reference_solution == null:
		return false

	return PuzzleValidator.validate_not_last_turn_only(puzzle.reference_solution, puzzle.target_geometry, puzzle.board_definition)

# Default generation (max_turns = 0) must stay inside 4-7 turns and actually use the range.
static func test_default_turn_range() -> bool:
	var board_def := BoardDefinition.new(8)
	var seen := {}

	for i in range(12):
		var puzzle := PuzzleGenerator.generate_puzzle(board_def, 0, 2, PuzzleGenerator.Difficulty.NORMAL)
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
		var puzzle := PuzzleGenerator.generate_puzzle(board_def, 0, 2, PuzzleGenerator.Difficulty.NORMAL)
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
		var puzzle := PuzzleGenerator.generate_puzzle(board_def, 5, 2, PuzzleGenerator.Difficulty.NORMAL)
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

	for tier in PuzzleGenerator.DIFFICULTY_ORDER:
		for candidate in PuzzleGenerator.generate_candidate_pool(board_def, tier):
			if candidate.geometry.is_equivalent_to(star.geometry):
				return false

	for shape_data in ShapeDatabase.get_easy_mode_predefined_shapes(board_def):
		if str(shape_data["name"]).to_lower() == "star":
			return false

	# And no generated solution should contain it
	for tier in PuzzleGenerator.DIFFICULTY_ORDER:
		for i in range(2):
			var puzzle := PuzzleGenerator.generate_puzzle(board_def, 0, 2, tier)
			for t in range(puzzle.max_turns):
				var act := puzzle.reference_solution.get_action(t)
				if act != null and act.shape_instance != null:
					if act.shape_instance.geometry.is_equivalent_to(star.geometry):
						return false

	return true

# EASY always begins erasing at TOP and always uses the X-wedge eraser. With only 3- and
# 4-turn sequences that leaves exactly two finishing zones, which is expected.
static func test_easy_board_is_fixed() -> bool:
	var board_def := BoardDefinition.new(8, Vector2(64, 64), 0, EraserSystem.ErasureShape.HALF_PLANE)
	PuzzleGenerator.reset_zone_rotation()

	var zones := {}
	var lengths := {}

	for i in range(8):
		# Deliberately hand it a HALF_PLANE board and a turn request; EASY must override
		# both, because its sequences only hold together under the wedge eraser.
		var puzzle := PuzzleGenerator.generate_puzzle(board_def, 6, 2, PuzzleGenerator.Difficulty.EASY)

		if puzzle.board_definition.erasure_start_phase != EraserSystem.ErasureRegion.TOP:
			return false
		if puzzle.board_definition.erasure_shape != EraserSystem.ErasureShape.DIAGONAL_WEDGE:
			return false
		if EraserSystem.get_phase_for_turn(0, puzzle.board_definition) != EraserSystem.ErasureRegion.TOP:
			return false
		if puzzle.max_turns < PuzzleGenerator.EASY_MIN_TURNS or puzzle.max_turns > PuzzleGenerator.EASY_MAX_TURNS:
			return false

		# EASY always opens on TOP, so the finishing zone is fixed by the sequence length
		# once the walk is known -- the third step of a 3-turn puzzle, the fourth of a
		# 4-turn one. Which region that is depends on the walk, so it is derived rather
		# than hard-coded.
		var order := EraserSystem.get_cycle(puzzle.board_definition.erasure_cycle_id)
		if puzzle.final_erasure_zone != order[(puzzle.max_turns - 1) % EraserSystem.PHASE_COUNT]:
			return false

		zones[puzzle.final_erasure_zone] = true
		lengths[puzzle.max_turns] = true

	# Both branches of the tree
	if lengths.size() != 2: return false

	return true

# The target must never already be on screen after the opening turn.
static func test_never_completed_on_first_turn() -> bool:
	var board_def := BoardDefinition.new(8)

	for tier in PuzzleGenerator.DIFFICULTY_ORDER:
		for i in range(2):
			var puzzle := PuzzleGenerator.generate_puzzle(board_def, 0, 2, tier)
			if puzzle.completion_turn < 1:
				return false

			# No opening shape may hand the player the target either
			var candidates := PuzzleGenerator.generate_candidate_pool(puzzle.board_definition, tier)
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
		var puzzle := PuzzleGenerator.generate_puzzle(board_def, 0, 2, PuzzleGenerator.Difficulty.EASY)

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

# The wedge eraser is the default and must produce genuine three-shape puzzles; the
# legacy half-plane eraser must still generate valid two-shape ones.
static func test_both_eraser_shapes_generate() -> bool:
	if BoardDefinition.new(8).erasure_shape != EraserSystem.ErasureShape.DIAGONAL_WEDGE:
		return false # wedge must be the default

	var wedge_board := BoardDefinition.new(8, Vector2(64, 64), 0, EraserSystem.ErasureShape.DIAGONAL_WEDGE)
	var half_board := BoardDefinition.new(8, Vector2(64, 64), 0, EraserSystem.ErasureShape.HALF_PLANE)

	var wedge_puzzle := PuzzleGenerator.generate_puzzle(wedge_board, 0, 3, PuzzleGenerator.Difficulty.NORMAL)
	var half_puzzle := PuzzleGenerator.generate_puzzle(half_board, 0, 3, PuzzleGenerator.Difficulty.NORMAL)

	for puzzle in [wedge_puzzle, half_puzzle]:
		if puzzle.target_geometry == null or puzzle.target_geometry.is_empty():
			return false
		# The puzzle must carry its own eraser shape through to replay
		if not PuzzleSimulator.simulate(puzzle.reference_solution, puzzle.board_definition) \
				.is_equivalent_to(puzzle.target_geometry):
			return false
		if not PuzzleValidator.validate_necessary_contributions(
				puzzle.reference_solution, puzzle.target_geometry, puzzle.board_definition):
			return false

	if wedge_puzzle.board_definition.erasure_shape != EraserSystem.ErasureShape.DIAGONAL_WEDGE:
		return false
	if half_puzzle.board_definition.erasure_shape != EraserSystem.ErasureShape.HALF_PLANE:
		return false

	# Both modes expose three live turns, so a three-shape puzzle is reachable in each
	if wedge_puzzle.required_shape_count != 3: return false
	if half_puzzle.required_shape_count != 3: return false

	return true

# The EASY space is exactly six sequences and nothing else.
static func test_easy_sequence_set_is_exactly_six() -> bool:
	var sequences := PuzzleGenerator.get_easy_sequences()
	if sequences.size() != 6:
		return false

	var expected := [
		[1, 0, 1],       # D S D
		[1, 1, 0],       # D D S
		[1, 1, 1],       # D D D
		[0, 1, 0, 1],    # S D S D
		[0, 1, 1, 0],    # S D D S
		[0, 1, 1, 1],    # S D D D
	]

	for want in expected:
		if not sequences.has(want):
			return false

	for sequence in sequences:
		# 3 or 4 turns only
		if sequence.size() < PuzzleGenerator.EASY_MIN_TURNS: return false
		if sequence.size() > PuzzleGenerator.EASY_MAX_TURNS: return false
		# Never two Skips in a row -- the invalid branch of the tree
		for i in range(sequence.size() - 1):
			if sequence[i] == 0 and sequence[i + 1] == 0:
				return false

	return true

# Every generated EASY puzzle must be one of the six, and across a batch all six appear.
static func test_easy_covers_all_six_sequences() -> bool:
	var board_def := BoardDefinition.new(8)
	PuzzleGenerator.reset_zone_rotation()

	var legal := PuzzleGenerator.get_easy_sequences()
	var seen := {}

	for i in range(12):
		var puzzle := PuzzleGenerator.generate_puzzle(board_def, 0, 2, PuzzleGenerator.Difficulty.EASY)

		var actions: Array[int] = []
		for t in range(puzzle.max_turns):
			var act := puzzle.reference_solution.get_action(t)
			actions.append(1 if (act != null and act.shape_instance != null) else 0)

		if not legal.has(actions):
			return false

		# No silent degradation to the fallback generator
		if puzzle.required_shape_count < 2:
			return false

		seen[str(actions)] = true

	# Two full bag draws must cover the whole space
	return seen.size() == legal.size()

# EASY+ is EASY with the opening erasure rotated: same six sequences, same simple shapes,
# but the puzzle can now start on any quarter instead of always the top.
static func test_easy_plus_rotates_opening() -> bool:
	var board_def := BoardDefinition.new(8)
	PuzzleGenerator.reset_zone_rotation()

	var legal := PuzzleGenerator.get_easy_sequences()
	var openings := {}
	var zones := {}

	for i in range(12):
		var puzzle := PuzzleGenerator.generate_puzzle(board_def, 0, 2, PuzzleGenerator.Difficulty.EASY_PLUS)

		# Still the wedge eraser and still one of the six sequences
		if puzzle.board_definition.erasure_shape != EraserSystem.ErasureShape.DIAGONAL_WEDGE:
			return false
		if puzzle.max_turns < PuzzleGenerator.EASY_MIN_TURNS: return false
		if puzzle.max_turns > PuzzleGenerator.EASY_MAX_TURNS: return false

		var actions: Array[int] = []
		for t in range(puzzle.max_turns):
			var act := puzzle.reference_solution.get_action(t)
			actions.append(1 if (act != null and act.shape_instance != null) else 0)
		if not legal.has(actions):
			return false
		if puzzle.required_shape_count < 2:
			return false

		# Still restricted to simple shapes
		for t in range(puzzle.max_turns):
			var act := puzzle.reference_solution.get_action(t)
			if act != null and act.shape_instance != null:
				if not _is_simple_shape(act.shape_instance, puzzle.board_definition):
					return false

		# The opening must be the rotation the finishing zone implies, not a fixed TOP.
		# Checking the relation is exact; sampling the openings is not, because they are
		# derived as (zone - (turns - 1)) mod 4 and can collide across a small batch.
		var opening := EraserSystem.get_phase_for_turn(0, puzzle.board_definition)
		if opening != EraserSystem.start_phase_for_final(puzzle.final_erasure_zone,
				puzzle.max_turns, puzzle.board_definition.erasure_cycle_id):
			return false

		openings[opening] = true
		zones[puzzle.final_erasure_zone] = true

	# The finishing zone is bag-driven, so it must cover all four
	if zones.size() != EraserSystem.PHASE_COUNT:
		return false

	# And unlike EASY, the opening must actually move around
	return openings.size() > 1

# EASY++ is EASY+ with the full shape vocabulary instead of the predefined simple set.
static func test_easy_plus_plus_uses_harder_shapes() -> bool:
	var board_def := BoardDefinition.new(8)

	var simple_pool := PuzzleGenerator.generate_candidate_pool(board_def, PuzzleGenerator.Difficulty.EASY_PLUS)
	var hard_pool := PuzzleGenerator.generate_candidate_pool(board_def, PuzzleGenerator.Difficulty.EASY_PLUS_PLUS)

	if hard_pool.size() <= simple_pool.size():
		return false

	PuzzleGenerator.reset_zone_rotation()

	var legal := PuzzleGenerator.get_easy_sequences()
	var saw_non_simple := false

	for i in range(12):
		var puzzle := PuzzleGenerator.generate_puzzle(board_def, 0, 2, PuzzleGenerator.Difficulty.EASY_PLUS_PLUS)

		# The tree still governs timing
		var actions: Array[int] = []
		for t in range(puzzle.max_turns):
			var act := puzzle.reference_solution.get_action(t)
			actions.append(1 if (act != null and act.shape_instance != null) else 0)
		if not legal.has(actions):
			return false
		if puzzle.required_shape_count < 2:
			return false

		for t in range(puzzle.max_turns):
			var act := puzzle.reference_solution.get_action(t)
			if act != null and act.shape_instance != null:
				if not _is_simple_shape(act.shape_instance, puzzle.board_definition):
					saw_non_simple = true

	# Over a batch it must actually reach beyond the simple set
	return saw_non_simple

# MEDIUM chains PATTERNs on a shared Draw. Every pattern but the last must end in Draw,
# and the seam means each extra pattern adds two turns rather than three.
static func test_medium_chain_structure() -> bool:
	var chains := PuzzleGenerator.get_medium_sequences(2)

	# 2 prefixes x 2 continuable openers x 3 closers
	if chains.size() != 12:
		return false

	for chain in chains:
		# 3 + 2(k-1) turns, plus an optional leading Skip
		if chain.size() != 5 and chain.size() != 6:
			return false

		# Never two Skips in a row -- still the invalid branch of the tree
		for i in range(chain.size() - 1):
			if chain[i] == 0 and chain[i + 1] == 0:
				return false

		var boundaries := PuzzleGenerator.get_stage_boundary_turns(chain, 2)
		if boundaries.size() != 2:
			return false
		# Stages sit two turns apart and the last one is the final turn
		if boundaries[1] != chain.size() - 1: return false
		if boundaries[1] - boundaries[0] != 2: return false
		# The seam itself must be a Draw: it is the shared node between the patterns
		if chain[boundaries[0]] != 1: return false

	# A longer chain must grow by exactly two turns per extra pattern
	for chain in PuzzleGenerator.get_medium_sequences(3):
		if chain.size() != 7 and chain.size() != 8:
			return false

	return true

# Each stage is a goal in its own right: reached in order, non-trivial, and different from
# the one before it. The last stage is the puzzle's final target.
static func test_medium_stages_are_progressive() -> bool:
	var board_def := BoardDefinition.new(8)
	PuzzleGenerator.reset_zone_rotation()

	var legal := PuzzleGenerator.get_medium_sequences()

	for i in range(6):
		var puzzle := PuzzleGenerator.generate_puzzle(board_def, 0, 2, PuzzleGenerator.Difficulty.MEDIUM)

		if not puzzle.is_multi_stage(): return false
		if puzzle.get_stage_count() != 2: return false
		if puzzle.stage_boundary_turns.size() != puzzle.stage_targets.size(): return false

		var actions: Array[int] = []
		for t in range(puzzle.max_turns):
			var act := puzzle.reference_solution.get_action(t)
			actions.append(1 if (act != null and act.shape_instance != null) else 0)
		if not legal.has(actions):
			return false

		var previous: VectorGeometry = null
		for stage in range(puzzle.get_stage_count()):
			var goal := puzzle.get_stage_target(stage)

			# A stage goal must be worth aiming at, and must move on from the last one
			if goal.segments.size() < 2: return false
			if previous != null and goal.is_equivalent_to(previous): return false

			# It must be exactly what the reference solution has on the board at that seam
			var at_seam := PuzzleSimulator.simulate_up_to_turn(
				puzzle.reference_solution, puzzle.board_definition, puzzle.stage_boundary_turns[stage])
			if not goal.is_equivalent_to(at_seam): return false

			previous = goal

		# The final stage is the puzzle's target
		if not puzzle.get_stage_target(puzzle.get_stage_count() - 1).is_equivalent_to(puzzle.target_geometry):
			return false

	return true

static func _is_simple_shape(shape: ShapeInstance, board_def: BoardDefinition) -> bool:
	for simple in PuzzleGenerator.generate_candidate_pool(board_def, PuzzleGenerator.Difficulty.EASY):
		if simple.geometry.is_equivalent_to(shape.geometry):
			return true
	return false
