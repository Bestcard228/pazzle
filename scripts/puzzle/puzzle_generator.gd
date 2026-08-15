class_name PuzzleGenerator
extends RefCounted

const DEFAULT_MIN_TURNS := 4
const DEFAULT_MAX_TURNS := 7

# The difficulty ladder. All three EASY tiers share the same six-sequence tree and the
# same forced X-wedge eraser; they differ only in what else is allowed to vary:
#
#            sequences   opening erasure   shapes
#   EASY     the six     always TOP        simple
#   EASY+    the six     rotates           simple
#   EASY++   the six     rotates           full pool
#   NORMAL   free        rotates           full pool
#
# NORMAL is 0 and EASY is 1 so that the old boolean `is_easy_mode` argument still maps to
# the right tier at any call site that has not been updated.
enum Difficulty {
	NORMAL = 0,
	EASY = 1,
	EASY_PLUS = 2,
	EASY_PLUS_PLUS = 3,
	MEDIUM = 4,
}

# Ascending order of hardness, for cycling through in the UI. NORMAL is deliberately not
# on this ladder: it is the untiered free-generation fallback the generator still defaults
# to internally, but it is not something the player picks.
const DIFFICULTY_ORDER := [
	Difficulty.EASY,
	Difficulty.EASY_PLUS,
	Difficulty.EASY_PLUS_PLUS,
	Difficulty.MEDIUM,
]

# Every tier driven by the PATTERN tree rather than free turn selection.
static func uses_sequence_tree(difficulty: int) -> bool:
	return difficulty != Difficulty.NORMAL

# MEDIUM chains PATTERNs, so it has intermediate states that must be hit.
static func is_multi_stage(difficulty: int) -> bool:
	return difficulty == Difficulty.MEDIUM

# Tiers restricted to the predefined simple shapes.
static func uses_simple_shapes(difficulty: int) -> bool:
	return difficulty == Difficulty.EASY or difficulty == Difficulty.EASY_PLUS

# Tiers that always open by erasing the top, instead of rotating the cycle.
static func uses_fixed_opening(difficulty: int) -> bool:
	return difficulty == Difficulty.EASY

# 1-based position on the ladder, for difficulty meters.
static func get_difficulty_rank(difficulty: int) -> int:
	var rank := DIFFICULTY_ORDER.find(difficulty)
	return rank + 1 if rank >= 0 else DIFFICULTY_ORDER.size()

static func get_difficulty_name(difficulty: int) -> String:
	match difficulty:
		Difficulty.EASY: return "Easy"
		Difficulty.EASY_PLUS: return "Easy+"
		Difficulty.EASY_PLUS_PLUS: return "Easy++"
		Difficulty.MEDIUM: return "Medium"
		_: return "Normal"

# EASY mode temporal patterns.
#
# PATTERN:
#
#   Draw
#   ├── Skip
#   │   └── Draw
#   │
#   └── Draw
#       ├── Skip
#       └── Draw
#
# This produces exactly:
#   Draw → Skip → Draw
#   Draw → Draw → Skip
#   Draw → Draw → Draw
#
# EASY can either begin with the pattern immediately, or have one initial Skip:
#
#   PATTERN
#
# or
#
#   Skip → PATTERN
#
# At most ONE leading Skip -- two Skips in a row are not a legal opening -- so EASY is
# exactly six sequences:
#
#   PATTERN         (3 turns)     Skip → PATTERN  (4 turns)
#     D S D                         S D S D
#     D D S                         S D D S
#     D D D                         S D D D
#
# The 3-turn depth is not arbitrary: three consecutive erasures cover the whole field, so
# a Draw more than three turns from the end is wiped before the target is ever read. The
# PATTERN therefore always occupies the final three turns, and the optional leading Skip
# is the only thing that shifts it.
#
# PATTERN is kept as its own constant because harder modes are meant to reuse it with
# deeper prefixes.
#
# GDScript has no nested typed arrays, so this stays an untyped Array of Arrays.
const EASY_PATTERN_DEPTH := 3
const EASY_MIN_TURNS := 3
const EASY_MAX_TURNS := 4
const EASY_PATTERNS := [
	[1, 0, 1], # Draw → Skip → Draw
	[1, 1, 0], # Draw → Draw → Skip
	[1, 1, 1], # Draw → Draw → Draw
]

# The only two legal openings: start on the PATTERN, or take one Skip first. A second
# leading Skip is the invalid branch of the tree, so there is no third prefix.
const EASY_PREFIXES := [
	[],  # PATTERN
	[0], # Skip → PATTERN
]

