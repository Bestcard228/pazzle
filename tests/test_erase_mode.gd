class_name TestEraseMode
extends RefCounted

static func run_all_tests() -> int:
	var passed := 0
	print("--- Running TestEraseMode ---")

	var checks := {
		"test_schedule_legality_rule": test_schedule_legality_rule(),
		"test_override_drives_every_consumer": test_override_drives_every_consumer(),
		"test_legal_orders_are_the_permutations": test_legal_orders_are_the_permutations(),
		"test_generated_erase_puzzles_are_solvable_and_not_trivial":
			test_generated_erase_puzzles_are_solvable_and_not_trivial(),
		"test_controller_replays_the_reference_schedule": test_controller_replays_the_reference_schedule(),
	}

	for name in checks.keys():
		if checks[name]:
			passed += 1
			print("  [PASS] %s" % name)
		else:
			print("  [FAIL] %s" % name)

	return passed

# The one rule the mode is built on: a quarter cannot come round again until the other
# three have gone. Under four turns that is exactly "no zone twice".
static func test_schedule_legality_rule() -> bool:
	var solution := ErasureSolution.new(4)

	if solution.legal_zones().size() != 4: return false
	if not solution.add_zone(EraserSystem.ErasureRegion.LEFT): return false

	# The same quarter is now blocked, the other three are not
	if solution.can_add(EraserSystem.ErasureRegion.LEFT): return false
	if solution.legal_zones().size() != 3: return false

	if not solution.add_zone(EraserSystem.ErasureRegion.TOP): return false
	if not solution.add_zone(EraserSystem.ErasureRegion.BOTTOM): return false

	# Only RIGHT is left, and the schedule is forced
	if solution.legal_zones() != [EraserSystem.ErasureRegion.RIGHT]: return false
	if not solution.add_zone(EraserSystem.ErasureRegion.RIGHT): return false

	# Full: nothing more may be committed
	if not solution.is_full(): return false
	if solution.can_add(EraserSystem.ErasureRegion.TOP): return false

	# Undo hands the last quarter back
	if solution.undo_last() != EraserSystem.ErasureRegion.RIGHT: return false
	if not solution.can_add(EraserSystem.ErasureRegion.RIGHT): return false

	# Past four turns the rule keeps going: a quarter is free again only once the other
	# three have all been used, so the fourth pick is forced and the fifth reopens the
	# first quarter.
	var long_solution := ErasureSolution.new(6)
	long_solution.add_zone(EraserSystem.ErasureRegion.TOP)
	long_solution.add_zone(EraserSystem.ErasureRegion.RIGHT)
	long_solution.add_zone(EraserSystem.ErasureRegion.BOTTOM)
	if long_solution.legal_zones() != [EraserSystem.ErasureRegion.LEFT]: return false

	long_solution.add_zone(EraserSystem.ErasureRegion.LEFT)
	if not long_solution.can_add(EraserSystem.ErasureRegion.TOP): return false
	if long_solution.can_add(EraserSystem.ErasureRegion.RIGHT): return false
	if long_solution.can_add(EraserSystem.ErasureRegion.LEFT): return false

	return true

# The player's schedule is put on the board, so the simulator and everything else that
# asks "what is erased on turn t" answers with their choices and no other code changes.
static func test_override_drives_every_consumer() -> bool:
	var board := BoardDefinition.new(8)
	var schedule: Array[int] = [
		EraserSystem.ErasureRegion.LEFT,
		EraserSystem.ErasureRegion.TOP,
		EraserSystem.ErasureRegion.RIGHT,
	]
	var scheduled := board.with_erasure_override(schedule)

	for turn in range(schedule.size()):
		if EraserSystem.get_phase_for_turn(turn, scheduled) != schedule[turn]: return false

	# The original board is untouched, and past the schedule the board falls back to its
	# own cycle rather than going undefined
	if not board.erasure_override.is_empty(): return false
	if EraserSystem.get_phase_for_turn(0, board) != EraserSystem.ErasureRegion.TOP: return false
	if EraserSystem.get_phase_for_turn(3, scheduled) != EraserSystem.get_phase_for_turn(3, board):
		return false

	# And it survives duplication, or a generated puzzle would lose the schedule
	if scheduled.duplicate_board().erasure_override != schedule: return false

	return true

