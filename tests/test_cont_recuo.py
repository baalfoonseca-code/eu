#!/usr/bin/env python3
"""Exercise the actual local 1.995 kernels/configuration, not native MetaTrader.

The previous kernel is read unchanged from the pre-correction Git commit. The
current kernel and WWConfiguration/WWValidateInputs bodies are compiled as-is
with explicit math/platform primitives. No strategy predicate is reimplemented.
"""
from pathlib import Path
import re
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
BASE = 'e98b9bbb2e36f48d1d32ada196d5d3c96741357d'
KERNEL = 'include/Weis1996Kernel.mqh'
ENGINE = 'include/Weis1996Engine.mqh'


def git_source(path):
    return subprocess.run(['git','show',BASE+':'+path],cwd=ROOT,check=True,
                          capture_output=True,text=True).stdout


def function(source,name):
    match = re.search(r'(?m)^\w+\s+'+re.escape(name)+r'\([^;]*?\)\s*\{',source)
    if match is None:
        raise AssertionError('Actual source function missing: '+name)
    index=source.index('{',match.start())+1
    depth=1; quoted=False; escaped=False
    while depth:
        char=source[index]
        if quoted:
            if escaped: escaped=False
            elif char=='\\': escaped=True
            elif char=='"': quoted=False
        elif char=='"': quoted=True
        elif char=='{': depth+=1
        elif char=='}': depth-=1
        index+=1
    return source[match.start():index]


def bare_kernel(source):
    # Include guards are the only removed syntax, to test both exact versions
    # in separate namespaces in one executable without header-guard suppression.
    return re.sub(r'^#(?:ifndef|define|endif)[^\n]*\n?', '', source, flags=re.M)


SHIM = r'''
#include <algorithm>
#include <cfloat>
#include <climits>
#include <cmath>
#include <cstring>
#include <iostream>
#include <stdexcept>
#include <string>
#include <type_traits>
using ulong=unsigned long;
constexpr double EMPTY_VALUE=DBL_MAX;
template<class T> void ZeroMemory(T &value){value=T{};}
bool MathIsValidNumber(double value){return std::isfinite(value);}
double MathAbs(double value){return std::abs(value);}
double MathMin(double a,double b){return std::min(a,b);}
double MathMax(double a,double b){return std::max(a,b);}
double MathRound(double value){return std::round(value);}
void require(bool condition,const char *reason){if(!condition)throw std::runtime_error(reason);}
'''

SUPPORT = r'''
using current::OMConfig;
using current::OMNumber;
bool gIsIndexFamily=true;
double gTickSize=5.0,gCONT_MinDisplPts=50.0,gABS_MinDisplPts=60.0;
double Inp_ABS_Effort=1.5,Inp_CONT_Effort=1.5;
void reset_inputs();
'''

