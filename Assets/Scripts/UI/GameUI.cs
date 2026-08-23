using System.Collections.Generic;
using UnityEngine;
using UnityEngine.UI;
using PuzzleGame.Board;
using PuzzleGame.Core;
using PuzzleGame.Puzzle;
using PuzzleGame.Session;
using PuzzleGame.Shapes;

namespace PuzzleGame.UI
{
    public class GameUI : MonoBehaviour
    {
        public PuzzleSession session = new PuzzleSession();
        public const int MODE_AUTO = -1;
        public int selectedMode = (int)PuzzleGenerator.Difficulty.EASY;
        public int difficulty = (int)PuzzleGenerator.Difficulty.EASY;
        List<int> modeCycle = new List<int>();
        List<int> autoBag = new List<int>();
        public int selectedTurnLimit = 0;
        public float turnTimeLimit = PuzzleGenerator.NO_TURN_TIME_LIMIT;
        public TurnClock turnClock = new TurnClock();

        public enum AppMode { MENU, STORY, DEBUG }
        public AppMode appMode = AppMode.MENU;
        public StoryRunner story = new StoryRunner();
        public TutorialController tutorial;
        public bool tutorialActive = false;
        float tutorialPromptT = 0f;

        public readonly int[] TURN_CHOICES = new int[]{0,4,5,6,7};
        public int erasureShape = EraserSystem.ErasureShape.DIAGONAL_WEDGE;
        public int erasureCycleId = PuzzleGenerator.SHUFFLED_ERASURE_CYCLE;
        public int inputMode = (int)PuzzleData.InputMode.DRAW_SHAPES;
        public int layerCount = 1;
        public bool solutionRevealed = false;
        public bool pixelFilterEnabled = true;

        public HintDirector hints;
        float statusOverrideTime = 0f;

        [Header("References")]
        public DrawingBoard drawingBoard;
        public InputHandler inputHandler;
        public TargetDisplay targetDisplay;
        public TargetDisplay checkpointDisplay;
        public Text checkpointTitle;
        public TurnTimeline turnTimeline;
        public SolutionStrip solutionStrip;
        public IconButton btnReveal;
        public IconButton btnHint;
        public IconButton btnPixel;
        public IconButton btnDirection;
        public IconButton btnInputMode;
        public IconButton btnLayers;
        public IconButton btnTimer;
        public IconButton btnTutorial;
        public IconButton btnMenu;
        public MainMenu mainMenu;
        public GameObject hud;
        public GameObject controls;
        public Text titleLabel;
        public GameObject pixelFilter;
        public Text labelStatus;
        public Button btnReset;
        public Button btnSkip;
        public Button btnNewPuzzle;
        public IconButton btnMode;
        public IconButton btnEraser;
        public IconButton btnEraserToggle { get => btnEraser; set => btnEraser=value; }
        public IconButton btnTurns;

        void Awake()
        {
            modeCycle = new List<int>{ MODE_AUTO };
            foreach(var tier in PuzzleGenerator.DIFFICULTY_ORDER) modeCycle.Add((int)tier);

            if(btnReset!=null) btnReset.onClick.AddListener(OnResetPressed);
            if(btnSkip!=null) btnSkip.onClick.AddListener(OnSkipPressed);
            if(btnNewPuzzle!=null) btnNewPuzzle.onClick.AddListener(OnNewPuzzlePressed);
            if(btnMode!=null) btnMode.GetComponent<Button>()?.onClick.AddListener(OnModeToggled);
            if(btnEraser!=null) btnEraser.GetComponent<Button>()?.onClick.AddListener(OnEraserToggled);
            if(btnTurns!=null) btnTurns.GetComponent<Button>()?.onClick.AddListener(OnTurnsCycled);
            if(btnReveal!=null) btnReveal.GetComponent<Button>()?.onClick.AddListener(OnRevealToggled);
            if(btnHint!=null) btnHint.GetComponent<Button>()?.onClick.AddListener(OnHintPressed);
            if(btnPixel!=null) btnPixel.GetComponent<Button>()?.onClick.AddListener(OnPixelToggled);
            if(btnDirection!=null) btnDirection.GetComponent<Button>()?.onClick.AddListener(OnDirectionToggled);
            if(btnInputMode!=null) btnInputMode.GetComponent<Button>()?.onClick.AddListener(OnInputModeToggled);
            if(btnLayers!=null) btnLayers.GetComponent<Button>()?.onClick.AddListener(OnLayersCycled);
            if(btnTimer!=null) btnTimer.GetComponent<Button>()?.onClick.AddListener(OnTimerCycled);
            if(btnTutorial!=null) btnTutorial.GetComponent<Button>()?.onClick.AddListener(OnTutorialPressed);
            if(btnMenu!=null) btnMenu.GetComponent<Button>()?.onClick.AddListener(OnMenuPressed);
            if(mainMenu!=null) mainMenu.ModeChosen += OnModeChosen;

            hints = new HintDirector(session);
            session.TurnAdvanced += OnTurnAdvanced;
            session.LayerAdvanced += OnLayerAdvanced;
            session.StageCleared += OnStageCleared;
            session.PuzzleCleared += OnPuzzleCleared;

            if(inputHandler!=null)
            {
                inputHandler.ShapeDrawn += OnShapeDrawn;
                inputHandler.ActivePathChanged += OnActivePathChanged;
            }
            RefreshPixelFilter();
            RefreshSelectorIcons();
            RefreshSelectorAvailability();
            ShowMenu();
        }

