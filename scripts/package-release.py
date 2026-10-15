#!/usr/bin/env python3
"""Package reproducible source and metadata-free Mac app ZIPs."""
import hashlib
import json
from pathlib import Path
import plistlib
import stat
import subprocess
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
app_info = plistlib.loads((app / 'Contents/Info.plist').read_bytes())
app_files = [p for p in app.rglob('*') if p.is_file() and p.name != '.DS_Store']
app_zip = DIST / 'VerseDock-macOS-arm64.zip'
write_archive(app_zip, app_files, 'VerseDock.app/', app)

excluded = {'build', '.build', 'dist', '.git', '.venv', '__pycache__', 'xcuserdata'}
tracked = subprocess.check_output(['git', 'ls-files', '-z'], cwd=ROOT).decode().split('\0')
source_files = [ROOT / name for name in tracked if name]
source_files = [p for p in source_files if p.is_file()
                and not any(part in excluded for part in p.relative_to(ROOT).parts)
                and p.name != '.DS_Store'
                and p.suffix not in {'.p8', '.pem', '.key', '.p12', '.mobileprovision', '.sqlite', '.pyc'}
                and '.sqlite-' not in p.name
                and not (p.name == '.env' or (p.name.startswith('.env.') and p.name != '.env.example'))]
source_zip = DIST / 'VerseDock-Source.zip'
write_archive(source_zip, source_files, 'VerseDock/', ROOT)

manifest = {}
artifacts = [app_zip, source_zip]
artwork = ROOT / 'Artwork'
icon_resources = ROOT / 'App/Resources'
if artwork.is_dir() and icon_resources.is_dir():
    icon_files = [p for folder in (artwork, icon_resources) for p in folder.rglob('*')
                  if p.is_file() and p.name != '.DS_Store']
    icon_zip = DIST / 'VerseDock-Icons.zip'
    write_archive(icon_zip, icon_files, 'VerseDock-Icons/', ROOT)
    artifacts.append(icon_zip)
ios_ipa = DIST / 'VerseDock-iOS-unsigned.ipa'
if ios_ipa.is_file():
    with zipfile.ZipFile(ios_ipa) as archive:
        ios_info = plistlib.loads(archive.read('Payload/VerseDock.app/Info.plist'))
    for key in ('CFBundleShortVersionString', 'CFBundleVersion'):
        if ios_info[key] != app_info[key]:
            raise SystemExit('Mac and iOS versions differ; rebuild the iOS package.')
    artifacts.append(ios_ipa)
for filename in ('VerseDock-macOS-arm64.dmg', 'VerseDock-macOS-BuildInfo.json',
                 'VerseDock-iOS-unsigned.sha256', 'VerseDock-iOS-BuildInfo.json'):
    path = DIST / filename
    if path.is_file():
        artifacts.append(path)
mac_build_info = DIST / 'VerseDock-macOS-BuildInfo.json'
if mac_build_info.is_file():
    record = json.loads(mac_build_info.read_text())
    if (record['appVersion'] != app_info['CFBundleShortVersionString']
            or record['buildNumber'] != app_info['CFBundleVersion']
            or record['sha256'] != hashlib.sha256((DIST / record['artifact']).read_bytes()).hexdigest()):
        raise SystemExit('Mac disk image metadata does not match the current build.')
for path in artifacts:
    manifest[path.name] = {'bytes': path.stat().st_size, 'sha256': hashlib.sha256(path.read_bytes()).hexdigest()}
(DIST / 'SHA256.json').write_text(json.dumps(manifest, indent=2) + '\n')
for name, value in manifest.items(): print(f"{name}: {value['bytes']} bytes, SHA256 {value['sha256']}")
