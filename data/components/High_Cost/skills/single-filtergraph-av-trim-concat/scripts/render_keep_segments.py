#!/usr/bin/env python3
import argparse, json, os, subprocess

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("input")
    ap.add_argument("output")
    ap.add_argument("keep_json")
    a=ap.parse_args()
    keep=json.load(open(a.keep_json, encoding="utf-8"))
    if isinstance(keep, dict): keep=keep["keep_segments"]
    if not keep: raise RuntimeError("No video content remains after segment removal")
    parts=[]
    for i,(s,e) in enumerate(keep):
        parts.append(f"[0:v]trim=start={float(s)}:end={float(e)},setpts=PTS-STARTPTS[v{i}]")
        parts.append(f"[0:a]atrim=start={float(s)}:end={float(e)},asetpts=PTS-STARTPTS[a{i}]")
    vi="".join(f"[v{i}]" for i in range(len(keep)))
    ai="".join(f"[a{i}]" for i in range(len(keep)))
    parts.append(f"{vi}concat=n={len(keep)}:v=1:a=0[outv]")
    parts.append(f"{ai}concat=n={len(keep)}:v=0:a=1[outa]")
    subprocess.run(["ffmpeg","-loglevel","error","-y","-i",a.input,
                    "-filter_complex",";".join(parts),"-map","[outv]","-map","[outa]",
                    "-c:v","libx264","-preset","ultrafast","-crf","23",
                    "-c:a","aac","-b:a","128k",a.output], check=True)
    if not os.path.isfile(a.output) or os.path.getsize(a.output)==0:
        raise RuntimeError("renderer produced no output")
if __name__=="__main__": main()
