#!/usr/bin/env python3
"""Compile the real collector with explicit MQL array syntax substitutions.

The broker/time/history APIs are deterministic mocks. This exercises the actual
collector C++-compatible body; it does not compile MQL5 or emulate MetaTrader.
"""
from pathlib import Path
import re
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]


def main():
    original = (ROOT / "include/Weis1996Engine.mqh").read_text()
    translated = re.sub(r"\binput\s+", "", original)
    translated = re.sub(r"MqlTick\s+&(\w+)\[\]", r"std::vector<MqlTick> &\1", translated)
    translated = re.sub(r"MqlTick\s+(\w+)\[\]", r"std::vector<MqlTick> \1", translated)
    translated = translated.replace('#include "Weis1996Kernel.mqh"', '#include "' + str(ROOT / "include/Weis1996Kernel.mqh") + '"')
    # Fail rather than silently expand translation if new MQL syntax appears.
    if re.search(r"MqlTick[^\n;]*\[\]", translated):
        raise RuntimeError("untranslated MQL array syntax")
    with tempfile.TemporaryDirectory(prefix="weis-adapter-") as directory:
        directory = Path(directory)
        (directory / "Weis1996Engine.host.hpp").write_text(translated)
        binary = directory / "weis_adapter_test"
        subprocess.run([
            "g++", "-std=c++17", "-Wall", "-Wextra", "-Werror", "-O2",
            "-I", str(directory), str(ROOT / "tests/weis_adapter_test.cpp"),
            "-o", str(binary),
        ], check=True)
        subprocess.run([str(binary)], check=True)


if __name__ == "__main__":
    main()
