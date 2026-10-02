#!/usr/bin/env python3
"""Read package names/versions from the image's APK installed database."""
from pathlib import Path
import re
import sys

database = Path(sys.argv[1]).read_text(encoding='utf-8')
packages = {}
for record in database.split('\n\n'):
    fields = {}
    for line in record.splitlines():
        if line.startswith(('P:', 'V:')):
            fields[line[0]] = line[2:]
    if not fields:
        continue
    name, version = fields.get('P', ''), fields.get('V', '')
    if not re.fullmatch(r'[A-Za-z0-9][A-Za-z0-9+._-]*', name) or not version or any(c.isspace() for c in version):
        raise SystemExit('Invalid package name/version in APK installed database')
    if name in packages:
        raise SystemExit(f'Duplicate installed package: {name}')
    packages[name] = version
if not packages:
    raise SystemExit('No installed packages found in image database')
for name in sorted(packages):
    print(f'{name} - {packages[name]}')
