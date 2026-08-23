using System.Collections.Generic;
using PuzzleGame.Board;

namespace PuzzleGame.Core
{
    public class ErasureSolution
    {
        public int maxTurns;
        public List<int> zones = new List<int>();

        public ErasureSolution(int pMaxTurns = 4) { maxTurns = pMaxTurns; }

        public bool IsFull() => zones.Count >= maxTurns;
        public int GetTurnCount() => zones.Count;

        public bool CanAdd(int zone)
        {
            if (IsFull()) return false;
            return EraserSystem.IsLegalNextZone(zones, zone);
        }

        public bool AddZone(int zone)
        {
            if (!CanAdd(zone)) return false;
            int modded = ((zone % EraserSystem.PHASE_COUNT) + EraserSystem.PHASE_COUNT) % EraserSystem.PHASE_COUNT;
            zones.Add(modded);
            return true;
        }

        public int UndoLast()
        {
            if (zones.Count == 0) return -1;
            int last = zones[zones.Count - 1];
            zones.RemoveAt(zones.Count - 1);
            return last;
        }

        public int GetZone(int turn)
        {
            if (turn < 0 || turn >= zones.Count) return -1;
            return zones[turn];
        }

        public List<int> LegalZones()
        {
            if (IsFull()) return new List<int>();
            return EraserSystem.LegalZonesAfter(zones);
        }

        public void Clear() => zones.Clear();

        public ErasureSolution Duplicate()
        {
            var copy = new ErasureSolution(maxTurns);
            copy.zones = new List<int>(zones);
            return copy;
        }

        public BoardDefinition ApplyTo(BoardDefinition boardDef)
        {
            return boardDef.WithErasureOverride(zones);
        }

        public bool Matches(List<int> other)
        {
            if (other.Count != zones.Count) return false;
            for (int i = 0; i < zones.Count; i++) if (zones[i] != other[i]) return false;
            return true;
        }

        public override string ToString()
        {
            var names = new List<string>();
            foreach (var z in zones) names.Add(EraserSystem.GetRegionName(z));
            return $"ErasureSolution[{string.Join(" > ", names)}]";
        }
    }
}
