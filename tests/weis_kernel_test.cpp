// Portable tests of the literal MQL5 numerical kernel, not a MetaTrader test.
#include <algorithm>
#include <cmath>
#include <cfloat>
#include <cstring>
#include <iostream>
#include <limits>
#include <stdexcept>
#include <string>
#include <vector>

using ulong = unsigned long;
constexpr double EMPTY_VALUE = DBL_MAX;
template <class T> void ZeroMemory(T &v) { std::memset(&v, 0, sizeof(v)); }
bool MathIsValidNumber(double v) { return std::isfinite(v); }
double MathAbs(double v) { return std::abs(v); }
double MathMin(double a, double b) { return std::min(a, b); }
double MathMax(double a, double b) { return std::max(a, b); }
#include "../include/Weis1996Kernel.mqh"

static int passed = 0;
static void require(bool condition, const char *message) {
    if (!condition) throw std::runtime_error(message);
}
static bool near(double a, double b) { return std::abs(a-b) <= 1e-10; }
static OMConfig config() {
    OMConfig c{};
    c.tick=1; c.reversal=10; c.eventStep=2; c.contMaxRecuo=2;
    c.absEffort=1.5; c.contEffort=1.5; c.minCont=10; c.minAbs=10;
    c.contEfficiency=.60; c.absEfficiency=.30; c.minRejection=.35; c.minWaves=3;
    return c;
}
static OMWaveBook baseline(int count=3) {
    OMWaveBook b{};
    for (int i=0; i<count; ++i) b.closedVolume[i]=100;
    b.count=count; b.next=count % 10;
    return b;
}
static void push(OMWaveBook &b, double price, double volume, long msc) {
    OMConfig c=config(); OMBands bands{};
    require(OMWavePush(b, price, volume, msc, c.reversal, c.eventStep, bands), "push failed");
}
static OMWaveBook efficient(int direction=1) {
    OMWaveBook b=baseline();
    push(b,100,50,1000); push(b,100+direction*12,100,1100);
    return b;
}
static OMWaveBook inefficient(int direction=1, double volume=50, int count=3) {
    OMWaveBook b=baseline(count);
    const double offsets[]={0,8,1,9,2,10};
    for (int i=0; i<6; ++i) push(b,100+direction*offsets[i],volume,1000+i*100);
    return b;
}
static void run(const char *name, void (*test)()) {
    test(); ++passed; std::cout << "PASS " << name << '\n';
}
int main() {
    try {
        run("recognition_is_contemporaneous_not_backdated", [] {
            OMWaveBook b=baseline(); push(b,100,20,1000); push(b,109,20,1100);
            require(b.active.dir==0 && b.active.recognitionMsc==0,"recognized too early");
            push(b,110,20,1200);
            require(b.active.dir==1 && b.active.recognitionMsc==1200,"wrong recognition time");
            require(b.active.startMsc==1000,"original start lost");
        });
        run("baseline_excludes_active_and_is_frozen_at_start", [] {
            OMWaveBook b=baseline(); push(b,100,100000,1000);
            require(near(OMBaseline(b),100) && near(b.active.baseline,100),"active contaminated baseline");
            push(b,112,100000,1100);
            require(near(OMBaseline(b),100) && b.active.baselineCount==3,"baseline changed");
        });
        run("closed_wave_ring_is_bounded_to_ten", [] {
            OMWaveBook b{}; push(b,100,1,1000); push(b,112,1,1100);
            for (int i=0;i<25;++i) push(b,(i%2==0)?100:112,1,1200+i*100);
            require(b.count==10 && b.next>=0 && b.next<10,"ring unbounded");
            require(b.active.baselineCount==10 && OMBaseline(b)>0,"ring baseline invalid");
        });
        run("reversal_trade_belongs_once_to_new_wave", [] {
            OMWaveBook b=efficient(); const double before=b.active.volume;
            push(b,102,7,1200);
            require(b.previous.dir==1 && b.active.dir==-1,"reversal direction wrong");
            require(near(b.previous.volume,before) && near(b.active.volume,7),"reversal volume duplicated");
            require(b.active.startMsc==1200 && b.active.recognitionMsc==1200,"reversal backdated");
            require(b.count==4 && near(b.active.baseline,(300+before)/4),"closed baseline not updated");
        });
        run("same_millisecond_distinct_and_identical_trades_accumulate", [] {
            OMWaveBook b=baseline(); push(b,100,2,1000); push(b,101,3,1000); push(b,101,3,1000);
            require(near(b.active.volume,8),"same-ms multiplicity dropped");
            require(near(b.active.grossPath,1),"same-ms path wrong");
        });
        run("unordered_timestamp_rejected_without_state_change", [] {
            OMWaveBook b=efficient(); OMWaveBook before=b; OMBands bands{};
            require(!OMWavePush(b,113,2,999,10,2,bands),"out-of-order accepted");
            require(std::memcmp(&b,&before,sizeof(b))==0,"rejected record changed state");
        });
        run("invalid_price_volume_clock_and_scales_rejected", [] {
            OMWaveBook b{}; OMBands bands{};
            const double nan=std::numeric_limits<double>::quiet_NaN();
            require(!OMWavePush(b,0,1,1000,10,2,bands),"zero price accepted");
            require(!OMWavePush(b,nan,1,1000,10,2,bands),"NaN price accepted");
            require(!OMWavePush(b,100,0,1000,10,2,bands),"zero volume accepted");
            require(!OMWavePush(b,100,-1,1000,10,2,bands),"negative volume accepted");
            require(!OMWavePush(b,100,1,0,10,2,bands),"zero clock accepted");
            require(!OMWavePush(b,100,1,1000,0,2,bands),"zero reversal accepted");
            require(!OMWavePush(b,100,1,1000,10,0,bands),"zero event step accepted");
            require(b.active.id==0,"invalid input created wave");
        });
        run("ABS_sell_high_effort_inefficient_then_proved_rejection", [] {
            OMWaveBook b=inefficient(); push(b,106,50,1600); OMDecision d{};
            OMClassify(b,106,1600,config(),d);
            require(d.classification==4 && d.dir==-1,"ABS sell missing");
            require(near(d.pathEfficiency,10.0/38.0) && near(d.rejection,4),"ABS evidence wrong");
            require(near(d.effort,3) && near(d.volume,300),"ABS did not freeze peak effort");
        });
        run("ABS_buy_is_symmetric", [] {
            OMWaveBook b=inefficient(-1); push(b,94,50,1600); OMDecision d{};
            OMClassify(b,94,1600,config(),d);
            require(d.classification==3 && d.dir==1,"ABS buy missing");
            require(near(d.rejection,4),"symmetric rejection wrong");
        });
        run("ABS_high_effort_without_rejection_is_not_confirmed", [] {
            OMWaveBook b=inefficient(); OMDecision d{};
            OMClassify(b,110,1600,config(),d);
            require(d.classification==0,"ABS fabricated without rejection");
        });
        run("ABS_cannot_use_peak_or_future_timestamp", [] {
            OMWaveBook b=inefficient(); OMDecision d{};
            require(!OMAbsEvidence(b.active,106,1500,config(),d),"same-time peak treated as later rejection");
            require(!OMAbsEvidence(b.active,106,1499,config(),d),"future peak used");
        });
        run("ABS_insufficient_effort_rejected", [] {
            OMWaveBook b=inefficient(1,10); push(b,106,10,1600); OMDecision d{};
            OMClassify(b,106,1600,config(),d);
            require(d.classification==0,"low effort approved ABS");
        });
        run("ABS_efficient_progress_not_approved_by_volume_alone", [] {
            OMWaveBook b=efficient(); push(b,108,100,1200); OMDecision d{};
            require(!OMAbsEvidence(b.active,108,1200,config(),d),"efficient attempt classified ABS");
        });
        run("ABS_tick_and_fraction_rejection_thresholds_enforced", [] {
            OMWaveBook b=inefficient(); OMDecision d{};
            require(!OMAbsEvidence(b.active,109.5,1600,config(),d),"sub-tick rejection accepted");
            require(!OMAbsEvidence(b.active,107,1600,config(),d),"rejection fraction ignored");
            require(OMAbsEvidence(b.active,106.5,1600,config(),d),"exact fraction boundary rejected");
        });
        run("CONT_buy_high_effort_efficient_maintained_progress", [] {
            OMWaveBook b=efficient(); OMDecision d{}; OMClassify(b,112,1100,config(),d);
            require(d.classification==1 && d.dir==1 && near(d.pathEfficiency,1),"CONT buy missing");
        });
        run("CONT_sell_is_symmetric", [] {
            OMWaveBook b=efficient(-1); OMDecision d{}; OMClassify(b,88,1100,config(),d);
            require(d.classification==2 && d.dir==-1,"CONT sell missing");
        });
        run("CONT_drawdown_strictly_less_than_dedicated_tolerance", [] {
            OMWaveBook b=efficient(); push(b,111,10,1200); OMDecision d{};
            OMClassify(b,111,1200,config(),d); require(d.classification==1,"sub-limit drawdown rejected");
            push(b,110,10,1300); OMClassify(b,110,1300,config(),d);
            require(d.classification==0,"drawdown equal CONT tolerance accepted");
        });
        run("CONT_minimum_progress_enforced", [] {
            OMWaveBook b=efficient(); OMConfig c=config(); c.minCont=13; OMDecision d{};
            OMClassify(b,112,1100,c,d); require(d.classification==0,"small net approved CONT");
        });
        run("insufficient_baseline_neutral_for_both_routes", [] {
            OMWaveBook b=baseline(2); push(b,100,50,1000); push(b,112,100,1100); OMDecision d{};
            OMClassify(b,112,1100,config(),d);
            require(d.classification==0 && d.reasonCode==1,"CONT without baseline");
            b=inefficient(1,50,2); push(b,106,50,1600); OMClassify(b,106,1600,config(),d);
            require(d.classification==0 && d.reasonCode==1,"ABS without baseline");
        });
        run("high_volume_flat_price_is_neutral", [] {
            OMWaveBook b=baseline(); push(b,100,1000,1000); push(b,100,1000,1100); OMDecision d{};
            OMClassify(b,100,1100,config(),d); require(d.classification==0,"flat volume created thesis");
        });
        run("closed_original_ABS_wave_keeps_frozen_attempt_evidence", [] {
            OMWaveBook b=inefficient(); const ulong original=b.active.id;
            push(b,100,1,1600); OMDecision d{}; OMClassify(b,100,1600,config(),d);
            require(b.previous.id==original && b.active.id!=original,"wave did not close");
            require(d.classification==4 && d.waveID==original && near(d.effort,3),"previous ABS evidence lost");
        });
        run("simultaneous_real_cont_and_previous_abs_block_without_priority", [] {
            OMWaveBook b=inefficient(); push(b,100,1,1600); push(b,88,300,1700);
            OMDecision d{}; OMClassify(b,88,1700,config(),d);
            require(d.classification==0 && d.reasonCode==4,"same-side competing candidates silently prioritized");
        });
        run("event_sampling_does_not_replace_metric_by_gross_path", [] {
            OMWaveBook a=baseline(),b=baseline();
            push(a,100,50,1000); push(a,108,50,1100); push(a,110,50,1200);
            push(b,100,50,1000); push(b,101,0.5,1010); push(b,100,0.5,1020);
            push(b,108,49,1100); push(b,109,0.5,1110); push(b,108,0.5,1120); push(b,110,49,1200);
            require(near(a.active.eventPath,b.active.eventPath),"sub-event oscillations changed event path");
            require(b.active.grossPath>a.active.grossPath,"gross path not separately observable");
            OMDecision da{},db{}; OMClassify(a,110,1200,config(),da); OMClassify(b,110,1200,config(),db);
            require(da.classification==db.classification && near(da.pathEfficiency,db.pathEfficiency),"gross-path substituted into efficiency");
        });
        run("identical_price_fragmentation_keeps_event_path_and_total_volume", [] {
            OMWaveBook a=baseline(),b=baseline();
            push(a,100,50,1000); push(a,112,100,1100);
            push(b,100,25,1000); push(b,100,25,1000); push(b,112,25,1100);
            push(b,112,25,1100); push(b,112,25,1100); push(b,112,25,1100);
            require(near(a.active.volume,b.active.volume) && near(a.active.eventPath,b.active.eventPath),"fragmentation changed additive volume/event path");
            OMDecision da{},db{}; OMClassify(a,112,1200,config(),da); OMClassify(b,112,1200,config(),db);
            require(da.classification==db.classification && near(da.pathEfficiency,db.pathEfficiency),"identical-price fragmentation changed CONT");
            // Peak volume freezes at first newly observed extreme by reference design.
            require(a.active.peakVolume>b.active.peakVolume,"peak effort freeze behavior changed");
        });
        run("classification_rejects_invalid_clock_and_price", [] {
            OMWaveBook b=efficient(); OMDecision d{}; OMClassify(b,112,1099,config(),d);
            require(d.classification==0 && d.reasonCode==2,"past classification accepted");
            OMClassify(b,std::numeric_limits<double>::quiet_NaN(),1200,config(),d);
            require(d.classification==0 && d.reasonCode==2,"NaN close accepted");
        });
        std::cout << "RESULT " << passed << " tests passed; native MetaEditor and replay not executed\n";
    } catch (const std::exception &e) {
        std::cerr << "FAIL after " << passed << " tests: " << e.what() << '\n'; return 1;
    }
}
