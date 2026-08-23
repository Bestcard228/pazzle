using System.Collections.Generic;
using PuzzleGame.Core;

namespace PuzzleGame.Shapes
{
    public class ShapeInstance
    {
        public string templateId;
        public List<int> nodeIds = new List<int>();
        public VectorGeometry geometry;

        public ShapeInstance(string pTemplateId="", List<int> pNodeIds=null, VectorGeometry pGeometry=null)
        {
            templateId=pTemplateId;
            nodeIds = pNodeIds != null ? new List<int>(pNodeIds) : new List<int>();
            geometry = pGeometry != null ? pGeometry : new VectorGeometry();
        }

        public ShapeInstance Duplicate()
        {
            var copy = new ShapeInstance();
            copy.templateId = templateId;
            copy.nodeIds = new List<int>(nodeIds);
            copy.geometry = geometry.Duplicate();
            return copy;
        }

        public override string ToString() => $"ShapeInstance({templateId}, nodes=[{string.Join(",",nodeIds)}])";
    }
}
