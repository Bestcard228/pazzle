using System;
using System.Collections.Generic;
using UnityEngine;
using PuzzleGame.Board;
using PuzzleGame.Core;
using PuzzleGame.Puzzle;
using PuzzleGame.Shapes;

namespace PuzzleGame.Session
{
    public class PuzzleSession
    {
        public event Action<int> TurnAdvanced;
        public event Action<int> LayerAdvanced;
        public event Action<int> StageCleared;
        public event Action PuzzleCleared;
        public event Action ScheduleChanged;

        public enum Commit { REJECTED, LAYER_DONE, TURN_DONE }

        public PuzzleData puzzle;
        public PuzzleSolution solution;
        public LayeredSolution layered;
        public ErasePuzzleController erase;

        public int turn=0;
        public int stage=0;
        public int activeLayer=0;
        public bool cleared=false;

        public void Setup(PuzzleData p)
        {
            puzzle=p;
            solution=new PuzzleSolution(p.maxTurns);
            layered=new LayeredSolution(Mathf.Max(1,p.layerCount), p.maxTurns);
            erase=new ErasePuzzleController(p);
            Reset();
        }

        public void Reset()
        {
            solution=new PuzzleSolution(puzzle.maxTurns);
            layered=new LayeredSolution(Mathf.Max(1,puzzle.layerCount), puzzle.maxTurns);
            erase.Reset();
            turn=0; stage=0; activeLayer=0; cleared=false;
        }

        public bool IsReady()=> puzzle!=null;
        public bool UsesEraseInput()=> puzzle!=null && puzzle.UsesEraseInput();
        public bool UsesLayers()=> puzzle!=null && puzzle.UsesLayers();
        public int LayerCount()=> Mathf.Max(1, puzzle!=null? puzzle.layerCount:1);
        public bool TurnsRemain()=> puzzle!=null && turn < puzzle.maxTurns;
        public int LastResolvedTurn()=> turn-1;
        public PuzzleSolution PlayingSolution()=> UsesEraseInput()? puzzle.referenceSolution : solution;
        public BoardDefinition ActiveBoard()=> UsesEraseInput()? erase.ScheduledBoard() : puzzle.boardDefinition;

        public Commit CommitShape(ShapeInstance shape)
        {
            if(cleared||!TurnsRemain()||shape==null) return Commit.REJECTED;
            if(UsesLayers())
            {
                layered.SetAction(turn, activeLayer, shape);
                activeLayer++;
                if(activeLayer < LayerCount()){ LayerAdvanced?.Invoke(activeLayer); return Commit.LAYER_DONE; }
                activeLayer=0;
                AdvanceTurn();
                return Commit.TURN_DONE;
            }
            solution.SetAction(turn, shape);
            AdvanceTurn();
            return Commit.TURN_DONE;
        }

        public bool SkipTurn()
        {
            if(cleared||!TurnsRemain()||UsesEraseInput()) return false;
            if(UsesLayers())
            {
                for(int l=0;l<LayerCount();l++) layered.ClearAction(turn,l);
                activeLayer=0;
            }
            else solution.ClearAction(turn);
            AdvanceTurn();
            return true;
        }

        public bool PickZone(int zone)
        {
            if(cleared||!UsesEraseInput()||!erase.SelectZone(zone)) return false;
            ScheduleChanged?.Invoke();
            AdvanceTurn();
            return true;
        }

        public bool CanPickZone(int zone)=> UsesEraseInput() && erase.CanSelect(zone);
        public string RejectionReason(int zone)=> erase.RejectionReason(zone);
        public bool UndoPick()
        {
            if(!UsesEraseInput()||erase.UndoLast()<0) return false;
            turn=erase.CurrentTurn();
            stage = puzzle.IsMultiStage()? puzzle.GetStageForTurn(turn):0;
            cleared=false;
            ScheduleChanged?.Invoke();
            return true;
        }

        public void AdvanceTurn()
        {
            turn++;
            TurnAdvanced?.Invoke(turn);
            CheckVictory();
        }

        public void AdvanceStage(){ stage++; }

        public VectorGeometry SurvivingGeometry()=> PuzzleSimulator.SimulateUpToTurn(PlayingSolution(), ActiveBoard(), LastResolvedTurn());
        public List<VectorGeometry> LayerGeometry()=> PuzzleSimulator.SimulateLayersUpToTurn(layered, puzzle.layerBoards, LastResolvedTurn());
        public List<int> LayerPhases(int atTurn)
        {
            var phases=new List<int>();
            foreach(var board in puzzle.layerBoards) phases.Add(atTurn>=0? EraserSystem.GetPhaseForTurn(atTurn,board):-1);
            return phases;
        }
        public List<bool> DrawnTurnFlags()
        {
            var drawn=new List<bool>();
            for(int t=0;t<puzzle.maxTurns;t++)
            {
                if(UsesLayers()) drawn.Add(layered.IsDrawTurn(t));
                else{ var a=PlayingSolution().GetAction(t); drawn.Add(a!=null && a.shapeInstance!=null); }
            }
            return drawn;
        }
        public bool StageTargetReached()
        {
            if(UsesLayers()) return PuzzleSimulator.LayersAreEquivalent(LayerGeometry(), puzzle.GetLayerStageTargets(stage));
            return SurvivingGeometry().IsEquivalentTo(puzzle.GetStageTarget(stage));
        }
        void CheckVictory()
        {
            if(!StageTargetReached()) return;
            if(stage < puzzle.GetStageCount()-1){ StageCleared?.Invoke(stage); return; }
            cleared=true;
            PuzzleCleared?.Invoke();
        }
    }
}
