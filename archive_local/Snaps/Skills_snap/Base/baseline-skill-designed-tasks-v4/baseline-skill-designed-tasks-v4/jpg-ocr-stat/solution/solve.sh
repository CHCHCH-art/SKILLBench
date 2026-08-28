#!/bin/bash
set -euo pipefail

cat > /app/workspace/solution.py <<'PY'
import os,re,argparse
from dataclasses import dataclass
from datetime import datetime
from decimal import Decimal,InvalidOperation,ROUND_HALF_UP
from typing import Optional,List,Tuple
from PIL import Image,ImageOps,ImageStat
import pytesseract
from pytesseract import Output
from openpyxl import Workbook

IMAGE_EXTS={'.jpg','.jpeg','.png','.tif','.tiff','.webp','.bmp'}
DATE_CAND_RE=re.compile(r'(?:DATE|TARIKH)|(?:\d{1,4}\s*[/\-]\s*\d{1,2}\s*[/\-]\s*\d{1,4})',re.I)
DATE_PATTERNS=[
 (re.compile(r'(?:DATE|TARIKH)\s*[:=\-]*\s*([0-3]?\d[/\-][01]?\d[/\-]\d{2,4})',re.I),2),
 (re.compile(r'\b(\d{4}[/\-]\d{1,2}[/\-]\d{1,2})\b'),1),
 (re.compile(r'\b([0-3]?\d[/\-][01]?\d[/\-]\d{2,4})\b'),1),
]
MONEY_RE=re.compile(r'(?<!\d)(?:RM\s*)?([+-]?\d{1,3}(?:,\d{3})*\.\d{2}|[+-]?\d+\.\d{2})(?!\d)',re.I)
HARD_EXCLUDE_RE=re.compile(r'SUB\s*TOTAL|SUBTOTAL|DISCOUNT|CHANGE|CASH\s*TENDERED',re.I)
TAX_EXCLUDE_RE=re.compile(r'\b(?:TAX|GST|SST)\b',re.I)
TOTAL_PATTERNS=[
 (re.compile(r'GRAND\s*TOTAL',re.I),100),
 (re.compile(r'TOTAL\s*:?\s*RM',re.I),90),
 (re.compile(r'TOTAL\s*AMOUNT',re.I),80),
 (re.compile(r'TOTAL\s*DUE',re.I),70),(re.compile(r'AMOUNT\s*DUE',re.I),70),
 (re.compile(r'BALANCE\s*DUE',re.I),70),(re.compile(r'NETT\s*TOTAL',re.I),70),
 (re.compile(r'NET\s*TOTAL',re.I),70),(re.compile(r'\bTOTAL\b',re.I),60),
 (re.compile(r'\bAMOUNT\b',re.I),50),
]
@dataclass
class OCRLine:
 text:str; bbox:Tuple[int,int,int,int]; confidence:float
@dataclass
class TCand:
 amount:Optional[Decimal]; priority:int; finality:int; confidence:float; idx:int; malformed:bool=False

def normalize_text(s):
 s=s.upper().replace('|','I')
 s=re.sub(r'(?<=\d)\s*,\s*(?=\d{2}\b)','.',s)
 s=re.sub(r'(?<=\d)\s*\.\s*(?=\d{2}\b)','.',s)
 return re.sub(r'\s+',' ',s).strip()

def preprocess(img):
 g=ImageOps.grayscale(img)
 if ImageStat.Stat(g).mean[0] < 105: g=ImageOps.invert(g)
 g=ImageOps.autocontrast(g,cutoff=2)
 w,h=g.size
 if w<900:
  s=min(2.0,900.0/max(w,1))
  if s>1.05:g=g.resize((int(w*s),int(h*s)),Image.Resampling.LANCZOS)
 return g

