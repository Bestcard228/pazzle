class_name ClassicCampaign
extends RefCounted

# Classical mode: a long ladder of levels, each slightly harder than the last.
#
#   level 1-5       tutorial levels (locked settings, guided introduction)
#   level 6-100     Easy tier
#   level 101-200   Easy+
#   level 201-300   Easy++
#   level 301+      Medium, chain grows every 100 levels
#
# Progress is saved so the player always resumes where they left off.

const SAVE_PATH := "user://classic_progress.cfg"

const TUTORIAL_LEVEL_COUNT := 5

static func difficulty_for_level(level: int) -> int:
	var l := maxi(1, level)
	if l <= 100:
		return PuzzleGenerator.Difficulty.EASY
	if l <= 200:
		return PuzzleGenerator.Difficulty.EASY_PLUS
	if l <= 300:
		return PuzzleGenerator.Difficulty.EASY_PLUS_PLUS
	return PuzzleGenerator.Difficulty.MEDIUM

static func is_tutorial_level(level: int) -> bool:
	return level >= 1 and level <= TUTORIAL_LEVEL_COUNT

static func chain_length_for_level(level: int) -> int:
	if level <= 300:
		return 2
	return 2 + (level - 301) / 100

static func turns_for_level(level: int, difficulty: int) -> int:
	if difficulty == PuzzleGenerator.Difficulty.MEDIUM:
		return 0
	var base := 4
	if level > 20:
		base = 4 + mini(3, (level - 20) / 20)
	return base

static func required_shapes_for_level(level: int, difficulty: int) -> int:
	if difficulty == PuzzleGenerator.Difficulty.MEDIUM:
		return 0
	if is_tutorial_level(level):
		return 2
	if level <= 100:
		return 2
	if level <= 200:
		return 2 if (level % 2 == 1) else 3
	return 3

static func clock_for_level(level: int, difficulty: int) -> float:
	if is_tutorial_level(level):
		return 0.0
	return 12.0

static func cycle_for_level(level: int, difficulty: int) -> int:
	if is_tutorial_level(level):
		return EraserSystem.CYCLE_CLOCKWISE
	if difficulty == PuzzleGenerator.Difficulty.EASY:
		if level % 2 == 0:
			return EraserSystem.CYCLE_CLOCKWISE
		return EraserSystem.CYCLE_COUNTER_CLOCKWISE
	return PuzzleGenerator.SHUFFLED_ERASURE_CYCLE

static func input_mode_for_level(level: int, difficulty: int) -> int:
	if level > 450:
		if level % 3 == 0:
			return PuzzleData.InputMode.CHOOSE_ERASURES
	return PuzzleData.InputMode.DRAW_SHAPES

static func layers_for_level(level: int, difficulty: int) -> int:
	if level >= 250:
		return 2
	return LayerSystem.SINGLE_LAYER

static func level_name(level: int) -> String:
	if is_tutorial_level(level):
		match level:
			1: return "THE FIRST LINE"
			2: return "CLOSING THE SHAPE"
			3: return "THE ERASER'S PATH"
			4: return "SKIPS AND TURNS"
			5: return "PUTTING IT TOGETHER"
	return "LEVEL %d" % level

static func progress_label(level: int) -> String:
	if is_tutorial_level(level):
		return "%s  -  TUTORIAL" % level_name(level)
	return level_name(level)