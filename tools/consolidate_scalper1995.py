#!/usr/bin/env python3
"""Inline the pinned, corrected modular EA; never rewrite a modular input.

Only local include directives are expanded. Repeated guarded modules are emitted
once in their original order. All other bytes inside each input remain intact.
"""
from pathlib import Path
import argparse
import hashlib
import re

ROOT = Path(__file__).resolve().parents[1]
BASE_COMMIT = 'ac0540261d6f0e578e79bddd46ff26ff65f317e8'
MAIN = 'RemoraScalper1995_Weis1996.mq5'
OUTPUT = 'RemoraScalper1995_Weis1996_COMPLETA.mq5'
PINNED = {
    MAIN: '91d47ddc41af969e248fc3ffb585c4b9b433e0bd0e8d2c61cd0ee228dcfad23c',
    'include/Weis1996Kernel.mqh': '8aaef7aebe183a21537f64c2a4031ecaaaf88e5a2d79a075143f1d1a4337470e',
    'include/Weis1996Engine.mqh': '357bfb526d023ec5c43b3358f416400099f183e34e8d584e59803f19986d3f3c',
    'include/SignalLifecycle1995.mqh': '500338661e5f731dbecfd31ecc1194e0cdfd89105afcfd6ea12a318acd097504',
}
OFFICIAL = {'Trade\\Trade.mqh', 'Trade\\PositionInfo.mqh'}
INCLUDE = re.compile(r'^\s*#\s*include\s*(["<])([^">]+)[">]\s*$')


def build(root=ROOT):
    for relative, expected in PINNED.items():
        actual = hashlib.sha256((root / relative).read_bytes()).hexdigest()
        if actual != expected:
            raise ValueError(f'Input differs from corrected base {BASE_COMMIT}: {relative}')
    emitted = set()

    def expand(relative):
        if relative in emitted:
            # No implementation omitted: the same guarded module is above.
            return f'// Guarded module already incorporated above: {relative}\n'
        emitted.add(relative)
        result = []
        for line in (root / relative).read_bytes().decode('utf-8').splitlines(keepends=True):
            match = INCLUDE.fullmatch(line.rstrip('\r\n'))
            if not match:
                result.append(line)
                continue
            kind, target = match.groups()
            if kind == '<':
                if target not in OFFICIAL:
                    raise ValueError(f'Unapproved external include: {target}')
                result.append(line)
                continue
            resolved = (Path(relative).parent / target.replace('\\', '/')).as_posix()
            if resolved not in PINNED or resolved == MAIN:
                raise ValueError(f'Unrecognized project include: {relative}: {target}')
            body = expand(resolved)
            result.extend((f'// BEGIN INCORPORATED MODULE: {resolved}\n', body,
                           f'// END INCORPORATED MODULE: {resolved}\n'))
        return ''.join(result)

    header = ('// Complete single-file structural consolidation; modular inputs preserved.\n'
              f'// Exact corrected modular base: {BASE_COMMIT}\n'
              '// Only official MetaTrader standard-library includes remain.\n'
              '// COMPILACAO_NATIVA_NAO_VERIFICADA\n')
    text = header + expand(MAIN)
    if emitted != set(PINNED):
        raise ValueError('Not all required modules were incorporated')
    return text.encode('utf-8')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--check', action='store_true', help='compare without writing')
    args = parser.parse_args()
    payload = build()
    destination = ROOT / OUTPUT
    if args.check:
        if not destination.exists() or destination.read_bytes() != payload:
            raise SystemExit('Consolidated file differs from the exact pinned expansion')
        print('PASS: exact, reproducible consolidation of the latest corrected base')
    else:
        if destination.exists() and destination.read_bytes() != payload:
            raise SystemExit('Refusing to overwrite a different existing consolidated file')
        destination.write_bytes(payload)
        print(f'{OUTPUT}: {len(payload)} bytes; SHA256={hashlib.sha256(payload).hexdigest()}')


if __name__ == '__main__':
    main()
