using System.Collections.Generic;

namespace PuzzleGame.Session
{
    public static class StoryCampaign
    {
        public const float STORY_TURN_SECONDS = 12f;
        public const int SHUFFLED = Puzzle.PuzzleGenerator.SHUFFLED_ERASURE_CYCLE;
        public class Chapter
        {
            public string title;
            public int tasks;
            public bool tutorial;
            public int difficulty;
            public int[] cycles;
            public int inputMode;
            public int layers;
        }
        public static readonly Chapter[] CHAPTERS = new Chapter[]
        {
            new Chapter{ title="HOW IT WORKS", tasks=1, tutorial=true, difficulty=(int)Puzzle.PuzzleGenerator.Difficulty.EASY, cycles=new int[]{0}, inputMode=0, layers=1 },
            new Chapter{ title="CLOCKWISE", tasks=2, tutorial=false, difficulty=(int)Puzzle.PuzzleGenerator.Difficulty.EASY, cycles=new int[]{0}, inputMode=0, layers=1 },
            new Chapter{ title="THE OTHER WAY", tasks=2, tutorial=false, difficulty=(int)Puzzle.PuzzleGenerator.Difficulty.EASY, cycles=new int[]{1}, inputMode=0, layers=1 },
            new Chapter{ title="MOVING OPENINGS", tasks=3, tutorial=false, difficulty=(int)Puzzle.PuzzleGenerator.Difficulty.EASY_PLUS, cycles=new int[]{0,1}, inputMode=0, layers=1 },
            new Chapter{ title="ACROSS THE FIELD", tasks=3, tutorial=false, difficulty=(int)Puzzle.PuzzleGenerator.Difficulty.EASY_PLUS, cycles=new int[]{2,3}, inputMode=0, layers=1 },
            new Chapter{ title="ZIGZAG", tasks=4, tutorial=false, difficulty=(int)Puzzle.PuzzleGenerator.Difficulty.EASY_PLUS_PLUS, cycles=new int[]{4,5}, inputMode=0, layers=1 },
            new Chapter{ title="ANY ORDER", tasks=4, tutorial=false, difficulty=(int)Puzzle.PuzzleGenerator.Difficulty.EASY_PLUS_PLUS, cycles=new int[]{}, inputMode=0, layers=1 },
            new Chapter{ title="YOU HOLD THE ERASER", tasks=4, tutorial=false, difficulty=(int)Puzzle.PuzzleGenerator.Difficulty.EASY, cycles=new int[]{}, inputMode=1, layers=1 },
            new Chapter{ title="TWO COLOURS", tasks=4, tutorial=false, difficulty=(int)Puzzle.PuzzleGenerator.Difficulty.EASY, cycles=new int[]{}, inputMode=0, layers=2 },
            new Chapter{ title="ONE GOAL AFTER ANOTHER", tasks=5, tutorial=false, difficulty=(int)Puzzle.PuzzleGenerator.Difficulty.MEDIUM, cycles=new int[]{}, inputMode=0, layers=1 },
        };

        public static int TotalTasks(){ int t=0; foreach(var c in CHAPTERS) t+=c.tasks; return t; }
        public static int ChapterIndexForTask(int idx){ int rem=idx<0?0:idx; for(int i=0;i<CHAPTERS.Length;i++){ int tasks=CHAPTERS[i].tasks; if(rem<tasks) return i; rem-=tasks; } return CHAPTERS.Length-1; }
        public static int TaskWithinChapter(int idx){ int rem=idx<0?0:idx; foreach(var c in CHAPTERS){ int tasks=c.tasks; if(rem<tasks) return rem; rem-=tasks; } return 0; }
        public static Chapter GetChapter(int idx)=> CHAPTERS[ChapterIndexForTask(idx)];
        public static bool IsFinished(int idx)=> idx >= TotalTasks();
        public static bool IsTutorialTask(int idx)=> GetChapter(idx).tutorial;
        public static int CycleForTask(int idx){ var ch=GetChapter(idx); if(ch.cycles.Length==0) return SHUFFLED; return ch.cycles[TaskWithinChapter(idx)%ch.cycles.Length]; }
        public static int DifficultyForTask(int idx)=> GetChapter(idx).difficulty;
        public static int InputModeForTask(int idx)=> GetChapter(idx).inputMode;
        public static int LayersForTask(int idx){ if(InputModeForTask(idx)==1) return 1; return GetChapter(idx).layers; }
        public static float ClockForTask(int idx)=> IsTutorialTask(idx)?0f:STORY_TURN_SECONDS;
        public static string TitleForTask(int idx)=> GetChapter(idx).title;
        public static string ProgressLabel(int idx)
        {
            if(IsFinished(idx)) return "STORY COMPLETE";
            var ch=GetChapter(idx);
            return $"{ch.title}  -  {TaskWithinChapter(idx)+1} / {ch.tasks}";
        }
    }
}
