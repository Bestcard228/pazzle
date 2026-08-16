class_name TutorialController
extends RefCounted

# A fixed EASY puzzle used as a lesson, taught entirely by showing.
#
# There is no text anywhere in here on purpose. Everything the player needs is already a
# thing the board can say for itself: a ghost path is "draw this", the wedge warning is
# "this is about to go", the dead zone afterwards is "it went", and a button that will not
# stop pulsing is "press this". The lesson is just those cues put in an order that makes
# each one explain the next.
#
# The order is the sequence D S D, which happens to teach the whole game in three turns:
#
#   turn 0   draw a shape          -- this is how you act
#            ...and watch a quarter of it disappear
#   turn 1   skip                  -- not acting is a move too
#   turn 2   draw a second shape   -- and see it land on what survived
#
# It is a real puzzle, generated the same way and played through the same code path, so
# finishing it is winning rather than being told you won.

const TRIANGLE_PATH: Array[int] = [0, 3, 5, 0]
const SQUARE_PATH: Array[int] = [0, 2, 4, 6, 0]

# Turn -> the path the lesson wants, or an empty array for "skip this turn".
var lesson: Array = []
var puzzle: PuzzleData

func build_puzzle() -> PuzzleData:
	# Pinned down completely: same board, same opening quarter, same clockwise walk every
	# time, so the lesson is the same lesson for everyone.
	var board := BoardDefinition.new(
		8, Vector2(64, 64), EraserSystem.ErasureRegion.TOP,
		EraserSystem.ErasureShape.DIAGONAL_WEDGE, EraserSystem.CYCLE_CLOCKWISE)

	lesson = [TRIANGLE_PATH, [] as Array[int], SQUARE_PATH]

	var solution := PuzzleSolution.new(lesson.size())
	for turn in range(lesson.size()):
		var path: Array = lesson[turn]
		if path.is_empty():
			continue
		var shape := ShapeDatabase.create_instance_from_path(path, board)
		if shape == null:
			return null
		solution.set_action(turn, shape)

	var target := PuzzleSimulator.simulate(solution, board)
	if target.is_empty():
		return null

	puzzle = PuzzleData.new(board, target, lesson.size())
	puzzle.reference_solution = solution
	puzzle.required_shape_count = 2
	puzzle.final_erasure_zone = EraserSystem.get_final_phase(lesson.size(), board)
	puzzle.completion_turn = PuzzleSimulator.get_completion_turn(solution, board, target)
	puzzle.erase_order = PuzzleGenerator.get_erase_order(board, lesson.size())
	# No clock while learning: the lesson is what a turn does, not how fast to do it.
	puzzle.turn_time_limit = 0.0
	return puzzle

func turn_count() -> int:
	return lesson.size()

func is_skip_turn(turn: int) -> bool:
	if turn < 0 or turn >= lesson.size():
		return false
	return (lesson[turn] as Array).is_empty()

# The path being asked for this turn, for the ghost to trace. Empty on a skip turn.
func expected_path(turn: int) -> Array[int]:
	var path: Array[int] = []
	if turn < 0 or turn >= lesson.size():
		return path
	for node_id in lesson[turn]:
		path.append(int(node_id))
	return path

# Whether what the player drew is the shape being asked for. Compared by geometry, so a
# player who traces it the other way round is right too -- the lesson is the shape, not
# the direction their finger happened to travel.
func accepts(node_ids: Array[int], turn: int) -> bool:
	if puzzle == null or is_skip_turn(turn):
		return false

	var drawn := ShapeDatabase.create_instance_from_path(node_ids, puzzle.board_definition)
	if drawn == null:
		return false

	var wanted := ShapeDatabase.create_instance_from_path(expected_path(turn), puzzle.board_definition)
	if wanted == null:
		return false

	return drawn.geometry.is_equivalent_to(wanted.geometry)
