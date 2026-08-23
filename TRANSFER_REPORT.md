# Puzzle-game-main → shape-timing-puzzle Transfer Report
Generated: 2026-08-23

Source Godot project: `/home/lineage/share_windowns/Puzzle-game-main` (Godot 4.x / Redot 4.3, 540×960, mobile)
Target Unity project: `/home/lineage/share_windowns/shape-timing-puzzle` (Unity 6000.5.9f1, URP 17.5, InputSystem 1.20.0)

## What was transferred

### Project Settings
- `project.godot` → `ProjectSettings/ProjectSettings.asset`
  - `config/name = "Shape Timing Puzzle"` → `productName`
  - `window/size/viewport 540×960` → `defaultScreenWidth/Height = 540×960`, `CanvasScaler.referenceResolution = 540×960`
  - `stretch/mode = canvas_items` → `CanvasScaler.ScaleWithScreenSize`
  - `orientation = portrait` → `defaultScreenOrientation = Portrait (1)`
  - `rendering_method = mobile` → URP mobile settings kept

### Core (scripts/core/ → Assets/Scripts/Core/)
| Godot | Unity |
|-------|-------|
| `vector_geometry.gd` | `VectorGeometry.cs` (`PuzzleGame.Core.VectorGeometry`, `LineSegment2D`) |
| `draw_action.gd` | `DrawAction.cs` |
| `puzzle_solution.gd` | `PuzzleSolution.cs` |
| `erasure_solution.gd` | `ErasureSolution.cs` |
| `layered_solution.gd` | `LayeredSolution.cs` |
| `geometry_clipper.gd` | `GeometryClipper.cs` (static) |
| `puzzle_simulator.gd` | `PuzzleSimulator.cs` (static) |

- `Vector2` → `UnityEngine.Vector2`, `Rect2` → `UnityEngine.Rect`, `EPSILON = 0.01` preserved.
- `canonicalize()` / `is_equivalent_to()` sorting semantics preserved.

### Board (scripts/board/ → Assets/Scripts/Board/)
- `board_definition.gd` → `BoardDefinition.cs`
- `erase_area.gd` → `EraseArea.cs` (RECT/WEDGE, `Kind` enum, `Contains`, `GetSplitParameters`)
- `eraser_system.gd` → `EraserSystem.cs` (6 cycles, `CYCLE_CLOCKWISE` etc, `GetPhaseForTurn`, `LegalZonesAfter`)
- `layer_system.gd` → `LayerSystem.cs` (MAX_LAYERS=4, `GetLayerColor`, `AssignLayerCycles`)

### Shapes (scripts/shapes/ → Assets/Scripts/Shapes/)
- `shape_template.gd` → `ShapeTemplate.cs`
- `shape_instance.gd` → `ShapeInstance.cs`
- `shape_database.gd` → `ShapeDatabase.cs` (Triangle/Square/Circle/Pentagon/Star/Line/Polyline, `GetEasyModePredefinedShapes`)

