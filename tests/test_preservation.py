"""Static preservation proofs. These are not MQL compilation or MT5 replay."""
from pathlib import Path
import hashlib
import re
import unittest

ROOT = Path(__file__).resolve().parents[1]
ORIGINAL = ROOT / 'eu1995'
CANDIDATE = ROOT / 'RemoraScalper1995_Weis1996.mq5'
SHA256 = '2479ed8e5c9189438d787be1e804abbd95f9e1c06e01042e560251e64ef67fc5'
MASTER_SHA256 = '460617a86e17b32816458e7eea299469b01daaef0e30af277da094098e43db7a'


def code_mask(source):
    """Blank comments and literals, retaining indices and line breaks."""
    pattern = r'//[^\n]*|/\*[\s\S]*?\*/|"(?:\\.|[^"\\])*"|\'(?:\\.|[^\'\\])*\''
    return re.sub(pattern, lambda m: re.sub(r'[^\n]', ' ', m.group()), source)


def functions(source):
    masked = code_mask(source)
    result = {}
    pattern = re.compile(r'(?m)^([\w]+)\s+([A-Za-z_]\w*)\s*\([^;{}]*\)\s*\{')
    for m in pattern.finditer(masked):
        depth = 1
        i = m.end()
        while depth and i < len(masked):
            depth += (masked[i] == '{') - (masked[i] == '}')
            i += 1
        if depth:
            raise AssertionError('Unbalanced function ' + m.group(2))
        result[m.group(2)] = source[m.start():i]
    return result


def inputs(source):
    return re.findall(r'(?m)^input\s+(\w+)\s+(\w+)\s*=\s*([^;]+);', source)


def section(source, start, end):
    return source[source.index(start):source.index(end, source.index(start))]


class PreservationTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.original = ORIGINAL.read_text()
        cls.candidate = CANDIDATE.read_text()
        cls.old = functions(cls.original)
        cls.new = functions(cls.candidate)

    def assertFunctionEqual(self, name):
        self.assertIn(name, self.new)
        self.assertEqual(self.old[name], self.new[name], name)

    def test_original_files_preserved(self):
        self.assertEqual(hashlib.sha256(ORIGINAL.read_bytes()).hexdigest(), SHA256)
        master = ROOT / 'comando para a atualização do código'
        self.assertEqual(hashlib.sha256(master.read_bytes()).hexdigest(), MASTER_SHA256)

    def test_retained_inputs_exact_type_order_default(self):
        removed = {'Inp_POC_WindowSec', 'Inp_POC_FollowRatio', 'Inp_RejectPOCTies'}
        expected = [x for x in inputs(self.original) if x[1] not in removed]
        # Added inputs live in the separate engine include, after original inputs.
        self.assertEqual(expected, inputs(self.candidate))
        self.assertEqual(73, len(inputs(self.original)))
        self.assertEqual(70, len(expected))

    def test_added_weis_inputs_are_exact_reference_defaults(self):
        engine = (ROOT / 'include/Weis1996Engine.mqh').read_text()
        expected = [
            ('int', 'Inp_WaveBaselineMin', '3'),
            ('double', 'Inp_WaveReversalPts_WIN', '60.0'),
            ('double', 'Inp_WaveReversalPts_WDO', '2.0'),
            ('int', 'Inp_PathEventTicks', '2'),
            ('double', 'Inp_CONT_MinPathEfficiency', '0.60'),
            ('double', 'Inp_ABS_MaxPathEfficiency', '0.30'),
            ('double', 'Inp_ABS_MinRejectionFraction', '0.35'),
        ]
        self.assertEqual(expected, inputs(engine))
        self.assertEqual(77, len(inputs(self.candidate)) + len(inputs(engine)))
        forbidden = ('OMBuildBands', 'OMWeightedAdd', 'OMLocationEligible',
                     'OMInsideB3', 'OMResolveSession', 'OMRevalidate',
                     'Inp_BandsWarmupSec', 'Inp_FeedMaxGapSec')
        kernel = (ROOT / 'include/Weis1996Kernel.mqh').read_text()
        for name in forbidden:
            self.assertNotRegex(code_mask(engine + kernel), r'\b' + name + r'\b')

    def test_vwap_sigma_macro_literal(self):
        for name in ('ResetVwapCache', 'UpdateVwapIncremental', 'GetLiveVwapSnapshot',
                     'TryCalcD1', 'CalcSigmaHistory', 'ComputeMacroContext'):
            with self.subTest(name=name):
                self.assertFunctionEqual(name)

    def test_matrix_unauthorized_regions_literal(self):
        old = self.old['ComputeMatrixSnapshot']
        new = self.new['ComputeMatrixSnapshot']
        self.assertEqual(section(old, '  // MacroContext', '// POC — janelas'),
                         section(new, '  // MacroContext', '// C1 uses'))
        self.assertEqual(old[old.index('  // BASE / TURBO'):],
                         new[new.index('  // BASE / TURBO'):])
        self.assertFunctionEqual('HasHardDirectionalContradiction')

    def test_far_literal(self):
        names = [name for name in self.old if name.startswith('FAR')]
        self.assertGreaterEqual(len(names), 10)
        for name in names:
            with self.subTest(name=name):
                self.assertFunctionEqual(name)

    def test_trigger_and_entry_confirmation_literal(self):
        for name in ('EntryGridValid', 'EntryTimeoutExpired', 'InitSignalCloseTrigger',
                     'EntryRealTrade', 'ObserveEntryTrade', 'ValidateEntryDispatch',
                     'ClaimEntryDispatch', 'ComputeTrigger', 'ArmedTriggerReady',
                     'ArmedTriggerPrice'):
            with self.subTest(name=name):
                self.assertFunctionEqual(name)

    def test_financial_protocol_literal(self):
        # Every original function from the BE engine to the end, plus entry risk/EOD.
        names = list(functions(self.original[self.original.index('double BEPrice('):]))
        names += ['ComputeLotsForEntry', 'MarginOk', 'HasOpenPosition',
                  'HasOwnPositionStrict', 'UpdateMAEMFE', 'ProcessEOD', 'SendOrder',
                  'CsvTradeHeader', 'CsvTradeRow', 'WriteTradeHeader', 'WriteTradeRow']
        self.assertGreater(len(names), 170)
        for name in names:
            with self.subTest(name=name):
                if name == 'PersistEconomicMarker':
                    # Only independently documented, isolated marker-length fix allowed.
                    expected = self.old[name].replace('written==25', 'written==27')
                    self.assertIn(self.new[name], (self.old[name], expected))
                elif name == 'SendOrder':
                    # Explicitly authorized observation only: no financial statement changes.
                    candidate = self.new[name]
                    calls = (
                        '  LLRecord("SEND_ATTEMPT",armed,armed.weisEvidence,"CALL_POSITION_OPEN");\n',
                        ' LLRecord(IsFinalRejectedRetcode(ret)?"REQUEST_REJECTED":"REQUEST_RESULT",armed,armed.weisEvidence,"SYNCHRONOUS_RESULT",\n'
                        '    executionResult.request_id,executionResult.order,0,ret);\n',
                    )
                    for call in calls:
                        self.assertEqual(1, candidate.count(call), call)
                        candidate = candidate.replace(call, '')
                    self.assertEqual(self.old[name], candidate, name)
                else:
                    self.assertFunctionEqual(name)

    def test_csv_historical_headers_and_row_arity(self):
        for name in self.old:
            if name.startswith('Csv') and name.endswith('Header'):
                with self.subTest(name=name):
                    self.assertFunctionEqual(name)
                    row = name[:-6] + 'Row'
                    if row in self.new:
                        # Static CsvAdd count suffices here: both functions are unrolled.
                        self.assertEqual(len(re.findall(r'\bCsvAdd\(', self.new[name])),
                                         len(re.findall(r'\bCsvAdd\(', self.new[row])), name)

    def test_no_operational_poc_or_candle_weis(self):
        stripped = re.sub(r'"(?:\\.|[^"\\])*"', '""', self.candidate)
        stripped = code_mask(stripped)
        forbidden = ('POCResult', 'ENUM_POC_STATE', 'ComputePOCWithTieCore',
                     'ComputePOCWithTie', 'RebuildWeisCache', 'ComputeLiveWaveO1',
                     'Inp_POC_WindowSec', 'Inp_POC_FollowRatio', 'Inp_RejectPOCTies',
                     'pocNow', 'pocPrev', 'pocMove', 'pocState', 'contPocState',
                     'windowsValid', 'absPocContextOk', 'cont_poc_ok', 'wwValid')
        for token in forbidden:
            with self.subTest(token=token):
                self.assertNotRegex(stripped, r'\b' + token + r'\b')
        self.assertIn('if(s.absValid&&s.contValid)', self.candidate)
        self.assertIn('"ROUTE_CONFLICT_BLOCK"', self.candidate)

    def test_financial_management_precedes_analytical_service(self):
        tick = self.new['OnTick']
        service = tick.index('WWService();')
        for statement in ('SyncAccountingState();', 'UpdateMAEMFE();',
                          'ProcessEOD(hhmm);', 'ManageBreakEven();'):
            self.assertLess(tick.index(statement), service, statement)
        self.assertNotIn('WWReady()', tick[:service])
        timer = self.new['OnTimer']
        for statement in ('SyncAccountingState(true);', 'ReconcileBreakEvenProofs();',
                          'ProcessEOD(hhmm);'):
            self.assertLess(timer.index(statement), timer.index('WWService();'), statement)

    def test_closed_evidence_guards_and_boundary_order(self):
        engine = functions((ROOT / 'include/Weis1996Engine.mqh').read_text())
        freeze = engine['WWFreezeClosed']
        # A catch-up close cannot become a retrospective signal. The classifying
        # call sees only the book before any trade from the subsequent interval.
        self.assertIn('!gWWCaughtUp || endExclusive<=gWWAttachMsc', freeze)
        self.assertIn('bar!=iTime(Symbol(),Inp_SignalTF,1)', freeze)
        self.assertIn('OMClassify(gWWWaves,gWWLastPrice,endExclusive-1,c,gWWClosed)', freeze)
        chunk = engine['WWReadChunk']
        self.assertIn('(ulong)(endExclusive-1)', chunk)
        self.assertLess(chunk.index('WWApplyBatch('), chunk.index('WWFreezeClosed('))
        service = engine['WWServiceStep']
        self.assertIn('MathMin(until,MathMin(gWWCursor+(long)gWWChunkMsc,nextBar))', service)
        closed = engine['WWGetClosed']
        self.assertIn('barOpen!=gWWClosedBar', closed)
        self.assertIn('barOpen!=iTime(Symbol(),Inp_SignalTF,1)', closed)
        self.assertIn('end<=gWWAttachMsc', closed)

    def test_candidate_balanced_and_matrix_members_declared(self):
        # Lexical guard catches missing delimiters/removed-struct references, not MQL types.
        mask = code_mask(self.candidate)
        stack = []
        close = {'}': '{', ')': '(', ']': '['}
        for index, char in enumerate(mask):
            if char in '{([':
                stack.append((char, index))
            elif char in '})]':
                self.assertTrue(stack, f'extra {char} at {index}')
                start, _ = stack.pop()
                self.assertEqual(start, close[char], f'mismatch at {index}')
        self.assertFalse(stack)
        struct = re.search(r'struct MatrixSnapshot\s*\{([\s\S]*?)\};', self.candidate).group(1)
        fields = set()
        for statement in code_mask(struct).split(';'):
            words = re.findall(r'\b[A-Za-z_]\w*\b', statement)
            fields.update(words[1:])
        for name in ('ComputeMatrixSnapshot', 'ResetMatrixSnapshot', 'CsvMatrixRow'):
            used = set(re.findall(r'\bs\.(\w+)', code_mask(self.new[name])))
            self.assertFalse(used - fields, (name, used - fields))


if __name__ == '__main__':
    unittest.main(verbosity=2)