# Rotating bag of final erasure zones. Puzzles pull from a shuffled bag of all four
# zones, so a run of puzzles cannot all finish on the same zone, and no zone repeats
# back-to-back across bag refills.
static var _zone_bag: Array[int] = []
static var _last_final_zone: int = -1

# Alternates so that consecutive puzzles do not all resolve on the very last turn.
static var _prefer_early_finish: bool = false

# Shuffled bags over the sequence spaces, so every one appears before any repeats.
static var _easy_sequence_bag: Array = []
static var _medium_sequence_bag: Array = []


# The complete EASY space: prefix + PATTERN for each of the two legal prefixes.
#
#   D S D          S D S D
#   D D S          S D D S
#   D D D          S D D D
#
# Six sequences, 3 or 4 turns, and that is the whole mode.
static func get_easy_sequences() -> Array:
	var sequences: Array = []

	for prefix in EASY_PREFIXES:
		for pattern in EASY_PATTERNS:
			var sequence: Array[int] = []
			for action in prefix:
				sequence.append(int(action))
			for action in pattern:
				sequence.append(int(action))
			sequences.append(sequence)

	return sequences


# MEDIUM chains PATTERNs together. Each pattern after the first starts from the previous
# one's final Draw -- that Draw is shared, so it is both the previous pattern's END and
# the new pattern's opening:
#
#   D S D  +  D D S   ->   D S D D S      (the middle D is the seam)
#
# Only a PATTERN ending in Draw can be continued, so [D,D,S] is a terminal branch and can
# only ever appear last. Every chain is enumerated -- no randomness in here, so the set is
# stable and testable.
#
# A chain of k patterns is 3 + 2(k-1) turns, plus an optional leading Skip.
const MEDIUM_CHAIN_LENGTH := 2

static func get_medium_sequences(chain_length: int = MEDIUM_CHAIN_LENGTH) -> Array:
	var continuable: Array = []
	for pattern in EASY_PATTERNS:
		if pattern[pattern.size() - 1] == 1:
			continuable.append(pattern)

	var sequences: Array = []

	for prefix in EASY_PREFIXES:
		var base: Array[int] = []
		for action in prefix:
			base.append(int(action))
		_extend_medium_chains(base, 0, chain_length, continuable, sequences)

	return sequences


# Depth-first enumeration of every legal chain of `chain_length` patterns.
static func _extend_medium_chains(
	sequence: Array[int],
	depth: int,
	chain_length: int,
	continuable: Array,
	out: Array
) -> void:
	if depth >= chain_length:
		out.append(sequence.duplicate())
		return

	var is_last := depth == chain_length - 1
	var choices: Array = EASY_PATTERNS if is_last else continuable

	for pattern in choices:
		var next := sequence.duplicate()
		# The first pattern contributes all three turns; later ones skip their opening
		# Draw, because it is the seam already placed by the pattern before it.
		var from_index := 0 if depth == 0 else 1
		for i in range(from_index, pattern.size()):
			next.append(int(pattern[i]))
		_extend_medium_chains(next, depth + 1, chain_length, continuable, out)


static func get_sequences_for(difficulty: int, chain_length: int = MEDIUM_CHAIN_LENGTH) -> Array:
	if is_multi_stage(difficulty):
		return get_medium_sequences(chain_length)
	return get_easy_sequences()


# The turn each stage of a chain ends on. Stage i finishes on the seam that stage i+1
# opens from, and the last entry is the final turn of the puzzle.
#
# A chain of k patterns is 3 + 2(k-1) turns long, so the stages end two turns apart.
static func get_stage_boundary_turns(sequence: Array, chain_length: int = MEDIUM_CHAIN_LENGTH) -> Array[int]:
	var boundaries: Array[int] = []
	if sequence.is_empty() or chain_length <= 0:
		return boundaries

	var last := sequence.size() - 1
	for i in range(chain_length):
		var boundary := last - 2 * (chain_length - 1 - i)
		if boundary >= 0:
			boundaries.append(boundary)

	return boundaries


static func _take_next_sequence(difficulty: int, chain_length: int = MEDIUM_CHAIN_LENGTH) -> Array[int]:
	var bag := _medium_sequence_bag if is_multi_stage(difficulty) else _easy_sequence_bag

	if bag.is_empty():
		bag.assign(get_sequences_for(difficulty, chain_length))
		bag.shuffle()

	return bag.pop_front()