### Puzzle (scripts/puzzle/ → Assets/Scripts/Puzzle/)
- `puzzle_data.gd` → `PuzzleData.cs` (`InputMode.DRAW_SHAPES/CHOOSE_ERASURES`, `layerCount`, `stageTargets`, `GetStageForTurn`)
- `puzzle_solver.gd` → `PuzzleSolver.cs` (brute-force DFS)
- `puzzle_validator.gd` → `PuzzleValidator.cs` (necessary contributions, multi-turn timing, quadrant, erase-choice)
- `puzzle_generator.gd` → `PuzzleGenerator.cs` (1124 lines → C# static, bags for `_zoneBag`, `_cycleBag`, `_easy/mediumSequenceBag`, `GeneratePuzzle`, `GenerateLayeredPuzzle`, `GODOT RandomNumberGenerator` → `System.Random`)

### Session (scripts/session/ → Assets/Scripts/Session/)
- `turn_clock.gd` → `TurnClock.cs` (`Tick` returns true once on expiry)
- `erase_puzzle_controller.gd` → `ErasePuzzleController.cs` (events `ZoneCommitted`, `ScheduleChanged`)
- `puzzle_session.gd` → `PuzzleSession.cs` (`CommitShape` → `Commit.LayerDone/TurnDone`, `SkipTurn`, `PickZone`, `StageCleared`)
- `tutorial_controller.gd` → `TutorialController.cs` (fixed D S D lesson, `TRIANGLE_PATH=[0,3,5,0]`, `SQUARE_PATH=[0,2,4,6,0]`)
- `story_campaign.gd` → `StoryCampaign.cs` (10 chapters, `STORY_TURN_SECONDS=12`)
- `story_runner.gd` → `StoryRunner.cs` (`PlayerPrefs` instead of `ConfigFile`)
- `hint_director.gd` → `HintDirector.cs` (`IDLE_SECONDS=20`, `Kind.DRAW_PATH/SKIP/ERASE_ZONE`)

### UI (scripts/ui/ → Assets/Scripts/UI/)
- `drawing_board.gd` (843 lines) → `DrawingBoard.cs` (MonoBehaviour, GL `OnRenderObject` with `Hidden/Internal-Colored`, `ZoneAtPosition`, `ShowHint`, `FlashCommittedShape`)
- `input_handler.gd` → `InputHandler.cs` (IPointer handlers + mouse fallback, `DETECTION_RADIUS=70`, `DOT_RADIUS=32`, backtrack hysteresis)
- `icon_button.gd` → `IconButton.cs` (`IconKind` 12 kinds, procedural labels)
- `mini_board.gd` → `MiniBoard.cs` (static helpers `ScaleFor`, `WedgePolygon`)
- `target_display.gd` → `TargetDisplay.cs` (fade timers, `SetLayerTargets`)
- `turn_timeline.gd` → `TurnTimeline.cs` (`SetShapeMode`, `GetPhaseForTurn`)
- `solution_strip.gd` → `SolutionStrip.cs` (`SetRevealed`, `UsesLayers`)
- `main_menu.gd` → `MainMenu.cs` (`ModeChosen` event, story vs debug)
- `game_ui.gd` (931 lines) → `GameUI.cs` (central controller, `AppMode.MENU/STORY/DEBUG`, `LoadNewPuzzle`, `OnPuzzleCleared`, `OnStageCleared`)

### Shaders
- `shaders/pixel_filter.gdshader` (62 lines, box filter, linear light, center sharpness) → `Assets/Shaders/PixelFilter.shader` (URP `Half` box 2×2, `_PixelSize=2`, `_DesignResolution=540×960`, `_ColorLevels=32`, `_Sharpness=0.35`) + `Assets/Materials/PixelFilter.mat` + `Assets/Scripts/UI/PixelFilterEffect.cs` (`OnRenderImage` blit)

### Scene
- `scenes/main.tscn` (Godot `Control` root, 12 load steps, HUD with 11 IconButtons, DrawingBoard Node2D, InputHandler Node2D, PixelFilter CanvasLayer) → `Assets/Editor/SetupPuzzleScene.cs` (editor window `PuzzleGame/Setup Main Scene` creates Canvas 540×960, Main Camera orthographic, GameUI hierarchy, DrawingBoard GL, InputHandler full-screen, HUD/Controls, MainMenu with STORY/DEBUG buttons). Run once after opening project to generate `Assets/Scenes/Main.unity`.

### Assets
- `icon.svg` → `Assets/Textures/icon.svg`

## Namespacing
All C# scripts under `PuzzleGame.*`:
- `PuzzleGame.Core`, `PuzzleGame.Board`, `PuzzleGame.Shapes`, `PuzzleGame.Puzzle`, `PuzzleGame.Session`, `PuzzleGame.UI`

## Notable Adaptations
- Godot `signal` → C# `event Action<>`
- `RefCounted` → plain C# class (GC managed)
- `ConfigFile` → `PlayerPrefs` (StoryRunner persistence)
- `RandomNumberGenerator` → `System.Random` + `Shuffle` helpers
- `CanvasItem.draw_*` → `GL.LINES/TRIANGLES` with `Hidden/Internal-Colored` in `OnRenderObject`, plus UI `CanvasScaler` mapping (board 64×64 → screen `boardCenterScreen=270,490`, `boardRadiusScreen=170`)
- `_draw` / `queue_redraw` → `Update` + GL rebuild; `TWEEN` → direct pulse math (`sin`, `lerp`) in `Update`
- `push_back` / `posmod` → `List.Add`, `((x%N)+N)%N`

## How to finish in Unity Editor
1. Open `shape-timing-puzzle` in Unity 6000.5.9f1 (will reimport → generates `.meta` for new scripts).
2. Menu: `PuzzleGame → Setup Main Scene` → creates & saves `Assets/Scenes/Main.unity`.
3. Assign `PixelFilter.mat` to Main Camera's `PixelFilterEffect.pixelMaterial` if not auto-linked.
4. Press Play. Use `MainMenu → STORY` to step through campaign or `DEBUG` for sandbox.

## Verification
- `Assets/Scripts` contains 25 C# files (3894 LOC total) mirroring 34 GDScript files (Godot `scripts/` ≈ 3149 LOC + 931 game_ui) + shader.
- No remaining `extends` / `class_name` Godot syntax; balanced braces check passed; all `using UnityEngine` present.
- ProjectSettings `defaultScreen 540×960`, portrait, productName set.

## Known manual steps (not auto-written)
- URP Renderer Feature for pixel filter as post-process (provided as `OnRenderImage` fallback; for URP add `PixelFilterEffect` to camera or create RendererFeature using `PixelFilter.shader`).
- InputSystemActions already present (no change).
- Build profiles unchanged; export presets (`export_presets.cfg`) Android `arm64-v8a` maps to Unity `BuildProfile` Android.

