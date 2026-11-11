#!/usr/bin/env python3
"""Epoch review: real MQL helper/reset/process bodies with explicit service mocks.

This does not execute MetaTrader, broker requests or the financial protocol.
Only the one MQL integer-to-string cast is translated for portable compilation.
"""
from pathlib import Path
import re
import hashlib
import json
import sys
sys.dont_write_bytecode=True
from test_preservation import functions
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'RemoraScalper1995_Weis1996.mq5'


def function(text, name):
    match = re.search(r'(?m)^\w+\s+' + re.escape(name) + r'\([^;]*?\)\s*\{', text)
    if not match:
        raise AssertionError('missing function ' + name)
    level = 1
    index = text.index('{', match.start()) + 1
    quoted = False
    escape = False
    while level:
        char = text[index]
        if quoted:
            if escape: escape = False
            elif char == '\\': escape = True
            elif char == '"': quoted = False
        elif char == '"': quoted = True
        elif char == '{': level += 1
        elif char == '}': level -= 1
        index += 1
    return text[match.start():index]


def declaration(text, kind, name):
    return re.search(r'(?m)^' + kind + r' ' + name + r'\s*\{.*?\};', text, re.S)[0]


PREAMBLE = r'''
#include <algorithm>
#include <cmath>
#include <cfloat>
#include <cstring>
#include <iostream>
#include <stdexcept>
#include <string>
#include <vector>
using std::string;
using ulong=unsigned long;
using datetime=long;
constexpr double EMPTY_VALUE=DBL_MAX;
template<class T> void ZeroMemory(T &v) { v=T{}; }
bool MathIsValidNumber(double v){return std::isfinite(v);}
double MathAbs(double v){return std::abs(v);}
double MathMin(double a,double b){return std::min(a,b);}
double MathMax(double a,double b){return std::max(a,b);}
'''