FIXTURES = r'''
void reset_inputs(){
 Inp_WaveBaselineMin=3;Inp_WaveReversalPts_WIN=60;Inp_WaveReversalPts_WDO=2;
 Inp_PathEventTicks=2;Inp_CONT_MinPathEfficiency=.60;Inp_ABS_MaxPathEfficiency=.30;
 Inp_ABS_MinRejectionFraction=.35;Inp_CONT_MaxRecuoTicks_WIN=2;Inp_CONT_MaxRecuoTicks_WDO=2;
}
void family(bool win){
 reset_inputs();gIsIndexFamily=win;gTickSize=win?5.0:.5;
 gCONT_MinDisplPts=win?50.0:1.5;gABS_MinDisplPts=win?60.0:2.0;
}
old::OMConfig previous_config(const current::OMConfig &c){
 old::OMConfig out{};
 out.tick=c.tick;out.reversal=c.reversal;out.eventStep=c.eventStep;
 out.absEffort=c.absEffort;out.contEffort=c.contEffort;out.minCont=c.minCont;out.minAbs=c.minAbs;
 out.contEfficiency=c.contEfficiency;out.absEfficiency=c.absEfficiency;
 out.minRejection=c.minRejection;out.minWaves=c.minWaves;return out;
}
old::OMWaveBook previous_book(const current::OMWaveBook &book){
 static_assert(sizeof(old::OMWaveBook)==sizeof(current::OMWaveBook));
 static_assert(std::is_trivially_copyable<old::OMWaveBook>::value);
 static_assert(std::is_trivially_copyable<current::OMWaveBook>::value);
 old::OMWaveBook out{};std::memcpy(&out,&book,sizeof(out));return out;
}
template<class A,class B> void same_decision(const A &a,const B &b){
 require(a.classification==b.classification&&a.dir==b.dir&&a.reasonCode==b.reasonCode,"decision identity differs");
 require(a.waveID==b.waveID&&a.evidenceMsc==b.evidenceMsc,"decision provenance differs");
 require(a.effort==b.effort&&a.netProgress==b.netProgress&&a.grossPath==b.grossPath,"effort/progress/path differs");
 require(a.eventPath==b.eventPath&&a.pathEfficiency==b.pathEfficiency&&a.rejection==b.rejection,"efficiency/rejection differs");
 require(a.volume==b.volume&&a.velocity==b.velocity,"volume/velocity differs");
}
current::OMWaveBook baseline(){
 current::OMWaveBook book{};book.count=book.next=3;
 for(int i=0;i<3;i++)book.closedVolume[i]=100;
 return book;
}
void push(current::OMWaveBook &book,double price,double volume,long msc,const current::OMConfig &c){
 current::OMBands bands{};
 require(current::OMWavePush(book,price,volume,msc,c.reversal,c.eventStep,bands),"real OMWavePush rejected fixture");
}
current::OMWaveBook efficient(const current::OMConfig &c,int dir,double drawdown,double volume=150){
 auto book=baseline();double start=100000;
 push(book,start,50,1000,c);push(book,start+dir*20*c.tick,volume,1100,c);
 if(drawdown>0)push(book,start+dir*(20*c.tick-drawdown),10,1200,c);
 require(book.active.dir==dir,"fixture unexpectedly reversed wave");return book;
}
current::OMWaveBook inefficient(const current::OMConfig &c,int dir){
 auto book=baseline();double start=100000;
 const double peak=c.reversal/c.tick;
 push(book,start,50,1000,c);long msc=1100;
 for(int i=0;i<4;i++){
  push(book,start+dir*(peak-1)*c.tick,50,msc,c);msc+=100;
  push(book,start,50,msc,c);msc+=100;
 }
 push(book,start+dir*peak*c.tick,50,msc,c);msc+=100;
 const double rejection=std::ceil(c.minRejection*peak)*c.tick;
 push(book,start+dir*(peak*c.tick-rejection),10,msc,c);
 require(book.active.dir==dir,"inefficient fixture unexpectedly reversed");return book;
}
'''

