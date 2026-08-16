extends SceneTree

const TestGeometry = preload("res://tests/test_geometry.gd")
const TestErasure = preload("res://tests/test_erasure.gd")
const TestSimulator = preload("res://tests/test_simulator.gd")
const TestSolverGenerator = preload("res://tests/test_solver_generator.gd")
const TestEraseMode = preload("res://tests/test_erase_mode.gd")
const TestLayers = preload("res://tests/test_layers.gd")
const TestTutorialClock = preload("res://tests/test_tutorial_clock.gd")

func _init():
	print("==================================================")
	print("       SHAPE TIMING PUZZLE - UNIT TESTS           ")
	print("==================================================")

	const EXPECTED_TOTAL := 44

	var total_passed := 0
	total_passed += TestGeometry.run_all_tests()
	total_passed += TestErasure.run_all_tests()
	total_passed += TestSimulator.run_all_tests()
	total_passed += TestSolverGenerator.run_all_tests()
	total_passed += TestEraseMode.run_all_tests()
	total_passed += TestLayers.run_all_tests()
	total_passed += TestTutorialClock.run_all_tests()

	print("==================================================")
	print(" TESTS PASSED: %d / %d" % [total_passed, EXPECTED_TOTAL])
	print("==================================================")
	quit(0 if total_passed == EXPECTED_TOTAL else 1)
