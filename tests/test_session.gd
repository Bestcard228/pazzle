class_name TestSession
extends RefCounted

# The playing half of the game, which had no cover at all until it was pulled out of the
# UI. These drive PuzzleSession exactly the way game_ui does -- commit a shape, skip a
# turn, pick a quarter -- so a refactor that changes what a turn does fails here rather
# than on the player's screen.

static func run_all_tests() -> Array[int]:
	print("--- Running TestSession ---")

	var results := {
		"test_draw_mode_plays_to_a_win": test_draw_mode_plays_to_a_win(),
		"test_a_skip_still_advances_and_still_erases": test_a_skip_still_advances_and_still_erases(),
		"test_erase_mode_schedule_wins": test_erase_mode_schedule_wins(),
		"test_erase_mode_refuses_an_illegal_repeat": test_erase_mode_refuses_an_illegal_repeat(),
		"test_a_layered_turn_needs_every_colour": test_a_layered_turn_needs_every_colour(),
		"test_reset_returns_to_turn_zero": test_reset_returns_to_turn_zero(),
		"test_an_unstarted_clock_never_expires": test_an_unstarted_clock_never_expires(),
		"test_story_run_holds_its_rules": test_story_run_holds_its_rules(),
	}

	var passed := 0
	for name in results.keys():
		if results[name]:
			passed += 1
			print("  [PASS] %s" % name)
		else:
			print("  [FAIL] %s" % name)

	return [passed, results.size()]

static func _easy_puzzle() -> PuzzleData:
	return PuzzleGenerator.generate_puzzle(
		BoardDefinition.new(8), 0, 2, PuzzleGenerator.Difficulty.EASY)

# Playing the intended shapes, turn by turn, has to clear the puzzle.
static func test_draw_mode_plays_to_a_win() -> bool:
	var puzzle := _easy_puzzle()
	var session := PuzzleSession.new()
	session.setup(puzzle)

	if session.cleared: return false

	for turn in range(puzzle.max_turns):
		var action := puzzle.reference_solution.get_action(turn)
		var shape: ShapeInstance = action.shape_instance if action != null else null
		if shape == null:
			session.skip_turn()
		else:
			if session.commit_shape(shape) != PuzzleSession.Commit.TURN_DONE:
				return false

	if not session.cleared: return false
	if session.turn != puzzle.max_turns: return false

	# A cleared puzzle takes no more moves
	return session.commit_shape(puzzle.reference_solution.get_action(0).shape_instance) \
		== PuzzleSession.Commit.REJECTED

# A skipped turn is a move: the turn advances and the eraser still takes its quarter.
static func test_a_skip_still_advances_and_still_erases() -> bool:
	var puzzle := _easy_puzzle()
	var session := PuzzleSession.new()
	session.setup(puzzle)

	if not session.skip_turn(): return false
	if session.turn != 1: return false

	# Nothing was drawn, so nothing survives -- but the turn did happen
	if not session.surviving_geometry().is_empty(): return false
	if session.drawn_turn_flags()[0]: return false

	return true

# Replaying the schedule the puzzle was generated from must clear it.
static func test_erase_mode_schedule_wins() -> bool:
	var puzzle := PuzzleGenerator.generate_puzzle(
		BoardDefinition.new(8), 0, 2, PuzzleGenerator.Difficulty.EASY, 400,
		PuzzleGenerator.DEFAULT_ERASURE_CYCLE, PuzzleData.InputMode.CHOOSE_ERASURES)

	var session := PuzzleSession.new()
	session.setup(puzzle)

	if not session.uses_erase_input(): return false
	# The shapes are the given half in this mode
	if session.playing_solution() != puzzle.reference_solution: return false

	for zone in puzzle.erase_order:
		if not session.pick_zone(zone): return false

	return session.cleared

