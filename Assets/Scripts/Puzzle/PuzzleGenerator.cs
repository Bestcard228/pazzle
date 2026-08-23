using System;
using System.Collections.Generic;
using System.Linq;
using UnityEngine;
using PuzzleGame.Board;
using PuzzleGame.Core;
using PuzzleGame.Shapes;

namespace PuzzleGame.Puzzle
{
    public static class PuzzleGenerator
    {
        public static readonly float[] TURN_TIME_CHOICES = new float[]{0f,12f,6f,4f};
        public const float NO_TURN_TIME_LIMIT = 0f;
        public const int SHUFFLED_ERASURE_CYCLE = -1;
        public const int DEFAULT_ERASURE_CYCLE = SHUFFLED_ERASURE_CYCLE;
        public const int DEFAULT_MIN_TURNS = 4;
        public const int DEFAULT_MAX_TURNS = 7;

        public enum Difficulty { NORMAL=0, EASY=1, EASY_PLUS=2, EASY_PLUS_PLUS=3, MEDIUM=4 }
        public static readonly Difficulty[] DIFFICULTY_ORDER = new Difficulty[]{ Difficulty.EASY, Difficulty.EASY_PLUS, Difficulty.EASY_PLUS_PLUS, Difficulty.MEDIUM };

        public static bool UsesSequenceTree(int d) => d != (int)Difficulty.NORMAL;
        public static bool IsMultiStage(int d) => d == (int)Difficulty.MEDIUM;
        public static bool UsesSimpleShapes(int d) => d == (int)Difficulty.EASY || d == (int)Difficulty.EASY_PLUS;
        public static bool UsesFixedOpening(int d) => d == (int)Difficulty.EASY;
        public static int GetDifficultyRank(int d) { int r = Array.IndexOf(DIFFICULTY_ORDER, (Difficulty)d); return r >=0 ? r+1 : DIFFICULTY_ORDER.Length; }
        public static string GetDifficultyName(int d) { switch((Difficulty)d){ case Difficulty.EASY: return "Easy"; case Difficulty.EASY_PLUS: return "Easy+"; case Difficulty.EASY_PLUS_PLUS: return "Easy++"; case Difficulty.MEDIUM: return "Medium"; default: return "Normal"; } }

        public const int EASY_PATTERN_DEPTH = 3;
        public const int EASY_MIN_TURNS = 3;
        public const int EASY_MAX_TURNS = 4;
        public static readonly int[][] EASY_PATTERNS = new int[][] { new int[]{1,0,1}, new int[]{1,1,0}, new int[]{1,1,1} };
        public static readonly int[][] EASY_PREFIXES = new int[][] { new int[]{}, new int[]{0} };
        public const int MEDIUM_CHAIN_LENGTH = 2;

        static List<int> _zoneBag = new List<int>();
        static int _lastFinalZone = -1;
        static bool _preferEarlyFinish = false;
        static List<List<int>> _easySequenceBag = new List<List<int>>();
        static List<List<int>> _mediumSequenceBag = new List<List<int>>();
        static List<int> _cycleBag = new List<int>();

        public static List<List<int>> GetEasySequences()
        {
            var seqs = new List<List<int>>();
            foreach(var prefix in EASY_PREFIXES)
                foreach(var pattern in EASY_PATTERNS)
                {
                    var s = new List<int>();
                    s.AddRange(prefix);
                    s.AddRange(pattern);
                    seqs.Add(s);
                }
            return seqs;
        }

        public static List<List<int>> GetMediumSequences(int chainLength = MEDIUM_CHAIN_LENGTH)
        {
            var continuable = new List<int[]>();
            foreach(var p in EASY_PATTERNS) if(p[p.Length-1]==1) continuable.Add(p);
            var seqs = new List<List<int>>();
            foreach(var prefix in EASY_PREFIXES)
            {
                var baseSeq = new List<int>(prefix);
                ExtendMediumChains(baseSeq,0,chainLength,continuable,seqs);
            }
            return seqs;
        }

        static void ExtendMediumChains(List<int> sequence, int depth, int chainLength, List<int[]> continuable, List<List<int>> o)
        {
            if(depth>=chainLength){ o.Add(new List<int>(sequence)); return; }
            bool isLast = depth==chainLength-1;
            var choices = isLast ? new List<int[]>(EASY_PATTERNS) : continuable;
            foreach(var pattern in choices)
            {
                var next = new List<int>(sequence);
                int from = depth==0?0:1;
                for(int i=from;i<pattern.Length;i++) next.Add(pattern[i]);
                ExtendMediumChains(next,depth+1,chainLength,continuable,o);
            }
        }

