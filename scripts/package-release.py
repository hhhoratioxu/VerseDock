#!/usr/bin/env python3
"""Package reproducible source and metadata-free Mac app ZIPs."""
import hashlib
import json
from pathlib import Path
import stat
import zipfile

ROOT = Path(__file__).resolve().parent.parent
DIST = ROOT / 'dist'
DIST.mkdir(exist_ok=True)


def write_archive(output, files, prefix, relative_root):
    with zipfile.ZipFile(output, 'w', compression=zipfile.ZIP_DEFLATED) as archive:
        for path in sorted(files):
            entry = zipfile.ZipInfo(prefix + str(path.relative_to(relative_root)))
            entry.create_system = 3
            entry.external_attr = (stat.S_IFREG | (path.stat().st_mode & 0o777)) << 16
            entry.compress_type = zipfile.ZIP_DEFLATED
            archive.writestr(entry, path.read_bytes())


app = ROOT / 'build' / 'VerseDock.app'
if not (app / 'Contents' / 'MacOS' / 'VerseDockMac').exists():
    raise SystemExit('Build Mac app before packaging.')
app_files = [p for p in app.rglob('*') if p.is_file() and p.name != '.DS_Store']
app_zip = DIST / 'VerseDock-macOS-arm64.zip'
write_archive(app_zip, app_files, 'VerseDock.app/', app)

excluded = {'build', '.build', 'dist', '.git', '.venv', '__pycache__', 'xcuserdata'}
source_files = [p for p in ROOT.rglob('*') if p.is_file()
                and not any(part in excluded for part in p.relative_to(ROOT).parts)
                and p.name != '.DS_Store'
                and p.suffix not in {'.p8', '.pem', '.key', '.p12', '.mobileprovision', '.sqlite', '.pyc'}
                and '.sqlite-' not in p.name
                and not (p.name == '.env' or (p.name.startswith('.env.') and p.name != '.env.example'))]
source_zip = DIST / 'VerseDock-Source.zip'
write_archive(source_zip, source_files, 'VerseDock/', ROOT)

manifest = {}
artifacts = [app_zip, source_zip]
ios_ipa = DIST / 'VerseDock-iOS-unsigned.ipa'
if ios_ipa.is_file():
    artifacts.append(ios_ipa)
for path in artifacts:
    manifest[path.name] = {'bytes': path.stat().st_size, 'sha256': hashlib.sha256(path.read_bytes()).hexdigest()}
(DIST / 'SHA256.json').write_text(json.dumps(manifest, indent=2) + '\n')
for name, value in manifest.items(): print(f"{name}: {value['bytes']} bytes, SHA256 {value['sha256']}")