        void Update()
        {
            if(session.puzzle==null || appMode==AppMode.MENU) return;
            if(statusOverrideTime>0f){ statusOverrideTime-=Time.deltaTime; if(statusOverrideTime<=0f) RestoreStatusText(); }
            if(session.cleared || session.turn >= session.puzzle.maxTurns) return;
            if(turnClock.Tick(Time.deltaTime)){ OnTurnTimeExpired(); return; }
            if(drawingBoard!=null) drawingBoard.SetClockFraction(turnClock.Fraction());
            if(tutorialActive){ TickTutorial(Time.deltaTime); return; }
            if(hints.Tick(Time.deltaTime)) RaiseHintLamp();
            if(hints.isOffered && btnHint!=null)
            {
                float pulse = hints.Pulse();
                var img = btnHint.GetComponent<Image>();
                if(img!=null) img.color = new Color(1f,1f,1f,pulse);
                btnHint.transform.localScale = Vector3.one*(0.97f+0.05f*pulse);
            }
            // ERASE hover update via mouse
            if(UsesEraseInput() && session.puzzle!=null && !session.cleared && session.erase!=null && !session.erase.IsComplete())
            {
                Vector2 mp = Input.mousePosition;
                // Convert to board position - drawingBoard handles mapping
                // For now use screen position directly
                UpdateZoneHover(mp);
            }
        }

        void UpdateZoneHover(Vector2 pos)
        {
            if(drawingBoard==null) return;
            // Need DrawingBoard.ZoneAtPosition - implement simple mapping if not present, fallback to -1
            int zone = -1;
            try { zone = drawingBoard.ZoneAtPosition(pos); } catch { zone=-1; }
            session.erase.SetHoveredZone(zone);
            drawingBoard.SetHoveredZone(zone, zone>=0 && session.erase.CanSelect(zone));
        }

        void TryPickZone(int zone)
        {
            if(zone<0) return;
            if(!session.CanPickZone(zone)){ FlashStatus(session.RejectionReason(zone), new Color(1f,0.45f,0.4f),1.6f); return; }
            drawingBoard.SetHoveredZone(-1,true);
            session.PickZone(zone);
        }

