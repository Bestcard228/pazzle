class_name PuzzleGenerator
extends RefCounted

# Which of the six erasure walks a puzzle uses. This is an ordering of the existing
# rules, not a new tier: every walk still clears the field in four steps, so the six EASY
# sequences and the MEDIUM chain are unchanged by it. SHUFFLED_ERASURE_CYCLE draws one
# per puzzle from a bag, so all six appear before any repeats.
# Seconds per turn. Offered at every tier and in both input modes, because running out of
# time is just a skip and every tier already knows what a skip is.
const TURN_TIME_CHOICES: Array[float] = [0.0, 12.0, 6.0, 4.0]
const NO_TURN_TIME_LIMIT := 0.0

const SHUFFLED_ERASURE_CYCLE := -1
const DEFAULT_ERASURE_CYCLE := SHUFFLED_ERASURE_CYCLE

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
	max_attempts: int = 400,
	erasure_cycle_id: int = DEFAULT_ERASURE_CYCLE,
	input_mode: int = PuzzleData.InputMode.DRAW_SHAPES,
	turn_time_limit: float = NO_TURN_TIME_LIMIT
) -> PuzzleData:
	var is_easy_mode := uses_sequence_tree(difficulty)
	var is_erase_mode := input_mode == PuzzleData.InputMode.CHOOSE_ERASURES
	if board_def == null:
		board_def = BoardDefinition.new(8)

	var rng := RandomNumberGenerator.new()
	rng.randomize()

	var turns_were_requested := max_turns > 0

	if turns_were_requested:
		max_turns = clampi(max_turns, 3, DEFAULT_MAX_TURNS)

	var puzzle_board := board_def.duplicate_board()
	# The generated puzzle owns its cycle, so the caller only has to say it once here
	# rather than keeping a board in sync as well.
	# EASY forces the wedge below, so the walk is resolved against the shape the board
	# will actually be erased with.
	var eraser_shape: int = (EraserSystem.ErasureShape.DIAGONAL_WEDGE if is_easy_mode
		else puzzle_board.erasure_shape)
	puzzle_board.erasure_cycle_id = _resolve_erasure_cycle(erasure_cycle_id, eraser_shape)
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
				max_turns,
				puzzle_board.erasure_cycle_id
			)
	else:
		if not turns_were_requested:
			max_turns = rng.randi_range(DEFAULT_MIN_TURNS, DEFAULT_MAX_TURNS)

		# Pick the finishing zone, then rotate the cycle so that it lands there.
		final_zone = _take_next_final_zone(rng)
		puzzle_board.erasure_start_phase = EraserSystem.start_phase_for_final(
			final_zone,
			max_turns,
			puzzle_board.erasure_cycle_id
		)

	var candidates := generate_candidate_pool(puzzle_board, difficulty)
	if candidates.is_empty():
		return _create_fallback_puzzle(
			puzzle_board,
			max_turns,
			final_zone,
			difficulty,
			input_mode
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
			difficulty,
			input_mode
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

		# In ERASE mode the schedule is the thing being solved, so it has to be worth
		# solving: some orders must reach the target and some must not.
		if is_erase_mode:
			if not PuzzleValidator.validate_erase_choice_matters(
				sol,
				puzzle_board,
				target,
				max_turns
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
		p_data.input_mode = input_mode
		p_data.turn_time_limit = turn_time_limit
		p_data.erase_order = get_erase_order(puzzle_board, max_turns)

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
		difficulty,
		input_mode
	)


# The zone the board erases on each turn, spelled out. In DRAW mode this is a readout of
# the cycle; in ERASE mode it is the schedule the player is trying to rediscover.
static func get_erase_order(board_def: BoardDefinition, max_turns: int) -> Array[int]:
	var order: Array[int] = []
	for turn in range(max_turns):
		order.append(EraserSystem.get_phase_for_turn(turn, board_def))
	return order


# The turns an EASY sequence draws on.
static func _get_easy_draw_turns(sequence: Array) -> Array[int]:
	var draw_turns: Array[int] = []

	for turn in range(sequence.size()):
		if sequence[turn] == 1:
			draw_turns.append(turn)

	return draw_turns


# Draws the next final zone from a shuffled bag so all four zones are used before
# repeats, and the same zone never lands twice in a row.
# Bag over the walks, so a run of puzzles sees all of them before any repeats. Only walks
# that survive the board's eraser shape go in: under the half-plane the non-rotational
# ones clear the field in two turns, which would leave nothing for the sequences to work
# with. A walk asked for by name is honoured the same way -- corrected rather than used to
# generate puzzles that cannot hold together.
static var _cycle_bag: Array[int] = []

static func _resolve_erasure_cycle(requested: int, shape: int) -> int:
	if requested != SHUFFLED_ERASURE_CYCLE:
		var wanted := posmod(requested, EraserSystem.CYCLE_COUNT)
		if EraserSystem.is_cycle_usable(wanted, shape):
			return wanted
	return _take_next_erasure_cycle(shape)

static func _take_next_erasure_cycle(shape: int) -> int:
	var usable := EraserSystem.get_usable_cycles(shape)
	if usable.is_empty():
		return EraserSystem.CYCLE_CLOCKWISE

	# Drop anything the bag is holding that this shape cannot use
	var next_bag: Array[int] = []
	for cycle_id in _cycle_bag:
		if usable.has(cycle_id):
			next_bag.append(cycle_id)
	_cycle_bag = next_bag

	if _cycle_bag.is_empty():
		_cycle_bag = usable.duplicate()
		_cycle_bag.shuffle()
	return _cycle_bag.pop_back()

# The pair of reset_zone_rotation, which the tests use to make bag-driven generation
# repeatable. Kept so a test that needs to pin the walk has the same lever available.
static func reset_erasure_cycle_rotation() -> void:
	_cycle_bag.clear()

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
	difficulty: int = Difficulty.NORMAL,
	input_mode: int = PuzzleData.InputMode.DRAW_SHAPES
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

	var p_data := _build_puzzle_data(
		board_def,
		target,
		max_turns,
		sol.get_non_empty_action_count(),
		sol,
		final_zone
	)
	p_data.input_mode = input_mode
	p_data.erase_order = get_erase_order(board_def, max_turns)
	return p_data


# --- Layered puzzles ----------------------------------------------------------------

# The layered mod: one sequence, several colours.
#
# The D/S sequence is shared -- every layer draws on the same turns and skips on the same
# turns, which is what the notation D(r) D(g) / S(r) S(g) says. What differs per layer is
# the walk the blade takes through the quarters, so each colour is eaten in a different
# order and a shape that survives in red may not survive in green.
#
# Because each layer is erased once per turn by its own walk, a layer IS an ordinary
# single-layer puzzle. So this generates one per colour with the existing pool and the
# existing validators, and only then asks the cross-layer question: are these actually
# different puzzles, or the same one drawn twice?
static func generate_layered_puzzle(
	board_def: BoardDefinition = null,
	difficulty: int = Difficulty.EASY,
	layer_count: int = 2,
	max_attempts: int = 200,
	input_mode: int = PuzzleData.InputMode.DRAW_SHAPES,
	turn_time_limit: float = NO_TURN_TIME_LIMIT
) -> PuzzleData:
	if board_def == null:
		board_def = BoardDefinition.new(8)

	var layers := LayerSystem.clamp_layer_count(layer_count)
	if layers <= LayerSystem.SINGLE_LAYER or not uses_sequence_tree(difficulty):
		return generate_puzzle(board_def, 0, 2, difficulty, 400, DEFAULT_ERASURE_CYCLE,
			input_mode, turn_time_limit)

	var rng := RandomNumberGenerator.new()
	rng.randomize()

	# The wedge is forced for the same reason it is in the single-layer tiers: it is the
	# only eraser under which all six sequences hold together.
	var base_board := board_def.duplicate_board()
	base_board.erasure_shape = EraserSystem.ErasureShape.DIAGONAL_WEDGE

	for attempt in range(max_attempts):
		var sequence := _take_next_sequence(difficulty)
		var max_turns := sequence.size()
		var draw_turns := _get_easy_draw_turns(sequence)
		if draw_turns.is_empty():
			continue

		var cycles := LayerSystem.assign_layer_cycles(layers, base_board.erasure_shape, rng)
		var starts := LayerSystem.assign_layer_start_phases(layers, rng)

		var boards: Array[BoardDefinition] = []
		for layer in range(layers):
			var layer_board := base_board.duplicate_board()
			layer_board.erasure_cycle_id = cycles[layer]
			layer_board.erasure_start_phase = starts[layer]
			boards.append(layer_board)

		# Shapes are chosen turn by turn ACROSS the layers, not layer by layer, so that a
		# turn never paints the same shape twice in two colours. D(r) D(g) is two
		# different shapes going down on the same turn -- if they were the same one, the
		# turn would just be one shape drawn in two inks and the colours would carry no
		# information.
		var pools: Array = []
		var layered := LayeredSolution.new(layers, max_turns)
		var layers_ok := true

		for layer in range(layers):
			var pool := generate_candidate_pool(boards[layer], difficulty)
			if pool.size() < layers:
				# Not enough distinct shapes to give every colour its own on a turn
				layers_ok = false
				break
			pools.append(pool)

		if not layers_ok:
			continue

		for turn in draw_turns:
			var chosen: Array[ShapeInstance] = []
			for layer in range(layers):
				var shape := _pick_distinct_shape(pools[layer], chosen, rng)
				if shape == null:
					layers_ok = false
					break
				chosen.append(shape)
				layered.set_action(turn, layer, shape)
			if not layers_ok:
				break

		if not layers_ok:
			continue

		var targets: Array[VectorGeometry] = []

		for layer in range(layers):
			var layer_board := boards[layer]
			var layer_solution := layered.get_layer(layer)
			var layer_target := PuzzleSimulator.simulate(layer_solution, layer_board)

			# Every colour has to be worth drawing: it must leave something, and every
			# shape in it must matter, judged exactly as a single-layer puzzle would be.
			if layer_target.is_empty() or layer_target.segments.size() < 2:
				layers_ok = false
				break
			if not _validate_layer(layer_solution, layer_board, layer_target, sequence, difficulty):
				layers_ok = false
				break

			targets.append(layer_target)

		if not layers_ok:
			continue

		if not _layers_are_distinct(boards, targets):
			continue

		var layered_data := _build_layered_puzzle_data(
			base_board, boards, layered, targets, sequence, max_turns, difficulty, input_mode)
		layered_data.turn_time_limit = turn_time_limit
		return layered_data

	# Nothing held together in the attempts allowed: fall back to the single-layer game
	# rather than handing back a layered puzzle that does not stand up.
	return generate_puzzle(board_def, 0, 2, difficulty, 400, DEFAULT_ERASURE_CYCLE,
		input_mode, turn_time_limit)


# A shape for this turn that none of the colours already painted on it is using. Compared
# by geometry rather than by path, so the same lines walked in a different order still
# count as the same shape.
static func _pick_distinct_shape(
	pool: Array[ShapeInstance],
	already_chosen: Array[ShapeInstance],
	rng: RandomNumberGenerator
) -> ShapeInstance:
	if pool.is_empty():
		return null

	# Random draws first, so the shapes stay varied rather than always the pool's order
	for attempt in range(12):
		var candidate: ShapeInstance = pool[rng.randi() % pool.size()]
		if not _shape_matches_any(candidate, already_chosen):
			return candidate

	# Then an exhaustive sweep, so a crowded turn fails only when it genuinely has to
	for candidate in pool:
		if not _shape_matches_any(candidate, already_chosen):
			return candidate

	return null


static func _shape_matches_any(shape: ShapeInstance, others: Array[ShapeInstance]) -> bool:
	for other in others:
		if other == null or other.geometry == null or shape.geometry == null:
			continue
		if shape.geometry.is_equivalent_to(other.geometry):
			return true
	return false


# A layer is judged by the same rules as a whole puzzle, because that is what it is.
static func _validate_layer(
	solution: PuzzleSolution,
	board: BoardDefinition,
	target: VectorGeometry,
	sequence: Array[int],
	difficulty: int
) -> bool:
	if is_multi_stage(difficulty):
		var boundaries := get_stage_boundary_turns(sequence)
		if boundaries.is_empty():
			return false

		var previous_state: VectorGeometry = null
		var from_turn := 0
		for boundary in boundaries:
			if not PuzzleValidator.validate_stage_contributions(solution, board, from_turn, boundary):
				return false
			var stage_state := PuzzleSimulator.simulate_up_to_turn(solution, board, boundary)
			if stage_state.segments.size() < 2:
				return false
			if previous_state != null and stage_state.is_equivalent_to(previous_state):
				return false
			previous_state = stage_state
			from_turn = boundary + 1
		return true

	return PuzzleValidator.validate_necessary_contributions(solution, target, board)


# Two colours that are erased the same way and end up looking the same are one puzzle
# drawn twice. The layers have to differ in how they are eaten, and in what is left.
static func _layers_are_distinct(boards: Array[BoardDefinition], targets: Array[VectorGeometry]) -> bool:
	for i in range(boards.size()):
		for j in range(i + 1, boards.size()):
			var same_walk := (boards[i].erasure_cycle_id == boards[j].erasure_cycle_id
				and boards[i].erasure_start_phase == boards[j].erasure_start_phase)
			if same_walk:
				return false
			if targets[i].is_equivalent_to(targets[j]):
				return false
	return true


static func _build_layered_puzzle_data(
	base_board: BoardDefinition,
	boards: Array[BoardDefinition],
	layered: LayeredSolution,
	targets: Array[VectorGeometry],
	sequence: Array[int],
	max_turns: int,
	difficulty: int,
	input_mode: int
) -> PuzzleData:
	# Layer 0 also fills the single-layer fields, so everything that only knows about one
	# board -- the board rendering, the timeline, the erase-mode controller -- still has a
	# coherent puzzle to read.
	var merged := PuzzleSimulator.merge_layers(targets)
	var p_data := _build_puzzle_data(
		boards[0],
		targets[0],
		max_turns,
		layered.get_non_empty_action_count(),
		layered.get_layer(0),
		EraserSystem.get_final_phase(max_turns, boards[0])
	)

	p_data.layer_count = boards.size()
	p_data.layer_boards = boards
	p_data.layer_targets = targets
	p_data.layered_solution = layered
	p_data.input_mode = input_mode
	p_data.erase_order = get_erase_order(boards[0], max_turns)

	# The merged picture is what the board shows, so it is the one the win reads against
	# for anything that is not layer-aware.
	p_data.difficulty_rating = float(layered.get_non_empty_action_count() * 1.5 + max_turns * 0.8)

	if is_multi_stage(difficulty):
		p_data.stage_boundary_turns = get_stage_boundary_turns(sequence)
		var stage_targets: Array[VectorGeometry] = []
		var layer_stage_targets: Array = []

		for boundary in p_data.stage_boundary_turns:
			var per_layer := PuzzleSimulator.simulate_layers_up_to_turn(layered, boards, boundary)
			layer_stage_targets.append(per_layer)
			stage_targets.append(PuzzleSimulator.merge_layers(per_layer))

		p_data.stage_targets = stage_targets
		p_data.layer_stage_targets = layer_stage_targets

	# The single-layer target field carries the merged picture, which is what the goal
	# card draws; the per-layer goals live in layer_targets and are what the win checks.
	p_data.target_geometry = merged
	return p_data
