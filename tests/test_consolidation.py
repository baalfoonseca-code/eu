#!/usr/bin/env python3
"""Structural equivalence only; preprocessing is NOT native MQL compilation."""
from collections import Counter
import hashlib
import importlib.util
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile
import unittest
sys.dont_write_bytecode = True
from test_preservation import code_mask, functions, inputs

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('consolidate', ROOT/'tools/consolidate_scalper1995.py')
consolidate = importlib.util.module_from_spec(spec)
spec.loader.exec_module(consolidate)
MAIN = ROOT/consolidate.MAIN
MONOLITH = ROOT/consolidate.OUTPUT
SOURCE_PATHS = list(consolidate.PINNED)


def preprocess(entry):
    """Use a real C preprocessor for guards/macros in disposable shadow copies.

    Remove only the two official includes and #property directives from shadow
    inputs. Neither is C++ syntax; their equality is checked independently.
    No MetaTrader standard-library/API/type emulation or compilation occurs.
    """
    with tempfile.TemporaryDirectory(prefix='s1995-preprocess-') as temp:
        shadow = Path(temp)
        for relative in SOURCE_PATHS + [consolidate.OUTPUT]:
            text = (ROOT/relative).read_text()
            text = re.sub(r'^\s*#include\s*<[^>]+>[^\n]*$', '', text, flags=re.M)
            text = re.sub(r'^\s*#property[^\n]*$', '', text, flags=re.M)
            path = shadow/relative
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(text)
        result = subprocess.run(['g++','-E','-P','-x','c++',str(shadow/entry)],
                                capture_output=True,text=True,check=True)
        if result.stderr:
            raise AssertionError('Preprocessor diagnostics must be inspected: '+result.stderr)
        return result.stdout


def tokens(text):
    # Keep literals exact; remove only comments/whitespace. Match operators longest first.
    pattern = (r'//[^\n]*|/\*[\s\S]*?\*/|"(?:\\.|[^"\\])*"|'
               r"'(?:\\.|[^'\\])*'|[A-Za-z_]\w*|"
               r'(?:\d+(?:\.\d*)?|\.\d+)(?:[eE][+-]?\d+)?|'
               r'>>=|<<=|\+\+|--|==|!=|<=|>=|&&|\|\||\+=|-=|\*=|/=|%=|<<|>>|&=|\|=|\^=|\S')
    return [m.group() for m in re.finditer(pattern,text)
            if not m.group().startswith(('//','/*'))]


def global_declarations(text):
    """Inventory top-level variables including comma groups; omit prototypes."""
    masked = re.sub(r'^\s*#[^\n]*', '', code_mask(text), flags=re.M)
    depth=0; start=0; names=[]
    for i,char in enumerate(masked):
        if char=='{':
            depth+=1
            if depth==1: start=i+1
        elif char=='}':
            depth-=1
            if depth==0: start=i+1
        elif char==';' and depth==0:
            statement=masked[start:i].strip(); start=i+1
            m=re.match(r'(?s)^(?:(?:input|const|static)\s+)*(\w+)\s+(.+)$',statement)
            if not m: continue
            tail=m.group(2)
            # This source has no top-level function-valued initialization.
            if '(' in tail: continue
            for part in tail.split(','):
                name=re.match(r'\s*(\w+)',part)
                if name: names.append(name.group(1))
    return names


