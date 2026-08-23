using UnityEngine;
using UnityEngine.UI;

namespace PuzzleGame.UI
{
    public class IconButton : MonoBehaviour
    {
        public enum IconKind
        {
            DIFFICULTY=0,
            TURN_COUNT=1,
            ERASER_SHAPE=2,
            REVEAL=3,
            HINT=4,
            PIXEL=5,
            DIRECTION=6,
            INPUT_MODE=7,
            LAYERS=8,
            TURN_CLOCK=9,
            TUTORIAL=10,
            MENU=11,
        }

        public static readonly Color COLOR_ON = new Color(0.55f,0.80f,1f);
        public static readonly Color COLOR_OFF = new Color(0.42f,0.47f,0.58f);
        public static readonly Color COLOR_WARN = new Color(0.95f,0.30f,0.35f);

        public IconKind iconKind = IconKind.DIFFICULTY;
        public int iconState = 0;

        Image image;
        Button button;

        void Awake()
        {
            image = GetComponent<Image>();
            button = GetComponent<Button>();
        }

        public void SetIconState(int pState){ iconState=pState; UpdateVisual(); }

        void UpdateVisual()
        {
            // Icon visuals are drawn procedurally in original via _draw; here we update button image color or text as placeholder.
            // Full procedural drawing can be implemented via custom Graphic or by setting sprite.
            // For now, update tooltip / text if present.
            var text = GetComponentInChildren<Text>();
            if(text!=null)
            {
                text.text = GetLabel();
            }
        }

        string GetLabel()
        {
            switch(iconKind)
            {
                case IconKind.DIFFICULTY: return iconState<=0? "AUTO" : $"DIFF {iconState}";
                case IconKind.TURN_COUNT: return iconState<=0? "RND" : $"{iconState}T";
                case IconKind.ERASER_SHAPE: return iconState==0? "WEDGE" : "HALF";
                case IconKind.REVEAL: return iconState==0? "HIDE" : "SHOW";
                case IconKind.HINT: return iconState==0? "HINT" : "HINT*";
                case IconKind.PIXEL: return iconState==0? "PIX OFF" : "PIX ON";
                case IconKind.DIRECTION: return iconState==-1? "SHUFF" : $"DIR {iconState}";
                case IconKind.INPUT_MODE: return iconState==0? "DRAW" : "ERASE";
                case IconKind.LAYERS: return $"{iconState}L";
                case IconKind.TURN_CLOCK: return iconState==0? "NO CLOCK" : $"{iconState*6}s";
                case IconKind.TUTORIAL: return "TUT";
                case IconKind.MENU: return "MENU";
                default: return "";
            }
        }

        void OnValidate(){ UpdateVisual(); }
    }
}