MOCKS = r'''
ArmedSignal armed{};
ulong gWWEpoch=11;
struct Event { string event,id,reason; int direction; string route; };
std::vector<Event> events;
int farClears=0,clockReads=0,tickReads=0,farReads=0,sends=0;
int journalWrites=0,journalClears=0,pendingResets=0,positionChanges=0;
struct Pending { bool active=true,accepted=true; ulong order=99; };
Pending gPendingExec{},gPendingExit{};
bool gAccountingUnresolved=true;
struct OpenPosition { bool active=true; ulong id=77; } gOpenPos;
bool mockTickAvailable=false,mockTimedOut=false,mockLiveAvailable=false;
long mockNow=1000;
void WriteEntryDiagnostic(const ArmedSignal &s,string event) {
  events.push_back({event,s.signalID,s.lifecycleReason,s.dir,s.route});
}
void FARClearEvidence(){++farClears;}
void ResetPendingExec(){++pendingResets;++journalClears;gPendingExec.active=false;}
void PersistRequestJournal(){++journalWrites;}
long TimeTradeServer(){++clockReads;return mockNow;}
struct MqlDateTime {int hour=10,min=0;};
void TimeToStruct(datetime,MqlDateTime &d){d.hour=10;d.min=0;}
struct MqlTick {long time_msc=1000000;double last=200,bid=200,ask=200;unsigned flags=1;};
const unsigned TICK_FLAG_LAST=1,TICK_FLAG_VOLUME=2,TICK_FLAG_BUY=4,TICK_FLAG_SELL=8;
bool SymbolInfoTick(string,MqlTick &t){++tickReads;t=MqlTick{};return mockTickAvailable;}
string Symbol(){return "WIN";}
string DirStr(int d){return d==1?"BUY":"SELL";}
string DoubleToString(double d,int){return std::to_string(d);}
template<class... Args> void PrintFormat(const char*,Args...){ }
bool EntryTimeoutExpired(datetime,datetime,int){return mockTimedOut;}
int Inp_ArmedTimeoutSec=300,Inp_StopEntryHHMM=1530;
void WriteAuditRow(string event,string,string,double,double,double,double,double){
  armed.entryReason=event;armed.lifecycleReason=event;WriteEntryDiagnostic(armed,event);
}
bool FARBeforeDecision(){++farReads;return false;}
int ObserveEntryTrade(EntryTriggerState &,const MqlTick &,string &reason){reason="REAL_TRADE_CONFIRMED";return 1;}
double ArmedTriggerPrice(){return 200;}
bool ArmedTriggerReady(){return true;}
bool ValidateEntryDispatch(EntryTriggerState &,const MqlTick &,string &){return true;}
double gMaxOvershoot=100;
bool LiveWeisForArmed(const MqlTick &,double &eff,double &vol,double &avg,int &dir){
  eff=vol=avg=2;dir=armed.dir;return mockLiveAvailable;
}
string gWWReason="BOUNDARY_HISTORY_UNAVAILABLE";
void LLRecord(string event,const ArmedSignal &a,const OMDecision &,string reason){events.push_back({event,a.signalID,reason,a.dir,a.route});}
bool GetLiveVwapSnapshot(ulong,double &p){p=100;return true;}
double SigmaD1=10,gBandMultiplier=1,Inp_VWAP_Inner_Pct=.6,Inp_VWAP_Outer_Pct=1.5;
bool Inp_EnableLateDirectionBlock=false,gLiveDirectionTelemetryValid=false;
int gLiveDirAbs=0,gLiveDirCont=0;
bool gLateDirectionMismatch=false,gLateMismatchLogged=false;
bool HasExecutionInFlight(){return gPendingExec.active;}
bool HasOpenPosition(){return gOpenPos.active;}
int ordersEnteredToday=0,Inp_MaxTradesDay=10;
bool dailyRiskBlocked=false,gSpreadHoldLogged=false;
bool SpreadOk(){return true;}
double gLastBreakoutPrice=0;
bool SendOrder(int,double,string,double,double,double,double,double,double){++sends;return false;}
void require(bool condition,const char* message){if(!condition)throw std::runtime_error(message);}
void arm(string route,int direction){
  armed=ArmedSignal{};armed.active=true;armed.weisEpoch=10;armed.signalID="KNOWN_INTENTION";
  armed.dir=direction;armed.route=route;armed.mode="BASE";armed.armedAt=900;
  armed.entry.enabled=true;armed.entry.triggerReady=true;armed.entry.trigger=200;
  armed.weisEvidence.waveID=42;armed.weisEvidence.effort=1.5;
  armed.breakoutEffortMin=1.5;armed.lifecycleReason="ARMED";
}
void finance_unchanged(){
 require(gPendingExec.active&&gPendingExec.accepted&&gPendingExec.order==99,"pending entry changed");
 require(gPendingExit.active&&gPendingExit.accepted&&gPendingExit.order==99,"pending exit changed");
 require(gOpenPos.active&&gOpenPos.id==77&&gAccountingUnresolved,"financial ownership changed");
 require(journalWrites==0&&journalClears==0&&pendingResets==0&&positionChanges==0&&sends==0,"financial mutator called");
}
'''

