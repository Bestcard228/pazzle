using System.Collections.Generic;
using UnityEngine;

namespace PuzzleGame.Board
{
    public static class EraserSystem
    {
        public enum ErasureRegion { TOP = 0, RIGHT = 1, BOTTOM = 2, LEFT = 3 }

        public static readonly int[][] ERASURE_CYCLES = new int[][]
        {
            new int[]{0,1,2,3},
            new int[]{0,3,2,1},
            new int[]{0,2,3,1},
            new int[]{0,2,1,3},
            new int[]{0,1,3,2},
            new int[]{0,3,1,2},
        };

        public const int CYCLE_CLOCKWISE = 0;
        public const int CYCLE_COUNTER_CLOCKWISE = 1;
        public const int CYCLE_COUNT = 6;
        public static readonly string[] CYCLE_NAMES = new string[] { "CLOCKWISE","COUNTER-CLOCKWISE","ACROSS-LEFT","ACROSS-RIGHT","ZIGZAG-RIGHT","ZIGZAG-LEFT" };

        public static class ErasureShape
        {
            public const int DIAGONAL_WEDGE = 0;
            public const int HALF_PLANE = 1;
        }

        public const int PHASE_COUNT = 4;

        public static List<int> GetCycle(int cycleId)
        {
            int idx = ((cycleId % CYCLE_COUNT) + CYCLE_COUNT) % CYCLE_COUNT;
            var order = new List<int>();
            foreach (var r in ERASURE_CYCLES[idx]) order.Add(r);
            return order;
        }

        public static List<int> GetErasureOrder(BoardDefinition boardDef)
        {
            int cid = boardDef != null ? boardDef.erasureCycleId : CYCLE_CLOCKWISE;
            return GetCycle(cid);
        }

        public static bool IsValidCycle(List<int> cycle)
        {
            if (cycle.Count != PHASE_COUNT) return false;
            var seen = new HashSet<int>();
            foreach (var r in cycle) seen.Add(((r % PHASE_COUNT) + PHASE_COUNT) % PHASE_COUNT);
            return seen.Count == PHASE_COUNT;
        }

        public static int GetStartIndex(BoardDefinition boardDef)
        {
            int startRegion = boardDef != null ? boardDef.erasureStartPhase : (int)ErasureRegion.TOP;
            var order = GetErasureOrder(boardDef);
            int idx = order.IndexOf(((startRegion % PHASE_COUNT) + PHASE_COUNT) % PHASE_COUNT);
            return idx >= 0 ? idx : 0;
        }

        public static int GetPhaseForTurn(int turn, BoardDefinition boardDef)
        {
            if (boardDef != null && turn >= 0 && turn < boardDef.erasureOverride.Count)
                return ((boardDef.erasureOverride[turn] % PHASE_COUNT) + PHASE_COUNT) % PHASE_COUNT;
            var order = GetErasureOrder(boardDef);
            int startIdx = GetStartIndex(boardDef);
            int idx = ((startIdx + turn) % PHASE_COUNT + PHASE_COUNT) % PHASE_COUNT;
            return order[idx];
        }

        public static List<int> LegalZonesAfter(List<int> picks)
        {
            var blocked = new HashSet<int>();
            int lookback = Mathf.Min(picks.Count, PHASE_COUNT - 1);
            for (int i = picks.Count - lookback; i < picks.Count; i++)
                blocked.Add(((picks[i] % PHASE_COUNT) + PHASE_COUNT) % PHASE_COUNT);
            var legal = new List<int>();
            for (int z = 0; z < PHASE_COUNT; z++) if (!blocked.Contains(z)) legal.Add(z);
            return legal;
        }

        public static bool IsLegalNextZone(List<int> picks, int zone)
        {
            return LegalZonesAfter(picks).Contains(((zone % PHASE_COUNT) + PHASE_COUNT) % PHASE_COUNT);
        }

