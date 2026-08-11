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
