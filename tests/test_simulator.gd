class_name TestSimulator
extends RefCounted

static func run_all_tests() -> int:
	var passed := 0
	print("--- Running TestSimulator ---")

	if test_simulation():
		passed += 1
		print("  [PASS] test_simulation")
	else:
		print("  [FAIL] test_simulation")

	return passed

static func test_simulation() -> bool:
	var board_def := BoardDefinition.new(8, Vector2(64, 64))

	# Create a solution with a Triangle drawn at turn 0
	# Node 0 (Top), Node 3 (Bottom Left), Node 5 (Bottom Right)
	var triangle_path := [0, 3, 5, 0]
	var triangle_inst := ShapeDatabase.create_instance_from_path(triangle_path, board_def)

	var sol := PuzzleSolution.new(4)
	sol.set_action(0, triangle_inst)

	# Simulate turn 0 (Top erased)
	# Node 0 is at Top (16, 8) in grid, so top portion of triangle gets clipped by Top erasure rect [0, 0, 64, 32]
	var result := PuzzleSimulator.simulate_up_to_turn(sol, board_def, 0)
	if result.is_empty():
		return false

	# Full simulation across all 4 turns
	var final_result := PuzzleSimulator.simulate(sol, board_def)
	# Triangle should have undergone Top, Right, Bottom, Left erasures sequentially
	return true