        void OnInputNodePressed(int id, Vector2 pos){ /* visual handled in DrawingBoard */ }
        void OnInputNodeReleased(int id){}
        void OnInputHoverUpdated(int id){}
        void OnInputPositionUpdated(Vector2 pos,bool dragging){}
        void OnInputPreviewUpdated(Vector2 pos){ if(drawingBoard!=null){ drawingBoard.previewPosition=pos; drawingBoard.isPreviewActive=true; } }
        void OnTurnsCycled(){ int idx = System.Array.IndexOf(TURN_CHOICES, selectedTurnLimit); idx=(idx+1)%TURN_CHOICES.Length; selectedTurnLimit=TURN_CHOICES[idx]; RefreshSelectorIcons(); LoadNewPuzzle(); }
        void OnModeToggled(){ int idx=modeCycle.IndexOf(selectedMode); idx=(idx+1)%modeCycle.Count; selectedMode=modeCycle[idx]; autoBag.Clear(); RefreshSelectorIcons(); LoadNewPuzzle(); }
        bool IsEasyMode()=> PuzzleGenerator.UsesSequenceTree(difficulty);
        bool UsesClock()=> session.puzzle!=null && session.puzzle.turnTimeLimit>0f && !session.cleared;
        void OnTimerCycled(){ int idx=System.Array.IndexOf(PuzzleGenerator.TURN_TIME_CHOICES, turnTimeLimit); idx=(idx+1)%PuzzleGenerator.TURN_TIME_CHOICES.Length; turnTimeLimit=PuzzleGenerator.TURN_TIME_CHOICES[idx]; RefreshSelectorIcons(); LoadNewPuzzle(); }
        void RestartTurnClock(){ turnClock.SetLimit(session.puzzle!=null? session.puzzle.turnTimeLimit:0f); if(UsesClock()) turnClock.Start(); else turnClock.Stop(); if(drawingBoard!=null) drawingBoard.SetClockFraction(turnClock.Fraction()); }
        void OnTurnTimeExpired(){ if(drawingBoard!=null) drawingBoard.FlashClockExpiry(); FlashStatus("OUT OF TIME", new Color(1,0.35f,0.30f),1.2f); if(UsesEraseInput()){ RestartTurnClock(); return; } session.SkipTurn(); }
        bool UsesLayers()=> session.UsesLayers();
        int EffectiveLayerCount()=> UsesEraseInput()? LayerSystem.SINGLE_LAYER : layerCount;
        void OnLayersCycled(){ layerCount = layerCount>=LayerSystem.MAX_LAYERS? LayerSystem.SINGLE_LAYER : layerCount+1; RefreshSelectorIcons(); LoadNewPuzzle(); }
        bool UsesEraseInput()=> inputMode==(int)PuzzleData.InputMode.CHOOSE_ERASURES;
        void OnInputModeToggled(){ inputMode = UsesEraseInput()? (int)PuzzleData.InputMode.DRAW_SHAPES : (int)PuzzleData.InputMode.CHOOSE_ERASURES; RefreshSelectorIcons(); LoadNewPuzzle(); }
        bool IsCycleShuffled()=> erasureCycleId==PuzzleGenerator.SHUFFLED_ERASURE_CYCLE;
        bool IsAutoMode()=> selectedMode==MODE_AUTO;
        int ResolveDifficulty(){ if(!IsAutoMode()) return selectedMode; if(autoBag.Count==0){ foreach(var tier in PuzzleGenerator.DIFFICULTY_ORDER) autoBag.Add((int)tier); Shuffle(autoBag); } int last=autoBag[autoBag.Count-1]; autoBag.RemoveAt(autoBag.Count-1); return last; }
        void OnDirectionToggled(){ if(IsCycleShuffled()) erasureCycleId=0; else if(erasureCycleId>=EraserSystem.CYCLE_COUNT-1) erasureCycleId=PuzzleGenerator.SHUFFLED_ERASURE_CYCLE; else erasureCycleId++; RefreshSelectorIcons(); LoadNewPuzzle(); }
        void OnEraserToggled(){ erasureShape = erasureShape==EraserSystem.ErasureShape.DIAGONAL_WEDGE? EraserSystem.ErasureShape.HALF_PLANE : EraserSystem.ErasureShape.DIAGONAL_WEDGE; RefreshSelectorIcons(); LoadNewPuzzle(); }
        void OnRevealToggled(){ solutionRevealed=!solutionRevealed; RefreshReveal(); }
        void RefreshReveal()
        {
            if(UsesEraseInput())
            {
                if(btnReveal!=null) btnReveal.gameObject.SetActive(true);
                if(solutionStrip!=null) solutionStrip.gameObject.SetActive(true);
                if(solutionStrip!=null) solutionStrip.SetEraseOrder(solutionRevealed? session.puzzle.eraseOrder : new List<int>());
                if(btnReveal!=null) btnReveal.SetIconState(solutionRevealed?1:0);
                return;
            }
            bool easy=IsEasyMode();
            if(btnReveal!=null) btnReveal.gameObject.SetActive(easy);
            if(solutionStrip!=null) solutionStrip.gameObject.SetActive(easy);
            if(solutionStrip!=null) solutionStrip.SetEraseOrder(new List<int>());
            if(!easy) solutionRevealed=false;
            if(btnReveal!=null) btnReveal.SetIconState(solutionRevealed?1:0);
            if(solutionStrip!=null) solutionStrip.SetRevealed(solutionRevealed);
        }
        void RefreshSelectorIcons()
        {
            if(btnMode!=null) btnMode.SetIconState(IsAutoMode()?0: PuzzleGenerator.GetDifficultyRank(selectedMode));
            if(btnTimer!=null) btnTimer.SetIconState(System.Array.IndexOf(PuzzleGenerator.TURN_TIME_CHOICES, turnTimeLimit));
            if(btnLayers!=null){ btnLayers.SetIconState(EffectiveLayerCount()); btnLayers.GetComponent<Button>().interactable=!UsesEraseInput(); }
            if(btnInputMode!=null) btnInputMode.SetIconState(inputMode);
            if(btnDirection!=null) btnDirection.SetIconState(erasureCycleId);
            bool tierDriven=IsEasyMode();
            if(btnTurns!=null){ btnTurns.GetComponent<Button>().interactable=!tierDriven; btnTurns.gameObject.SetActive(!tierDriven); }
            if(btnEraser!=null){ btnEraser.GetComponent<Button>().interactable=!tierDriven; btnEraser.gameObject.SetActive(!tierDriven); }
            if(tierDriven)
            {
                if(btnTurns!=null) btnTurns.SetIconState(0);
                if(btnEraser!=null) btnEraser.SetIconState(EraserSystem.ErasureShape.DIAGONAL_WEDGE);
                return;
            }
            if(btnTurns!=null) btnTurns.SetIconState(selectedTurnLimit);
            if(btnEraser!=null) btnEraser.SetIconState(erasureShape);
        }

