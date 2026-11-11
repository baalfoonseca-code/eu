#!/usr/bin/env python3
"""Trace the real MaxBody predicate before/after POC removal; no MT5 claims."""
from pathlib import Path
import re
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
ORIGINAL = (ROOT / 'eu1995').read_text()
CANDIDATE = (ROOT / 'RemoraScalper1995_Weis1996.mq5').read_text()


def statement(source, target):
    match = re.search(r'(?m)^' + re.escape(target) + r'\s*=\s*[^;]+;', source)
    if not match:
        raise AssertionError('Missing actual source statement: ' + target)
    return match.group()


class MaxBodyReview(unittest.TestCase):
    def test_actual_original_and_candidate_c1_predicates(self):
        # Compile actual decision statements, not a hand-recreated classifier.
        old_block = ORIGINAL[ORIGINAL.index('// C1 ABS — fórmula'):ORIGINAL.index('// C1 CONT — fórmula')]
        new_block = statement(CANDIDATE, 's.c1')
        support = r'''
#include <cassert>
#include <iostream>
constexpr double Inp_ABS_Effort=1.5;
enum POC { POCS_INVALID, POCS_NO_DISPLACEMENT, POCS_FOLLOWING, POCS_DIVERGENT };
struct Decision { int classification=3, dir=1; };
struct Snapshot {
 bool wwok=true, windowsValid=true, displacementOk=false;
 double effort=1.5, candleBody=61, maxBody=60;
 int moveDir=0, dir=1, waveDir=0;
 POC pocState=POCS_NO_DISPLACEMENT;
 bool c1_effort_ok=false,c1_body_ok=false,c1_displacement_ok=false;
 bool c1_movedir_ok=false,c1_wavedir_ok=false;
 bool absDivergence=false,absStallStrict=false,absFollowingReaction=false,absFollowingExtension=false;
 bool absPocContextOk=false,c1=false;
 Decision weis;
};
'''
        main = r'''
int main() {
 Snapshot s;
 original(s); assert(!s.c1); // The original stall is rejected by a body above60.
 s.maxBody=70; original(s); assert(s.c1); // Same data, only old MaxBody differs.
 s.maxBody=60; s.pocState=POCS_DIVERGENT; original(s); assert(s.c1);
 s.maxBody=0.5; original(s); assert(s.c1); // No body AND in divergence.
 s.pocState=POCS_FOLLOWING; s.displacementOk=true; s.moveDir=s.dir;
 original(s); assert(s.c1); // Nor in following-reaction.
 s.pocState=POCS_NO_DISPLACEMENT; s.displacementOk=false; s.candleBody=61;
 for(double limit : {0.5,60.0,70.0,1000.0}) {
   s.maxBody=limit; s.weis.classification=3; candidate(s); assert(s.c1);
   s.weis.classification=0; candidate(s); assert(!s.c1);
 }
 // Candle body itself also cannot change candidate C1 once Weis evidence is fixed.
 s.weis.classification=3;
 for(double body : {0.0,61.0,10000.0}) { s.candleBody=body; candidate(s); assert(s.c1); }
 s.wwok=false; candidate(s); assert(!s.c1);
 s.wwok=true; s.weis.dir=-1; candidate(s); assert(!s.c1);
 std::cout << "PASS actual original stall body dependency, non-global original filter, candidate retirement and retained Weis gates\n";
}
'''
        source = support + '\nvoid original(Snapshot &s) {\n' + old_block + '\n}\n'
        source += '\nvoid candidate(Snapshot &s) {\n' + new_block + '\n}\n' + main
        with tempfile.TemporaryDirectory(prefix='max-body-review-') as temp:
            path = Path(temp)
            cpp, binary = path/'max-body.cpp', path/'max-body'
            cpp.write_text(source)
            subprocess.run(['g++','-std=c++17','-Wall','-Wextra','-Werror',str(cpp),'-o',str(binary)],check=True)
            subprocess.run([str(binary)],check=True)

    def test_retained_declarations_resolution_and_init_guard(self):
        for src in (ORIGINAL,CANDIDATE):
            for name,default in (('WIN','60.0'),('WDO','2.0')):
                self.assertRegex(src, r'input\s+double\s+Inp_ABS_MaxBodyPts_'+name+r'\s*=\s*'+re.escape(default)+r'\s*;')
            self.assertIn('gABS_MaxBodyPts=gIsIndexFamily?Inp_ABS_MaxBodyPts_WIN:Inp_ABS_MaxBodyPts_WDO;',src)
            self.assertIn('!Positive(gABS_MaxBodyPts)',src)
            self.assertEqual('s.maxBody =gABS_MaxBodyPts;',statement(src,'s.maxBody'))
        # C1 in candidate and the verified Weis module have no hidden MaxBody use.
        engine = (ROOT/'include/Weis1996Engine.mqh').read_text()
        kernel = (ROOT/'include/Weis1996Kernel.mqh').read_text()
        self.assertNotRegex(statement(CANDIDATE,'s.c1'),r'maxBody|candleBody|MaxBody')
        for helper in (engine,kernel):
            self.assertNotRegex(helper,r'\b(?:gABS_MaxBodyPts|Inp_ABS_MaxBodyPts_WIN|Inp_ABS_MaxBodyPts_WDO|c1_body_ok|absStallStrict)\b')
        # Snapshot metadata still stores the old value but candidate never reads it.
        uses = list(re.finditer(r'\bs\.maxBody\b',CANDIDATE))
        self.assertEqual(2,len(uses))
        for use in uses:
            tail=CANDIDATE[use.end():].lstrip()
            self.assertTrue(tail.startswith('='), 'MaxBody became an active consumer; re-audit its semantics')


if __name__ == '__main__':
    unittest.main()
