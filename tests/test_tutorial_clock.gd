class_name TestTutorialClock
extends RefCounted

static func run_all_tests() -> int:
	var passed := 0
	print("--- Running TestTutorialClock ---")

	var checks := {
		"test_clock_is_carried_by_the_puzzle": test_clock_is_carried_by_the_puzzle(),
		"test_lesson_is_a_real_winnable_puzzle": test_lesson_is_a_real_winnable_puzzle(),
		"test_lesson_teaches_draw_skip_draw": test_lesson_teaches_draw_skip_draw(),
		"test_lesson_only_accepts_the_shape_it_shows": test_lesson_only_accepts_the_shape_it_shows(),
	}

	for name in checks.keys():
		if checks[name]:
			passed += 1
			print("  [PASS] %s" % name)
		else:
			print("  [FAIL] %s" % name)

	return passed

# The clock is a play-time limit the generated puzzle carries, at any tier and with or
# without layers. Off is the default, so nothing acquires a clock by accident.
static func test_clock_is_carried_by_the_puzzle() -> bool:
	if PuzzleGenerator.TURN_TIME_CHOICES[0] != PuzzleGenerator.NO_TURN_TIME_LIMIT:
		return false
	if PuzzleGenerator.generate_puzzle(BoardDefinition.new(8), 0, 2,
			PuzzleGenerator.Difficulty.EASY).turn_time_limit != 0.0:
		return false

	for seconds in PuzzleGenerator.TURN_TIME_CHOICES:
		if seconds <= 0.0:
			continue

		var timed := PuzzleGenerator.generate_puzzle(
			BoardDefinition.new(8), 0, 2, PuzzleGenerator.Difficulty.EASY, 400,
			PuzzleGenerator.DEFAULT_ERASURE_CYCLE, PuzzleData.InputMode.DRAW_SHAPES, seconds)
		if timed.turn_time_limit != seconds:
			return false

		var layered := PuzzleGenerator.generate_layered_puzzle(
			BoardDefinition.new(8), PuzzleGenerator.Difficulty.EASY, 2, 200,
			PuzzleData.InputMode.DRAW_SHAPES, seconds)
		if layered.turn_time_limit != seconds:
			return false

	return true

# The lesson is played through the same code as any other puzzle, so finishing it has to
# be a real win rather than a scripted pat on the head.
static func test_lesson_is_a_real_winnable_puzzle() -> bool:
	var tutorial := TutorialController.new()
	var puzzle := tutorial.build_puzzle()

	if puzzle == null or puzzle.target_geometry.is_empty(): return false
	if puzzle.reference_solution == null: return false

	# Drawing what it asks for, turn by turn, must reach the goal
	var replay := PuzzleSimulator.simulate(puzzle.reference_solution, puzzle.board_definition)
	if not replay.is_equivalent_to(puzzle.target_geometry): return false

	# ...and only at the end, or the last lesson would be pointless
	if puzzle.completion_turn != puzzle.max_turns - 1: return false

	# No clock while learning
	if puzzle.turn_time_limit != 0.0: return false

	return true

# Draw, skip, draw: the three turns are the three things there are to learn, in the order
# that lets each one explain the next.
static func test_lesson_teaches_draw_skip_draw() -> bool:
	var tutorial := TutorialController.new()
	var puzzle := tutorial.build_puzzle()
	if puzzle == null: return false

	if tutorial.turn_count() != 3: return false
	if tutorial.is_skip_turn(0): return false
	if not tutorial.is_skip_turn(1): return false
	if tutorial.is_skip_turn(2): return false

	# The two drawn turns ask for different shapes, so the second is a lesson and not a
	# repetition of the first
	var first := tutorial.expected_path(0)
	var second := tutorial.expected_path(2)
	if first.is_empty() or second.is_empty(): return false
	if first == second: return false

	# And it is one of the six sequences, so the lesson is the real game in miniature
	var actions: Array[int] = []
	for turn in range(tutorial.turn_count()):
		actions.append(0 if tutorial.is_skip_turn(turn) else 1)
	return PuzzleGenerator.get_easy_sequences().has(actions)

# Anything other than the shape being shown is refused, so the player cannot wander off
# the lesson -- but tracing it the other way round is still the same shape.
static func test_lesson_only_accepts_the_shape_it_shows() -> bool:
	var tutorial := TutorialController.new()
	if tutorial.build_puzzle() == null: return false

	if not tutorial.accepts(tutorial.expected_path(0), 0): return false
	if not tutorial.accepts(tutorial.expected_path(2), 2): return false

	# The other lesson's shape is wrong on this turn
	if tutorial.accepts(tutorial.expected_path(2), 0): return false
	if tutorial.accepts(tutorial.expected_path(0), 2): return false

	# A skip turn accepts no shape at all
	if tutorial.accepts(tutorial.expected_path(0), 1): return false

	# Drawn backwards is the same shape
	var reversed_path: Array[int] = []
	var forward := tutorial.expected_path(0)
	for i in range(forward.size() - 1, -1, -1):
		reversed_path.append(forward[i])
	if not tutorial.accepts(reversed_path, 0): return false

	return true