        public void LoadNewPuzzle()
        {
            difficulty=ResolveDifficulty();
            int boardCycle = IsCycleShuffled()? EraserSystem.CYCLE_CLOCKWISE : erasureCycleId;
            var boardDef=new BoardDefinition(8, new Vector2(64,64), 0, erasureShape, boardCycle);
            int reqShapes = IsEasyMode()? 2:3;
            PuzzleData puzzle;
            if(EffectiveLayerCount()> LayerSystem.SINGLE_LAYER)
                puzzle = PuzzleGenerator.GenerateLayeredPuzzle(boardDef,difficulty,EffectiveLayerCount(),200,inputMode,turnTimeLimit);
            else
                puzzle = PuzzleGenerator.GeneratePuzzle(boardDef,selectedTurnLimit,reqShapes,difficulty,400,erasureCycleId,inputMode,turnTimeLimit);
            session.Setup(puzzle);
            hints.session=session;
            if(drawingBoard!=null){ drawingBoard.SetBoardDefinition(session.puzzle.boardDefinition); drawingBoard.layerCount=session.puzzle.layerCount; drawingBoard.activeLayer=0; drawingBoard.SetCleared(false); }
            if(inputHandler!=null) inputHandler.Setup(session.puzzle.boardDefinition, drawingBoard!=null? drawingBoard.nodeScreenPositions: new List<Vector2>());
            if(turnTimeline!=null){ turnTimeline.Setup(session.puzzle.boardDefinition, session.puzzle.maxTurns); turnTimeline.SetShapeMode(UsesEraseInput(), session.puzzle.referenceSolution); turnTimeline.SetCommittedZones(new List<int>()); }
            solutionRevealed=false;
            if(inputHandler!=null) inputHandler.SetEnabled(!UsesEraseInput());
            if(drawingBoard!=null) drawingBoard.SetZonePicking(UsesEraseInput());
            if(solutionStrip!=null){ solutionStrip.SetSolution(session.puzzle.referenceSolution, session.puzzle.boardDefinition); solutionStrip.SetLayeredSolution(UsesLayers()? session.puzzle.layeredSolution:null, session.puzzle.layerCount); }
            RefreshReveal(); RefreshSelectorIcons();
            if(checkpointDisplay!=null) checkpointDisplay.gameObject.SetActive(false);
            WithdrawHint(); RestartTurnClock(); RefreshStageTargets(); UpdateUI();
        }

        void RefreshStageTargets()
        {
            if(targetDisplay!=null)
            {
                targetDisplay.SetTarget(session.puzzle.GetStageTarget(session.stage), session.puzzle.boardDefinition);
                var layerTargets = UsesLayers()? session.puzzle.GetLayerStageTargets(session.stage) : new List<VectorGeometry>();
                targetDisplay.SetLayerTargets(layerTargets, session.puzzle.layerCount);
                targetDisplay.SetMatched(false);
            }
            RefreshStageLabel();
        }