def ocr_lines(img,psm=6):
 d=pytesseract.image_to_data(img,config=f'--oem 3 --psm {psm}',output_type=Output.DICT)
 groups={}
 for i,t in enumerate(d['text']):
  if str(t).strip(): groups.setdefault((d['block_num'][i],d['par_num'][i],d['line_num'][i]),[]).append(i)
 out=[]
 for inds in groups.values():
  inds.sort(key=lambda j:d['left'][j]); toks=[str(d['text'][j]).strip() for j in inds if str(d['text'][j]).strip()]
  if not toks: continue
  x0=min(d['left'][j] for j in inds); y0=min(d['top'][j] for j in inds)
  x1=max(d['left'][j]+d['width'][j] for j in inds); y1=max(d['top'][j]+d['height'][j] for j in inds)
  cs=[]
  for j in inds:
   try:
    c=float(d['conf'][j]);
    if c>=0:cs.append(c)
   except:pass
  out.append(OCRLine(' '.join(toks),(x0,y0,x1,y1),sum(cs)/len(cs) if cs else 0))
 out.sort(key=lambda l:(l.bbox[1],l.bbox[0])); return out

def parse_date(s):
 s=s.strip().replace('O','0').replace('o','0').replace('I','1').replace('l','1'); s=re.sub(r'\s+','',s)
 for fmt in ('%d/%m/%Y','%d-%m-%Y','%d/%m/%y','%d-%m-%y','%Y/%m/%d','%Y-%m-%d'):
  try:
   v=datetime.strptime(s,fmt)
   if 2000<=v.year<=2030:return v
  except ValueError:pass
 return None

def extract_date(lines):
 c=[]
 for i,l in enumerate(lines):
  for pat,ctx in DATE_PATTERNS:
   for m in pat.finditer(normalize_text(l.text)):
    v=parse_date(m.group(1))
    if v:c.append((ctx,l.confidence,-i,v))
 return max(c,key=lambda x:x[:3])[3] if c else None

def expand_box(b,size,px=70,py=28):
 x0,y0,x1,y1=b; w,h=size
 return max(0,x0-px),max(0,y0-py),min(w,x1+px),min(h,y1+py)

def retry_date(img,lines):
 cands=[]
 for i,l in enumerate(lines):
  t=normalize_text(l.text)
  if DATE_CAND_RE.search(t):
   score=(10 if re.search(r'\b(?:DATE|TARIKH)\b',t,re.I) else 0) + t.count('/')*2+t.count('-')
   cands.append((score,l.confidence,i,l))
 cands.sort(reverse=True,key=lambda x:(x[0],x[1]))
 for _,_,_,l in cands[:4]:
  crop=img.crop(expand_box(l.bbox,img.size))
  crop=crop.resize((crop.width*2,crop.height*2),Image.Resampling.LANCZOS)
  for psm in (7,13):
   txt=pytesseract.image_to_string(crop,config=f'--oem 3 --psm {psm}')
   fake=[OCRLine(txt,(0,0,crop.width,crop.height),l.confidence)]
   v=extract_date(fake)
   if v:return v
 return None

def money_values(s):
 s=normalize_text(s)
 vals=[]
 for raw in MONEY_RE.findall(s):
  try: vals.append(Decimal(raw.replace(',','')))
  except InvalidOperation:pass
 return vals

def kw_priority(s):
 t=normalize_text(s)
 if HARD_EXCLUDE_RE.search(t):return -1
 priority=-1
 for p,k in TOTAL_PATTERNS:
  if p.search(t):
   priority=k; break
 if priority<0 and TAX_EXCLUDE_RE.search(t):return -1
 return priority

def finality_score(s):
 t=normalize_text(s)
 score=0
 if re.search(r'AFTER\s+(?:ADJ|ADJUST|ROUND)',t):score+=30
 if re.search(r'ROUNDED\s+TOTAL|TOTAL\s+(?:AFTER\s+)?ROUND',t):score+=25
 if re.search(r'GRAND\s+TOTAL',t):score+=20
 if re.search(r'NETT?\s+TOTAL',t):score+=15
 return score

def in_summary_context(lines,i):
 for j in range(max(0,i-2),i):
  if re.search(r'(GST|TAX)\s+SUMMARY|SUMMARY\s+AMOUNT',normalize_text(lines[j].text)):
   return True
 return False

def malformed_money_hint(s):
 t=normalize_text(s)
 if re.search(r'\b\d{1,5}\s+\d{2}\b',t):return True
 if re.search(r'\b\d{3,6}\b',t):return True
 if re.search(r'\d+\.\s*\D?$',t):return True
 return False