MAIN = r'''
int main(int argc,char **argv){
 try {
  require(argc==2,"one scenario required");string scenario=argv[1];
  if(scenario=="terminal_routes"){
   for(const string &route:{string("ABS"),string("CONT")})for(int direction:{1,-1}){
    events.clear();arm(route,direction);int farBefore=farClears;
    require(ProcessArmedSignal()==APS_ENDED_FAIL_CLOSED,"epoch must terminate fail closed");
    require(!armed.active&&armed.signalID.empty()&&armed.weisEpoch==0,"analytical intention not cleared");
    require(events.size()==2,"expected exactly invalidation and end");
    require(events[0].event=="THESIS_INVALIDATED"&&events[1].event=="SIGNAL_END","event order wrong");
    for(const auto &e:events)require(e.id=="KNOWN_INTENTION"&&e.reason=="FROZEN_WEIS_EVIDENCE_REVISED"&&e.direction==direction&&e.route==route,"frozen identity/reason lost before event");
    require(farClears==farBefore+1,"FAR analytical evidence not cleared once");
    require(!EndRevisedWeisThesis()&&events.size()==2,"duplicate terminal event");
    require(clockReads==0&&tickReads==0&&farReads==0,"epoch depends on clock/tick/FAR");finance_unchanged();
   }
  }else if(scenario=="expired_mismatch"){
   arm("ABS",1);mockTimedOut=true;
   require(ProcessArmedSignal()==APS_ENDED_FAIL_CLOSED,"expired mismatch wrongly permits reevaluation");
   require(events.size()==2&&events[0].event=="THESIS_INVALIDATED","epoch reason obscured by timeout");finance_unchanged();
  }else if(scenario=="same_epoch_no_tick"){
   arm("CONT",-1);armed.weisEpoch=gWWEpoch;long armTime=armed.armedAt;
   require(ProcessArmedSignal()==APS_STILL_ARMED,"transient no-tick must wait");
   require(armed.active&&armed.armedAt==armTime&&events.empty()&&farClears==0,"same epoch state changed");finance_unchanged();
  }else if(scenario=="same_epoch_unready"){
   arm("CONT",1);armed.weisEpoch=gWWEpoch;mockTickAvailable=true;
   require(ProcessArmedSignal()==APS_STILL_ARMED,"transient unready must wait");
   require(armed.active&&armed.armedAt==900&&armed.entry.trigger==200,"transient state changed");
   require(events.size()==2&&events.back().event=="THESIS_REVALIDATION","unready wrongly marked terminal");
   require(farClears==0,"transient clears evidence");finance_unchanged();
  }else if(scenario=="same_epoch_timeout"){
   arm("ABS",-1);armed.weisEpoch=gWWEpoch;mockTimedOut=true;
   require(ProcessArmedSignal()==APS_ENDED_REEVAL_ALLOWED,"original timeout status changed");
   require(!armed.active&&events.size()==2&&events[0].event=="TIMEOUT_ARMED","original timeout trace changed");finance_unchanged();
  }else if(scenario=="inactive_noop"){
   armed.active=false;armed.weisEpoch=10;
   require(!EndRevisedWeisThesis()&&events.empty()&&farClears==0,"inactive helper has side effects");finance_unchanged();
  }else throw std::runtime_error("unknown scenario");
  std::cout<<"PASS "<<scenario<<"\n";
 }catch(const std::exception &e){std::cerr<<e.what()<<"\n";return 1;}
}
'''