static func generate_puzzle(
	board_def: BoardDefinition = null,
	max_turns: int = 0,
	required_shape_count: int = 2,
	difficulty: int = Difficulty.NORMAL,
	max_attempts: int = 400
) -> PuzzleData:
	var is_easy_mode := uses_sequence_tree(difficulty)
	if board_def == null:
		board_def = BoardDefinition.new(8)

	var rng := RandomNumberGenerator.new()
	rng.randomize()

	var turns_were_requested := max_turns > 0

	if turns_were_requested:
		max_turns = clampi(max_turns, 3, DEFAULT_MAX_TURNS)

	var puzzle_board := board_def.duplicate_board()
	var final_zone: int
	var easy_sequence: Array[int] = []

	if is_easy_mode:
		# Every EASY tier is exactly one of the six sequences. The sequence IS the puzzle's
		# shape: it fixes the turn count, which turns are Draws, and how many shapes there
		# are. The requested turn count and required_shape_count are both ignored here --
		# there is nothing left for them to decide.
		#
		# The wedge eraser is forced because it is the only one under which all six
		# sequences work. Under the half-plane eraser a 3-turn puzzle draws on turn 0,
		# which is then clipped by TOP, RIGHT and BOTTOM -- and TOP plus BOTTOM covers
		# the whole field, so no shape could survive to reach the target.
		puzzle_board.erasure_shape = EraserSystem.ErasureShape.DIAGONAL_WEDGE

		easy_sequence = _take_next_sequence(difficulty)
		max_turns = easy_sequence.size()

		if uses_fixed_opening(difficulty):
			# EASY: the opening erasure is always TOP, so the player learns one layout.
			puzzle_board.erasure_start_phase = EraserSystem.ErasureRegion.TOP
			final_zone = EraserSystem.get_final_phase(max_turns, puzzle_board)
		else:
			# EASY+ and up: rotate the cycle, so the same six sequences have to be read
			# against a different opening quarter each time. Rotation never changes how
			# many turns survive -- three wedge erasures always leave exactly one wedge --
			# so all six sequences stay valid.
			final_zone = _take_next_final_zone(rng)
			puzzle_board.erasure_start_phase = EraserSystem.start_phase_for_final(
				final_zone,
				max_turns
			)
	else:
		if not turns_were_requested:
			max_turns = rng.randi_range(DEFAULT_MIN_TURNS, DEFAULT_MAX_TURNS)

		# Pick the finishing zone, then rotate the cycle so that it lands there.
		final_zone = _take_next_final_zone(rng)
		puzzle_board.erasure_start_phase = EraserSystem.start_phase_for_final(
			final_zone,
			max_turns
		)

	var candidates := generate_candidate_pool(puzzle_board, difficulty)
	if candidates.is_empty():
		return _create_fallback_puzzle(
			puzzle_board,
			max_turns,
			final_zone,
			difficulty
		)

	var survivable_turns := PuzzleSimulator.get_survivable_turns(
		puzzle_board,
		max_turns
	)

	if survivable_turns.is_empty():
		return _create_fallback_puzzle(
			puzzle_board,
			max_turns,
			final_zone,
			difficulty
		)

	# The non-EASY generator asks for a fixed shape count. EASY takes its count from
	# whichever pattern the attempt rolls, so it is resolved inside the loop.
	var shape_count := clampi(required_shape_count, 1, survivable_turns.size())

	var last_turn := max_turns - 1
	var prefer_early_finish := _take_next_early_finish_preference()

	for attempt in range(max_attempts):
		var sol := PuzzleSolution.new(max_turns)
		var active_shape_count := shape_count

		if is_easy_mode:
			# The sequence is fixed for this puzzle; only the shapes re-roll. Every Draw
			# node receives one of the predefined simple shapes.
			var draw_turns := _get_easy_draw_turns(easy_sequence)

			for turn in draw_turns:
				var shape: ShapeInstance = candidates[
					rng.randi_range(0, candidates.size() - 1)
				]
				sol.set_action(turn, shape)

			active_shape_count = draw_turns.size()

		else:
			# Existing non-EASY generation behaviour.
			var enforce_early_finish := (
				prefer_early_finish
				and attempt < max_attempts * 3 / 4
			)

			var turn_pool := survivable_turns.duplicate()

			if enforce_early_finish:
				turn_pool.erase(last_turn)

			if turn_pool.size() < shape_count:
				continue

			turn_pool.shuffle()

			var turns_to_use := turn_pool.slice(0, shape_count)

			for t in turns_to_use:
				sol.set_action(
					t,
					candidates[rng.randi() % candidates.size()]
				)

		# 1. Simulate to get target
		var target := PuzzleSimulator.simulate(sol, puzzle_board)

		if target.is_empty() or target.segments.size() < 2:
			continue

		# 2. Every drawn shape must matter. In a chained puzzle the early patterns are
		# wiped long before the final target is read, so their shapes are judged against
		# their own stage's seam instead -- the leftovers the next pattern builds from.
		if is_multi_stage(difficulty):
			var boundaries := get_stage_boundary_turns(easy_sequence)
			if boundaries.is_empty():
				continue

			var stages_ok := true
			var previous_state: VectorGeometry = null
			var from_turn := 0

			for boundary in boundaries:
				if not PuzzleValidator.validate_stage_contributions(sol, puzzle_board, from_turn, boundary):
					stages_ok = false
					break

				# Each stage must leave a real intermediate goal, and must move on from
				# the one before it, or that stage was busywork.
				var stage_state := PuzzleSimulator.simulate_up_to_turn(sol, puzzle_board, boundary)
				if stage_state.segments.size() < 2:
					stages_ok = false
					break
				if previous_state != null and stage_state.is_equivalent_to(previous_state):
					stages_ok = false
					break

				previous_state = stage_state
				from_turn = boundary + 1

			if not stages_ok:
				continue

		elif not PuzzleValidator.validate_necessary_contributions(
			sol,
			target,
			puzzle_board
		):
			continue

		# 3. The opening turn must never already be the answer.
		# This remains valid for EASY mode as well. If EASY starts with Skip,
		# the opening turn cannot be the answer because nothing has been drawn.
		if not PuzzleValidator.validate_not_completable_on_first_turn(
			sol,
			target,
			puzzle_board,
			candidates
		):
			continue

		# 4. The final turn alone must never be the whole answer.
		if active_shape_count >= 2:
			if not PuzzleValidator.validate_not_last_turn_only(
				sol,
				target,
				puzzle_board
			):
				continue

		# 5. Timing has to matter. Skipped for multi-stage puzzles: that check asks whether
		# moving a shape changes the FINAL target, and a first-half shape never does --
		# its timing is pinned by the seam instead, which stage contributions already
		# enforce.
		if not is_multi_stage(difficulty):
			if not PuzzleValidator.validate_multi_turn_timing(
				sol,
				target,
				puzzle_board
			):
				continue

		if not is_easy_mode:
			if not PuzzleValidator.validate_spans_multiple_quadrants(
				target,
				puzzle_board
			):
				continue

		# Most expensive check, so it runs last.
		if not PuzzleValidator.validate_not_solvable_in_one_turn(
			target,
			puzzle_board,
			candidates,
			max_turns,
			survivable_turns
		):
			continue

		var p_data := _build_puzzle_data(
			puzzle_board,
			target,
			max_turns,
			active_shape_count,
			sol,
			final_zone
		)

		if is_multi_stage(difficulty):
			# Each stage's target is what survives at its seam; the last one is the final
			# target. The UI reveals them one at a time.
			p_data.stage_boundary_turns = get_stage_boundary_turns(easy_sequence)
			var stage_targets: Array[VectorGeometry] = []
			for boundary in p_data.stage_boundary_turns:
				stage_targets.append(PuzzleSimulator.simulate_up_to_turn(sol, puzzle_board, boundary))
			p_data.stage_targets = stage_targets

		return p_data

	# Fallback if attempt limit reached
	return _create_fallback_puzzle(
		puzzle_board,
		max_turns,
		final_zone,
		difficulty
	)