        public static List<List<int>> GetSequencesFor(int difficulty, int chainLength=MEDIUM_CHAIN_LENGTH)
        {
            if(IsMultiStage(difficulty)) return GetMediumSequences(chainLength);
            return GetEasySequences();
        }

        public static List<int> GetStageBoundaryTurns(List<int> sequence, int chainLength=MEDIUM_CHAIN_LENGTH)
        {
            var boundaries = new List<int>();
            if(sequence==null||sequence.Count==0||chainLength<=0) return boundaries;
            int last = sequence.Count-1;
            for(int i=0;i<chainLength;i++){ int b = last - 2*(chainLength-1-i); if(b>=0) boundaries.Add(b); }
            return boundaries;
        }

        static List<int> TakeNextSequence(int difficulty, int chainLength=MEDIUM_CHAIN_LENGTH)
        {
            var bag = IsMultiStage(difficulty)? _mediumSequenceBag : _easySequenceBag;
            if(bag.Count==0){ bag.AddRange(GetSequencesFor(difficulty,chainLength)); Shuffle(bag); }
            var nxt = bag[0]; bag.RemoveAt(0); return nxt;
        }

        public static PuzzleData GeneratePuzzle(BoardDefinition boardDef=null, int maxTurns=0, int requiredShapeCount=2, int difficulty=(int)Difficulty.NORMAL, int maxAttempts=400, int erasureCycleId=DEFAULT_ERASURE_CYCLE, int inputMode=(int)PuzzleData.InputMode.DRAW_SHAPES, float turnTimeLimit=NO_TURN_TIME_LIMIT)
        {
            bool isEasy = UsesSequenceTree(difficulty);
            bool isErase = inputMode==(int)PuzzleData.InputMode.CHOOSE_ERASURES;
            if(boardDef==null) boardDef=new BoardDefinition(8);
            var rng = new System.Random();
            bool turnsWereRequested = maxTurns>0;
            if(turnsWereRequested) maxTurns=Mathf.Clamp(maxTurns,3,DEFAULT_MAX_TURNS);
            var puzzleBoard = boardDef.Duplicate();
            int eraserShape = isEasy ? EraserSystem.ErasureShape.DIAGONAL_WEDGE : puzzleBoard.erasureShape;
            puzzleBoard.erasureCycleId = ResolveErasureCycle(erasureCycleId, eraserShape);
            int finalZone;
            List<int> easySequence = new List<int>();
            if(isEasy)
            {
                puzzleBoard.erasureShape = EraserSystem.ErasureShape.DIAGONAL_WEDGE;
                easySequence = TakeNextSequence(difficulty);
                maxTurns = easySequence.Count;
                if(UsesFixedOpening(difficulty))
                {
                    puzzleBoard.erasureStartPhase = (int)EraserSystem.ErasureRegion.TOP;
                    finalZone = EraserSystem.GetFinalPhase(maxTurns, puzzleBoard);
                }
                else
                {
                    finalZone = TakeNextFinalZone(rng);
                    puzzleBoard.erasureStartPhase = EraserSystem.StartPhaseForFinal(finalZone, maxTurns, puzzleBoard.erasureCycleId);
                }
            }
            else
            {
                if(!turnsWereRequested) maxTurns = rng.Next(DEFAULT_MIN_TURNS, DEFAULT_MAX_TURNS+1);
                finalZone = TakeNextFinalZone(rng);
                puzzleBoard.erasureStartPhase = EraserSystem.StartPhaseForFinal(finalZone, maxTurns, puzzleBoard.erasureCycleId);
            }

            var candidates = GenerateCandidatePool(puzzleBoard,difficulty);
            if(candidates.Count==0) return CreateFallbackPuzzle(puzzleBoard,maxTurns,finalZone,difficulty,inputMode);
            var survivable = PuzzleSimulator.GetSurvivableTurns(puzzleBoard,maxTurns);
            if(survivable.Count==0) return CreateFallbackPuzzle(puzzleBoard,maxTurns,finalZone,difficulty,inputMode);
            int shapeCount = Mathf.Clamp(requiredShapeCount,1,survivable.Count);
            int lastTurn = maxTurns-1;
            bool preferEarly = TakeNextEarlyFinishPreference();

            for(int attempt=0; attempt<maxAttempts; attempt++)
            {
                var sol = new PuzzleSolution(maxTurns);
                int activeShapeCount = shapeCount;
                if(isEasy)
                {
                    var drawTurns = GetEasyDrawTurns(easySequence);
                    foreach(var turn in drawTurns)
                    {
                        var shape = candidates[rng.Next(candidates.Count)];
                        sol.SetAction(turn, shape);
                    }
                    activeShapeCount = drawTurns.Count;
                }
                else
                {
                    bool enforceEarly = preferEarly && attempt < maxAttempts*3/4;
                    var pool = new List<int>(survivable);
                    if(enforceEarly) pool.Remove(lastTurn);
                    if(pool.Count < shapeCount) continue;
                    Shuffle(pool, rng);
                    var turnsToUse = pool.Take(shapeCount).ToList();
                    foreach(var t in turnsToUse) sol.SetAction(t, candidates[rng.Next(candidates.Count)]);
                }

                var target = PuzzleSimulator.Simulate(sol, puzzleBoard);
                if(target.IsEmpty() || target.segments.Count < 2) continue;

                if(IsMultiStage(difficulty))
                {
                    var boundaries = GetStageBoundaryTurns(easySequence);
                    if(boundaries.Count==0) continue;
                    bool stagesOk=true;
                    VectorGeometry prev=null;
                    int from=0;
                    foreach(var b in boundaries)
                    {
                        if(!PuzzleValidator.ValidateStageContributions(sol,puzzleBoard,from,b)){ stagesOk=false; break; }
                        var stageState = PuzzleSimulator.SimulateUpToTurn(sol,puzzleBoard,b);
                        if(stageState.segments.Count<2){ stagesOk=false; break; }
                        if(prev!=null && stageState.IsEquivalentTo(prev)){ stagesOk=false; break; }
                        prev=stageState; from=b+1;
                    }
                    if(!stagesOk) continue;
                }
                else if(!PuzzleValidator.ValidateNecessaryContributions(sol,target,puzzleBoard)) continue;

                if(!PuzzleValidator.ValidateNotCompletableOnFirstTurn(sol,target,puzzleBoard,candidates)) continue;
                if(activeShapeCount>=2 && !PuzzleValidator.ValidateNotLastTurnOnly(sol,target,puzzleBoard)) continue;
                if(!IsMultiStage(difficulty) && !PuzzleValidator.ValidateMultiTurnTiming(sol,target,puzzleBoard)) continue;
                if(!isEasy && !PuzzleValidator.ValidateSpansMultipleQuadrants(target,puzzleBoard)) continue;
                if(!PuzzleValidator.ValidateNotSolvableInOneTurn(target,puzzleBoard,candidates,maxTurns,survivable)) continue;
                if(isErase && !PuzzleValidator.ValidateEraseChoiceMatters(sol,puzzleBoard,target,maxTurns)) continue;

                var pData = BuildPuzzleData(puzzleBoard,target,maxTurns,activeShapeCount,sol,finalZone);
                pData.inputMode=inputMode;
                pData.turnTimeLimit=turnTimeLimit;
                pData.eraseOrder=GetEraseOrder(puzzleBoard,maxTurns);
                if(IsMultiStage(difficulty))
                {
                    pData.stageBoundaryTurns = GetStageBoundaryTurns(easySequence);
                    var stageTargets = new List<VectorGeometry>();
                    foreach(var b in pData.stageBoundaryTurns) stageTargets.Add(PuzzleSimulator.SimulateUpToTurn(sol,puzzleBoard,b));
                    pData.stageTargets=stageTargets;
                }
                return pData;
            }
            return CreateFallbackPuzzle(puzzleBoard,maxTurns,finalZone,difficulty,inputMode);
        }

