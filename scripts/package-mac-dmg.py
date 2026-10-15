#!/usr/bin/env python3
"""Create and verify a native Mac disk image from the signed build."""
import hashlib
import json
from pathlib import Path
import plistlib
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parent.parent
APP = (ROOT / 'build/VerseDock.app').resolve()
DIST = ROOT / 'dist'
DIST.mkdir(exist_ok=True)


def run(*args):
    return subprocess.check_output(args, text=True, stderr=subprocess.STDOUT)


info = plistlib.loads((APP / 'Contents/Info.plist').read_bytes())
binary = APP / 'Contents/MacOS' / info['CFBundleExecutable']
subprocess.run(['codesign', '--verify', '--deep', '--strict', str(APP)], check=True)
architecture = run('lipo', '-archs', str(binary)).strip()
if architecture != 'arm64':
    raise SystemExit('This distribution script expects the validated Apple Silicon app.')
binary_hash = hashlib.sha256(binary.read_bytes()).hexdigest()
image = DIST / 'VerseDock-macOS-arm64.dmg'

with tempfile.TemporaryDirectory(prefix='versedock-dmg-') as temporary:
    temporary = Path(temporary)
    content = temporary / 'content'
    content.mkdir()
    shutil.copytree(APP, content / 'VerseDock.app', copy_function=shutil.copy)
    (content / 'Applications').symlink_to('/Applications')
    (content / '安装说明 - Read Me.txt').write_text(
        'VerseDock ' + info['CFBundleShortVersionString'] + '\n\n'
        '将 VerseDock 拖入 Applications，然后从“应用程序”打开。\n'
        '本版本适用于 Apple Silicon，最低 macOS 14。\n'
        'Mac 包使用本地签名，尚未完成 Apple Developer ID 公证。\n'
        '首次运行请允许读取 Spotify 的自动化权限。\n\n'
        'Drag VerseDock to Applications, then open it from Applications.\n'
        'This build is for Apple Silicon and requires macOS 14 or later.\n'
        'The Mac app is locally signed and has no Apple Developer ID notarization.\n'
        'Allow Spotify Automation access on first use.\n'
    )
    run('hdiutil', 'create', '-volname', 'VerseDock', '-fs', 'HFS+', '-srcfolder', str(content),
        '-format', 'UDZO', '-ov', str(image))
    run('hdiutil', 'verify', str(image))
    mount = temporary / 'mounted'
    mount.mkdir()
    run('hdiutil', 'attach', '-readonly', '-nobrowse', '-mountpoint', str(mount), str(image))
    try:
        mounted_app = mount / 'VerseDock.app'
        subprocess.run(['codesign', '--verify', '--deep', '--strict', str(mounted_app)], check=True)
        mounted_hash = hashlib.sha256((mounted_app / 'Contents/MacOS' / info['CFBundleExecutable']).read_bytes()).hexdigest()
        if mounted_hash != binary_hash or not (mount / 'Applications').is_symlink():
            raise SystemExit('Disk image differs from the verified app or lacks the Applications shortcut.')
    finally:
        run('hdiutil', 'detach', str(mount))

record = {
    'artifact': image.name, 'appVersion': info['CFBundleShortVersionString'],
    'buildNumber': info['CFBundleVersion'], 'architecture': architecture,
    'minimumOS': info['LSMinimumSystemVersion'], 'signing': 'local-ad-hoc',
    'developerIDNotarized': False, 'strictSignature': True, 'readOnlyMountVerified': True,
    'mountedExecutableMatchesBuild': True, 'executableSHA256': binary_hash,
    'bytes': image.stat().st_size, 'sha256': hashlib.sha256(image.read_bytes()).hexdigest()
}
(DIST / 'VerseDock-macOS-BuildInfo.json').write_text(json.dumps(record, indent=2) + '\n')
print(json.dumps(record, indent=2))
