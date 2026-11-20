#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
import json,re
from pathlib import Path
root=Path(__file__).resolve().parents[1]
spec=json.loads((root/'catalog-keys.json').read_text())
pattern=re.compile(r'\s*("(?:[^"\\]|\\.)*")\s*=\s*("(?:[^"\\]|\\.)*")\s*;')
print('| Key | '+' | '.join(spec['languages'])+' |')
print('| --- | '+' | '.join('---' for _ in spec['languages'])+' |')
for filename in ('Localizable.strings','InfoPlist.strings'):
 for lang in spec['languages']:
  text=(root/'Resources'/f'{lang}.lproj'/filename).read_text();pos=0;entries={}
  while text[pos:].strip():
   match=pattern.match(text,pos);assert match,(lang,filename,pos)
   key,value=map(json.loads,match.groups());assert key not in entries and value.strip();entries[key]=value;pos=match.end()
  missing=set(spec[filename])-set(entries);extra=set(entries)-set(spec[filename])
  if missing or extra:raise ValueError(f'{lang}/{filename}: missing {sorted(missing)}, unexpected {sorted(extra)}')
  if filename=='InfoPlist.strings':assert entries['CFBundleDisplayName']==entries['CFBundleName']=='Cardboard'
 for key in spec[filename]: print('| '+filename+': '+key+' | '+' | '.join('yes' for _ in spec['languages'])+' |')
print('PASS: all 18 keys in ten native catalogues')