        void RefreshStageLabel()
        {
            if(session.cleared || labelStatus==null) return;
            var parts=new List<string>();
            if(session.puzzle.IsMultiStage()) parts.Add($"STEP {session.stage+1} / {session.puzzle.GetStageCount()}");
            if(UsesLayers() && session.turn < session.puzzle.maxTurns) parts.Add($"PAINT {LayerSystem.GetLayerName(session.activeLayer)}");
            if(parts.Count==0) return;
            labelStatus.text = string.Join("  -  ", parts);
            labelStatus.color = UsesLayers()? LayerSystem.GetLayerColor(session.activeLayer, session.puzzle.layerCount) : new Color(0.4f,0.7f,1f);
        }

        void OnShapeDrawn(List<int> nodeIds)
        {
            if(session.cleared || session.turn>=session.puzzle.maxTurns) return;
            var shapeInst = ShapeDatabase.CreateInstanceFromPath(nodeIds, session.puzzle.boardDefinition);
            if(shapeInst==null) return;
            if(tutorialActive && !tutorial.Accepts(nodeIds, session.turn)){ tutorialPromptT=0f; return; }
            if(drawingBoard!=null) drawingBoard.TriggerCommitFlash(nodeIds);
            session.CommitShape(shapeInst);
        }

        void OnSkipPressed()
        {
            if(session.cleared) return;
            if(tutorialActive && !tutorial.IsSkipTurn(session.turn)) return;
            if(UsesEraseInput()){ UndoLastPick(); return; }
            session.SkipTurn();
        }

        void UndoLastPick()
        {
            if(!session.UndoPick()) return;
            if(drawingBoard!=null) drawingBoard.pickedZones = new List<int>(session.erase.solution.zones);
            if(checkpointDisplay!=null) checkpointDisplay.gameObject.SetActive(false);
            WithdrawHint(); RefreshStageTargets(); UpdateUI();
        }

        void OnLayerAdvanced(int layer){ if(drawingBoard!=null) drawingBoard.activeLayer=layer; UpdateUI(); }
        void OnTurnAdvanced(int t){ WithdrawHint(); RestartTurnClock(); if(drawingBoard!=null) drawingBoard.activeLayer=session.activeLayer; if(UsesEraseInput() && drawingBoard!=null) drawingBoard.pickedZones=new List<int>(session.erase.solution.zones); UpdateUI(); if(UsesEraseInput() && !session.cleared && !session.TurnsRemain()) FlashStatus("NOT THE GOAL -- UNDO A PICK OR RESET", new Color(1,0.6f,0.35f),3f); }
        void OnPuzzleCleared()
        {
            if(tutorialActive){ tutorialActive=false; tutorial=null; RefreshSelectorAvailability(); }
            if(appMode==AppMode.STORY) story.MarkCleared();
            if(labelStatus!=null){ labelStatus.text="★ SOLVED ★"; labelStatus.color=new Color(0.2f,0.95f,0.5f); }
            if(drawingBoard!=null){ drawingBoard.SetCleared(true); drawingBoard.SetErasurePhases(drawingBoard.appliedErasurePhase,-1); }
            if(targetDisplay!=null) targetDisplay.SetMatched(true);
        }

        void OnStageCleared(int finishedStage)
        {
            if(targetDisplay!=null){ targetDisplay.SetMatched(true); targetDisplay.StartFadeOut(); targetDisplay.FadeOutFinished += AdvanceStage; }
            if(checkpointDisplay!=null && checkpointTitle!=null)
            {
                checkpointTitle.text = $"STEP {finishedStage+1}";
                checkpointDisplay.SetTarget(session.puzzle.GetStageTarget(finishedStage), session.puzzle.boardDefinition);
                var lt = UsesLayers()? session.puzzle.GetLayerStageTargets(finishedStage) : new List<VectorGeometry>();
                checkpointDisplay.SetLayerTargets(lt, session.puzzle.layerCount);
                checkpointDisplay.SetMatched(true);
                checkpointDisplay.gameObject.SetActive(true);
                checkpointDisplay.StartFadeOut();
                checkpointDisplay.FadeOutFinished += OnCheckpointFaded;
            }
            FlashStatus($"STEP {finishedStage+1} COMPLETE", new Color(0.2f,0.95f,0.5f),1.2f);
        }

