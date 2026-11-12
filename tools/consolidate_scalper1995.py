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
BASE_COMMIT = '0ecac27d81f8ebbf887d936305543af78122a019'
MAIN = 'RemoraScalper1995_Weis1996.mq5'
OUTPUT = 'RemoraScalper1995_Weis1996_COMPLETA.mq5'
PINNED = {
    MAIN: '5406da06a82ef0887e582fc3f858f2ebfcaeb2b2d5b49297a2357ab3a2c3d821',
    'include/Weis1996Kernel.mqh': '0154730988557de1aefe1765dfe74dd0b559d526223a1f0d0d66e045f00fac16',
    'include/Weis1996Engine.mqh': '19fcf723254e56efb68a45fe1f986d780e1220f2b14d604e1ed306fcfd0b390e',
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
    parser.add_argument('--replace-generated', metavar='SHA256',
                        help='replace a generated output only if its current hash matches')
    args = parser.parse_args()
    if args.check and args.replace_generated:
        parser.error('--check cannot be combined with --replace-generated')
    payload = build()
    destination = ROOT / OUTPUT
    if args.check:
        if not destination.exists() or destination.read_bytes() != payload:
            raise SystemExit('Consolidated file differs from the exact pinned expansion')
        print('PASS: exact, reproducible consolidation of the latest corrected base')
    else:
        if destination.exists() and destination.read_bytes() != payload:
            previous = hashlib.sha256(destination.read_bytes()).hexdigest()
            if not args.replace_generated or args.replace_generated != previous:
                raise SystemExit('Refusing to overwrite a different existing consolidated file; '
                                 'use --replace-generated with its verified SHA256')
        destination.write_bytes(payload)
        print(f'{OUTPUT}: {len(payload)} bytes; SHA256={hashlib.sha256(payload).hexdigest()}')


if __name__ == '__main__':
    main()
