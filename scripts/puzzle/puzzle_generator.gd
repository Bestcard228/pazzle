class_name PuzzleGenerator
extends RefCounted

const DEFAULT_MIN_TURNS := 4
const DEFAULT_MAX_TURNS := 7

# Rotating bag of final erasure zones. Puzzles pull from a shuffled bag of all four
# zones, so a run of puzzles cannot all finish on the same zone, and no zone repeats
# back-to-back across bag refills.
static var _zone_bag: Array[int] = []
static var _last_final_zone: int = -1

# Alternates so that consecutive puzzles do not all resolve on the very last turn.
static var _prefer_early_finish: bool = false

static func generate_puzzle(
	board_def: BoardDefinition = null,
	max_turns: int = 0,
	required_shape_count: int = 2,
	is_easy_mode: bool = false,
	max_attempts: int = 400
) -> PuzzleData:
	if board_def == null:
		board_def = BoardDefinition.new(8)
	# Under the wedge eraser most shapes survive two erasures, so the third-from-last turn
	# is genuinely usable; under the half-plane eraser only centre-seam shapes get there.
	# `shape_count` below is clamped to the board's own survivable window either way.

	var rng := RandomNumberGenerator.new()
	rng.randomize()

	var turns_were_requested := max_turns > 0
	if turns_were_requested:
		max_turns = clampi(max_turns, 3, DEFAULT_MAX_TURNS)

	var puzzle_board := board_def.duplicate_board()
	var final_zone: int

	if is_easy_mode:
		# Easy mode always begins the cycle at TOP, so rotating the start phase is not
		# available as a lever. The finishing zone is varied through the turn count
		# instead: across 4..7 turns each length lands on a different zone.
		puzzle_board.erasure_start_phase = EraserSystem.ErasureRegion.TOP
		if not turns_were_requested:
			max_turns = EraserSystem.turn_count_for_final_phase_from_top(_take_next_final_zone(rng), DEFAULT_MIN_TURNS)
		final_zone = EraserSystem.get_final_phase(max_turns, puzzle_board)
	else:
		if not turns_were_requested:
			max_turns = rng.randi_range(DEFAULT_MIN_TURNS, DEFAULT_MAX_TURNS)
		# Pick the finishing zone, then rotate the cycle so that it lands there. Without
		# this the final zone would be a pure function of max_turns, and every puzzle of
		# a given length would end on the same side of the board.
		final_zone = _take_next_final_zone(rng)
		puzzle_board.erasure_start_phase = EraserSystem.start_phase_for_final(final_zone, max_turns)

	var candidates := generate_candidate_pool(puzzle_board, is_easy_mode)
	if candidates.is_empty():
		return _create_fallback_puzzle(puzzle_board, max_turns, final_zone)

	# Only the late turns can leave anything behind; placing a shape earlier guarantees a
	# redundant draw that the necessity check would reject anyway.
	var survivable_turns := PuzzleSimulator.get_survivable_turns(puzzle_board, max_turns)
	if survivable_turns.is_empty():
		return _create_fallback_puzzle(puzzle_board, max_turns, final_zone)

	var shape_count := clampi(required_shape_count, 1, survivable_turns.size())
	var last_turn := max_turns - 1

	# Alternate whether we aim to have the last shape land before the final turn, so
	# puzzles do not all play out as "draw right up to the buzzer".
	var prefer_early_finish := _take_next_early_finish_preference()

	for attempt in range(max_attempts):
		# Honour the preference for most of the budget, then relax, so a hard preference
		# degrades into an ordinary puzzle rather than into the fallback. It needs a
		# generous share because finishing early forces the earliest survivable turn into
		# play, and only shapes with geometry on the centre seam survive from there.
		var enforce_early_finish := prefer_early_finish and attempt < max_attempts * 3 / 4

		var turn_pool := survivable_turns.duplicate()
		if enforce_early_finish:
			turn_pool.erase(last_turn)
		if turn_pool.size() < shape_count:
			continue

		turn_pool.shuffle()
		var turns_to_use := turn_pool.slice(0, shape_count)

		var sol := PuzzleSolution.new(max_turns)
		for t in turns_to_use:
			sol.set_action(t, candidates[rng.randi() % candidates.size()])

		# 1. Simulate to get target
		var target := PuzzleSimulator.simulate(sol, puzzle_board)
		if target.is_empty() or target.segments.size() < 2:
			continue

		# 2. Every drawn shape must survive into the target
		if not PuzzleValidator.validate_necessary_contributions(sol, target, puzzle_board):
			continue

		# 3. The opening turn must never already be the answer (every mode)
		if not PuzzleValidator.validate_not_completable_on_first_turn(sol, target, puzzle_board, candidates):
			continue

		# 4. The final turn alone must never be the whole answer (every mode)
		if shape_count >= 2 and not PuzzleValidator.validate_not_last_turn_only(sol, target, puzzle_board):
			continue

		# 5. Timing has to matter (every mode)
		if not PuzzleValidator.validate_multi_turn_timing(sol, target, puzzle_board):
			continue

		if not is_easy_mode and not PuzzleValidator.validate_spans_multiple_quadrants(target, puzzle_board):
			continue

		# Most expensive check, so it runs last
		if not PuzzleValidator.validate_not_solvable_in_one_turn(target, puzzle_board, candidates, max_turns, survivable_turns):
			continue

		return _build_puzzle_data(puzzle_board, target, max_turns, shape_count, sol, final_zone)

	# Fallback if attempt limit reached
	return _create_fallback_puzzle(puzzle_board, max_turns, final_zone)

