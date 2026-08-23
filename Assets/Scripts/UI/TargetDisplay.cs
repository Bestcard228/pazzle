using System.Collections.Generic;
using UnityEngine;
using UnityEngine.UI;
using PuzzleGame.Board;
using PuzzleGame.Core;

namespace PuzzleGame.UI
{
    public class TargetDisplay : MonoBehaviour
    {
        public Vector2 widgetSize = new Vector2(125,125);
        public Color colorTarget = new Color(0.3f,0.85f,1f);
        public Color colorMatched = new Color(0.2f,0.95f,0.5f);
        public Color colorField = new Color(0.45f,0.52f,0.66f,0.28f);
        public Color colorDot = new Color(0.40f,0.70f,1f,0.55f);
        public const float FADE_OUT_TIME = 0.8f;
        public const float FADE_IN_TIME = 0.35f;

        public event System.Action FadeOutFinished;

        public List<VectorGeometry> layerTargets = new List<VectorGeometry>();
        public int layerCount = 1;
        public VectorGeometry targetGeometry;
        public BoardDefinition boardDef;
        public bool isMatched = false;
        float fadeTimer = 0f;
        bool isFadingOut = false;
        float fadeInTimer = FADE_IN_TIME;

        void Awake()
        {
            var rt = GetComponent<RectTransform>();
            if(rt!=null) rt.sizeDelta = widgetSize;
        }

        void Update()
        {
            if(isFadingOut)
            {
                fadeTimer+=Time.deltaTime;
                if(fadeTimer>=FADE_OUT_TIME){ isFadingOut=false; fadeTimer=FADE_OUT_TIME; FadeOutFinished?.Invoke(); }
            }
            else if(fadeInTimer < FADE_IN_TIME)
            {
                fadeInTimer = Mathf.Min(FADE_IN_TIME, fadeInTimer+Time.deltaTime);
            }
        }

        public void SetTarget(VectorGeometry pTarget, BoardDefinition pBoardDef)
        {
            targetGeometry=pTarget; boardDef=pBoardDef; isMatched=false;
            isFadingOut=false; fadeTimer=0f; fadeInTimer=0f;
        }

        public void SetLayerTargets(List<VectorGeometry> pTargets, int pLayerCount)
        {
            layerTargets = new List<VectorGeometry>(pTargets);
            layerCount = pLayerCount;
        }

        public void SetMatched(bool pMatched){ isMatched=pMatched; }
        public void StartFadeOut(){ isFadingOut=true; fadeTimer=0f; }

        // Drawing via OnGUI / Gizmos - placeholder: actual rendering uses GL in DrawingBoard style.
        // For Unity UI, this component would use a Graphic to draw; here we just store state for DrawingBoard to read.
        public float GetFadeAlpha()
        {
            if(isFadingOut) return Mathf.Max(0f, 1f - fadeTimer/FADE_OUT_TIME);
            if(fadeInTimer < FADE_IN_TIME){ float t = fadeInTimer/FADE_IN_TIME; return 1f - Mathf.Pow(1f-t,3f); }
            return 1f;
        }
    }
}
