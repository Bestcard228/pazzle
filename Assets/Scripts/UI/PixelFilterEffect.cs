using UnityEngine;

namespace PuzzleGame.UI
{
    [ExecuteInEditMode]
    [RequireComponent(typeof(Camera))]
    public class PixelFilterEffect : MonoBehaviour
    {
        public Material pixelMaterial;
        public bool enabledFilter = true;
        [Range(1f,8f)] public float pixelSize = 2f;
        public Vector2 designResolution = new Vector2(540,960);
        [Range(0,64)] public int colorLevels = 32;
        [Range(0f,1f)] public float sharpness = 0.35f;

        void OnRenderImage(RenderTexture src, RenderTexture dest)
        {
            if(!enabledFilter || pixelMaterial==null)
            {
                Graphics.Blit(src,dest);
                return;
            }
            pixelMaterial.SetFloat("_PixelSize", pixelSize);
            pixelMaterial.SetVector("_DesignResolution", new Vector4(designResolution.x, designResolution.y,0,0));
            pixelMaterial.SetInt("_ColorLevels", colorLevels);
            pixelMaterial.SetFloat("_Sharpness", sharpness);
            Graphics.Blit(src,dest,pixelMaterial);
        }
    }
}