MAIN = r'''
int main(int argc,char **argv){
 try{
  require(argc==2,"scenario required");std::string scenario=argv[1];
  if(scenario=="defaults_equivalent"){
   long comparisons=0;
   for(bool win:{true,false})for(int dir:{1,-1}){
    family(win);auto c=WWConfiguration();
    require(c.eventStep==2*c.tick&&c.contMaxRecuo==c.eventStep,"defaults not equal to old threshold");
    for(double ddTicks:{0.,.5,1.,1.999,2.,2.001,3.})for(double volume:{50.,75.,100.,150.,1000.}){
     auto book=efficient(c,dir,ddTicks*c.tick,volume);auto oldbook=previous_book(book);
     current::OMDecision now{};old::OMDecision before{};
     current::OMClassify(book,book.active.last,1300,c,now);
     old::OMClassify(oldbook,book.active.last,1300,previous_config(c),before);
     same_decision(now,before);comparisons++;
    }
   }
   std::cout<<"differential comparisons="<<comparisons<<"\n";
  }else if(scenario=="strict_grid_boundary"){
   for(bool win:{true,false})for(int dir:{1,-1})for(int ddTicks:{0,1,2,3}){
    family(win);auto c=WWConfiguration();auto book=efficient(c,dir,ddTicks*c.tick);
    current::OMDecision decision{};current::OMClassify(book,book.active.last,1300,c,decision);
    require(decision.classification==(ddTicks<2?(dir==1?1:2):0),"strict 0/1 pass and 2/3 fail violated");
   }
  }else if(scenario=="increase_only_drawdown_approval"){
   for(bool win:{true,false})for(int dir:{1,-1}){
    family(win);auto low=WWConfiguration();auto high=low;high.contMaxRecuo=3*low.tick;
    for(int ddTicks:{0,1,2,3}){
     auto book=efficient(low,dir,ddTicks*low.tick);auto frozen=book;
     current::OMDecision a{},b{};current::OMClassify(book,book.active.last,1300,low,a);
     current::OMClassify(book,book.active.last,1300,high,b);
     require(std::memcmp(&book,&frozen,sizeof(book))==0,"classification changed trajectory state");
     if(ddTicks<2)same_decision(a,b);
     if(ddTicks==2)require(a.classification==0&&b.classification==(dir==1?1:2),"raised limit changed wrong admission");
     if(ddTicks==3)require(a.classification==0&&b.classification==0,"strict raised boundary ignored");
    }
   }
  }else if(scenario=="abs_identical_for_active_and_previous"){
   for(bool win:{true,false})for(int dir:{1,-1}){
    family(win);auto cfg=WWConfiguration();auto book=inefficient(cfg,dir);
    current::OMDecision reference{};require(current::OMAbsEvidence(book.active,book.active.last,3000,cfg,reference),"fixture lacks ABS evidence");
    auto oldbook=previous_book(book);old::OMDecision original{};
    require(old::OMAbsEvidence(oldbook.active,book.active.last,3000,previous_config(cfg),original),"original ABS fixture invalid");
    same_decision(reference,original);
    for(int limit:{1,2,3,INT_MAX}){
     auto c=cfg;c.contMaxRecuo=(double)limit*c.tick;current::OMDecision direct{},classified{};
     require(current::OMAbsEvidence(book.active,book.active.last,3000,c,direct),"CONT tolerance changed direct ABS");same_decision(reference,direct);
     current::OMClassify(book,book.active.last,3000,c,classified);same_decision(reference,classified);
    }
    // End rejected attempt. It remains the previous-wave evidence, unchanged.
    push(book,book.active.start,100,3100,cfg);require(book.previous.id==reference.waveID,"previous ABS not retained");
    current::OMDecision previousRef{};
    require(current::OMAbsEvidence(book.previous,book.active.last,3200,cfg,previousRef),"previous ABS missing");
    for(int limit:{1,2,3,INT_MAX}){
     auto c=cfg;c.contMaxRecuo=(double)limit*c.tick;current::OMDecision d{},full{};
     require(current::OMAbsEvidence(book.previous,book.active.last,3200,c,d),"CONT tolerance changed previous ABS");same_decision(previousRef,d);
     current::OMClassify(book,book.active.last,3200,c,full);same_decision(previousRef,full);
    }
   }
  }else if(scenario=="existing_conflict_is_downstream_effect"){
   for(bool win:{true,false})for(int dir:{1,-1}){
    family(win);auto cfg=WWConfiguration();auto book=inefficient(cfg,dir);
    double start=book.active.start;push(book,start,100,3100,cfg);
    push(book,start-dir*20*cfg.tick,500,3200,cfg);
    push(book,start-dir*18*cfg.tick,10,3300,cfg);
    current::OMDecision absBefore{},absAfter{},low{},high{};
    require(current::OMAbsEvidence(book.previous,book.active.last,3400,cfg,absBefore),"previous ABS absent");
    current::OMClassify(book,book.active.last,3400,cfg,low);
    auto raised=cfg;raised.contMaxRecuo=3*cfg.tick;
    require(current::OMAbsEvidence(book.previous,book.active.last,3400,raised,absAfter),"raised limit modified ABS");same_decision(absBefore,absAfter);
    current::OMClassify(book,book.active.last,3400,raised,high);
    require(low.classification==(dir==1?4:3),"low threshold should preserve previous ABS");
    require(high.classification==0&&high.reasonCode==4,"newly admitted CONT must retain original conflict block");
   }
  }else if(scenario=="contract_family_and_sampling_are_independent"){
   for(bool win:{true,false}){
    family(win);Inp_CONT_MaxRecuoTicks_WIN=3;Inp_CONT_MaxRecuoTicks_WDO=7;
    auto c=WWConfiguration();require(c.contMaxRecuo==(win?3:7)*c.tick,"wrong contract tolerance used");
    require(c.eventStep==2*c.tick,"CONT parameter changed event step");
    auto before=c;Inp_PathEventTicks=1;auto changed=WWConfiguration();
    require(changed.eventStep==c.tick&&changed.contMaxRecuo==c.contMaxRecuo,"path parameter changed CONT tolerance");
    current::OMWaveBook a=baseline(),b=baseline();long msc=1000;
    for(double offset:{0.,1.,2.,1.,3.,2.,4.,20.}){
     push(a,100000+offset*c.tick,25,msc,before);push(b,100000+offset*c.tick,25,msc,changed);msc+=100;
    }
    require(a.active.eventPath!=b.active.eventPath,"sampling fixture did not alter event path");
    require(a.active.volume==b.active.volume&&a.active.grossPath==b.active.grossPath,"sampling changed raw accumulated trades");
    current::OMDecision da{},db{};
    current::OMClassify(a,a.active.last,msc,before,da);current::OMClassify(b,b.active.last,msc,changed,db);
    require(da.classification==1&&db.classification==1,"sampling fixture should retain recognized CONT");
    require(da.pathEfficiency!=db.pathEfficiency,"PathEventTicks must still affect actual Weis efficiency");
    require(WWValidateInputs(),"independent settings unexpectedly invalid");
   }
  }else if(scenario=="sampling_does_not_set_tolerance_anymore"){
   for(bool win:{true,false})for(int dir:{1,-1})for(int path:{1,3}){
    family(win);Inp_PathEventTicks=path;auto cfg=WWConfiguration();
    require(WWValidateInputs(),"valid non-default path setting rejected");
    double ddTicks=path==1?1:2;
    auto book=efficient(cfg,dir,ddTicks*cfg.tick);auto oldbook=previous_book(book);
    current::OMDecision now{};old::OMDecision before{};
    current::OMClassify(book,book.active.last,1300,cfg,now);
    old::OMClassify(oldbook,book.active.last,1300,previous_config(cfg),before);
    require(cfg.contMaxRecuo==2*cfg.tick,"sampling changed configured tolerance");
    require(now.classification==(path==1?(dir==1?1:2):0),"new independent tolerance wrong");
    require(before.classification==(path==3?(dir==1?1:2):0),"old coupled comparison fixture not discriminating");
   }
  }else if(scenario=="input_validation_positive_without_cap_or_dependency"){
   for(bool win:{true,false}){
    family(win);require(WWValidateInputs(),"defaults invalid");
    for(int invalid:{0,-1,INT_MIN}){
     Inp_CONT_MaxRecuoTicks_WIN=invalid;require(!WWValidateInputs(),"invalid WIN tolerance accepted");
     Inp_CONT_MaxRecuoTicks_WIN=2;Inp_CONT_MaxRecuoTicks_WDO=invalid;require(!WWValidateInputs(),"invalid WDO tolerance accepted");
     Inp_CONT_MaxRecuoTicks_WDO=2;
    }
    for(int path:{1,2,3}){
     Inp_PathEventTicks=path;Inp_CONT_MaxRecuoTicks_WIN=INT_MAX;Inp_CONT_MaxRecuoTicks_WDO=INT_MAX;
     require(WWValidateInputs(),"arbitrary tolerance cap/dependency introduced");
     auto c=WWConfiguration();require(c.contMaxRecuo==(double)INT_MAX*c.tick,"large tolerance wrong conversion");
     require(c.contEfficiency==.60&&c.absEfficiency==.30&&c.minRejection==.35&&c.minWaves==3,"preserved numeric criteria changed");
    }
    Inp_PathEventTicks=0;require(!WWValidateInputs(),"original zero sampling guard lost");
    Inp_PathEventTicks=100000;require(!WWValidateInputs(),"original reversal/event constraint lost");
   }
  }else throw std::runtime_error("unknown scenario");
  std::cout<<"PASS "<<scenario<<"\n";
 }catch(const std::exception &error){std::cerr<<error.what()<<"\n";return 1;}
}
'''