class EpochReview(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.source=SOURCE.read_text()
        cls.baseline=json.loads((ROOT/'tests/fixtures/review_epoch_baseline.json').read_text())
        cls.temp=tempfile.TemporaryDirectory(prefix='s1995-review-epoch-')
        cls.binary=Path(cls.temp.name)/'epoch'
        kernel='#include "'+str(ROOT/'include/Weis1996Kernel.mqh')+'"\n'
        types='\n'.join([declaration(cls.source,'enum','ENUM_APS'),declaration(cls.source,'enum','ENTRY_PHASE'),declaration(cls.source,'struct','EntryTriggerState'),declaration(cls.source,'struct','ArmedSignal')])
        process=function(cls.source,'ProcessArmedSignal')
        if process.count('(string)waveDir')!=1:
            raise AssertionError('MQL cast changed: review portable translation')
        process=process.replace('(string)waveDir','std::to_string(waveDir)')
        bodies=function(cls.source,'ResetArmedSignal')+'\n'+function(cls.source,'EndRevisedWeisThesis')+'\n'+process
        cpp=Path(cls.temp.name)/'epoch.cpp'
        cpp.write_text(PREAMBLE+kernel+types+MOCKS+bodies+MAIN)
        subprocess.run(['g++','-std=c++17','-Wall','-Wextra','-Werror',str(cpp),'-o',str(cls.binary)],check=True)
        # Negative control: the exact pre-review Process body is refuted by
        # the same terminal scenario. Current helper is linked but this body
        # never invokes it; no strategy/financial code is rewritten for the test.
        cls.oldbinary=Path(cls.temp.name)/'epoch-before-review'
        oldprocess=cls.baseline['process_body'].replace('(string)waveDir','std::to_string(waveDir)')
        oldbodies=cls.baseline['reset_body']+'\n'+function(cls.source,'EndRevisedWeisThesis')+'\n'+oldprocess
        oldcpp=Path(cls.temp.name)/'epoch-before-review.cpp'
        oldcpp.write_text(PREAMBLE+kernel+types+MOCKS+oldbodies+MAIN)
        subprocess.run(['g++','-std=c++17','-Wall','-Wextra','-Werror',str(oldcpp),'-o',str(cls.oldbinary)],check=True)

    @classmethod
    def tearDownClass(cls):cls.temp.cleanup()
    def scenario(self,name):subprocess.run([str(self.binary),name],check=True)
    def test_terminal_routes_without_tick_or_breakout(self):self.scenario('terminal_routes')
    def test_mismatch_precedes_expired_timeout(self):self.scenario('expired_mismatch')
    def test_same_epoch_no_tick_keeps_intention(self):self.scenario('same_epoch_no_tick')
    def test_same_epoch_transient_unavailable_waits(self):self.scenario('same_epoch_unready')
    def test_same_epoch_original_timeout_preserved(self):self.scenario('same_epoch_timeout')
    def test_inactive_helper_has_no_effect(self):self.scenario('inactive_noop')
    def test_pre_review_process_is_refuted(self):
        result=subprocess.run([str(self.oldbinary),'terminal_routes'],capture_output=True,text=True)
        self.assertNotEqual(result.returncode,0)
        self.assertIn('epoch must terminate fail closed',result.stderr)

    def test_only_requested_functions_changed_from_delivered_baseline(self):
        current=functions(self.source)
        previous=self.baseline['function_sha256']
        self.assertEqual(set(current)-set(previous),{'EndRevisedWeisThesis'})
        self.assertEqual(set(previous)-set(current),set())
        changed={n for n,h in previous.items() if hashlib.sha256(current[n].encode()).hexdigest()!=h}
        self.assertEqual(changed,{'ProcessArmedSignal','OnTick','OnTimer'})
        for name,digest in self.baseline['include_sha256'].items():
            self.assertEqual(hashlib.sha256((ROOT/'include'/name).read_bytes()).hexdigest(),digest,name)

    def test_callback_order_and_no_same_callback_rearming(self):
        tick=function(self.source,'OnTick')
        expected=['SyncAccountingState();','ProcessEOD(hhmm);','ManageBreakEven();','WWService();','if(EndRevisedWeisThesis()) return;','bool newSig=','HasHardDirectionalContradiction','ProcessArmedSignal();','EvaluateMatrix();']
        positions=[tick.index(x) for x in expected]
        self.assertEqual(sorted(positions),positions)
        self.assertIn('if(outcome!=APS_ENDED_REEVAL_ALLOWED || !newSig) return;',tick)
        timer=function(self.source,'OnTimer')
        expected=['SyncAccountingState(true);','ReconcileBreakEvenProofs();','ProcessEOD(hhmm);','WWService();','EndRevisedWeisThesis();','LLFlush();']
        positions=[timer.index(x) for x in expected]
        self.assertEqual(sorted(positions),positions)
        helper=function(self.source,'EndRevisedWeisThesis')
        self.assertNotRegex(helper,r'ResetPending|Persist|Journal|OrderSend|SendOrder|PositionClose')


if __name__=='__main__':unittest.main(verbosity=2)
