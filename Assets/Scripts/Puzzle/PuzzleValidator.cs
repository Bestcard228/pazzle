using System.Collections.Generic;
using PuzzleGame.Board;
using PuzzleGame.Core;
using PuzzleGame.Shapes;

namespace PuzzleGame.Puzzle
{
    public static class PuzzleValidator
    {
        public static bool ValidateNecessaryContributions(PuzzleSolution solution, VectorGeometry target, BoardDefinition boardDef)
        {
            if (solution == null || target == null || target.IsEmpty()) return false;
            int totalDrawn = 0;
            for (int turn = 0; turn < solution.GetTurnCount(); turn++)
            {
                var action = solution.GetAction(turn);
                if (action != null && action.shapeInstance != null)
                {
                    totalDrawn++;
                    var testSol = solution.Duplicate();
                    testSol.ClearAction(turn);
                    var testTarget = PuzzleSimulator.Simulate(testSol, boardDef);
                    if (testTarget.IsEquivalentTo(target)) return false;
                }
            }
            return totalDrawn > 0;
        }

        public static bool ValidateStageContributions(PuzzleSolution solution, BoardDefinition boardDef, int fromTurn, int toTurn)
        {
            if (solution == null || boardDef == null || fromTurn > toTurn) return false;
            var stageState = PuzzleSimulator.SimulateUpToTurn(solution, boardDef, toTurn);
            if (stageState.IsEmpty()) return false;
            int drawn = 0;
            for (int turn = fromTurn; turn <= toTurn; turn++)
            {
                var action = solution.GetAction(turn);
                if (action == null || action.shapeInstance == null) continue;
                drawn++;
                var testSol = solution.Duplicate();
                testSol.ClearAction(turn);
                if (PuzzleSimulator.SimulateUpToTurn(testSol, boardDef, toTurn).IsEquivalentTo(stageState)) return false;
            }
            return drawn > 0;
        }

        public static bool ValidateNotSolvableInOneTurn(VectorGeometry target, BoardDefinition boardDef, List<ShapeInstance> candidates, int maxTurns, List<int> turnsToTest = null)
        {
            var turns = turnsToTest;
            if (turns == null || turns.Count == 0)
            {
                turns = new List<int>();
                for (int t = 0; t < maxTurns; t++) turns.Add(t);
            }
            var single = new PuzzleSolution(maxTurns);
            foreach (var t in turns)
            {
                foreach (var shape in candidates)
                {
                    single.SetAction(t, shape);
                    var sim = PuzzleSimulator.Simulate(single, boardDef);
                    if (sim.IsEquivalentTo(target)) return false;
                    single.ClearAction(t);
                }
            }
            return true;
        }

        public static bool ValidateSpansMultipleQuadrants(VectorGeometry target, BoardDefinition boardDef)
        {
            if (target == null || target.IsEmpty()) return false;
            var c = boardDef.center;
            var quadrants = new HashSet<string>();
            foreach (var seg in target.segments)
            {
                var mid = (seg.p1 + seg.p2) * 0.5f;
                int qx = mid.x >= c.x ? 1 : -1;
                int qy = mid.y >= c.y ? 1 : -1;
                quadrants.Add($"{qx},{qy}");
            }
            return quadrants.Count >= 2;
        }

        public static bool ValidateMultiTurnTiming(PuzzleSolution solution, VectorGeometry target, BoardDefinition boardDef)
        {
            if (solution == null || target == null || target.IsEmpty()) return false;
            var drawnTurns = new List<int>();
            for (int t = 0; t < solution.GetTurnCount(); t++)
            {
                var act = solution.GetAction(t);
                if (act != null && act.shapeInstance != null) drawnTurns.Add(t);
            }
            if (drawnTurns.Count < 2) return false;
            foreach (var turn in drawnTurns)
            {
                var shape = solution.GetAction(turn).shapeInstance;
                for (int other = 0; other < solution.GetTurnCount(); other++)
                {
                    if (other == turn || drawnTurns.Contains(other)) continue;
                    var testSol = solution.Duplicate();
                    testSol.ClearAction(turn);
                    testSol.SetAction(other, shape);
                    if (PuzzleSimulator.Simulate(testSol, boardDef).IsEquivalentTo(target)) return false;
                }
            }
            return true;
        }

        public static bool ValidateNotCompletableOnFirstTurn(PuzzleSolution solution, VectorGeometry target, BoardDefinition boardDef, List<ShapeInstance> candidates)
        {
            if (solution == null || target == null || target.IsEmpty()) return false;
            if (PuzzleSimulator.SimulateUpToTurn(solution, boardDef, 0).IsEquivalentTo(target)) return false;
            var opening = new PuzzleSolution(solution.GetTurnCount());
            foreach (var shape in candidates)
            {
                opening.SetAction(0, shape);
                if (PuzzleSimulator.SimulateUpToTurn(opening, boardDef, 0).IsEquivalentTo(target)) return false;
            }
            return true;
        }

        public static bool ValidateNotLastTurnOnly(PuzzleSolution solution, VectorGeometry target, BoardDefinition boardDef)
        {
            if (solution == null || target == null || target.IsEmpty()) return false;
            int maxT = solution.GetTurnCount();
            int last = maxT - 1;
            var lastOnly = new PuzzleSolution(maxT);
            var lastAct = solution.GetAction(last);
            if (lastAct != null && lastAct.shapeInstance != null) lastOnly.SetAction(last, lastAct.shapeInstance);
            var lastOnlyTarget = PuzzleSimulator.Simulate(lastOnly, boardDef);
            if (lastOnlyTarget.IsEquivalentTo(target)) return false;
            bool earlyDrawn = false;
            for (int t = 0; t < last; t++)
            {
                var act = solution.GetAction(t);
                if (act != null && act.shapeInstance != null) { earlyDrawn = true; break; }
            }
            return earlyDrawn;
        }

        public static List<List<int>> EnumerateLegalEraseOrders(int maxTurns)
        {
            var orders = new List<List<int>>();
            ExtendEraseOrders(new List<int>(), maxTurns, orders);
            return orders;
        }

        static void ExtendEraseOrders(List<int> picks, int maxTurns, List<List<int>> o)
        {
            if (picks.Count >= maxTurns) { o.Add(new List<int>(picks)); return; }
            foreach (var zone in EraserSystem.LegalZonesAfter(picks))
            {
                var next = new List<int>(picks); next.Add(zone);
                ExtendEraseOrders(next, maxTurns, o);
            }
        }

        public static int CountSolvingEraseOrders(PuzzleSolution solution, BoardDefinition boardDef, VectorGeometry target, int maxTurns)
        {
            int solving = 0;
            foreach (var order in EnumerateLegalEraseOrders(maxTurns))
            {
                var scheduled = boardDef.WithErasureOverride(order);
                if (PuzzleSimulator.Simulate(solution, scheduled).IsEquivalentTo(target)) solving++;
            }
            return solving;
        }

        public static bool ValidateEraseChoiceMatters(PuzzleSolution solution, BoardDefinition boardDef, VectorGeometry target, int maxTurns)
        {
            int total = EnumerateLegalEraseOrders(maxTurns).Count;
            if (total <= 1) return false;
            int solving = CountSolvingEraseOrders(solution, boardDef, target, maxTurns);
            return solving >= 1 && solving < total;
        }
    }
}