        void OnCheckpointFaded(){ if(checkpointDisplay!=null) checkpointDisplay.gameObject.SetActive(false); }
        void AdvanceStage(){ session.AdvanceStage(); RefreshStageTargets(); UpdateUI(); }

        void OnResetPressed()
        {
            if(session.erase!=null){ session.erase.Reset(); if(drawingBoard!=null) drawingBoard.pickedZones=new List<int>(); }
            session.solution=new PuzzleSolution(session.puzzle.maxTurns);
            session.layered=new LayeredSolution(Mathf.Max(1,session.puzzle.layerCount), session.puzzle.maxTurns);
            session.activeLayer=0; if(drawingBoard!=null) drawingBoard.activeLayer=0;
            session.turn=0; session.stage=0; session.cleared=false;
            RestartTurnClock();
            if(drawingBoard!=null) drawingBoard.SetCleared(false);
            if(checkpointDisplay!=null) checkpointDisplay.gameObject.SetActive(false);
            WithdrawHint(); RefreshStageTargets(); UpdateUI();
        }

        void OnNewPuzzlePressed()
        {
            if(appMode==AppMode.STORY)
            {
                if(story.taskCleared) AdvanceStoryTask();
                else StartStoryTask();
                return;
            }
            LoadNewPuzzle();
        }

        void OnActivePathChanged(List<int> nodes){ if(drawingBoard!=null) drawingBoard.SetActiveSwipe(nodes); }

        void UpdateUI()
        {
            var board = session.ActiveBoard();
            bool turnsRemain = session.TurnsRemain();
            if(turnTimeline!=null){ turnTimeline.SetProgress(session.turn, session.DrawnTurnFlags()); turnTimeline.SetCommittedZones(UsesEraseInput()? session.erase.solution.zones : new List<int>()); }
            int lastResolved = session.LastResolvedTurn();
            int applied = -1;
            if(lastResolved>=0) applied=EraserSystem.GetPhaseForTurn(lastResolved, board);
            int upcoming=-1;
            if(turnsRemain && !session.cleared && !UsesEraseInput()) upcoming=EraserSystem.GetPhaseForTurn(session.turn, board);
            if(UsesLayers())
            {
                if(drawingBoard!=null)
                {
                    drawingBoard.layerGeometry = session.LayerGeometry();
                    bool showingNext = turnsRemain && !session.cleared;
                    drawingBoard.layerAppliedPhases = session.LayerPhases(lastResolved);
                    drawingBoard.layerUpcomingPhases = showingNext? session.LayerPhases(session.turn) : session.LayerPhases(-1);
                }
            }
            else
            {
                if(drawingBoard!=null){ drawingBoard.SetSurvivingGeometry(session.SurvivingGeometry()); drawingBoard.SetErasurePhases(applied, upcoming); }
            }
            if(btnSkip!=null)
            {
                var txt = btnSkip.GetComponentInChildren<Text>();
                if(txt!=null) txt.text = UsesEraseInput()? "UNDO PICK" : "SKIP TURN";
                btnSkip.interactable = UsesEraseInput()? (!session.cleared && session.turn>0) : (!session.cleared && turnsRemain);
            }
            if(!session.cleared && statusOverrideTime<=0f && labelStatus!=null)
            {
                labelStatus.text="";
                labelStatus.color=Color.white;
                RefreshStageLabel();
            }
        }

        void OnLoopClosedChanged(bool closed){ /* handled in DrawingBoard */ }
        void OnPixelToggled(){ pixelFilterEnabled=!pixelFilterEnabled; RefreshPixelFilter(); }
        void RefreshPixelFilter(){ if(pixelFilter!=null) pixelFilter.SetActive(pixelFilterEnabled); if(btnPixel!=null) btnPixel.SetIconState(pixelFilterEnabled?1:0); }

        void ShowMenu()
        {
            appMode=AppMode.MENU;
            if(mainMenu!=null){ mainMenu.gameObject.SetActive(true); mainMenu.SetStoryProgress(story.taskIndex); }
            if(hud!=null) hud.SetActive(false);
            if(controls!=null) controls.SetActive(false);
            if(drawingBoard!=null) drawingBoard.gameObject.SetActive(false);
            if(inputHandler!=null) inputHandler.SetEnabled(false);
        }

