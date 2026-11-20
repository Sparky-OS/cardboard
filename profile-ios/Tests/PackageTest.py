#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
import importlib.util
from pathlib import Path
import plistlib
import struct
import tempfile
import zipfile

spec = importlib.util.spec_from_file_location('package', Path(__file__).resolve().parents[1]/'Tools/package_manifest.py')
m = importlib.util.module_from_spec(spec)
spec.loader.exec_module(m)
info = {'CFBundleIdentifier':'org.sparkyos.cardboard','CFBundleExecutable':'CardboardProfile','CFBundleDisplayName':'Cardboard','MinimumOSVersion':'16.0'}
base = {m.PREFIX+'Info.plist':plistlib.dumps(info), m.PREFIX+'CardboardProfile':struct.pack('<8I',0xfeedfacf,0x100000c,0,2,0,0,0,0)}
for lang in m.LANGUAGES:
    for name in ('Localizable.strings','InfoPlist.strings'):base[m.PREFIX+lang+'.lproj/'+name]=b'fixture'
for name in ('CardboardProfile-GPL-3.0.txt','Cardboard-Apache-2.0.txt'):base[m.PREFIX+'Licenses/'+name]=b'fixture'
with tempfile.TemporaryDirectory() as d:
    path=Path(d)/'fixture.ipa'
    def run(files, valid):
        with zipfile.ZipFile(path,'w') as z:
            for key,value in files.items():z.writestr(key,value)
        try:m.check(path)
        except (ValueError,KeyError):assert not valid
        else:assert valid
    run(base,True)
    for name in ('embedded.mobileprovision','_CodeSignature/CodeResources','Frameworks/Evil.framework/Evil','libEvil.dylib','../elsewhere'):
        run({**base,m.PREFIX+name:b'bad'},False)
    for name in (m.PREFIX+'ja.lproj/Localizable.strings',m.PREFIX+'Licenses/Cardboard-Apache-2.0.txt'):
        run({k:v for k,v in base.items() if k!=name},False)
    run({**base,m.PREFIX+'CardboardProfile':b'not Mach-O'},False)
    run({**base,m.PREFIX+'CardboardProfile':struct.pack('<8I',0xfeedfacf,0x1000007,0,2,0,0,0,0)},False)
    signed=struct.pack('<10I',0xfeedfacf,0x100000c,0,2,1,8,0,0,0x1d,8)
    run({**base,m.PREFIX+'CardboardProfile':signed},False)
    run({**base,m.PREFIX+'Info.plist':plistlib.dumps({**info,'CFBundleIdentifier':'wrong'})},False)
print('PASS: IPA fixtures reject signature, wrong identity/architecture, embedded code, unsafe paths, missing language/licence')
