#!/usr/bin/env python3
"""Read the explicit Swift build inputs, including in a source ZIP without Git."""
import json
from pathlib import Path, PurePosixPath
import sys

ROOT = Path(__file__).resolve().parent.parent


def source_groups():
    groups = json.loads((ROOT / 'Config/SwiftSources.json').read_text())
    required = {'core', 'shared', 'macOS', 'iOS', 'liveActivity', 'tests'}
    if set(groups) != required:
        raise ValueError('Swift source groups do not match the build targets')
    seen = set()
    for name, paths in groups.items():
        if not isinstance(paths, list) or not paths:
            raise ValueError(f'Empty Swift source group: {name}')
        for path in paths:
            relative = PurePosixPath(path)
            if relative.is_absolute() or '..' in relative.parts or relative.suffix != '.swift':
                raise ValueError(f'Invalid Swift source path in {name}')
            if path in seen or not (ROOT / path).is_file():
                raise ValueError(f'Duplicate or missing Swift source in {name}: {path}')
            seen.add(path)
    return groups


if __name__ == '__main__':
    groups = source_groups()
    if len(sys.argv) == 2 and sys.argv[1] in groups:
        print('\n'.join(groups[sys.argv[1]]))
    elif sys.argv[1:] == ['--check']:
        print(json.dumps({name: len(paths) for name, paths in groups.items()}))
    else:
        raise SystemExit('Usage: source_manifest.py <group> | --check')