# Draws the next final zone from a shuffled bag so all four zones are used before any
# repeats, and the same zone never lands twice in a row.
static func _take_next_final_zone(rng: RandomNumberGenerator) -> int:
	if _zone_bag.is_empty():
		_zone_bag = [
			EraserSystem.ErasureRegion.TOP,
			EraserSystem.ErasureRegion.RIGHT,
			EraserSystem.ErasureRegion.BOTTOM,
			EraserSystem.ErasureRegion.LEFT,
		]
		_zone_bag.shuffle()
		# Avoid a repeat across the bag boundary
		if _zone_bag.size() > 1 and _zone_bag[0] == _last_final_zone:
			_zone_bag.append(_zone_bag.pop_front())

	var zone: int = _zone_bag.pop_front()
	_last_final_zone = zone
	return zone

static func _take_next_early_finish_preference() -> bool:
	_prefer_early_finish = not _prefer_early_finish
	return _prefer_early_finish

static func reset_zone_rotation() -> void:
	_zone_bag.clear()
	_last_final_zone = -1
	_prefer_early_finish = false

static func _build_puzzle_data(
	board_def: BoardDefinition,
	target: VectorGeometry,
	max_turns: int,
	shape_count: int,
	sol: PuzzleSolution,
	final_zone: int
) -> PuzzleData:
	var p_data := PuzzleData.new(board_def, target, max_turns)
	p_data.required_shape_count = shape_count
	p_data.reference_solution = sol
	p_data.final_erasure_zone = final_zone
	p_data.completion_turn = PuzzleSimulator.get_completion_turn(sol, board_def, target)
	p_data.difficulty_rating = float(shape_count * 1.5 + max_turns * 0.8)
	return p_data

# In easy mode the player can only tap the predefined shape buttons, so the generator
# must build its solution out of exactly those shapes or the puzzle is unsolvable.
static func generate_candidate_pool(board_def: BoardDefinition, is_easy_mode: bool = false) -> Array[ShapeInstance]:
	if is_easy_mode:
		return _generate_easy_candidate_pool(board_def)

	var pool: Array[ShapeInstance] = []
	var N := board_def.node_count

	# Add Full Circle / Octagon
	var circ_path: Array[int] = []
	for i in range(N):
		circ_path.append(i)
	circ_path.append(0)
	var c_inst := ShapeDatabase.create_instance_from_path(circ_path, board_def)
	if c_inst != null: pool.append(c_inst)

	for i in range(N):
		# Triangles (various orientations)
		var t1 := [i, (i + 2) % N, (i + 5) % N, i]
		var s1 := ShapeDatabase.create_instance_from_path(t1, board_def)
		if s1 != null: pool.append(s1)

		var t2 := [i, (i + 3) % N, (i + 6) % N, i]
		var s2 := ShapeDatabase.create_instance_from_path(t2, board_def)
		if s2 != null: pool.append(s2)

		var t3 := [i, (i + 2) % N, (i + 4) % N, i]
		var s3 := ShapeDatabase.create_instance_from_path(t3, board_def)
		if s3 != null: pool.append(s3)

		# Squares & Diamonds
		var sq1 := [i, (i + 2) % N, (i + 4) % N, (i + 6) % N, i]
		var sq_inst := ShapeDatabase.create_instance_from_path(sq1, board_def)
		if sq_inst != null: pool.append(sq_inst)

		# NOTE: the 8-point star is deliberately excluded. Its eight crossing edges shatter
		# into too many fragments under erasure to be readable as a puzzle target.

		# Center-crossing Lines
		var line1 := [i, (i + 4) % N]
		var l1_inst := ShapeDatabase.create_instance_from_path(line1, board_def)
		if l1_inst != null: pool.append(l1_inst)

		var line2 := [i, (i + 3) % N]
		var l2_inst := ShapeDatabase.create_instance_from_path(line2, board_def)
		if l2_inst != null: pool.append(l2_inst)

	return pool

static func _generate_easy_candidate_pool(board_def: BoardDefinition) -> Array[ShapeInstance]:
	var pool: Array[ShapeInstance] = []
	for shape_data in ShapeDatabase.get_easy_mode_predefined_shapes(board_def):
		var inst: ShapeInstance = shape_data["instance"]
		if inst != null:
			pool.append(inst)
	return pool

static func _create_fallback_puzzle(board_def: BoardDefinition, max_turns: int, final_zone: int) -> PuzzleData:
	var sol := PuzzleSolution.new(max_turns)
	var candidates := generate_candidate_pool(board_def)
	var survivable := PuzzleSimulator.get_survivable_turns(board_def, max_turns)

	for i in range(min(survivable.size(), min(2, candidates.size()))):
		sol.set_action(survivable[i], candidates[i])

	var target := PuzzleSimulator.simulate(sol, board_def)
	return _build_puzzle_data(board_def, target, max_turns, sol.get_non_empty_action_count(), sol, final_zone)