# The one rule of the schedule: a quarter cannot come round again until the other three
# have gone. A refused pick must not burn a turn.
static func test_erase_mode_refuses_an_illegal_repeat() -> bool:
	var puzzle := PuzzleGenerator.generate_puzzle(
		BoardDefinition.new(8), 0, 2, PuzzleGenerator.Difficulty.EASY, 400,
		PuzzleGenerator.DEFAULT_ERASURE_CYCLE, PuzzleData.InputMode.CHOOSE_ERASURES)

	var session := PuzzleSession.new()
	session.setup(puzzle)

	var first: int = puzzle.erase_order[0]
	if not session.pick_zone(first): return false
	if session.turn != 1: return false

	if session.can_pick_zone(first): return false
	if session.pick_zone(first): return false
	if session.turn != 1: return false

	# Skipping is not a move that exists here
	return not session.skip_turn()

# D(r) D(g): the turn is over only once every colour has acted, and a skip skips all of
# them at once.
static func test_a_layered_turn_needs_every_colour() -> bool:
	var puzzle := PuzzleGenerator.generate_layered_puzzle(
		BoardDefinition.new(8), PuzzleGenerator.Difficulty.EASY, 2, 200)

	var session := PuzzleSession.new()
	session.setup(puzzle)
	if not session.uses_layers(): return false

	# Half the sequences open with a Skip, so walk up to the first turn that draws
	while session.turns_remain() and not puzzle.layered_solution.is_draw_turn(session.turn):
		if not session.skip_turn(): return false
	if not session.turns_remain(): return false

	var draw_turn := session.turn
	var red := puzzle.layered_solution.get_shape(draw_turn, 0)
	var green := puzzle.layered_solution.get_shape(draw_turn, 1)
	if red == null or green == null: return false

	if session.commit_shape(red) != PuzzleSession.Commit.LAYER_DONE: return false
	if session.turn != draw_turn: return false
	if session.active_layer != 1: return false

	if session.commit_shape(green) != PuzzleSession.Commit.TURN_DONE: return false
	if session.turn != draw_turn + 1: return false
	if session.active_layer != 0: return false

	# A skipped turn is skipped in every colour
	if session.turns_remain() and not session.cleared:
		var skipped := session.turn
		session.skip_turn()
		for layer in range(session.layer_count()):
			if session.layered.get_shape(skipped, layer) != null: return false

	return true

static func test_reset_returns_to_turn_zero() -> bool:
	var puzzle := _easy_puzzle()
	var session := PuzzleSession.new()
	session.setup(puzzle)

	session.skip_turn()
	session.reset()

	if session.turn != 0: return false
	if session.stage != 0: return false
	if session.cleared: return false
	if session.drawn_turn_flags().has(true): return false

	return true

# "Not started" and "expired" are both zero seconds left, so the running flag is the only
# thing keeping an unstarted clock from eating a turn on the first frame.
static func test_an_unstarted_clock_never_expires() -> bool:
	var clock := TurnClock.new()
	clock.set_limit(12.0)

	if clock.tick(100.0): return false
	if clock.fraction() >= 0.0: return false

	clock.start()
	if clock.fraction() != 1.0: return false
	if clock.tick(5.0): return false
	if not is_equal_approx(clock.fraction(), 7.0 / 12.0): return false

	# It expires once, not every frame after
	if not clock.tick(100.0): return false
	if clock.tick(100.0): return false

	# No limit means no clock at all
	var off := TurnClock.new()
	off.set_limit(0.0)
	off.start()
	return not off.tick(100.0) and off.fraction() < 0.0

# The run's two standing rules: everything after the lesson is on a 12 second clock, and
# a task never introduces two modes at once.
static func test_story_run_holds_its_rules() -> bool:
	if not StoryCampaign.is_tutorial_task(0): return false
	if StoryCampaign.clock_for_task(0) != 0.0: return false

	for task in range(1, StoryCampaign.total_tasks()):
		if StoryCampaign.clock_for_task(task) != StoryCampaign.STORY_TURN_SECONDS:
			return false
		if StoryCampaign.input_mode_for_task(task) == PuzzleData.InputMode.CHOOSE_ERASURES:
			if StoryCampaign.layers_for_task(task) != LayerSystem.SINGLE_LAYER:
				return false

	# The run opens on the rotations before it shows anything else
	if StoryCampaign.cycle_for_task(1) != EraserSystem.CYCLE_CLOCKWISE: return false

	var runner := StoryRunner.new()
	runner.task_index = 0
	var config := runner.current_config()
	return int(config["difficulty"]) == StoryCampaign.difficulty_for_task(0)
