extends SceneTree

const TestGeometry = preload("res://tests/test_geometry.gd")
const TestErasure = preload("res://tests/test_erasure.gd")
const TestSimulator = preload("res://tests/test_simulator.gd")
const TestSolverGenerator = preload("res://tests/test_solver_generator.gd")
const TestEraseMode = preload("res://tests/test_erase_mode.gd")
const TestLayers = preload("res://tests/test_layers.gd")
const TestTutorialClock = preload("res://tests/test_tutorial_clock.gd")
const TestSession = preload("res://tests/test_session.gd")

# Each suite reports [passed, total], so adding a test does not also mean remembering to
# bump a number over here. A forgotten bump used to read as a failure that was not one.
func _init():
	print("==================================================")
	print("       SHAPE TIMING PUZZLE - UNIT TESTS           ")
	print("==================================================")

	var suites := [
		TestGeometry, TestErasure, TestSimulator, TestSolverGenerator,
		TestEraseMode, TestLayers, TestTutorialClock, TestSession,
	]

	var passed := 0
	var total := 0
	for suite in suites:
		var result: Array[int] = suite.run_all_tests()
		passed += result[0]
		total += result[1]

	print("==================================================")
	print(" TESTS PASSED: %d / %d" % [passed, total])
	print("==================================================")
	quit(0 if passed == total else 1)
