using System.Collections.Generic;
using UnityEngine;
using PuzzleGame.Board;

namespace PuzzleGame.Core
{
    public static class PuzzleSimulator
    {
        public static VectorGeometry Simulate(PuzzleSolution solution, BoardDefinition boardDef)
        {
            if (solution == null || boardDef == null) return new VectorGeometry();
            return SimulateUpToTurn(solution, boardDef, solution.GetTurnCount() - 1);
        }

        public static VectorGeometry SimulateUpToTurn(PuzzleSolution solution, BoardDefinition boardDef, int upToTurn)
        {
            if (solution == null || boardDef == null) return new VectorGeometry();
            var current = new VectorGeometry();
            int endTurn = Mathf.Min(upToTurn, solution.GetTurnCount() - 1);
            for (int t = 0; t <= endTurn; t++)
            {
                var action = solution.GetAction(t);
                if (action != null && action.shapeInstance != null && action.shapeInstance.geometry != null)
                    current.Merge(action.shapeInstance.geometry);
                var erasedArea = EraserSystem.GetErasureRegionForTurn(t, boardDef);
                current = GeometryClipper.ClipGeometryOut(current, erasedArea);
            }
            return current.Canonicalize();
        }

        public static List<VectorGeometry> SimulateLayersUpToTurn(LayeredSolution solution, List<BoardDefinition> boards, int upToTurn)
        {
            var results = new List<VectorGeometry>();
            if (solution == null) return results;
            for (int layer = 0; layer < solution.layers.Count; layer++)
            {
                BoardDefinition board = layer < boards.Count ? boards[layer] : null;
                results.Add(SimulateUpToTurn(solution.GetLayer(layer), board, upToTurn));
            }
            return results;
        }

        public static List<VectorGeometry> SimulateLayers(LayeredSolution solution, List<BoardDefinition> boards)
        {
            int turns = solution != null ? solution.maxTurns : 0;
            return SimulateLayersUpToTurn(solution, boards, turns - 1);
        }

        public static bool LayersAreEquivalent(List<VectorGeometry> a, List<VectorGeometry> b)
        {
            if (a.Count != b.Count) return false;
            for (int i = 0; i < a.Count; i++)
            {
                if (a[i] == null || b[i] == null) return false;
                if (!a[i].IsEquivalentTo(b[i])) return false;
            }
            return true;
        }

        public static VectorGeometry MergeLayers(List<VectorGeometry> layers)
        {
            var merged = new VectorGeometry();
            foreach (var g in layers) if (g != null) merged.Merge(g);
            return merged.Canonicalize();
        }

        public static int GetCompletionTurn(PuzzleSolution solution, BoardDefinition boardDef, VectorGeometry target)
        {
            if (solution == null || boardDef == null || target == null) return -1;
            for (int t = 0; t < solution.GetTurnCount(); t++)
                if (SimulateUpToTurn(solution, boardDef, t).IsEquivalentTo(target)) return t;
            return -1;
        }

        public static List<int> GetSurvivableTurns(BoardDefinition boardDef, int maxTurns)
        {
            var result = new List<int>();
            if (boardDef == null || maxTurns <= 0) return result;
            var probe = BuildBoardProbeGeometry(boardDef);
            for (int t = 0; t < maxTurns; t++)
            {
                var geom = probe.Duplicate();
                for (int u = t; u < maxTurns; u++)
                {
                    geom = GeometryClipper.ClipGeometryOut(geom, EraserSystem.GetErasureRegionForTurn(u, boardDef));
                    if (geom.IsEmpty()) break;
                }
                if (!geom.IsEmpty()) result.Add(t);
            }
            return result;
        }

        private static VectorGeometry BuildBoardProbeGeometry(BoardDefinition boardDef)
        {
            var geom = new VectorGeometry();
            int n = boardDef.nodeCount;
            for (int i = 0; i < n; i++)
            {
                geom.AddLine(boardDef.GetNodePosition(i), boardDef.GetNodePosition((i + 1) % n));
                geom.AddLine(boardDef.GetNodePosition(i), boardDef.GetNodePosition((i + n / 2) % n));
            }
            return geom;
        }
    }
}
