using System.Collections.Generic;
using UnityEngine;
using PuzzleGame.Board;
using PuzzleGame.Core;

namespace PuzzleGame.Puzzle
{
    public class PuzzleData
    {
        public enum InputMode { DRAW_SHAPES = 0, CHOOSE_ERASURES = 1 }

        public BoardDefinition boardDefinition;
        public VectorGeometry targetGeometry;
        public int maxTurns = 4;
        public int requiredShapeCount = 2;
        public PuzzleSolution referenceSolution;
        public float difficultyRating = 1f;
        public int inputMode = (int)InputMode.DRAW_SHAPES;
        public float turnTimeLimit = 0f;

        public int layerCount = 1;
        public List<BoardDefinition> layerBoards = new List<BoardDefinition>();
        public List<VectorGeometry> layerTargets = new List<VectorGeometry>();
        public LayeredSolution layeredSolution;
        public List<List<VectorGeometry>> layerStageTargets = new List<List<VectorGeometry>>();
        public List<int> eraseOrder = new List<int>();
        public int finalErasureZone = 0;
        public int completionTurn = -1;
        public List<int> stageBoundaryTurns = new List<int>();
        public List<VectorGeometry> stageTargets = new List<VectorGeometry>();

        public PuzzleData(BoardDefinition pBoardDef = null, VectorGeometry pTarget = null, int pMaxTurns = 4)
        {
            boardDefinition = pBoardDef != null ? pBoardDef : new BoardDefinition();
            targetGeometry = pTarget != null ? pTarget : new VectorGeometry();
            maxTurns = pMaxTurns;
            finalErasureZone = EraserSystem.GetFinalPhase(pMaxTurns, boardDefinition);
        }

        public bool IsMultiStage() => stageTargets.Count > 1;
        public int GetStageCount() => Mathf.Max(1, stageTargets.Count);
        public VectorGeometry GetStageTarget(int stage)
        {
            if (stage >= 0 && stage < stageTargets.Count) return stageTargets[stage];
            return targetGeometry;
        }
        public int GetStageForTurn(int turn)
        {
            for (int i = 0; i < stageBoundaryTurns.Count; i++) if (turn <= stageBoundaryTurns[i]) return i;
            return Mathf.Max(0, stageTargets.Count - 1);
        }
        public bool UsesLayers() => layerCount > 1 && layeredSolution != null;
        public List<VectorGeometry> GetLayerStageTargets(int stage)
        {
            if (stage >= 0 && stage < layerStageTargets.Count)
            {
                var targets = new List<VectorGeometry>();
                foreach (var g in layerStageTargets[stage]) targets.Add(g);
                return targets;
            }
            return layerTargets;
        }
        public bool UsesEraseInput() => inputMode == (int)InputMode.CHOOSE_ERASURES;
    }
}