        void OnMenuPressed()
        {
            if(tutorialActive){ tutorialActive=false; tutorial=null; }
            ShowMenu();
        }

        void OnModeChosen(bool startStory)
        {
            appMode = startStory? AppMode.STORY : AppMode.DEBUG;
            if(mainMenu!=null) mainMenu.gameObject.SetActive(false);
            if(hud!=null) hud.SetActive(true);
            if(controls!=null) controls.SetActive(true);
            if(drawingBoard!=null) drawingBoard.gameObject.SetActive(true);
            if(appMode==AppMode.STORY){ story.RestartIfFinished(); StartStoryTask(); }
            else{ if(titleLabel!=null) titleLabel.text=""; RefreshSelectorAvailability(); LoadNewPuzzle(); }
        }

        void StartStoryTask()
        {
            story.BeginTask();
            var config=story.CurrentConfig();
            difficulty=(int)config["difficulty"];
            erasureCycleId=(int)config["cycle"];
            inputMode=(int)config["input_mode"];
            layerCount=(int)config["layers"];
            turnTimeLimit=(float)config["clock"];
            selectedMode=difficulty;
            if(titleLabel!=null) titleLabel.text=story.ProgressLabel();
            if(story.IsTutorialTask()){ StartTutorial(); return; }
            RefreshSelectorAvailability(); LoadNewPuzzle();
        }

        void AdvanceStoryTask()
        {
            story.Advance();
            if(story.IsFinished()){ if(titleLabel!=null) titleLabel.text="STORY COMPLETE"; FlashStatus("★ STORY COMPLETE ★", new Color(0.2f,0.95f,0.5f),4f); return; }
            StartStoryTask();
        }

        void OnTutorialPressed(){ if(tutorialActive) EndTutorial(); else StartTutorial(); }

        void StartTutorial()
        {
            tutorial=new TutorialController();
            var lessonPuzzle=tutorial.BuildPuzzle();
            if(lessonPuzzle==null) return;
            tutorialActive=true; tutorialPromptT=0f;
            session.Setup(lessonPuzzle);
            hints.session=session;
            if(drawingBoard!=null){ drawingBoard.SetBoardDefinition(session.puzzle.boardDefinition); drawingBoard.layerCount=1; drawingBoard.activeLayer=0; drawingBoard.SetCleared(false); }
            if(inputHandler!=null) inputHandler.Setup(session.puzzle.boardDefinition, drawingBoard!=null? drawingBoard.nodeScreenPositions: new List<Vector2>());
            if(inputHandler!=null) inputHandler.SetEnabled(true);
            if(turnTimeline!=null){ turnTimeline.Setup(session.puzzle.boardDefinition, session.puzzle.maxTurns); turnTimeline.SetShapeMode(false,null); turnTimeline.SetCommittedZones(new List<int>()); }
            solutionRevealed=false;
            if(solutionStrip!=null){ solutionStrip.SetSolution(session.puzzle.referenceSolution, session.puzzle.boardDefinition); solutionStrip.SetLayeredSolution(null,1); solutionStrip.SetEraseOrder(new List<int>()); solutionStrip.gameObject.SetActive(false); }
            if(btnReveal!=null) btnReveal.gameObject.SetActive(false);
            if(checkpointDisplay!=null) checkpointDisplay.gameObject.SetActive(false);
            WithdrawHint(); RestartTurnClock(); RefreshSelectorAvailability(); RefreshStageTargets(); UpdateUI();
        }

        void EndTutorial(){ tutorialActive=false; tutorial=null; RefreshSelectorAvailability(); LoadNewPuzzle(); }
        void RefreshSelectorAvailability()
        {
            if(btnTutorial!=null) btnTutorial.SetIconState(tutorialActive?1:0);
            bool locked = tutorialActive || appMode==AppMode.STORY;
            var buttons = new IconButton[]{ btnMode, btnTurns, btnEraser, btnDirection, btnInputMode, btnLayers, btnTimer };
            foreach(var b in buttons) if(b!=null) b.GetComponent<Button>().interactable=!locked;
            if(btnTutorial!=null) btnTutorial.GetComponent<Button>().interactable= appMode!=AppMode.STORY;
            if(btnNewPuzzle!=null)
            {
                var txt=btnNewPuzzle.GetComponentInChildren<Text>();
                if(txt!=null) txt.text = (appMode==AppMode.STORY && story.taskCleared)? "NEXT" : "NEW PUZZLE";
                btnNewPuzzle.interactable=!tutorialActive;
            }
        }

