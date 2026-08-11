class_name TestErasure
extends RefCounted

static func run_all_tests() -> int:
	var passed := 0
	print("--- Running TestErasure ---")

	if test_erasure_regions():
		passed += 1
		print("  [PASS] test_erasure_regions")
	else:
		print("  [FAIL] test_erasure_regions")

	if test_wedge_regions():
		passed += 1
		print("  [PASS] test_wedge_regions")
	else:
		print("  [FAIL] test_wedge_regions")

	if test_survivable_window_by_eraser_shape():
		passed += 1
		print("  [PASS] test_survivable_window_by_eraser_shape")
	else:
		print("  [FAIL] test_survivable_window_by_eraser_shape")

	return passed

static func test_erasure_regions() -> bool:
	var board_def := BoardDefinition.new(8, Vector2(64, 64))

	var top_rect := EraserSystem.get_erasure_rect_for_phase(0, board_def)
	var right_rect := EraserSystem.get_erasure_rect_for_phase(1, board_def)
	var bottom_rect := EraserSystem.get_erasure_rect_for_phase(2, board_def)
	var left_rect := EraserSystem.get_erasure_rect_for_phase(3, board_def)

	if top_rect != Rect2(0, 0, 64, 32): return false
	if right_rect != Rect2(32, 0, 32, 64): return false
	if bottom_rect != Rect2(0, 32, 64, 32): return false
	if left_rect != Rect2(0, 0, 32, 64): return false

	return true

# The X divides the field into four 90-degree wedges. A point straight up is in TOP; the
# same distance out along a diagonal sits on the boundary and must be erased rather than
# belonging to no wedge at all.
static func test_wedge_regions() -> bool:
	var board_def := BoardDefinition.new(8, Vector2(64, 64), 0, EraserSystem.ErasureShape.DIAGONAL_WEDGE)
	var c := board_def.center

	var top := EraserSystem.get_erasure_region_for_phase(EraserSystem.ErasureRegion.TOP, board_def)
	var right := EraserSystem.get_erasure_region_for_phase(EraserSystem.ErasureRegion.RIGHT, board_def)
	var bottom := EraserSystem.get_erasure_region_for_phase(EraserSystem.ErasureRegion.BOTTOM, board_def)

	if top.kind != EraseArea.Kind.WEDGE: return false

	# Straight up is TOP only
	if not top.contains(c + Vector2(0, -20)): return false
	if right.contains(c + Vector2(0, -20)): return false
	if bottom.contains(c + Vector2(0, -20)): return false

	# Straight right is RIGHT only -- this is the key difference from the half-plane
	# eraser, where the upper-right area belonged to TOP as well.
	if not right.contains(c + Vector2(20, 0)): return false
	if top.contains(c + Vector2(20, 0)): return false

	# The up-right diagonal is shared by TOP and RIGHT, and must be erased by both so no
	# geometry can hide on the seam forever.
	var on_diagonal := c + Vector2(14, -14)
	if not top.contains(on_diagonal): return false
	if not right.contains(on_diagonal): return false

	# Four wedges tile the field, so every direction belongs to some wedge
	for i in range(16):
		var probe := c + Vector2(20, 0).rotated(TAU * float(i) / 16.0)
		var covered := false
		for phase in range(EraserSystem.PHASE_COUNT):
			if EraserSystem.get_erasure_region_for_phase(phase, board_def).contains(probe):
				covered = true
				break
		if not covered:
			return false

	return true

# The whole point of the wedge eraser: quarters instead of halves means ordinary shapes
# can outlive three erasures, so the third-from-last turn becomes genuinely usable.
static func test_survivable_window_by_eraser_shape() -> bool:
	var wedge_board := BoardDefinition.new(8, Vector2(64, 64), 0, EraserSystem.ErasureShape.DIAGONAL_WEDGE)
	var half_board := BoardDefinition.new(8, Vector2(64, 64), 0, EraserSystem.ErasureShape.HALF_PLANE)

	# The probe-based window is an upper bound and reads 3 in both modes, because a
	# diameter lying exactly on the centre axis slips through the half-plane eraser.
	if PuzzleSimulator.get_survivable_turns(wedge_board, 7) != [4, 5, 6]: return false
	if PuzzleSimulator.get_survivable_turns(half_board, 7) != [4, 5, 6]: return false

	# What actually differs is how many real shapes can use that third turn.
	var wedge_ratio := _survivor_ratio(wedge_board, 7, 2)
	var half_ratio := _survivor_ratio(half_board, 7, 2)

	if wedge_ratio < 0.5: return false # most shapes survive two erasures under the X
	if half_ratio > 0.2: return false  # only the centre-seam ones do under half-planes
	if wedge_ratio <= half_ratio: return false

	# A shape drawn three turns before the end is gone in either mode
	if _survivor_ratio(wedge_board, 7, 3) != 0.0: return false
	if _survivor_ratio(half_board, 7, 3) != 0.0: return false

	return true

# Fraction of the candidate pool that still leaves geometry when drawn `turns_before_end`
# turns before the puzzle ends.
static func _survivor_ratio(board_def: BoardDefinition, max_turns: int, turns_before_end: int) -> float:
	var pool := PuzzleGenerator.generate_candidate_pool(board_def)
	if pool.is_empty():
		return 0.0

	var turn := max_turns - 1 - turns_before_end
	var survivors := 0
	for shape in pool:
		var sol := PuzzleSolution.new(max_turns)
		sol.set_action(turn, shape)
		if not PuzzleSimulator.simulate(sol, board_def).is_empty():
			survivors += 1

	return float(survivors) / float(pool.size())
