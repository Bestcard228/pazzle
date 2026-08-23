using UnityEngine;

namespace PuzzleGame.Session
{
    public class TurnClock
    {
        public float limit = 0f;
        public float remaining = 0f;
        public bool running = false;

        public void SetLimit(float seconds){ limit = Mathf.Max(0f, seconds); }
        public bool HasLimit()=> limit>0f;
        public void Start(){ remaining=limit; running=HasLimit(); }
        public void Stop(){ running=false; remaining=0f; }
        public bool Tick(float delta)
        {
            if(!running) return false;
            remaining=Mathf.Max(0f, remaining-delta);
            if(remaining>0f) return false;
            running=false;
            return true;
        }
        public float Fraction()
        {
            if(!running||!HasLimit()) return -1f;
            return remaining/limit;
        }
    }
}
