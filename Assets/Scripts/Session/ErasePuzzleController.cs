using System;
using System.Collections.Generic;
using UnityEngine;
using PuzzleGame.Board;
using PuzzleGame.Core;
using PuzzleGame.Puzzle;

namespace PuzzleGame.Session
{
    public class ErasePuzzleController
    {
        public event Action<int,int> ZoneCommitted;
        public event Action<int,string> ZoneRejected;
        public event Action ScheduleChanged;

        public PuzzleData puzzle;
        public ErasureSolution solution;
        public int hoveredZone = -1;

        public ErasePuzzleController(PuzzleData p=null){ Setup(p); }
        public void Setup(PuzzleData p)
        {
            puzzle=p;
            solution = new ErasureSolution(p!=null? p.maxTurns : 4);
            hoveredZone=-1;
        }
        public void Reset(){ solution.Clear(); hoveredZone=-1; ScheduleChanged?.Invoke(); }
        public int CurrentTurn()=> solution.GetTurnCount();
        public bool IsComplete()=> solution.IsFull();
        public List<int> LegalZones()=> solution.LegalZones();
        public bool CanSelect(int zone)=> solution.CanAdd(zone);
        public string RejectionReason(int zone)
        {
            if(IsComplete()) return "NO TURNS LEFT";
            if(solution.zones.Contains(zone)) return $"{EraserSystem.GetRegionName(zone)} IS STILL COOLING DOWN";
            return "";
        }
        public void SetHoveredZone(int zone){ if(hoveredZone==zone) return; hoveredZone=zone; ScheduleChanged?.Invoke(); }
        public bool SelectZone(int zone)
        {
            if(!CanSelect(zone)){ ZoneRejected?.Invoke(zone, RejectionReason(zone)); return false; }
            int turn=solution.GetTurnCount();
            solution.AddZone(zone);
            ZoneCommitted?.Invoke(zone,turn);
            ScheduleChanged?.Invoke();
            return true;
        }
        public int UndoLast(){ int r=solution.UndoLast(); if(r>=0) ScheduleChanged?.Invoke(); return r; }
        public BoardDefinition ScheduledBoard()
        {
            if(puzzle==null) return null;
            return solution.ApplyTo(puzzle.boardDefinition);
        }
        public VectorGeometry CurrentGeometry()
        {
            if(puzzle==null) return new VectorGeometry();
            return PuzzleSimulator.SimulateUpToTurn(puzzle.referenceSolution, ScheduledBoard(), CurrentTurn()-1);
        }
        public bool FollowsReference()
        {
            if(puzzle==null||puzzle.eraseOrder.Count==0) return false;
            for(int turn=0; turn<solution.GetTurnCount(); turn++)
            {
                if(turn>=puzzle.eraseOrder.Count) return false;
                if(solution.GetZone(turn)!=puzzle.eraseOrder[turn]) return false;
            }
            return true;
        }
        public int ReferenceZoneForCurrentTurn()
        {
            int turn=CurrentTurn();
            if(puzzle==null||turn<0||turn>=puzzle.eraseOrder.Count) return -1;
            return puzzle.eraseOrder[turn];
        }
    }
}
