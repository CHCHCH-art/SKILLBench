#!/usr/bin/env python3
import argparse, json, os, subprocess, tempfile

def run(cmd): subprocess.run(cmd, check=True)
def q(path): return os.path.abspath(path).replace("'", "'\\''")

def main():
    ap=argparse.ArgumentParser(); ap.add_argument("input"); ap.add_argument("output"); ap.add_argument("keep_json"); a=ap.parse_args()
    keep=json.load(open(a.keep_json, encoding="utf-8")); keep=keep.get("keep_segments",keep) if isinstance(keep,dict) else keep
    if not keep: raise RuntimeError("No video content remains after segment removal")
    with tempfile.TemporaryDirectory(prefix="segmented-render-") as tmp:
        parts=[]
        for i,(s,e) in enumerate(keep):
            s=float(s); e=float(e); p=os.path.join(tmp,f"v{i:03d}.mp4"); parts.append(p)
            run(["ffmpeg","-hide_banner","-loglevel","error","-y","-ss",f"{s:.6f}","-i",a.input,"-t",f"{e-s:.6f}",
                 "-an","-map","0:v:0","-vf","setpts=PTS-STARTPTS","-c:v","libx264","-preset","ultrafast","-crf","23",
                 "-threads","1","-pix_fmt","yuv420p","-video_track_timescale","15360",p])
        lst=os.path.join(tmp,"video.ffconcat")
        with open(lst,"w",encoding="utf-8") as f:
            f.write("ffconcat version 1.0\n")
            for p in parts: f.write(f"file '{q(p)}'\n")
        joined=os.path.join(tmp,"video.mp4")
        run(["ffmpeg","-hide_banner","-loglevel","error","-y","-f","concat","-safe","0","-i",lst,"-an","-c:v","copy",joined])
        af=[]
        for i,(s,e) in enumerate(keep):
            af.append(f"[0:a]atrim=start={float(s):.6f}:end={float(e):.6f},asetpts=PTS-STARTPTS[a{i}]")
        ai="".join(f"[a{i}]" for i in range(len(keep))); af.append(f"{ai}concat=n={len(keep)}:v=0:a=1[outa]")
        audio=os.path.join(tmp,"audio.m4a")
        run(["ffmpeg","-hide_banner","-loglevel","error","-y","-i",a.input,"-filter_complex",";".join(af),"-map","[outa]",
             "-c:a","aac","-b:a","128k","-threads","1",audio])
        run(["ffmpeg","-hide_banner","-loglevel","error","-y","-i",joined,"-i",audio,"-map","0:v:0","-map","1:a:0",
             "-c","copy","-shortest","-movflags","+faststart",a.output])
    if not os.path.isfile(a.output) or os.path.getsize(a.output)==0: raise RuntimeError("renderer produced no output")
if __name__=="__main__": main()