        public static List<int> GetEraseOrder(BoardDefinition boardDef, int maxTurns)
        {
            var order=new List<int>();
            for(int t=0;t<maxTurns;t++) order.Add(EraserSystem.GetPhaseForTurn(t,boardDef));
            return order;
        }

        public static List<int> GetEasyDrawTurns(List<int> sequence)
        {
            var draw=new List<int>();
            for(int i=0;i<sequence.Count;i++) if(sequence[i]==1) draw.Add(i);
            return draw;
        }

        static int ResolveErasureCycle(int requested,int shape)
        {
            if(requested!=SHUFFLED_ERASURE_CYCLE)
            {
                int wanted = ((requested % EraserSystem.CYCLE_COUNT)+EraserSystem.CYCLE_COUNT)%EraserSystem.CYCLE_COUNT;
                if(EraserSystem.IsCycleUsable(wanted,shape)) return wanted;
            }
            return TakeNextErasureCycle(shape);
        }

        static int TakeNextErasureCycle(int shape)
        {
            var usable = EraserSystem.GetUsableCycles(shape);
            if(usable.Count==0) return EraserSystem.CYCLE_CLOCKWISE;
            var nextBag = new List<int>();
            foreach(var c in _cycleBag) if(usable.Contains(c)) nextBag.Add(c);
            _cycleBag=nextBag;
            if(_cycleBag.Count==0){ _cycleBag=new List<int>(usable); Shuffle(_cycleBag); }
            int last=_cycleBag[_cycleBag.Count-1]; _cycleBag.RemoveAt(_cycleBag.Count-1); return last;
        }