class Consolidation(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.output=MONOLITH.read_text()
        cls.modular=preprocess(consolidate.MAIN)
        cls.complete=preprocess(consolidate.OUTPUT)
        cls.old_functions=functions(cls.modular)
        cls.new_functions=functions(cls.complete)

    def test_exact_pinned_expansion_and_inputs_untouched(self):
        self.assertEqual(MONOLITH.read_bytes(),consolidate.build())
        for path,digest in consolidate.PINNED.items():
            self.assertEqual(hashlib.sha256((ROOT/path).read_bytes()).hexdigest(),digest,path)
        self.assertEqual(hashlib.sha256((ROOT/'eu1995').read_bytes()).hexdigest(),
                         '2479ed8e5c9189438d787be1e804abbd95f9e1c06e01042e560251e64ef67fc5')

    def test_each_module_body_is_present_once_without_edits(self):
        # Independent exact-body comparison, ignoring only local include directives
        # and the comment boundaries inserted by the generator.
        for relative in SOURCE_PATHS[1:]:
            original=(ROOT/relative).read_text()
            original=re.sub(r'^\s*#include\s*"[^"\n]+"\s*$', '', original, flags=re.M)
            begin='// BEGIN INCORPORATED MODULE: '+relative+'\n'
            start=self.output.index(begin)+len(begin)
            end=self.output.index('// END INCORPORATED MODULE: '+relative+'\n',start)
            embedded=self.output[start:end]
            embedded=re.sub(r'^// (?:BEGIN|END) INCORPORATED MODULE:[^\n]*\n','',embedded,flags=re.M)
            embedded=re.sub(r'^// Guarded module already incorporated above:[^\n]*\n','',embedded,flags=re.M)
            self.assertEqual(tokens(original),tokens(embedded),relative)
            self.assertEqual(1,self.output.count('#define '+re.search(r'#ifndef\s+(\w+)',original)[1]))

    def test_only_official_includes_and_properties_preserved(self):
        expected=re.findall(r'^#include\s*<[^>]+>',MAIN.read_text(),re.M)
        actual=re.findall(r'^#include\s*<[^>]+>',self.output,re.M)
        self.assertEqual(expected,actual)
        self.assertEqual(2,len(actual))
        self.assertNotRegex(self.output,r'(?m)^\s*#\s*include\s*"')
        self.assertEqual(re.findall(r'^#property[^\n]*',MAIN.read_text(),re.M),
                         re.findall(r'^#property[^\n]*',self.output,re.M))

    def test_preprocessed_effective_tokens_identical(self):
        self.assertEqual(tokens(self.modular),tokens(self.complete))
        self.assertEqual(self.modular,self.complete)

    def test_77_inputs_exact_names_types_order_defaults(self):
        self.assertEqual(inputs(self.modular),inputs(self.complete))
        self.assertEqual(77,len(inputs(self.complete)))

    def test_no_duplicate_functions_types_globals_or_inputs(self):
        masked=code_mask(self.complete)
        names=re.findall(r'(?m)^\w+\s+(\w+)\s*\([^;{}]*\)\s*\{',masked)
        types=re.findall(r'\b(?:struct|enum)\s+(\w+)\s*\{',masked)
        globals_=global_declarations(self.complete)
        self.assertGreater(len(globals_),100)
        for label,entries in [('functions',names),('types',types),('globals',globals_),
                              ('inputs',[x[1] for x in inputs(self.complete)])]:
            self.assertFalse({k:v for k,v in Counter(entries).items() if v>1},label)
        self.assertEqual(global_declarations(self.modular),globals_)

    def test_all_function_bodies_and_finance_exact(self):
        self.assertGreater(len(self.new_functions),300)
        self.assertEqual(self.old_functions,self.new_functions)
        for name in ('ComputeMatrixSnapshot','ProcessArmedSignal','EvaluateMatrixCandidate',
                     'SendOrder','ComputeLotsForEntry','OnTradeTransaction',
                     'PersistEconomicMarker','ManageBreakEven','ProcessEOD',
                     'EndRevisedWeisThesis','EntryDispatchGuard'):
            self.assertIn(name,self.new_functions)
            self.assertEqual(self.old_functions[name],self.new_functions[name])

    def test_project_module_calls_have_definitions(self):
        masked=code_mask(self.complete)
        calls=set(re.findall(r'\b((?:OM|WW|LL)\w+)\s*\(',masked))
        self.assertGreater(len(calls),20)
        self.assertFalse(calls-set(self.new_functions))
        # Every reference/declaration token is identical, including original EA
        # globals and types; no new internal dependency is introduced.
        self.assertEqual(tokens(self.modular),tokens(self.complete))

    def test_corrected_epoch_and_marker_retained(self):
        helper=self.new_functions['EndRevisedWeisThesis']
        self.assertIn('WriteEntryDiagnostic(armed,"THESIS_INVALIDATED");',helper)
        self.assertIn('ResetArmedSignal();',helper)
        self.assertIn('if(EndRevisedWeisThesis()) return APS_ENDED_FAIL_CLOSED;',self.new_functions['ProcessArmedSignal'])
        self.assertIn('if(EndRevisedWeisThesis()) return;',self.new_functions['OnTick'])
        self.assertIn('EndRevisedWeisThesis();',self.new_functions['OnTimer'])
        self.assertIn('written==27',self.new_functions['PersistEconomicMarker'])


if __name__=='__main__':
    unittest.main(verbosity=2)
