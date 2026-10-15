#!/usr/bin/env python3
"""Validate and package real device binaries as an unsigned IPA for re-signing."""
import hashlib
import json
from pathlib import Path
import plistlib
import stat
import struct
import subprocess
import zipfile

ROOT = Path(__file__).resolve().parent.parent
APP = ROOT / 'build/ios-derived/Build/Products/Release-iphoneos/VerseDock.app'
DIST = ROOT / 'dist'
IPA_NAME = 'VerseDock-iOS-unsigned.ipa'


def require(condition, message):
    if not condition:
        raise SystemExit(message)


def device_binary(data):
    require(len(data) >= 32, 'Executable is truncated')
    magic, cpu, subtype, file_type, commands, command_bytes, flags, reserved = struct.unpack_from('<8I', data)
    require(magic == 0xFEEDFACF and cpu == 0x0100000C and file_type == 2,
            'Expected a 64-bit arm64 device executable')
    require(32 + command_bytes <= len(data), 'Invalid Mach-O load commands')
    require(flags & 0x200000, 'Expected a position-independent executable')
    build = None
    offset = 32
    for _ in range(commands):
        require(offset + 8 <= 32 + command_bytes, 'Truncated load command')
        command, length = struct.unpack_from('<2I', data, offset)
        require(length >= 8 and offset + length <= 32 + command_bytes, 'Invalid load command size')
        if command == 0x32:  # LC_BUILD_VERSION
            require(length >= 24, 'Invalid build version command')
            platform, minimum, sdk = struct.unpack_from('<3I', data, offset + 8)
            require(platform == 2, 'Simulator or macOS executable is not a device IPA')
            def version(value):
                return f'{value >> 16}.{(value >> 8) & 255}.{value & 255}'
            build = {'architecture': 'arm64', 'platform': 'iOS',
                     'minimumOS': version(minimum), 'sdk': version(sdk)}
        if command in (0x21, 0x2C):  # LC_ENCRYPTION_INFO / LC_ENCRYPTION_INFO_64
            require(length >= 20, 'Invalid encryption command')
            require(struct.unpack_from('<I', data, offset + 16)[0] == 0, 'Encrypted executable cannot be re-signed')
        offset += length
    require(build is not None, 'Missing iOS build version command')
    return build


def bundle_record(bundle):
    info = plistlib.loads((bundle / 'Info.plist').read_bytes())
    executable = info.get('CFBundleExecutable', '')
    identifier = info.get('CFBundleIdentifier', '')
    require(executable and '/' not in executable and '$(' not in executable, 'Unresolved executable name')
    require(identifier and '$(' not in identifier, 'Unresolved bundle identifier')
    require(info.get('CFBundleSupportedPlatforms') == ['iPhoneOS'], 'Bundle is not built for iOS devices')
    require(set(info.get('UIDeviceFamily', [])) == {1, 2}, 'Expected iPhone and iPad support')
    require(not (bundle / '_CodeSignature').exists(), 'Remove signing output before packaging an unsigned IPA')
    require(not (bundle / 'embedded.mobileprovision').exists(), 'Do not distribute a personal provisioning profile')
    binary = bundle / executable
    require(binary.is_file() and binary.stat().st_mode & 0o111, 'Missing executable or execute permissions')
    return {'bundle': str(bundle.relative_to(APP)), 'identifier': identifier,
            'executable': executable, 'appVersion': info.get('CFBundleShortVersionString'),
            'buildNumber': info.get('CFBundleVersion'), 'minimumOS': info.get('MinimumOSVersion'),
            'deviceFamilies': info.get('UIDeviceFamily'), 'sha256': hashlib.sha256(binary.read_bytes()).hexdigest(),
            'machO': device_binary(binary.read_bytes())}


require(APP.is_dir(), 'Run scripts/build-ios-unsigned.sh first')
main = bundle_record(APP)
extensions = sorted(APP.glob('PlugIns/*.appex'))
require(len(extensions) == 1, 'Expected exactly one Live Activity extension')
extension = bundle_record(extensions[0])
require(extension['identifier'].startswith(main['identifier'] + '.'), 'Extension bundle ID must start with the app bundle ID')
require(extension['appVersion'] == main['appVersion'] and extension['buildNumber'] == main['buildNumber'],
        'App and extension versions differ')
widget_info = plistlib.loads((extensions[0] / 'Info.plist').read_bytes())
require(widget_info.get('NSExtension', {}).get('NSExtensionPointIdentifier') == 'com.apple.widgetkit-extension',
        'Missing WidgetKit extension declaration')
app_info = plistlib.loads((APP / 'Info.plist').read_bytes())
require(app_info.get('NSSupportsLiveActivities') is True, 'Live Activities are not enabled')
require(any('versedock' in item.get('CFBundleURLSchemes', []) for item in app_info.get('CFBundleURLTypes', [])),
        'Missing Spotify authorization callback scheme')

DIST.mkdir(exist_ok=True)
ipa = DIST / IPA_NAME
with zipfile.ZipFile(ipa, 'w', compression=zipfile.ZIP_DEFLATED) as archive:
    for path in sorted(APP.rglob('*')):
        if path.name == '.DS_Store':
            continue
        require(not path.is_symlink(), 'Unexpected symlink in iOS bundle')
        if not path.is_file():
            continue
        require(path.suffix not in {'.p8', '.pem', '.key', '.p12', '.mobileprovision'},
                'Signing credentials must not enter the IPA')
        entry = zipfile.ZipInfo('Payload/VerseDock.app/' + str(path.relative_to(APP)))
        entry.create_system = 3
        entry.external_attr = (stat.S_IFREG | (path.stat().st_mode & 0o777)) << 16
        entry.compress_type = zipfile.ZIP_DEFLATED
        archive.writestr(entry, path.read_bytes())

with zipfile.ZipFile(ipa) as archive:
    require(archive.testzip() is None, 'IPA ZIP integrity check failed')
    for record, prefix in [(main, 'Payload/VerseDock.app/'),
                           (extension, 'Payload/VerseDock.app/' + extension['bundle'] + '/')]:
        executable = archive.getinfo(prefix + record['executable'])
        require((executable.external_attr >> 16) & 0o111, 'IPA lost executable permissions')
        require(hashlib.sha256(archive.read(executable)).hexdigest() == record['sha256'],
                'IPA executable differs from the build output')

digest = hashlib.sha256(ipa.read_bytes()).hexdigest()
(DIST / 'VerseDock-iOS-unsigned.sha256').write_text(f'{digest}  {IPA_NAME}\n')
commit = subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip()
dirty = bool(subprocess.check_output(['git', 'status', '--porcelain'], cwd=ROOT, text=True).strip())
xcode = subprocess.check_output(['/usr/bin/xcodebuild', '-version'], text=True).strip()
record = {'artifact': IPA_NAME, 'bytes': ipa.stat().st_size, 'sha256': digest, 'signed': False,
          'provisioningProfileIncluded': False, 'requiresResigning': True, 'deviceTested': False,
          'sourceCommit': commit, 'sourceWorkingTreeDirty': dirty,
          'xcode': xcode, 'bundles': [main, extension]}
(DIST / 'VerseDock-iOS-BuildInfo.json').write_text(json.dumps(record, ensure_ascii=False, indent=2) + '\n')
print(json.dumps(record, ensure_ascii=False, indent=2))
