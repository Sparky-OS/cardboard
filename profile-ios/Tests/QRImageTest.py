#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Independent QR pixel decode feeds the production policy; not an AVFoundation test."""
import subprocess
import sys
import qrcode
from pyzbar.pyzbar import decode
urls = ('https://g.co/cardboard', 'https://google.com/cardboard/cfg?p=CgZHb29nbGUSEkNhcmRib2FyZCBJL08gMjAxNR0rGBU9JQHegj0qEAAASEIAAEhCAABIQgAASEJYADUpXA89OggeZnc-Ej6aPlAAYAM')
for url in urls:
    image = qrcode.make(url).convert('RGB')
    for angle in (0, 90, 180, 270):
        results = decode(image.rotate(angle, expand=True))
        assert len(results)==1 and results[0].data.decode()==url
        result = subprocess.check_output([sys.argv[1], results[0].data.decode()], text=True).strip()
        assert result.startswith('https://google.com/cardboard/cfg?p=')
print('PASS: v1/I-O 2015 QR pixels, four rotations each, independent decoder to production profile policy')
