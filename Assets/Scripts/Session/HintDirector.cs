using System;
using System.Collections.Generic;
using UnityEngine;
using PuzzleGame.Core;
using PuzzleGame.Shapes;

namespace PuzzleGame.Session
{
    public class HintDirector
    {
        public event Action Offered;
        public const float IDLE_SECONDS = 20f;
        public enum Kind { DRAW_PATH, SKIP_TURN, ERASE_ZONE, SCHEDULE_DONE, OFF_PLAN }
        public PuzzleSession session;
        public float idleTime=0f;
        public bool isOffered=false;
        public float pulseTime=0f;

        public HintDirector(PuzzleSession s=null){ session=s; }
        public bool Tick(float delta)
        {
            if(isOffered){ pulseTime+=delta; return false; }
            idleTime+=delta;
            if(idleTime < IDLE_SECONDS) return false;
            isOffered=true; pulseTime=0f; Offered?.Invoke(); return true;
        }
        public float Pulse()=> 0.75f + 0.25f * Mathf.Sin(pulseTime*3f);
        public void Withdraw(){ idleTime=0f; isOffered=false; pulseTime=0f; }
        public Dictionary<string, object> Request()
        {
            idleTime=0f;
            if(session.UsesEraseInput()) return EraseRequest();
            if(!FollowsReference()) return new Dictionary<string, object>{{"kind", Kind.OFF_PLAN}};
            ShapeInstance shape=null;
            if(session.UsesLayers()) shape=session.layered.GetShape(session.turn, session.activeLayer);
            else { var a=session.puzzle.referenceSolution.GetAction(session.turn); shape=a!=null? a.shapeInstance:null; }
            if(shape==null) return new Dictionary<string, object>{{"kind", Kind.SKIP_TURN}};
            return new Dictionary<string, object>{{"kind", Kind.DRAW_PATH},{"path", shape.nodeIds},{"layer", session.activeLayer}};
        }
        Dictionary<string, object> EraseRequest()
        {
            if(!session.erase.FollowsReference()) return new Dictionary<string, object>{{"kind", Kind.OFF_PLAN}};
            int zone=session.erase.ReferenceZoneForCurrentTurn();
            if(zone<0) return new Dictionary<string, object>{{"kind", Kind.SCHEDULE_DONE}};
            return new Dictionary<string, object>{{"kind", Kind.ERASE_ZONE},{"zone", zone}};
        }
        public bool FollowsReference()
        {
            if(session.UsesLayers()) return LayeredFollowsReference();
            var reference=session.puzzle.referenceSolution;
            if(reference==null) return false;
            for(int t=0;t<session.turn;t++) if(!SameShape(session.solution.GetAction(t), reference.GetAction(t))) return false;
            return true;
        }
        bool LayeredFollowsReference()
        {
            var plan=session.puzzle.layeredSolution;
            if(plan==null) return false;
            for(int t=0; t<=session.turn; t++)
                for(int layer=0; layer<session.LayerCount(); layer++)
                {
                    if(t==session.turn && layer>=session.activeLayer) break;
                    if(!SameGeometry(session.layered.GetShape(t,layer), plan.GetShape(t,layer))) return false;
                }
            return true;
        }
        bool SameShape(DrawAction mine, DrawAction theirs)=> SameGeometry(mine!=null? mine.shapeInstance:null, theirs!=null? theirs.shapeInstance:null);
        bool SameGeometry(ShapeInstance mine, ShapeInstance theirs)
        {
            if((mine==null)!=(theirs==null)) return false;
            if(mine==null) return true;
            return mine.geometry.IsEquivalentTo(theirs.geometry);
        }
    }
}