# Every legal schedule is a permutation of the four quarters, extended by the rule -- so
# the space is 24 walks whatever the turn count, small enough to enumerate exactly.
static func test_legal_orders_are_the_permutations() -> bool:
	if PuzzleValidator.enumerate_legal_erase_orders(4).size() != 24: return false
	if PuzzleValidator.enumerate_legal_erase_orders(3).size() != 24: return false

	# Past four turns the tail is forced, so the count does not grow
	if PuzzleValidator.enumerate_legal_erase_orders(6).size() != 24: return false

	for order in PuzzleValidator.enumerate_legal_erase_orders(6):
		var window: Array[int] = []
		for zone in order:
			window.append(int(zone))
		# Any four consecutive picks must still clear the whole field
		for start in range(window.size() - 3):
			var seen := {}
			for i in range(start, start + 4):
				seen[window[i]] = true
			if seen.size() != 4: return false

	return true

# An ERASE puzzle has to be worth playing: its own schedule must reach the target, and
# some other schedule must not.
static func test_generated_erase_puzzles_are_solvable_and_not_trivial() -> bool:
	for difficulty in PuzzleGenerator.DIFFICULTY_ORDER:
		var board_def := BoardDefinition.new(8)
		var puzzle := PuzzleGenerator.generate_puzzle(
			board_def, 0, 2, difficulty, 400, PuzzleGenerator.DEFAULT_ERASURE_CYCLE,
			PuzzleData.InputMode.CHOOSE_ERASURES)

		if puzzle == null or not puzzle.uses_erase_input(): return false
		if puzzle.erase_order.size() != puzzle.max_turns: return false

		# The recorded schedule is the board's own, and it reaches the target
		var scheduled := puzzle.board_definition.with_erasure_override(puzzle.erase_order)
		var replay := PuzzleSimulator.simulate(puzzle.reference_solution, scheduled)
		if not replay.is_equivalent_to(puzzle.target_geometry): return false

		# ...and the choice carries information: not every schedule gets there
		var solving := PuzzleValidator.count_solving_erase_orders(
			puzzle.reference_solution, puzzle.board_definition, puzzle.target_geometry,
			puzzle.max_turns)
		var total := PuzzleValidator.enumerate_legal_erase_orders(puzzle.max_turns).size()
		if solving < 1: return false
		if solving >= total: return false

	return true

# Playing the generated schedule through the controller has to win the puzzle, one pick
# at a time, exactly as the UI drives it.
static func test_controller_replays_the_reference_schedule() -> bool:
	var board_def := BoardDefinition.new(8)
	var puzzle := PuzzleGenerator.generate_puzzle(
		board_def, 0, 2, PuzzleGenerator.Difficulty.EASY, 400,
		PuzzleGenerator.DEFAULT_ERASURE_CYCLE, PuzzleData.InputMode.CHOOSE_ERASURES)

	var controller := ErasePuzzleController.new(puzzle)
	if controller.is_complete(): return false

	for zone in puzzle.erase_order:
		if not controller.follows_reference(): return false
		if controller.reference_zone_for_current_turn() != zone: return false
		if not controller.select_zone(zone): return false

	if not controller.is_complete(): return false
	if not controller.current_geometry().is_equivalent_to(puzzle.target_geometry): return false

	# An illegal repeat is refused rather than quietly accepted
	var repeat := ErasePuzzleController.new(puzzle)
	var first: int = puzzle.erase_order[0]
	if not repeat.select_zone(first): return false
	if repeat.select_zone(first): return false
	if repeat.current_turn() != 1: return false

	return true