def total_candidates(lines):
 c=[]
 for i,l in enumerate(lines):
  p=kw_priority(l.text)
  if p<0:continue
  if in_summary_context(lines,i):continue
  vals=money_values(l.text)
  fin=finality_score(l.text)
  if vals:
   c.append(TCand(abs(vals[-1]),p,fin,l.confidence,i,False))
  else:
   c.append(TCand(None,p,fin,l.confidence,i,malformed_money_hint(l.text)))
   if not malformed_money_hint(l.text) and i+1<len(lines) and not HARD_EXCLUDE_RE.search(normalize_text(lines[i+1].text)):
    nv=money_values(lines[i+1].text)
    if nv:c.append(TCand(abs(nv[-1]),p,fin,min(l.confidence,lines[i+1].confidence),i,False))
 return c

def amount_support(lines, amount):
 n=0
 for l in lines:
  for v in money_values(l.text):
   if abs(abs(v)-amount) <= Decimal('0.01'):
    n += 1
 return n

def cand_rank(c, lines=None):
 support=amount_support(lines,c.amount) if lines is not None and c.amount is not None else 0
 return (c.priority,c.finality,support,c.confidence,c.idx)

def local_total_from_line(img,line):
 crop=img.crop(expand_box(line.bbox,img.size,90,10))
 crop=crop.resize((crop.width*2,crop.height*2),Image.Resampling.LANCZOS)
 results=[]
 for psm in (6,7,11):
  txt=pytesseract.image_to_string(crop,config=f'--oem 3 --psm {psm}')
  ls=[OCRLine(x.strip(),(0,0,crop.width,crop.height),line.confidence) for x in txt.splitlines() if x.strip()]
  for j,x in enumerate(ls):
   p=kw_priority(x.text)
   if p<0:continue
   vals=money_values(x.text)
   if vals:results.append(TCand(abs(vals[-1]),p,finality_score(x.text),line.confidence,j,False))
  whole=' '.join(x.text for x in ls)
  p=kw_priority(whole); vals=money_values(whole)
  if p>=0 and vals:results.append(TCand(abs(vals[-1]),p,finality_score(whole),line.confidence,0,False))
 if not results:return None
 counts={}
 for r in results:counts[r.amount]=counts.get(r.amount,0)+1
 results.sort(key=lambda r:(counts[r.amount],)+cand_rank(r),reverse=True)
 return results[0]

def extract_total(img,lines):
 cs=total_candidates(lines)
 if not cs:return None
 cs.sort(key=lambda c:cand_rank(c,lines),reverse=True)
 best=cs[0]
 if best.amount is None:
  refined=local_total_from_line(img,lines[best.idx])
  if refined is not None:return refined.amount
  for c in cs[1:]:
   if c.amount is not None:return c.amount
  return None
 return best.amount

def extract_receipt(path):
 with Image.open(path) as src:
  src.load(); original=src.copy()
 img=preprocess(original); lines=ocr_lines(img,6)
 date=extract_date(lines)
 if date is None: date=retry_date(img,lines)
 total=extract_total(img,lines)
 return (date.strftime('%Y-%m-%d') if date else None,
         f'{total.quantize(Decimal("0.01"),rounding=ROUND_HALF_UP):.2f}' if total is not None else None)

def main():
 ap=argparse.ArgumentParser();ap.add_argument('--input',required=True);ap.add_argument('--output',required=True);a=ap.parse_args()
 files=sorted(f for f in os.listdir(a.input) if os.path.splitext(f)[1].lower() in IMAGE_EXTS)
 wb=Workbook();ws=wb.active;ws.title='results';ws.append(['filename','date','total_amount'])
 for fn in files:
  try:d,t=extract_receipt(os.path.join(a.input,fn))
  except Exception:d,t=None,None
  ws.append([fn,d,t])
 wb.save(a.output)
if __name__=='__main__':main()
PY

python3 /app/workspace/solution.py \
  --input /app/workspace/dataset/img \
  --output /app/workspace/stat_ocr.xlsx
