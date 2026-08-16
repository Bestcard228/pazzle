class_name TestLayers
extends RefCounted

static func run_all_tests() -> int:
	var passed := 0
	print("--- Running TestLayers ---")

	var checks := {
		"test_layer_window_matches_single_layer": test_layer_window_matches_single_layer(),
		"test_layers_share_the_sequence": test_layers_share_the_sequence(),
		"test_layered_generation_holds_up": test_layered_generation_holds_up(),
		"test_layers_are_compared_colour_for_colour": test_layers_are_compared_colour_for_colour(),
		"test_single_layer_is_the_original_game": test_single_layer_is_the_original_game(),
		"test_a_turn_never_paints_the_same_shape_twice": test_a_turn_never_paints_the_same_shape_twice(),
	}

	for name in checks.keys():
		if checks[name]:
			passed += 1
			print("  [PASS] %s" % name)
		else:
			print("  [FAIL] %s" % name)

	return passed

# The claim the whole mod rests on: a layer is erased once per turn by its own walk, so
# from that layer's point of view nothing has changed. If the live window differed from
# the single-layer one, the D/S sequences would no longer be correct for layers.
static func test_layer_window_matches_single_layer() -> bool:
	var reference := PuzzleSimulator.get_survivable_turns(BoardDefinition.new(8), 4)

	for cycle_id in range(EraserSystem.CYCLE_COUNT):
		for start in range(EraserSystem.PHASE_COUNT):
			var layer_board := BoardDefinition.new(8, Vector2(64, 64), start,
				EraserSystem.ErasureShape.DIAGONAL_WEDGE, cycle_id)
			if PuzzleSimulator.get_survivable_turns(layer_board, 4) != reference:
				return false

	return true

# D(r) D(g) / S(r) S(g): the layers act on the same turns and differ only in how they are
# eaten. A turn is a draw turn in every colour or in none.
static func test_layers_share_the_sequence() -> bool:
	var board_def := BoardDefinition.new(8)
	var puzzle := PuzzleGenerator.generate_layered_puzzle(board_def, PuzzleGenerator.Difficulty.EASY, 2, 200)
	if not puzzle.uses_layers(): return false

	var sequences := PuzzleGenerator.get_easy_sequences()
	var actions: Array[int] = []

	for turn in range(puzzle.max_turns):
		var drawing_layers := 0
		for layer in range(puzzle.layer_count):
			if puzzle.layered_solution.get_shape(turn, layer) != null:
				drawing_layers += 1
		# All of them or none of them -- never a turn where red draws and green does not
		if drawing_layers != 0 and drawing_layers != puzzle.layer_count:
			return false
		actions.append(1 if drawing_layers > 0 else 0)

	# And the shared pattern is still one of the six, unchanged by the colours
	return sequences.has(actions)

# Every tier must generate a layered puzzle whose layers each replay to their own goal.
static func test_layered_generation_holds_up() -> bool:
	for difficulty in PuzzleGenerator.DIFFICULTY_ORDER:
		for layer_count in [2, 3]:
			var puzzle := PuzzleGenerator.generate_layered_puzzle(
				BoardDefinition.new(8), difficulty, layer_count, 200)

			if puzzle == null or not puzzle.uses_layers(): return false
			if puzzle.layer_count != layer_count: return false
			if puzzle.layer_boards.size() != layer_count: return false
			if puzzle.layer_targets.size() != layer_count: return false

			var replay := PuzzleSimulator.simulate_layers(puzzle.layered_solution, puzzle.layer_boards)
			if not PuzzleSimulator.layers_are_equivalent(replay, puzzle.layer_targets): return false

			# No two colours may be the same puzzle wearing a different ink
			for i in range(layer_count):
				for j in range(i + 1, layer_count):
					var same_walk := (puzzle.layer_boards[i].erasure_cycle_id == puzzle.layer_boards[j].erasure_cycle_id
						and puzzle.layer_boards[i].erasure_start_phase == puzzle.layer_boards[j].erasure_start_phase)
					if same_walk: return false
					if puzzle.layer_targets[i].is_equivalent_to(puzzle.layer_targets[j]): return false

	return true

# Swapping two layers' geometry leaves the merged picture identical but must not count as
# a win -- otherwise a red line could answer for a green one and the colours would be
# decoration.
static func test_layers_are_compared_colour_for_colour() -> bool:
	var board_def := BoardDefinition.new(8)
	var red := VectorGeometry.new()
	red.add_line(board_def.get_node_position(0), board_def.get_node_position(2))
	var green := VectorGeometry.new()
	green.add_line(board_def.get_node_position(4), board_def.get_node_position(6))

	var goal: Array[VectorGeometry] = [red, green]
	var same: Array[VectorGeometry] = [red.duplicate_geometry(), green.duplicate_geometry()]
	var swapped: Array[VectorGeometry] = [green.duplicate_geometry(), red.duplicate_geometry()]

	if not PuzzleSimulator.layers_are_equivalent(same, goal): return false
	if PuzzleSimulator.layers_are_equivalent(swapped, goal): return false

	# The merged picture cannot tell them apart, which is exactly why it is not what the
	# win is judged on
	if not PuzzleSimulator.merge_layers(swapped).is_equivalent_to(PuzzleSimulator.merge_layers(goal)):
		return false

	return true

# One layer is the game that already existed, not a special case of the new one.
static func test_single_layer_is_the_original_game() -> bool:
	var puzzle := PuzzleGenerator.generate_layered_puzzle(
		BoardDefinition.new(8), PuzzleGenerator.Difficulty.EASY, 1, 200)

	if puzzle == null or puzzle.uses_layers(): return false
	if puzzle.layer_count != 1: return false
	if puzzle.reference_solution == null: return false

	# It is an ordinary puzzle in every respect, replay included
	var replay := PuzzleSimulator.simulate(puzzle.reference_solution, puzzle.board_definition)
	if not replay.is_equivalent_to(puzzle.target_geometry): return false

	# And the ink stays the original amber rather than becoming "the red layer"
	if LayerSystem.get_layer_color(0, 1) != LayerSystem.SINGLE_LAYER_COLOR: return false

	return true


# D(r) D(g) is two different shapes going down on one turn. If both colours painted the
# same shape it would be one shape in two inks, and the colours would carry nothing.
static func test_a_turn_never_paints_the_same_shape_twice() -> bool:
	for difficulty in PuzzleGenerator.DIFFICULTY_ORDER:
		for layer_count in [2, 3]:
			var puzzle := PuzzleGenerator.generate_layered_puzzle(
				BoardDefinition.new(8), difficulty, layer_count, 200)
			if not puzzle.uses_layers(): return false

			for turn in range(puzzle.max_turns):
				for i in range(layer_count):
					var first := puzzle.layered_solution.get_shape(turn, i)
					if first == null:
						continue
					for j in range(i + 1, layer_count):
						var second := puzzle.layered_solution.get_shape(turn, j)
						if second == null:
							continue
						if first.geometry.is_equivalent_to(second.geometry):
							return false

	return true