        void TickTutorial(float delta)
        {
            tutorialPromptT+=delta;
            if(session.turn >= session.puzzle.maxTurns) return;
            if(tutorial.IsSkipTurn(session.turn))
            {
                if(tutorialPromptT>=1.1f){ tutorialPromptT=0f; /* pulse skip button */ }
                return;
            }
            // Show hint ghost if not showing
            if(drawingBoard!=null)
            {
                // Check if hint showing via drawingBoard internal
                // For simplicity, show ghost
                drawingBoard.ShowHint(tutorial.ExpectedPath(session.turn));
            }
        }

        void RaiseHintLamp()
        {
            if(btnHint!=null)
            {
                btnHint.gameObject.SetActive(true);
                btnHint.SetIconState(1);
            }
        }
        void WithdrawHint(){ hints.Withdraw(); if(btnHint!=null){ btnHint.gameObject.SetActive(false); btnHint.SetIconState(0); btnHint.transform.localScale=Vector3.one; var img=btnHint.GetComponent<Image>(); if(img!=null) img.color=Color.white; } }
        void OnHintPressed()
        {
            var hint = hints.Request();
            var kind = (HintDirector.Kind)hint["kind"];
            switch(kind)
            {
                case HintDirector.Kind.DRAW_PATH:
                    var path=(List<int>)hint["path"];
                    if(drawingBoard!=null) drawingBoard.ShowHint(path);
                    FlashStatus(UsesLayers()?$"HINT: DRAW THIS IN {LayerSystem.GetLayerName((int)hint["layer"])}":"HINT: DRAW THIS", new Color(1,0.85f,0.35f),2f);
                    break;
                case HintDirector.Kind.SKIP_TURN:
                    FlashStatus("HINT: SKIP THIS TURN", new Color(1,0.85f,0.35f),3f);
                    break;
                case HintDirector.Kind.ERASE_ZONE:
                    int zone=(int)hint["zone"];
                    if(drawingBoard!=null) drawingBoard.SetHoveredZone(zone,true);
                    FlashStatus($"HINT: ERASE {EraserSystem.GetRegionName(zone)} NEXT", new Color(1,0.85f,0.35f),2.5f);
                    break;
                case HintDirector.Kind.SCHEDULE_DONE:
                    FlashStatus("HINT: NOTHING LEFT TO SCHEDULE", new Color(1,0.85f,0.35f),2f);
                    break;
                case HintDirector.Kind.OFF_PLAN:
                    string msg = UsesEraseInput()? "THIS SCHEDULE HAS LEFT THE ONE I KNOW -- UNDO OR RESET" : "THIS LINE CAN'T REACH THE GOAL -- RESET";
                    FlashStatus($"HINT: {msg}", new Color(1,0.6f,0.35f),3f);
                    break;
            }
            WithdrawHint();
        }

        void FlashStatus(string text, Color color, float hold)
        {
            if(labelStatus!=null){ labelStatus.text=text; labelStatus.color=color; }
            statusOverrideTime=hold;
        }
        void RestoreStatusText(){ if(session.cleared) return; if(labelStatus!=null){ labelStatus.text=""; labelStatus.color=Color.white; RefreshStageLabel(); } }
        void Shuffle<T>(List<T> list){ var rng=new System.Random(); for(int i=list.Count-1;i>0;i--){ int j=rng.Next(i+1); T tmp=list[i]; list[i]=list[j]; list[j]=tmp; } }

        // Input for ERASE mode - handle clicks via Unity's Input
        void OnGUI()
        {
            if(!UsesEraseInput()||session.puzzle==null||session.cleared|| session.erase==null||session.erase.IsComplete()) return;
            Event e = Event.current;
            if(e!=null && e.type==EventType.MouseDown && e.button==0)
            {
                Vector2 pos = e.mousePosition;
                pos.y = Screen.height - pos.y; // convert
                int zone = -1;
                try{ zone=drawingBoard.ZoneAtPosition(pos); }catch{}
                TryPickZone(zone); e.Use();
            }
        }
    }
}
