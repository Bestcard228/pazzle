using System.Collections.Generic;
using PuzzleGame.Shapes;

namespace PuzzleGame.Core
{
    public class PuzzleSolution
    {
        public int maxTurns;
        public List<DrawAction> actions = new List<DrawAction>();

        public PuzzleSolution(int pMaxTurns = 4)
        {
            maxTurns = pMaxTurns;
            for (int t = 0; t < pMaxTurns; t++)
                actions.Add(new DrawAction(t, null));
        }

        public void SetAction(int turn, ShapeInstance shape)
        {
            if (turn >= 0 && turn < maxTurns)
                actions[turn] = new DrawAction(turn, shape);
        }

        public void ClearAction(int turn) => SetAction(turn, null);

        public DrawAction GetAction(int turn)
        {
            if (turn >= 0 && turn < maxTurns) return actions[turn];
            return null;
        }

        public int GetTurnCount() => maxTurns;

        public PuzzleSolution Duplicate()
        {
            var copy = new PuzzleSolution(maxTurns);
            for (int t = 0; t < maxTurns; t++)
                copy.actions[t] = actions[t].Duplicate();
            return copy;
        }

        public int GetNonEmptyActionCount()
        {
            int count = 0;
            foreach (var a in actions) if (a.shapeInstance != null) count++;
            return count;
        }

        public override string ToString()
        {
            var parts = new List<string>();
            foreach (var a in actions) parts.Add(a.ToString());
            return "Solution[\n  " + string.Join(",\n  ", parts) + "\n]";
        }
    }
}