        static int TakeNextFinalZone(System.Random rng)
        {
            if(_zoneBag.Count==0)
            {
                _zoneBag=new List<int>{0,1,2,3};
                Shuffle(_zoneBag,rng);
                if(_zoneBag.Count>1 && _zoneBag[0]==_lastFinalZone){ int f=_zoneBag[0]; _zoneBag.RemoveAt(0); _zoneBag.Add(f); }
            }
            int zone=_zoneBag[0]; _zoneBag.RemoveAt(0); _lastFinalZone=zone; return zone;
        }

        static bool TakeNextEarlyFinishPreference(){ _preferEarlyFinish=!_preferEarlyFinish; return _preferEarlyFinish; }

        public static void ResetZoneRotation(){ _zoneBag.Clear(); _lastFinalZone=-1; _preferEarlyFinish=false; _easySequenceBag.Clear(); _mediumSequenceBag.Clear(); }

        static PuzzleData BuildPuzzleData(BoardDefinition boardDef, VectorGeometry target, int maxTurns, int shapeCount, PuzzleSolution sol, int finalZone)
        {
            var p=new PuzzleData(boardDef,target,maxTurns);
            p.requiredShapeCount=shapeCount;
            p.referenceSolution=sol;
            p.finalErasureZone=finalZone;
            p.completionTurn=PuzzleSimulator.GetCompletionTurn(sol,boardDef,target);
            p.difficultyRating=shapeCount*1.5f+maxTurns*0.8f;
            return p;
        }

        public static List<ShapeInstance> GenerateCandidatePool(BoardDefinition boardDef, int difficulty=(int)Difficulty.NORMAL)
        {
            if(UsesSimpleShapes(difficulty)) return GenerateEasyCandidatePool(boardDef);
            var pool=new List<ShapeInstance>();
            int N=boardDef.nodeCount;
            var circPath=new List<int>();
            for(int i=0;i<N;i++) circPath.Add(i);
            circPath.Add(0);
            var cInst=ShapeDatabase.CreateInstanceFromPath(circPath,boardDef);
            if(cInst!=null) pool.Add(cInst);
            for(int i=0;i<N;i++)
            {
                var t1=new List<int>{i,(i+2)%N,(i+5)%N,i}; var s1=ShapeDatabase.CreateInstanceFromPath(t1,boardDef); if(s1!=null) pool.Add(s1);
                var t2=new List<int>{i,(i+3)%N,(i+6)%N,i}; var s2=ShapeDatabase.CreateInstanceFromPath(t2,boardDef); if(s2!=null) pool.Add(s2);
                var t3=new List<int>{i,(i+2)%N,(i+4)%N,i}; var s3=ShapeDatabase.CreateInstanceFromPath(t3,boardDef); if(s3!=null) pool.Add(s3);
                var sq1=new List<int>{i,(i+2)%N,(i+4)%N,(i+6)%N,i}; var sq=ShapeDatabase.CreateInstanceFromPath(sq1,boardDef); if(sq!=null) pool.Add(sq);
                var l1=new List<int>{i,(i+4)%N}; var ll1=ShapeDatabase.CreateInstanceFromPath(l1,boardDef); if(ll1!=null) pool.Add(ll1);
                var l2=new List<int>{i,(i+3)%N}; var ll2=ShapeDatabase.CreateInstanceFromPath(l2,boardDef); if(ll2!=null) pool.Add(ll2);
            }
            return pool;
        }

        static List<ShapeInstance> GenerateEasyCandidatePool(BoardDefinition boardDef)
        {
            var pool=new List<ShapeInstance>();
            foreach(var d in ShapeDatabase.GetEasyModePredefinedShapes(boardDef)){ var inst=(ShapeInstance)d["instance"]; if(inst!=null) pool.Add(inst); }
            return pool;
        }