        public static bool CycleClearsFieldEarly(int cycleId, int shape)
        {
            if (shape != ErasureShape.HALF_PLANE) return false;
            var order = GetCycle(cycleId);
            for (int i = 0; i < PHASE_COUNT; i++)
            {
                var here = GetPhaseAxis(order[i]);
                var next = GetPhaseAxis(order[(i + 1) % PHASE_COUNT]);
                if (Vector2.Dot(here, next) < 0f) return true;
            }
            return false;
        }

        public static List<int> GetUsableCycles(int shape)
        {
            var usable = new List<int>();
            for (int i = 0; i < CYCLE_COUNT; i++) if (!CycleClearsFieldEarly(i, shape)) usable.Add(i);
            return usable;
        }

        public static bool IsCycleUsable(int cycleId, int shape) => !CycleClearsFieldEarly(cycleId, shape);

        public static Vector2 GetPhaseAxis(int phase)
        {
            int p = ((phase % PHASE_COUNT) + PHASE_COUNT) % PHASE_COUNT;
            switch (p)
            {
                case 0: return new Vector2(0, -1);
                case 1: return new Vector2(1, 0);
                case 2: return new Vector2(0, 1);
                case 3: return new Vector2(-1, 0);
                default: return Vector2.zero;
            }
        }

        public static EraseArea GetErasureRegionForPhase(int phase, BoardDefinition boardDef)
        {
            if (boardDef != null && boardDef.erasureShape == ErasureShape.DIAGONAL_WEDGE)
                return EraseArea.MakeWedge(boardDef.center, GetPhaseAxis(phase));
            return EraseArea.MakeRect(GetErasureRectForPhase(phase, boardDef));
        }

        public static EraseArea GetErasureRegionForTurn(int turn, BoardDefinition boardDef)
        {
            return GetErasureRegionForPhase(GetPhaseForTurn(turn, boardDef), boardDef);
        }

        public static Rect GetErasureRectForPhase(int phase, BoardDefinition boardDef)
        {
            Vector2 c = boardDef.center;
            Vector2 res = boardDef.resolution;
            int p = ((phase % PHASE_COUNT) + PHASE_COUNT) % PHASE_COUNT;
            switch (p)
            {
                case 0: return new Rect(0, 0, res.x, c.y);
                case 1: return new Rect(c.x, 0, res.x - c.x, res.y);
                case 2: return new Rect(0, c.y, res.x, res.y - c.y);
                case 3: return new Rect(0, 0, c.x, res.y);
                default: return new Rect();
            }
        }

        public static string GetRegionName(int phase)
        {
            int p = ((phase % PHASE_COUNT) + PHASE_COUNT) % PHASE_COUNT;
            switch (p) { case 0: return "TOP"; case 1: return "RIGHT"; case 2: return "BOTTOM"; case 3: return "LEFT"; default: return "UNKNOWN"; }
        }

        public static string GetShapeName(int shape) => shape == ErasureShape.DIAGONAL_WEDGE ? "X-WEDGE" : "HALF";

        public static int GetFinalPhase(int maxTurns, BoardDefinition boardDef) => GetPhaseForTurn(maxTurns - 1, boardDef);

        public static int StartPhaseForFinal(int finalPhase, int maxTurns, int cycleId = CYCLE_CLOCKWISE)
        {
            var order = GetCycle(cycleId);
            int finalIdx = order.IndexOf(((finalPhase % PHASE_COUNT) + PHASE_COUNT) % PHASE_COUNT);
            if (finalIdx < 0) finalIdx = 0;
            int idx = ((finalIdx - (maxTurns - 1)) % PHASE_COUNT + PHASE_COUNT) % PHASE_COUNT;
            return order[idx];
        }

        public static string GetCycleName(int cycleId) => CYCLE_NAMES[((cycleId % CYCLE_COUNT) + CYCLE_COUNT) % CYCLE_COUNT];
        public static string GetCycleDescription(int cycleId)
        {
            var parts = new List<string>();
            foreach (var r in GetCycle(cycleId)) parts.Add(GetRegionName(r));
            return string.Join(" > ", parts);
        }
    }
}
