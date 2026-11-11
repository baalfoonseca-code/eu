#!/usr/bin/env python3
"""Compile the actual extracted MQL5 numeric header with a minimal C++ shim.

No MetaTrader service, order path, feed collector, financial recovery or replay
is emulated by this runner. Pass --reference for a literal provenance check.
"""
from __future__ import annotations

import argparse
import hashlib
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
REFERENCE_BLOB = "e0bacb9fa1e003ddb57c658c9cc8860e208cfbfc"


def verify_reference(path: Path) -> None:
    raw = path.read_bytes()
    blob = hashlib.sha1(b"blob " + str(len(raw)).encode() + b"\0" + raw).hexdigest()
    if blob != REFERENCE_BLOB:
        raise RuntimeError(f"reference Git blob mismatch: {blob}")
    ref = raw.decode("utf-8")
    bands = ref[ref.index("struct OMBands\n"):ref.index("struct OMWeighted\n")]
    number_start = ref.index("bool OMNumber(")
    number = ref[number_start:ref.index("\n", number_start) + 1]
    waves = ref[ref.index("struct OMWave\n"):ref.index("bool OMLocationEligible(")]
    expected = bands + number + waves
    header = (ROOT / "include/Weis1996Kernel.mqh").read_text()
    actual = header[header.index("struct OMBands\n"):header.index("\n#endif")]
    if actual.rstrip("\n") != expected.rstrip("\n"):
        raise RuntimeError("kernel differs from literal verified reference segments")
    print(f"PASS literal_reference_segments Git_blob={blob}", flush=True)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--reference", type=Path)
    args = parser.parse_args()
    if args.reference:
        verify_reference(args.reference)
    else:
        print("NOT_RUN literal_reference_check (supply --reference exact ObjectiveMatrix.mqh)", flush=True)
    with tempfile.TemporaryDirectory(prefix="weis-kernel-") as directory:
        executable = Path(directory) / "weis_kernel_test"
        subprocess.run([
            "g++", "-std=c++17", "-Wall", "-Wextra", "-Werror", "-O2",
            str(ROOT / "tests/weis_kernel_test.cpp"), "-o", str(executable),
        ], check=True)
        subprocess.run([str(executable)], check=True)


if __name__ == "__main__":
    main()
