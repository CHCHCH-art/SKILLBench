#!/usr/bin/env python3
from __future__ import annotations
import argparse, json, re, unicodedata
from decimal import Decimal, InvalidOperation

LEGAL_SUFFIXES={
    'ltd','limited','inc','incorporated','corp','corporation','llc','plc','gmbh','ag','sa','sarl','bv','nv','pte','pty','company','co'
}

VENDOR_PATTERNS=[r'^\s*From\s*:\s*(.+?)\s*$', r'^\s*Vendor\s+Name\s*:\s*(.+?)\s*$']
AMOUNT_PATTERNS=[
    r'^\s*(?:Invoice\s+)?Total\s*:?\s*(?:USD\s*)?\$?\s*([0-9][0-9,]*(?:\.[0-9]+)?)\b',
    r'^\s*Amount\s+Due\s*:?\s*(?:USD\s*)?\$?\s*([0-9][0-9,]*(?:\.[0-9]+)?)\b',
]
PO_PATTERNS=[
    r'^\s*PO\s+Number\s*:\s*([A-Za-z0-9][A-Za-z0-9._/-]*)\s*$',
    r'^\s*PO\s+No\.?\s*:\s*([A-Za-z0-9][A-Za-z0-9._/-]*)\s*$',
    r'^\s*Purchase\s+Order(?:\s+Number)?\s*:\s*([A-Za-z0-9][A-Za-z0-9._/-]*)\s*$',
]
IBAN_PATTERNS=[r'^\s*(?:Payment\s+)?IBAN\s*:\s*([A-Z0-9][A-Z0-9 _-]*)\s*$']
VENDOR_ID_PATTERNS=[r'^\s*Vendor\s+ID\s*:\s*([A-Za-z0-9][A-Za-z0-9._/-]*)\s*$']


def first_group(text,patterns):
    for p in patterns:
        m=re.search(p,text,re.IGNORECASE|re.MULTILINE)
        if m:
            v=m.group(1).strip()
            if v: return v
    return None


def normalize_vendor_name(value):
    if value is None: return ''
    text=unicodedata.normalize('NFKD',str(value))
    text=''.join(c for c in text if not unicodedata.combining(c)).casefold().replace('&',' and ')
    tokens=re.sub(r'[^a-z0-9]+',' ',text).split()
    original=list(tokens)
    while len(tokens)>1 and tokens[-1] in LEGAL_SUFFIXES:
        tokens.pop()
    if not tokens: tokens=original
    return ' '.join(tokens)


def normalize_po(value):
    if value is None: return None
    v=str(value).strip()
    return v.upper() if v else None


def normalize_iban(value):
    if value is None: return None
    v=str(value).strip().upper()
    return re.sub(r'[^A-Z0-9]','',v) if v else None


def normalize_identifier(value):
    if value is None: return None
    v=str(value).strip()
    if not v: return None
    if re.fullmatch(r'[0-9]+\.0+',v): v=v.split('.',1)[0]
    return v.casefold()


def parse_decimal(value):
    if value is None: return None
    text=str(value).strip().replace(',','')
    if not text: return None
    text=re.sub(r'^[^\d+\-.]*','',text)
    text=re.sub(r'[^\d]+$','',text)
    try: return Decimal(text)
    except InvalidOperation as e: raise SystemExit(f'invalid monetary value: {value!r}') from e


def main():
    ap=argparse.ArgumentParser()
    ap.add_argument('--text',required=True)
    ap.add_argument('--page-number',type=int,required=True)
    ap.add_argument('--output')
    args=ap.parse_args()
    text=open(args.text,encoding='utf-8',errors='replace').read().replace('\x0c','')
    vendor=first_group(text,VENDOR_PATTERNS)
    amount_raw=first_group(text,AMOUNT_PATTERNS)
    po=first_group(text,PO_PATTERNS)
    iban=first_group(text,IBAN_PATTERNS)
    vid=first_group(text,VENDOR_ID_PATTERNS)
    if vendor is None: raise SystemExit(f'missing vendor on page {args.page_number}')
    amount=parse_decimal(amount_raw)
    if amount is None: raise SystemExit(f'missing amount on page {args.page_number}')
    record={
        'page_number':args.page_number,
        'vendor_name_raw':vendor,
        'vendor_name_norm':normalize_vendor_name(vendor),
        'amount_text':format(amount,'f'),
        'po_number_raw':po,
        'po_number_norm':normalize_po(po),
        'iban_raw':iban,
        'iban_norm':normalize_iban(iban),
        'vendor_id_raw':vid,
        'vendor_id_norm':normalize_identifier(vid),
    }
    out=json.dumps(record,ensure_ascii=False,indent=2)+'\n'
    if args.output: open(args.output,'w',encoding='utf-8').write(out)
    else: print(out,end='')

if __name__=='__main__': main()
