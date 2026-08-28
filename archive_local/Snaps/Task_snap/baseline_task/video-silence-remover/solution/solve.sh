#!/bin/bash
set -euo pipefail
INPUT_VIDEO="${INPUT_VIDEO:-data/input_video.mp4}"
OUTPUT_VIDEO="${OUTPUT_VIDEO:-compressed_video.mp4}"
OUTPUT_REPORT="${OUTPUT_REPORT:-compression_report.json}"
python3 - "$INPUT_VIDEO" "$OUTPUT_VIDEO" "$OUTPUT_REPORT" <<'PY'
import json, os, subprocess, sys, tempfile, wave
import numpy as np
from scipy.ndimage import uniform_filter1d
INPUT_VIDEO, OUTPUT_VIDEO, OUTPUT_REPORT = sys.argv[1:4]
SAMPLE_RATE=16000; WINDOW_SECONDS=1

def run(cmd): subprocess.run(cmd,check=True)
def get_duration(path):
 r=subprocess.run(["ffprobe","-v","error","-show_entries","format=duration","-of","default=noprint_wrappers=1:nokey=1",path],check=True,capture_output=True,text=True); return float(r.stdout.strip())
def extract_audio(video_path,wav_path):
 run(["ffmpeg","-loglevel","error","-y","-i",video_path,"-vn","-acodec","pcm_s16le","-ar",str(SAMPLE_RATE),"-ac","1",wav_path])
def calculate_energies(wav_path):
 with wave.open(wav_path,"rb") as w: sr=w.getframerate(); raw=w.readframes(w.getnframes())
 audio=np.frombuffer(raw,dtype=np.int16).astype(np.float32); ws=int(sr*WINDOW_SECONDS); energies=[]
 for i in range(0,len(audio),ws):
  window=audio[i:i+ws]
  if len(window): energies.append(float(np.sqrt(np.mean(window**2))))
 return energies
def detect_initial_silence(energies,threshold_multiplier=1.7,initial_window=60,smoothing_window=30):
 arr=np.asarray(energies); avg=np.mean(arr[:min(initial_window,len(arr))]); threshold=avg*threshold_multiplier
 smoothed=np.convolve(arr,np.ones(smoothing_window)/smoothing_window,mode="valid") if len(arr)>=smoothing_window else arr
 for i,v in enumerate(smoothed):
  if v>threshold: return i
 return 0
def detect_pauses(energies,start_time,threshold_ratio=0.55,min_duration=2,window_size=30):
 arr=np.asarray(energies); local=uniform_filter1d(arr,size=window_size,mode="nearest"); low=arr<(local*threshold_ratio)
 out=[]; active=False; s=0
 for i in range(int(start_time),len(low)):
  if low[i]:
   if not active: s=i; active=True
  elif active:
   d=i-s
   if d>=min_duration: out.append({"start":s,"end":i,"duration":d})
   active=False
 if active:
  d=len(arr)-s
  if d>=min_duration: out.append({"start":s,"end":len(arr),"duration":d})
 return out
def keep_segments(remove,total):
 out=[]; cur=0.0
 for seg in sorted(remove,key=lambda x:x["start"]):
  s=float(seg["start"]); e=float(seg["end"])
  if cur<s: out.append((cur,s))
  cur=max(cur,e)
 if cur<total: out.append((cur,total))
 return out
def q(path): return os.path.abspath(path).replace("'", "'\\''")

def encode_segmented(input_path, output_path, keep, tmp):
 if not keep: raise RuntimeError("No video content remains after silence removal")
 # Video route: independent accurate seeks + independent encodes.
 video_parts=[]
 for i,(s,e) in enumerate(keep):
  p=os.path.join(tmp,f"v{i:03d}.mp4"); video_parts.append(p)
  run(["ffmpeg","-hide_banner","-loglevel","error","-y",
       "-ss",f"{s:.6f}","-i",input_path,"-t",f"{e-s:.6f}","-an",
       "-map","0:v:0","-vf","setpts=PTS-STARTPTS","-c:v","libx264","-preset","ultrafast","-crf","23","-threads","1",
       "-pix_fmt","yuv420p","-video_track_timescale","15360",p])
 # Concat already-encoded video packets; no final video re-encode.
 lst=os.path.join(tmp,"video.ffconcat")
 with open(lst,"w") as f:
  f.write("ffconcat version 1.0\n")
  for p in video_parts: f.write(f"file '{q(p)}'\n")
 joined_video=os.path.join(tmp,"video.mp4")
 run(["ffmpeg","-hide_banner","-loglevel","error","-y","-f","concat","-safe","0","-i",lst,"-an","-c:v","copy",joined_video])
 # Audio route: one continuous trim/concat pass, avoiding per-part AAC delay.
 af=[]
 for i,(s,e) in enumerate(keep):
  af.append(f"[0:a]atrim=start={s:.6f}:end={e:.6f},asetpts=PTS-STARTPTS[a{i}]")
 ai="".join(f"[a{i}]" for i in range(len(keep)))
 af.append(f"{ai}concat=n={len(keep)}:v=0:a=1[outa]")
 audio=os.path.join(tmp,"audio.m4a")
 run(["ffmpeg","-hide_banner","-loglevel","error","-y","-i",input_path,
      "-filter_complex",";".join(af),"-map","[outa]","-c:a","aac","-b:a","128k","-threads","1",audio])
 # Final mux only.
 run(["ffmpeg","-hide_banner","-loglevel","error","-y","-i",joined_video,"-i",audio,
      "-map","0:v:0","-map","1:a:0","-c","copy","-shortest","-movflags","+faststart",output_path])

def main():
 if not os.path.isfile(INPUT_VIDEO): raise FileNotFoundError(f"Input video not found: {INPUT_VIDEO}")
 with tempfile.TemporaryDirectory(prefix="video-segmented-") as tmp:
  wav=os.path.join(tmp,"audio.wav"); extract_audio(INPUT_VIDEO,wav); energies=calculate_energies(wav)
  se=detect_initial_silence(energies); segments=[]
  if se>0: segments.append({"start":0,"end":se,"duration":se})
  segments.extend(detect_pauses(energies,se)); segments.sort(key=lambda x:x["start"])
  original=get_duration(INPUT_VIDEO); keep=keep_segments(segments,original)
  encode_segmented(INPUT_VIDEO,OUTPUT_VIDEO,keep,tmp)
  compressed=get_duration(OUTPUT_VIDEO); removed=original-compressed
  report={"original_duration_seconds":round(original,2),"compressed_duration_seconds":round(compressed,2),"removed_duration_seconds":round(removed,2),"compression_percentage":round(removed/original*100,2),"segments_removed":segments}
  with open(OUTPUT_REPORT,"w",encoding="utf-8") as f: json.dump(report,f,indent=2); f.write("\n")
if __name__=="__main__": main()
PY
