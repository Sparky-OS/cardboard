#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Check the unsigned Cardboard IPA and write its renewal entry and checksum."""
import argparse
import hashlib
import json
from pathlib import Path, PurePosixPath
import plistlib
import re
import struct
import zipfile

LANGUAGES = ('en', 'pt-BR', 'es', 'fr', 'de', 'pl', 'ja', 'ko', 'zh-Hans', 'zh-Hant')
PREFIX = 'Payload/CardboardProfile.app/'

def require(ok, message):
    if not ok:
        raise ValueError(message)

def check(ipa):
    with zipfile.ZipFile(ipa) as archive:
        names = archive.namelist()
        require(len(names) == len(set(names)), 'Duplicate archive entries')
        for item in archive.infolist():
            name = item.filename
            require(name in ('Payload/', PREFIX) or name.startswith(PREFIX), 'Unexpected package member')
            require('..' not in PurePosixPath(name).parts and not name.startswith('/'), 'Unsafe archive path')
            require((item.external_attr >> 16) & 0o170000 != 0o120000, 'Symbolic link in IPA')
            require(not any(x in name for x in ('_CodeSignature', 'embedded.mobileprovision', '.framework/', '.appex/', '.dylib')), 'App must be unsigned and self-contained')
        info = plistlib.loads(archive.read(PREFIX+'Info.plist'))
        for key, value in {'CFBundleIdentifier':'org.sparkyos.cardboard', 'CFBundleExecutable':'CardboardProfile', 'CFBundleDisplayName':'Cardboard', 'MinimumOSVersion':'16.0'}.items():
            require(info.get(key) == value, 'Unexpected '+key)
        binary = archive.read(PREFIX+'CardboardProfile')
        require(len(binary) >= 32, 'Truncated executable')
        magic, cpu, subtype, kind, count, size, flags, reserved = struct.unpack_from('<8I', binary)
        require(magic == 0xfeedfacf and cpu == 0x100000c and kind == 2, 'Expected a thin arm64 Mach-O executable')
        require(32+size <= len(binary), 'Truncated load commands')
        offset = 32
        for _ in range(count):
            require(offset+8 <= 32+size, 'Truncated command')
            command, length = struct.unpack_from('<2I', binary, offset)
            require(length >= 8 and offset+length <= 32+size, 'Invalid command size')
            require(command != 0x1d, 'Code signature load command in app')
            offset += length
        require(offset == 32+size, 'Unexpected load command size')
        for language in LANGUAGES:
            for catalog in ('Localizable.strings', 'InfoPlist.strings'):
                require(archive.read(PREFIX+language+'.lproj/'+catalog), 'Missing catalogue')
        for license in ('CardboardProfile-GPL-3.0.txt', 'Cardboard-Apache-2.0.txt'):
            require(archive.read(PREFIX+'Licenses/'+license), 'Missing licence')
    return info

def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('ipa', type=Path)
    p.add_argument('--commit', required=True)
    p.add_argument('--workflow-commit', required=True)
    a = p.parse_args()
    require(all(re.fullmatch('[0-9a-f]{40}', x) for x in (a.commit, a.workflow_commit)), 'Expected full source commits')
    info = check(a.ipa)
    with a.ipa.open('rb') as stream:
        digest = hashlib.file_digest(stream, 'sha256').hexdigest()
    entry = {'role':'cardboard', 'path':a.ipa.name, 'sha256':digest, 'bundle_id':info['CFBundleIdentifier']}
    a.ipa.with_name('cardboard-artifact.json').write_text(json.dumps({'commit':a.commit, 'workflow_commit':a.workflow_commit, 'apps':[entry]}, indent=2)+'\n')
    a.ipa.with_name('SHA256SUMS').write_text(f'{digest}  {a.ipa.name}\n')
    print('PASS: unsigned arm64 Cardboard IPA, ten languages, licences, renewal entry and SHA-256')

if __name__ == '__main__':
    main()
