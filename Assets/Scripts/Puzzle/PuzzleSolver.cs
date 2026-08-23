using System.Collections.Generic;
using PuzzleGame.Board;
using PuzzleGame.Core;
using PuzzleGame.Shapes;

namespace PuzzleGame.Puzzle
{
    public static class PuzzleSolver
    {
        public static List<PuzzleSolution> Solve(VectorGeometry target, BoardDefinition boardDef, int maxTurns, List<ShapeInstance> candidates, int maxSolutions = 100)
        {
            var solutions = new List<PuzzleSolution>();
            var cur = new PuzzleSolution(maxTurns);
            SolveRecursive(0, maxTurns, cur, candidates, target, boardDef, solutions, maxSolutions);
            return solutions;
        }

        static void SolveRecursive(int turn, int maxTurns, PuzzleSolution cur, List<ShapeInstance> candidates, VectorGeometry target, BoardDefinition boardDef, List<PuzzleSolution> solutions, int maxSolutions)
        {
            if (solutions.Count >= maxSolutions) return;
            if (turn == maxTurns)
            {
                var result = PuzzleSimulator.Simulate(cur, boardDef);
                if (result.IsEquivalentTo(target)) solutions.Add(cur.Duplicate());
                return;
            }
            cur.SetAction(turn, null);
            SolveRecursive(turn + 1, maxTurns, cur, candidates, target, boardDef, solutions, maxSolutions);
            foreach (var shape in candidates)
            {
                if (solutions.Count >= maxSolutions) break;
                cur.SetAction(turn, shape);
                SolveRecursive(turn + 1, maxTurns, cur, candidates, target, boardDef, solutions, maxSolutions);
            }
        }
    }
}