        static PuzzleData CreateFallbackPuzzle(BoardDefinition boardDef,int maxTurns,int finalZone,int difficulty=(int)Difficulty.NORMAL,int inputMode=(int)PuzzleData.InputMode.DRAW_SHAPES)
        {
            var sol=new PuzzleSolution(maxTurns);
            var candidates=GenerateCandidatePool(boardDef,difficulty);
            var survivable=PuzzleSimulator.GetSurvivableTurns(boardDef,maxTurns);
            if(UsesSequenceTree(difficulty))
            {
                var seq=GetSequencesFor(difficulty)[0];
                int idx=0;
                foreach(var turn in GetEasyDrawTurns(seq)){ if(turn>=maxTurns||candidates.Count==0) break; sol.SetAction(turn,candidates[idx % candidates.Count]); idx++; }
            }
            else
            {
                int cnt=Mathf.Min(survivable.Count, Mathf.Min(2,candidates.Count));
                for(int i=0;i<cnt;i++) sol.SetAction(survivable[i],candidates[i]);
            }
            var target=PuzzleSimulator.Simulate(sol,boardDef);
            var p=BuildPuzzleData(boardDef,target,maxTurns,sol.GetNonEmptyActionCount(),sol,finalZone);
            p.inputMode=inputMode;
            p.eraseOrder=GetEraseOrder(boardDef,maxTurns);
            return p;
        }

        // Layered
        public static PuzzleData GenerateLayeredPuzzle(BoardDefinition boardDef=null,int difficulty=(int)Difficulty.EASY,int layerCount=2,int maxAttempts=200,int inputMode=(int)PuzzleData.InputMode.DRAW_SHAPES,float turnTimeLimit=NO_TURN_TIME_LIMIT)
        {
            if(boardDef==null) boardDef=new BoardDefinition(8);
            int layers=LayerSystem.ClampLayerCount(layerCount);
            if(layers<=LayerSystem.SINGLE_LAYER || !UsesSequenceTree(difficulty)) return GeneratePuzzle(boardDef,0,2,difficulty,400,DEFAULT_ERASURE_CYCLE,inputMode,turnTimeLimit);
            var rng=new System.Random();
            var baseBoard=boardDef.Duplicate(); baseBoard.erasureShape=EraserSystem.ErasureShape.DIAGONAL_WEDGE;
            for(int attempt=0; attempt<maxAttempts; attempt++)
            {
                var sequence=TakeNextSequence(difficulty);
                int maxTurns=sequence.Count;
                var drawTurns=GetEasyDrawTurns(sequence);
                if(drawTurns.Count==0) continue;
                var cycles=LayerSystem.AssignLayerCycles(layers,baseBoard.erasureShape,rng);
                var starts=LayerSystem.AssignLayerStartPhases(layers,rng);
                var boards=new List<BoardDefinition>();
                for(int layer=0;layer<layers;layer++){ var lb=baseBoard.Duplicate(); lb.erasureCycleId=cycles[layer]; lb.erasureStartPhase=starts[layer]; boards.Add(lb); }
                var pools=new List<List<ShapeInstance>>();
                var layered=new LayeredSolution(layers,maxTurns);
                bool ok=true;
                for(int layer=0;layer<layers;layer++){ var pool=GenerateCandidatePool(boards[layer],difficulty); if(pool.Count<layers){ ok=false; break; } pools.Add(pool); }
                if(!ok) continue;
                for(int turnIdx=0; turnIdx<drawTurns.Count; turnIdx++)
                {
                    int turn=drawTurns[turnIdx];
                    var chosen=new List<ShapeInstance>();
                    for(int layer=0; layer<layers; layer++)
                    {
                        var shape=PickDistinctShape(pools[layer],chosen,rng);
                        if(shape==null){ ok=false; break; }
                        chosen.Add(shape); layered.SetAction(turn,layer,shape);
                    }
                    if(!ok) break;
                }
                if(!ok) continue;
                var targets=new List<VectorGeometry>();
                for(int layer=0; layer<layers; layer++)
                {
                    var lb=boards[layer]; var ls=layered.GetLayer(layer); var lt=PuzzleSimulator.Simulate(ls,lb);
                    if(lt.IsEmpty()||lt.segments.Count<2){ ok=false; break; }
                    if(!ValidateLayer(ls,lb,lt,sequence,difficulty)){ ok=false; break; }
                    targets.Add(lt);
                }
                if(!ok) continue;
                if(!LayersAreDistinct(boards,targets)) continue;
                var data=BuildLayeredPuzzleData(baseBoard,boards,layered,targets,sequence,maxTurns,difficulty,inputMode);
                data.turnTimeLimit=turnTimeLimit;
                return data;
            }
            return GeneratePuzzle(boardDef,0,2,difficulty,400,DEFAULT_ERASURE_CYCLE,inputMode,turnTimeLimit);
        }