# The turns an EASY sequence draws on.
static func _get_easy_draw_turns(sequence: Array) -> Array[int]:
	var draw_turns: Array[int] = []

	for turn in range(sequence.size()):
		if sequence[turn] == 1:
			draw_turns.append(turn)

	return draw_turns


# Draws the next final zone from a shuffled bag so all four zones are used before
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
	_easy_sequence_bag.clear()
	_medium_sequence_bag.clear()


static func _build_puzzle_data(
	board_def: BoardDefinition,
	target: VectorGeometry,
	max_turns: int,
	shape_count: int,
	sol: PuzzleSolution,
	final_zone: int
) -> PuzzleData:
	var p_data := PuzzleData.new(
		board_def,
		target,
		max_turns
	)

	p_data.required_shape_count = shape_count
	p_data.reference_solution = sol
	p_data.final_erasure_zone = final_zone
	p_data.completion_turn = PuzzleSimulator.get_completion_turn(
		sol,
		board_def,
		target
	)
	p_data.difficulty_rating = float(
		shape_count * 1.5 + max_turns * 0.8
	)

	return p_data


# EASY and EASY+ are limited to the handful of predefined simple shapes. EASY++ and NORMAL
# use the full pool: the same shape families at every rotation, plus off-centre chords.
# That difference in vocabulary is the whole of what makes EASY++ harder than EASY+.
static func generate_candidate_pool(
	board_def: BoardDefinition,
	difficulty: int = Difficulty.NORMAL
) -> Array[ShapeInstance]:
	if uses_simple_shapes(difficulty):
		return _generate_easy_candidate_pool(board_def)

	var pool: Array[ShapeInstance] = []
	var N := board_def.node_count

	# Add Full Circle / Octagon
	var circ_path: Array[int] = []

	for i in range(N):
		circ_path.append(i)

	circ_path.append(0)

	var c_inst := ShapeDatabase.create_instance_from_path(
		circ_path,
		board_def
	)

	if c_inst != null:
		pool.append(c_inst)

	for i in range(N):
		# Triangles (various orientations)
		var t1 := [
			i,
			(i + 2) % N,
			(i + 5) % N,
			i
		]

		var s1 := ShapeDatabase.create_instance_from_path(
			t1,
			board_def
		)

		if s1 != null:
			pool.append(s1)

		var t2 := [
			i,
			(i + 3) % N,
			(i + 6) % N,
			i
		]

		var s2 := ShapeDatabase.create_instance_from_path(
			t2,
			board_def
		)

		if s2 != null:
			pool.append(s2)

		var t3 := [
			i,
			(i + 2) % N,
			(i + 4) % N,
			i
		]

		var s3 := ShapeDatabase.create_instance_from_path(
			t3,
			board_def
		)

		if s3 != null:
			pool.append(s3)

		# Squares & Diamonds
		var sq1 := [
			i,
			(i + 2) % N,
			(i + 4) % N,
			(i + 6) % N,
			i
		]

		var sq_inst := ShapeDatabase.create_instance_from_path(
			sq1,
			board_def
		)

		if sq_inst != null:
			pool.append(sq_inst)

		# NOTE: the 8-point star is deliberately excluded. Its eight crossing
		# edges shatter into too many fragments under erasure to be readable
		# as a puzzle target.

		# Center-crossing Lines
		var line1 := [
			i,
			(i + 4) % N
		]

		var l1_inst := ShapeDatabase.create_instance_from_path(
			line1,
			board_def
		)

		if l1_inst != null:
			pool.append(l1_inst)

		var line2 := [
			i,
			(i + 3) % N
		]

		var l2_inst := ShapeDatabase.create_instance_from_path(
			line2,
			board_def
		)

		if l2_inst != null:
			pool.append(l2_inst)

	return pool


