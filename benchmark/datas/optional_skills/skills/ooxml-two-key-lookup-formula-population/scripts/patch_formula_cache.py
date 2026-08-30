#!/usr/bin/env python3
from __future__ import annotations
import argparse, html, json, os, re, shutil, tempfile, zipfile
from pathlib import Path, PurePosixPath
import xml.etree.ElementTree as ET

MAIN_NS = 'http://schemas.openxmlformats.org/spreadsheetml/2006/main'
REL_DOC_NS = 'http://schemas.openxmlformats.org/officeDocument/2006/relationships'
REL_PKG_NS = 'http://schemas.openxmlformats.org/package/2006/relationships'
NS = {'m': MAIN_NS, 'r': REL_DOC_NS, 'p': REL_PKG_NS}


def resolve_target(base: PurePosixPath, target: str) -> PurePosixPath:
    if target.startswith('/'):
        return PurePosixPath(target.lstrip('/'))
    parts=[]
    for part in (base.parent / target).parts:
        if part in ('', '.'):
            continue
        if part == '..':
            if parts: parts.pop()
        else:
            parts.append(part)
    return PurePosixPath(*parts)


def sheet_member(pkg: Path, sheet_name: str) -> str:
    wb_rel = PurePosixPath('xl/workbook.xml')
    wb = ET.parse(pkg / wb_rel).getroot()
    rels = ET.parse(pkg / 'xl/_rels/workbook.xml.rels').getroot()
    targets={r.attrib['Id']: r.attrib['Target'] for r in rels.findall('p:Relationship',NS)}
    for sh in wb.findall('m:sheets/m:sheet',NS):
        if sh.attrib.get('name') == sheet_name:
            rid=sh.attrib[f'{{{REL_DOC_NS}}}id']
            return resolve_target(wb_rel, targets[rid]).as_posix()
    raise SystemExit(f'sheet not found: {sheet_name}')


def patch_cell(text: str, ref: str, formula: str, value: float) -> str:
    ftxt=html.escape(str(formula), quote=False)
    vtxt=format(float(value), '.15g')
    qref=re.escape(ref)
    patterns=[
        re.compile(rf'<c\b(?P<attrs>[^>]*?\br=([\"\']){qref}\2[^>]*?)/>', re.DOTALL),
        re.compile(rf'<c\b(?P<attrs>[^>]*?\br=([\"\']){qref}\2[^>]*?)>.*?</c>', re.DOTALL),
    ]
    match=None
    for p in patterns:
        match=p.search(text)
        if match: break
    if match is None:
        raise SystemExit(f'missing existing target cell: {ref}')
    attrs=re.sub(r'\s+t=([\"\']).*?\1', '', match.group('attrs'))
    replacement=f'<c{attrs}><f>{ftxt}</f><v>{vtxt}</v></c>'
    return text[:match.start()] + replacement + text[match.end():]


def main():
    ap=argparse.ArgumentParser(description='Patch formula text and numeric caches into existing XLSX cells while preserving cell attributes.')
    ap.add_argument('--input', required=True)
    ap.add_argument('--output', required=True)
    ap.add_argument('--sheet', required=True)
    ap.add_argument('--manifest', required=True, help='JSON object {"cells": {"A1": {"formula": "...", "value": 1.2}}}')
    args=ap.parse_args()
    src=Path(args.input); out=Path(args.output); manifest=json.loads(Path(args.manifest).read_text(encoding='utf-8'))
    cells=manifest.get('cells')
    if not isinstance(cells, dict) or not cells:
        raise SystemExit('manifest.cells must be a nonempty object')
    with tempfile.TemporaryDirectory() as td:
        pkg=Path(td)/'pkg'
        with zipfile.ZipFile(src,'r') as z: z.extractall(pkg)
        member=sheet_member(pkg,args.sheet)
        path=pkg/member
        text=path.read_text(encoding='utf-8')
        for ref,item in cells.items():
            if not isinstance(item,dict) or 'formula' not in item or 'value' not in item:
                raise SystemExit(f'bad manifest entry: {ref}')
            text=patch_cell(text,str(ref),str(item['formula']),float(item['value']))
        path.write_text(text,encoding='utf-8')
        tmp=out.with_suffix(out.suffix+'.tmp')
        tmp.parent.mkdir(parents=True, exist_ok=True)
        with zipfile.ZipFile(tmp,'w',compression=zipfile.ZIP_DEFLATED,compresslevel=6) as z:
            for p in sorted(pkg.rglob('*')):
                if p.is_file(): z.write(p,p.relative_to(pkg).as_posix())
        os.replace(tmp,out)
        with zipfile.ZipFile(out,'r') as z:
            bad=z.testzip()
            if bad: raise SystemExit(f'corrupt output member: {bad}')

if __name__ == '__main__':
    main()