class ContRecuo(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.old_kernel=git_source(KERNEL)
        cls.kernel=(ROOT/KERNEL).read_text()
        cls.engine=(ROOT/ENGINE).read_text()
        if 'contMaxRecuo' not in cls.kernel:
            raise AssertionError('Current source correction not yet present; do not fake the new classifier')
        inputs=re.findall(r'(?m)^input\s+[^;]+;',cls.engine)
        input_declarations='\n'.join(re.sub(r'^input\s+','',line) for line in inputs)
        source=SHIM+'\nnamespace old {\n'+bare_kernel(cls.old_kernel)+'\n}\n'
        source+='namespace current {\n'+bare_kernel(cls.kernel)+'\n}\n'+SUPPORT
        source+=input_declarations+'\n'+function(cls.engine,'WWConfiguration')+'\n'+function(cls.engine,'WWValidateInputs')
        source+=FIXTURES+MAIN
        cls.temp=tempfile.TemporaryDirectory(prefix='s1995-cont-recuo-')
        cls.binary=Path(cls.temp.name)/'cont-recuo'
        cpp=Path(cls.temp.name)/'cont-recuo.cpp';cpp.write_text(source)
        subprocess.run(['g++','-std=c++17','-Wall','-Wextra','-Werror','-O2',str(cpp),'-o',str(cls.binary)],check=True)

    @classmethod
    def tearDownClass(cls):cls.temp.cleanup()
    def scenario(self,name):subprocess.run([str(self.binary),name],check=True)
    def test_default_two_ticks_matches_previous_kernel(self):self.scenario('defaults_equivalent')
    def test_strict_zero_one_accepted_two_three_rejected(self):self.scenario('strict_grid_boundary')
    def test_increasing_cont_limit_only_changes_drawdown_admission(self):self.scenario('increase_only_drawdown_approval')
    def test_abs_active_and_previous_evidence_mathematically_identical(self):self.scenario('abs_identical_for_active_and_previous')
    def test_conflict_block_is_preserved_as_downstream_effect(self):self.scenario('existing_conflict_is_downstream_effect')
    def test_WIN_WDO_and_sampling_independence(self):self.scenario('contract_family_and_sampling_are_independent')
    def test_positive_validation_without_arbitrary_cap_or_path_dependency(self):self.scenario('input_validation_positive_without_cap_or_dependency')
    def test_nondefault_sampling_does_not_set_CONT_tolerance(self):self.scenario('sampling_does_not_set_tolerance_anymore')
    def test_original_numeric_wave_and_abs_functions_unchanged(self):
        for name in ('OMNumber','OMWaveReset','OMBaseline','OMStartWave','OMWavePush','OMAbsEvidence'):
            self.assertEqual(function(self.old_kernel,name),function(self.kernel,name),name)
    def test_1996_reference_and_1995_operational_financial_EA_unchanged(self):
        for path in ('references/ObjectiveMatrix.e0bacb9.mqh','include/SignalLifecycle1995.mqh','eu1995'):
            self.assertEqual(git_source(path),(ROOT/path).read_text(),path)
        old_main=git_source('RemoraScalper1995_Weis1996.mq5')
        current_main=(ROOT/'RemoraScalper1995_Weis1996.mq5').read_text()
        names=re.findall(r'(?m)^\w+\s+(\w+)\s*\([^;{}]*\)\s*\{',old_main)
        self.assertGreater(len(names),300)
        # Only the now-obsolete predicate comment was updated in the EA.
        old_main=old_main.replace('// C1 uses the exact verified numeric classifier (including drawdown<eventStep).',
                                  '// C1 uses the verified wave classifier with an independent CONT drawdown limit.')
        for name in names:
            self.assertEqual(function(old_main,name),function(current_main,name),name)
        self.assertIn('drawdown<c.eventStep',git_source('references/ObjectiveMatrix.e0bacb9.mqh'))
        self.assertIn('drawdown<c.eventStep',(ROOT/'references/ObjectiveMatrix.e0bacb9.mqh').read_text())


if __name__=='__main__':unittest.main(verbosity=2)