static func _generate_easy_candidate_pool(
	board_def: BoardDefinition
) -> Array[ShapeInstance]:
	var pool: Array[ShapeInstance] = []

	for shape_data in ShapeDatabase.get_easy_mode_predefined_shapes(board_def):
		var inst: ShapeInstance = shape_data["instance"]

		if inst != null:
			pool.append(inst)

	return pool


static func _create_fallback_puzzle(
	board_def: BoardDefinition,
	max_turns: int,
	final_zone: int,
	difficulty: int = Difficulty.NORMAL
) -> PuzzleData:
	var sol := PuzzleSolution.new(max_turns)
	var candidates := generate_candidate_pool(
		board_def,
		difficulty
	)

	var survivable := PuzzleSimulator.get_survivable_turns(
		board_def,
		max_turns
	)

	if uses_sequence_tree(difficulty):
		# Keep the fallback inside the tree: the simplest sequence, Draw → Skip → Draw.
		var sequence: Array = get_sequences_for(difficulty)[0]
		var candidate_index := 0

		for turn in _get_easy_draw_turns(sequence):
			if turn >= max_turns or candidates.is_empty():
				break

			sol.set_action(
				turn,
				candidates[candidate_index % candidates.size()]
			)

			candidate_index += 1
	else:
		for i in range(
			min(
				survivable.size(),
				min(2, candidates.size())
			)
		):
			sol.set_action(
				survivable[i],
				candidates[i]
			)

	var target := PuzzleSimulator.simulate(
		sol,
		board_def
	)

	return _build_puzzle_data(
		board_def,
		target,
		max_turns,
		sol.get_non_empty_action_count(),
		sol,
		final_zone
	)