        static ShapeInstance PickDistinctShape(List<ShapeInstance> pool, List<ShapeInstance> chosen, System.Random rng)
        {
            if(pool.Count==0) return null;
            for(int a=0;a<12;a++){ var cand=pool[rng.Next(pool.Count)]; if(!ShapeMatchesAny(cand,chosen)) return cand; }
            foreach(var cand in pool) if(!ShapeMatchesAny(cand,chosen)) return cand;
            return null;
        }

        static bool ShapeMatchesAny(ShapeInstance shape, List<ShapeInstance> others)
        {
            foreach(var o in others){ if(o==null||o.geometry==null||shape.geometry==null) continue; if(shape.geometry.IsEquivalentTo(o.geometry)) return true; }
            return false;
        }

        static bool ValidateLayer(PuzzleSolution sol, BoardDefinition board, VectorGeometry target, List<int> seq, int diff)
        {
            if(IsMultiStage(diff))
            {
                var boundaries=GetStageBoundaryTurns(seq);
                if(boundaries.Count==0) return false;
                VectorGeometry prev=null; int from=0;
                foreach(var b in boundaries)
                {
                    if(!PuzzleValidator.ValidateStageContributions(sol,board,from,b)) return false;
                    var state=PuzzleSimulator.SimulateUpToTurn(sol,board,b);
                    if(state.segments.Count<2) return false;
                    if(prev!=null && state.IsEquivalentTo(prev)) return false;
                    prev=state; from=b+1;
                }
                return true;
            }
            return PuzzleValidator.ValidateNecessaryContributions(sol,target,board);
        }

        static bool LayersAreDistinct(List<BoardDefinition> boards, List<VectorGeometry> targets)
        {
            for(int i=0;i<boards.Count;i++) for(int j=i+1;j<boards.Count;j++)
            {
                bool sameWalk = boards[i].erasureCycleId==boards[j].erasureCycleId && boards[i].erasureStartPhase==boards[j].erasureStartPhase;
                if(sameWalk) return false;
                if(targets[i].IsEquivalentTo(targets[j])) return false;
            }
            return true;
        }

        static PuzzleData BuildLayeredPuzzleData(BoardDefinition baseBoard, List<BoardDefinition> boards, LayeredSolution layered, List<VectorGeometry> targets, List<int> sequence, int maxTurns, int difficulty, int inputMode)
        {
            var merged=PuzzleSimulator.MergeLayers(targets);
            var p=BuildPuzzleData(boards[0],targets[0],maxTurns,layered.GetNonEmptyActionCount(),layered.GetLayer(0),EraserSystem.GetFinalPhase(maxTurns,boards[0]));
            p.layerCount=boards.Count; p.layerBoards=boards; p.layerTargets=targets; p.layeredSolution=layered; p.inputMode=inputMode; p.eraseOrder=GetEraseOrder(boards[0],maxTurns);
            p.difficultyRating=layered.GetNonEmptyActionCount()*1.5f+maxTurns*0.8f;
            if(IsMultiStage(difficulty))
            {
                p.stageBoundaryTurns=GetStageBoundaryTurns(sequence);
                var stageTargets=new List<VectorGeometry>();
                var layerStageTargets=new List<List<VectorGeometry>>();
                foreach(var b in p.stageBoundaryTurns){ var per=PuzzleSimulator.SimulateLayersUpToTurn(layered,boards,b); layerStageTargets.Add(per); stageTargets.Add(PuzzleSimulator.MergeLayers(per)); }
                p.stageTargets=stageTargets; p.layerStageTargets=layerStageTargets;
            }
            p.targetGeometry=merged;
            return p;
        }

        static void Shuffle<T>(List<T> list){ var rng=new System.Random(); Shuffle(list,rng); }
        static void Shuffle<T>(List<T> list, System.Random rng){ for(int i=list.Count-1;i>0;i--){ int j=rng.Next(i+1); T tmp=list[i]; list[i]=list[j]; list[j]=tmp; } }
    }
}
