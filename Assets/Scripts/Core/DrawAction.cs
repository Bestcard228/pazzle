using PuzzleGame.Shapes;

namespace PuzzleGame.Core
{
    public class DrawAction
    {
        public int turn;
        public ShapeInstance shapeInstance;

        public DrawAction(int t = 0, ShapeInstance shape = null)
        {
            turn = t;
            shapeInstance = shape;
        }

        public DrawAction Duplicate()
        {
            var copy = shapeInstance != null ? shapeInstance.Duplicate() : null;
            return new DrawAction(turn, copy);
        }

        public override string ToString()
        {
            if (shapeInstance == null) return $"Turn {turn}: Nothing";
            return $"Turn {turn}: {shapeInstance}";
        }
    }
}
