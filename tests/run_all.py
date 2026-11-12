#!/usr/bin/env python3
"""Run each readiness layer and preserve any failing command's exit status."""
from pathlib import Path
import subprocess
import sys
ROOT = Path(__file__).resolve().parents[1]
commands = [
    [sys.executable, 'tests/run_weis_kernel_tests.py', '--reference', 'references/ObjectiveMatrix.e0bacb9.mqh'],
    [sys.executable, 'tests/run_weis_adapter_tests.py'],
    [sys.executable, 'tests/test_lifecycle.py'],
    [sys.executable, 'tests/test_preservation.py'],
    [sys.executable, 'tests/finance/test_economic_marker.py'],
    [sys.executable, 'tests/test_review_epoch.py'],
    [sys.executable, 'tests/test_review_max_body.py'],
    [sys.executable, 'tests/test_cont_recuo.py'],
    [sys.executable, 'tests/test_consolidation.py'],
]
for command in commands:
    print('\nRUN ' + ' '.join(command), flush=True)
    result = subprocess.run(command, cwd=ROOT)
    if result.returncode:
        sys.exit(result.returncode)
print('\nALL EXECUTED LAYERS PASSED. Native MQL5 and real replay remain unverified.')
