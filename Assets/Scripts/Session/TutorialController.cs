using System.Collections.Generic;
using UnityEngine;
using PuzzleGame.Board;
using PuzzleGame.Core;
using PuzzleGame.Puzzle;
using PuzzleGame.Shapes;

namespace PuzzleGame.Session
{
    public class TutorialController
    {
        public static readonly int[] TRIANGLE_PATH = new int[]{0,3,5,0};
        public static readonly int[] SQUARE_PATH = new int[]{0,2,4,6,0};
        public List<List<int>> lesson = new List<List<int>>();
        public PuzzleData puzzle;

        public PuzzleData BuildPuzzle()
        {
            var board = new BoardDefinition(8, new Vector2(64,64), 0, EraserSystem.ErasureShape.DIAGONAL_WEDGE, EraserSystem.CYCLE_CLOCKWISE);
            lesson = new List<List<int>>{ new List<int>(TRIANGLE_PATH), new List<int>(), new List<int>(SQUARE_PATH) };
            var solution = new PuzzleSolution(lesson.Count);
            for(int turn=0; turn<lesson.Count; turn++)
            {
                var path=lesson[turn];
                if(path.Count==0) continue;
                var shape=ShapeDatabase.CreateInstanceFromPath(path, board);
                if(shape==null) return null;
                solution.SetAction(turn, shape);
            }
            var target=PuzzleSimulator.Simulate(solution, board);
            if(target.IsEmpty()) return null;
            puzzle=new PuzzleData(board,target,lesson.Count);
            puzzle.referenceSolution=solution;
            puzzle.requiredShapeCount=2;
            puzzle.finalErasureZone=EraserSystem.GetFinalPhase(lesson.Count, board);
            puzzle.completionTurn=PuzzleSimulator.GetCompletionTurn(solution,board,target);
            puzzle.eraseOrder=PuzzleGenerator.GetEraseOrder(board, lesson.Count);
            puzzle.turnTimeLimit=0f;
            return puzzle;
        }

        public int TurnCount()=> lesson.Count;
        public bool IsSkipTurn(int turn)
        {
            if(turn<0||turn>=lesson.Count) return false;
            return lesson[turn].Count==0;
        }
        public List<int> ExpectedPath(int turn)
        {
            var path=new List<int>();
            if(turn<0||turn>=lesson.Count) return path;
            foreach(var id in lesson[turn]) path.Add(id);
            return path;
        }
        public bool Accepts(List<int> nodeIds,int turn)
        {
            if(puzzle==null||IsSkipTurn(turn)) return false;
            var drawn=ShapeDatabase.CreateInstanceFromPath(nodeIds, puzzle.boardDefinition);
            if(drawn==null) return false;
            var wanted=ShapeDatabase.CreateInstanceFromPath(ExpectedPath(turn), puzzle.boardDefinition);
            if(wanted==null) return false;
            return drawn.geometry.IsEquivalentTo(wanted.geometry);
        }
    }
}
