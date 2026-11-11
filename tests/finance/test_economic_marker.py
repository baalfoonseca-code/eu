#!/usr/bin/env python3
"""Compile the exact marker function in a filesystem harness, not MetaEditor/MT5.

The mock contract returns ASCII bytes written. This tests the isolated marker
invariant, not broker requests, CTrade, journals, BE, EOD or native MQL I/O.
"""
import pathlib
import shutil
import subprocess
import tempfile
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[2]


def exact_function(text):
    start = text.index('bool PersistEconomicMarker(ulong pid)\n{')
    end = text.index('\n}', start) + 2
    return text[start:end]


PREAMBLE = r'''
#include <cstdio>
#include <filesystem>
#include <iostream>
#include <string>
#include <unistd.h>
using std::string;
using uint = unsigned int;
static const int FILE_WRITE=1, FILE_TXT=2, FILE_ANSI=4, INVALID_HANDLE=-1;
static FILE *stream=nullptr;
static int lastError=0;
static bool denyOpen=false, shortWrite=false, failFlush=false;
static int writes=0, flushes=0;
string EconomicMarkerPath(unsigned long pid) { return std::to_string(pid)+".econ.partial"; }
bool FileIsExist(const string &path) { return std::filesystem::exists(path); }
int FileOpen(const string &path,int flags) {
  if(denyOpen || flags!=(FILE_WRITE|FILE_TXT|FILE_ANSI)) { lastError=5; return INVALID_HANDLE; }
  stream=std::fopen(path.c_str(),"wb");
  if(!stream) { lastError=5; return INVALID_HANDLE; }
  return 1;
}
void ResetLastError() { lastError=0; }
int GetLastError() { return lastError; }
uint FileWriteString(int,const string &payload) {
  ++writes;
  size_t count=shortWrite?payload.size()-1:payload.size();
  size_t got=std::fwrite(payload.data(),1,count,stream);
  if(got!=count) lastError=29;
  return static_cast<uint>(got);
}
void FileFlush(int) {
  ++flushes;
  if(std::fflush(stream)!=0 || ::fsync(::fileno(stream))!=0 || failFlush) lastError=29;
}
void FileClose(int) { std::fclose(stream); stream=nullptr; }
'''

MAIN = r'''
int main(int argc,char **argv) {
  if(argc!=3) return 3;
  bool corrected=string(argv[1])=="corrected";
  string scenario=argv[2];
  unsigned long pid=scenario=="sentinel"?0:17;
  if(scenario=="denied") denyOpen=true;
  if(scenario=="short") shortWrite=true;
  if(scenario=="flush") failFlush=true;
  bool result=corrected?corrected_source::PersistEconomicMarker(pid):original_source::PersistEconomicMarker(pid);
  if(scenario=="restart") {
    // No in-memory state retained: second invocation runs as a separate process.
    if(writes!=0 || flushes!=0 || !result) return 4;
  }
  std::cout << result << " " << writes << " " << flushes << "\n";
}
'''


class EconomicMarkerHarness(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.temp = tempfile.TemporaryDirectory(prefix='s1995-marker-build-')
        cls.build = pathlib.Path(cls.temp.name)
        baseline = exact_function((ROOT / 'eu1995').read_text())
        if baseline.count('written==25') != 1:
            raise AssertionError('baseline marker differs; re-audit instead of silently adapting')
        cls.original = baseline
        cls.corrected = baseline.replace('written==25', 'written==27')
        source = PREAMBLE + '\nnamespace original_source {\n' + baseline + '\n}\n'
        source += '\nnamespace corrected_source {\n' + cls.corrected + '\n}\n' + MAIN
        cpp = cls.build / 'harness.cpp'
        cpp.write_text(source)
        compiler = shutil.which('g++')
        if compiler is None:
            raise RuntimeError('g++ required; this suite must not silently skip')
        cls.binary = cls.build / 'marker-test'
        subprocess.run([compiler, '-std=c++17', '-Wall', '-Wextra', '-Werror', str(cpp), '-o', str(cls.binary)], check=True)

    @classmethod
    def tearDownClass(cls):
        cls.temp.cleanup()

    def run_case(self, mode, case, directory):
        result = subprocess.run([str(self.binary), mode, case], cwd=directory, text=True, capture_output=True, check=True)
        return tuple(map(int, result.stdout.split()))

    def test_literal_is_27_ascii_bytes(self):
        literal = b'S1995_ECONOMIC_OBLIGATION\r\n'
        self.assertEqual(len(literal), 27)
        self.assertEqual(len(literal.decode('ascii')), 27)
        self.assertEqual(len(literal.rstrip(b'\r\n')), 25)

    def test_first_write_original_refuted_corrected_accepted(self):
        for mode, expected in [('original', 0), ('corrected', 1)]:
            with self.subTest(mode=mode), tempfile.TemporaryDirectory() as d:
                self.assertEqual(self.run_case(mode, 'create', d), (expected, 1, 1))
                self.assertEqual((pathlib.Path(d) / '17.econ.partial').read_bytes(), b'S1995_ECONOMIC_OBLIGATION\r\n')

    def test_restart_presence_remains_unresolved_identity(self):
        for mode in ['original', 'corrected']:
            with self.subTest(mode=mode), tempfile.TemporaryDirectory() as d:
                self.run_case(mode, 'create', d)
                self.assertEqual(self.run_case(mode, 'restart', d), (1, 0, 0))
                self.assertTrue((pathlib.Path(d) / '17.econ.partial').exists())

    def test_sentinel_first_creation_and_retry(self):
        for mode, expected in [('original', 0), ('corrected', 1)]:
            with self.subTest(mode=mode), tempfile.TemporaryDirectory() as d:
                self.assertEqual(self.run_case(mode, 'sentinel', d), (expected, 1, 1))
                self.assertEqual(self.run_case(mode, 'sentinel', d), (1, 0, 0))
                self.assertEqual((pathlib.Path(d) / '0.econ.partial').stat().st_size, 27)

    def test_failed_open_stays_failure(self):
        for mode in ['original', 'corrected']:
            with self.subTest(mode=mode), tempfile.TemporaryDirectory() as d:
                self.assertEqual(self.run_case(mode, 'denied', d), (0, 0, 0))
                self.assertFalse((pathlib.Path(d) / '17.econ.partial').exists())

    def test_short_write_stays_failure_and_evidence_remains(self):
        for mode in ['original', 'corrected']:
            with self.subTest(mode=mode), tempfile.TemporaryDirectory() as d:
                self.assertEqual(self.run_case(mode, 'short', d), (0, 1, 1))
                self.assertEqual((pathlib.Path(d) / '17.econ.partial').stat().st_size, 26)
                self.assertEqual(self.run_case(mode, 'restart', d), (1, 0, 0))

    def test_flush_failure_stays_failure_and_evidence_remains(self):
        for mode in ['original', 'corrected']:
            with self.subTest(mode=mode), tempfile.TemporaryDirectory() as d:
                self.assertEqual(self.run_case(mode, 'flush', d), (0, 1, 1))
                self.assertTrue((pathlib.Path(d) / '17.econ.partial').exists())
                self.assertEqual(self.run_case(mode, 'restart', d), (1, 0, 0))

    def test_candidate_contains_exact_isolated_correction(self):
        candidate = ROOT / 'RemoraScalper1995_Weis1996.mq5'
        if not candidate.exists():
            self.skipTest('candidate not yet created; no native/candidate validation claimed')
        self.assertEqual(exact_function(candidate.read_text()), self.corrected)


if __name__ == '__main__':
    unittest.main(verbosity=2)
