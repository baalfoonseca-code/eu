// Actual adapter body with only MQL array/input syntax translated by runner.
#include <algorithm>
#include <cmath>
#include <cfloat>
#include <cstring>
#include <ctime>
#include <iostream>
#include <stdexcept>
#include <string>
#include <vector>
using ulong=unsigned long;
using uint=unsigned int;
using datetime=long;
using string=std::string;
constexpr double EMPTY_VALUE=DBL_MAX;
constexpr int TICK_FLAG_LAST=8,TICK_FLAG_VOLUME=16,TICK_FLAG_BUY=32,TICK_FLAG_SELL=64;
constexpr int COPY_TICKS_TRADE=1,TERMINAL_CONNECTED=1,MQL_TESTER=2,SERIES_SYNCHRONIZED=3;
constexpr int D1_SESSION_START=900,D1_SESSION_END_INDEX=1825,D1_SESSION_END_DOLLAR=1830;
double gTickSize=5,gABS_MinDisplPts=60,gCONT_MinDisplPts=50;
bool gIsIndexFamily=true,gIsDollarFamily=false;
double Inp_ABS_Effort=1.5,Inp_CONT_Effort=1.5;
int Inp_SignalTF=60;
struct MqlDateTime { int year,mon,day,hour,min,sec,day_of_year; };
struct MqlTick { datetime time{}; double bid{},ask{},last{}; ulong volume{}; long time_msc{}; uint flags{}; double volume_real{}; };
template<class T> void ZeroMemory(T &s) { std::memset(&s,0,sizeof(s)); }
bool MathIsValidNumber(double x) { return std::isfinite(x); }
double MathAbs(double x) { return std::abs(x); }
double MathMin(double a,double b) { return std::min(a,b); }
double MathMax(double a,double b) { return std::max(a,b); }
double MathRound(double x) { return std::round(x); }
template<class T> int ArraySize(const std::vector<T>& a) { return static_cast<int>(a.size()); }
template<class T> bool ArraySwap(std::vector<T>& a,std::vector<T>& b) { a.swap(b); return true; }
static bool mockFailResize=false;
template<class T> int ArrayResize(std::vector<T>& a,int n) { if(mockFailResize) { mockFailResize=false; return -1; } a.resize(n); return n; }
template<class T,size_t N,class V> void ArrayInitialize(T (&a)[N],V v) { std::fill(std::begin(a),std::end(a),static_cast<T>(v)); }
static long mockNow=0;
static ulong mockUs=0;
static int mockError=0,mockCopyError=0,mockCopyCalls=0;
static bool mockConnected=true,mockSynchronized=true,mockHasLatest=true;
static string mockSymbol="WIN_TEST";
static MqlTick mockLatest;
static std::vector<MqlTick> mockHistory;
long TimeTradeServer() { return mockNow; }
ulong GetMicrosecondCount() { return ++mockUs; }
string Symbol() { return mockSymbol; }
bool SymbolInfoTick(const string&,MqlTick &tick) { tick=mockLatest; return mockHasLatest; }
long TerminalInfoInteger(int) { return mockConnected; }
long MQLInfoInteger(int) { return 0; }
bool SymbolIsSynchronized(const string&) { return mockSynchronized; }
long SeriesInfoInteger(const string&,int,int) { return mockSynchronized; }
int PeriodSeconds(int tf) { return tf; }
long iTime(const string&,int tf,int shift) { return (mockNow/tf-shift)*tf; }
void TimeToStruct(long timestamp,MqlDateTime &s) {
    std::time_t t=timestamp; std::tm *v=std::gmtime(&t);
    s.year=v->tm_year+1900; s.mon=v->tm_mon+1; s.day=v->tm_mday;
    s.hour=v->tm_hour; s.min=v->tm_min; s.sec=v->tm_sec; s.day_of_year=v->tm_yday;
}
long StructToTime(const MqlDateTime &s) {
    std::tm t{}; t.tm_year=s.year-1900; t.tm_mon=s.mon-1; t.tm_mday=s.day;
    t.tm_hour=s.hour; t.tm_min=s.min; t.tm_sec=s.sec; return timegm(&t);
}
void ResetLastError() { mockError=0; }
int GetLastError() { return mockError; }
int CopyTicksRange(const string&,std::vector<MqlTick> &out,int,ulong from,ulong to) {
    ++mockCopyCalls; out.clear();
    if(mockCopyError) { mockError=mockCopyError; return -1; }
    for(const auto &tick:mockHistory)
        if(tick.time_msc>=static_cast<long>(from) && tick.time_msc<=static_cast<long>(to)) out.push_back(tick);
    return static_cast<int>(out.size());
}
#include "Weis1996Engine.host.hpp"

static constexpr long midnight=1736121600000L; // 2025-01-06 00:00 UTC
static constexpr long session=midnight; // Analytical collection starts at broker midnight, independent of entry hours.
static int passed=0;
static void require(bool ok,const char *why) { if(!ok) throw std::runtime_error(why); }
static bool near(double a,double b) { return std::abs(a-b)<1e-9; }
static MqlTick trade(long msc,double price=10000,ulong volume=1,double real=0) {
    MqlTick t{}; t.time=msc/1000; t.time_msc=msc; t.last=price;
    t.bid=price; t.ask=price+5; t.volume=volume; t.volume_real=real; t.flags=TICK_FLAG_LAST|TICK_FLAG_VOLUME;
    return t;
}
static void clock(long msc) { mockNow=msc/1000; mockLatest=trade(msc); }
static void fixture(long msc=session+1000) {
    mockHistory.clear(); mockFailResize=false; mockCopyError=0; mockCopyCalls=0; mockConnected=true;
    mockSynchronized=true; mockHasLatest=true; mockSymbol="WIN_TEST";
    clock(msc); require(WWInit(),"WWInit failed");
}
static void catchup() {
    for(int i=0;i<10000 && !WWReady() && !gWWFault;++i) WWService();
    require(WWReady(),gWWReason.c_str());
}
static void run(const char *name,void (*test)()) {
    test(); ++passed; std::cout << "PASS " << name << '\n';
}
int main() {
    try {
        run("before09_trade_collection_not_gated_by_D1_schedule", [] {
            fixture(midnight+8L*3600*1000); mockHistory={trade(midnight+8L*3600*1000,10000,7)};
            catchup(); require(gWWCursor>mockLatest.time_msc && gWWProcessedTrades==1,"before09 trade blocked by D1 schedule");
            require(gWWReason=="WEIS_READY" && near(gWWWaves.active.volume,7),"before09 collector unavailable");
        });
        run("after1825_trade_collection_not_capped_by_D1_schedule", [] {
            fixture(midnight+(19L*3600)*1000); mockHistory={trade(midnight+19L*3600*1000,10000,7)};
            catchup(); require(gWWCursor>mockLatest.time_msc && gWWProcessedTrades==1,"after1825 trade not collected");
            require(gWWReason=="WEIS_READY" && near(gWWWaves.active.volume,7),"after1825 collector capped");
        });
        run("same_ms_distinct_identical_trade_multiplicity", [] {
            fixture(); mockHistory={trade(session+1000,10000,2),trade(session+1000,10005,3),trade(session+1000,10005,3)};
            mockLatest=mockHistory.back(); catchup();
            require(gWWProcessedTrades==3 && near(gWWWaves.active.volume,8),"same-ms records dropped or doubled");
            WWService(); require(gWWProcessedTrades==3,"boundary reread duplicated trades");
        });
        run("same_ms_boundary_append_applied_once", [] {
            fixture(); mockHistory={trade(session+1000,10000,2)}; catchup();
            mockHistory.push_back(trade(session+1000,10005,3)); mockHistory.push_back(mockHistory.back());
            mockLatest=mockHistory.back(); WWService();
            require(WWReady() && gWWProcessedTrades==3 && near(gWWWaves.active.volume,8),"boundary suffix lost");
            WWService(); require(gWWProcessedTrades==3,"boundary suffix applied twice");
        });
        run("boundary_prefix_revision_fails_closed", [] {
            fixture(); mockHistory={trade(session+1000)}; catchup(); mockHistory[0].volume=2;
            WWService(); require(gWWFault && !WWReady(),"revised prefix accepted");
            require(gWWReason=="BOUNDARY_PREFIX_REVISED_RESTART_REQUIRED","wrong revision reason");
            require(gWWProcessedTrades==1,"revision changed committed volume");
        });
        run("boundary_multiplicity_removal_fails_closed", [] {
            fixture(); mockHistory={trade(session+1000),trade(session+1000)}; catchup(); mockHistory.pop_back();
            WWService(); require(gWWFault && !WWReady(),"removed record accepted");
            require(gWWReason=="BOUNDARY_MULTIPLICITY_REVISED_RESTART_REQUIRED","wrong removal reason");
        });
        run("history_unavailable_is_retryable_without_cursor_advance", [] {
            fixture(); mockHistory={trade(session+1000)}; long cursor=gWWCursor; mockCopyError=4401;
            WWService(); require(!WWReady() && !gWWFault && gWWCursor==cursor,"failed history committed");
            mockCopyError=0; catchup(); require(gWWProcessedTrades==1,"retry duplicate");
        });
        run("regressed_broker_clock_unavailable_until_recovered", [] {
            fixture(); mockHistory={trade(session+1000)}; catchup(); const long cursor=gWWCursor;
            clock(session+999); WWService();
            require(!WWReady() && !gWWFault && gWWReason=="BROKER_CLOCK_REGRESSED","regressed broker clock trusted");
            require(gWWCursor==cursor && gWWProcessedTrades==1,"clock regression changed collector state");
            clock(session+1000); catchup(); require(gWWProcessedTrades==1,"clock recovery duplicated volume");
        });
        run("boundary_allocation_failure_before_chunk_commit_is_retryable", [] {
            fixture(); mockHistory={trade(session+1000,10000,7)}; const long cursor=gWWCursor;
            mockFailResize=true; WWService();
            require(!gWWFault && !WWReady() && gWWCursor==cursor && gWWProcessedTrades==0,"allocation failure committed partial chunk");
            catchup(); require(gWWProcessedTrades==1 && gWWWaves.active.volume==7,"allocation retry changed multiplicity");
        });
        run("boundary_suffix_allocation_failure_leaves_committed_prefix_intact", [] {
            fixture(); mockHistory={trade(session+1000,10000,7)}; catchup();
            mockHistory.push_back(trade(session+1000,10005,3)); mockLatest=mockHistory.back();
            mockFailResize=true; WWService();
            require(!gWWFault && !WWReady() && gWWProcessedTrades==1 && gWWBoundary.size()==1,"suffix allocation corrupted prefix/state");
            catchup(); require(gWWProcessedTrades==2 && gWWWaves.active.volume==10,"suffix allocation retry doubled/lost print");
        });
        run("mixed_volume_sources_batch_is_atomic_and_fails_closed", [] {
            fixture(); mockHistory={trade(session+500,10000,2,2),trade(session+1000,10005,3,0)};
            WWService(); require(gWWFault && gWWReason=="VOLUME_SOURCE_MIXED","source mixture accepted");
            require(gWWProcessedTrades==0 && gWWWaves.active.id==0,"partial invalid batch committed");
        });
        run("integer_and_real_sources_each_supported_without_mix", [] {
            fixture(); mockHistory={trade(session+1000,10000,7)}; catchup();
            require(gWWSource==2 && near(gWWWaves.active.volume,7),"integer source wrong");
            fixture(); mockHistory={trade(session+1000,10000,7,2.5)}; catchup();
            require(gWWSource==1 && near(gWWWaves.active.volume,2.5),"real source wrong");
        });
        run("invalid_off_grid_record_is_rejected_atomically", [] {
            fixture(); mockHistory={trade(session+500),trade(session+1000,10001)};
            WWService(); require(gWWFault && gWWReason=="TRADE_RECORD_INVALID","off-grid accepted");
            require(gWWProcessedTrades==0,"invalid batch partially committed");
        });
        run("quote_only_record_never_becomes_executed_trade", [] {
            fixture(); MqlTick quote=trade(session+1000); quote.flags=2|4;
            mockHistory={quote}; WWService();
            require(gWWFault && gWWProcessedTrades==0,"quote counted as trade");
        });
        run("empty_intervals_do_not_fabricate_volume_or_gap_gate", [] {
            fixture(); mockHistory={trade(session+1000,10000,7)}; catchup(); const ulong count=gWWProcessedTrades;
            clock(session+180000); mockLatest.flags=2|4;
            for(int i=0;i<10;++i) WWService();
            require(WWReady() && gWWProcessedTrades==count && near(gWWWaves.active.volume,7),"empty interval invented trade or experimental gap gate");
            OMDecision d{}; require(WWLive(d),"verified last cannot survive quote-only update");
        });
        run("disconnect_reconnect_catchup_preserves_once_only_volume", [] {
            fixture(); mockHistory={trade(session+1000,10000,7)}; catchup();
            mockConnected=false; WWService(); require(!WWReady() && !gWWCaughtUp,"disconnect retained readiness");
            clock(session+130000); mockHistory.push_back(trade(session+130000,10060,11));
            mockConnected=true; catchup();
            require(gWWProcessedTrades==2 && near(gWWWaves.active.volume,18),"reconnect lost or duplicated history");
            require(gWWClosedBar==0,"reconnect generated historical closed signal");
        });
        run("new_day_resets_waves_and_volume_source", [] {
            fixture(); mockHistory={trade(session+1000,10000,7)}; catchup(); const ulong epoch=gWWEpoch;
            clock(session+86400000+1000); mockHistory={trade(session+86400000+1000,10000,9,3)}; WWService();
            require(WWReady() && gWWEpoch>epoch && gWWWaves.active.volume==3 && gWWSource==1,"new session contaminated by prior waves/source");
            require(gWWAttachMsc>=session+86400000+1000,"new session attach clock wrong");
        });
        run("contract_symbol_change_resets_analytical_state", [] {
            fixture(); mockHistory={trade(session+1000,10000,7)}; catchup(); const ulong epoch=gWWEpoch;
            mockSymbol="WIN_NEW"; mockHistory={trade(session+1000,20000,3)}; WWService();
            require(WWReady() && gWWEpoch>epoch && near(gWWWaves.active.volume,3) && near(gWWLastPrice,20000),"contract change retained old wave");
        });
        run("initial_attach_warmup_cannot_publish_old_close", [] {
            fixture(session+130000); mockHistory={trade(session+1000),trade(session+130000)}; catchup();
            require(gWWClosedBar==0,"restart reconstructed old signal"); OMDecision d{};
            require(!WWGetClosed((session+60000)/1000,d),"old close exposed");
        });
        run("new_closed_snapshot_is_causal_before_next_bar_trade", [] {
            fixture(); mockHistory={trade(session+1000,10000,1)}; catchup();
            mockHistory.push_back(trade(session+2000,10060,1));
            mockHistory.push_back(trade(session+3000,10000,1));
            mockHistory.push_back(trade(session+4000,10060,1));
            mockHistory.push_back(trade(session+5000,10000,1));
            mockHistory.push_back(trade(session+59999,9940,20));
            mockHistory.push_back(trade(session+60000,10000,13)); clock(session+60000); mockLatest=mockHistory.back();
            WWService(); catchup(); OMDecision d{},live{};
            require(WWGetClosed(session/1000,d),"fresh closed snapshot missing");
            require(gWWClosedBar==session/1000 && d.evidenceMsc==session+59999,"closed evidence clock wrong");
            require(d.classification==2 && d.dir==-1 && near(d.volume,21),"next-bar information contaminated frozen CONT sell");
            require(gWWWaves.active.volume==13 && gWWWaves.active.dir==1,"next-bar trade not exclusively in new live wave");
            require(WWLive(live) && live.classification==0,"live state did not reflect next-bar reversal");
        });
        run("late_boundary_append_invalidates_already_frozen_close", [] {
            fixture(); mockHistory={trade(session+1000,10000,7)}; catchup();
            clock(session+60000); mockLatest.flags=2|4; mockHistory.push_back(trade(session+59999,10060,11));
            WWService(); catchup(); require(gWWClosedBar==session/1000,"fresh snapshot not frozen"); const ulong epoch=gWWEpoch;
            mockHistory.push_back(trade(session+59999,10060,11)); WWService();
            require(gWWClosedBar==0 && gWWEpoch>epoch,"revised close silently reused");
            OMDecision d{}; require(!WWGetClosed(session/1000,d),"invalidated close available");
        });
        run("oversized_chunk_is_split_then_committed_without_duplicates", [] {
            fixture(session+10000);
            mockHistory.reserve(60000);
            for(int i=0;i<60000;++i) mockHistory.push_back(trade(session+(i%10000),10000,1));
            // Feed order must be temporal; 6 records per millisecond.
            std::sort(mockHistory.begin(),mockHistory.end(),[](const auto&a,const auto&b){ return a.time_msc<b.time_msc; });
            mockLatest=trade(session+10000); catchup();
            require(gWWProcessedTrades==60000 && near(gWWWaves.active.volume,60000),"adaptive chunk cap lost/doubled volume");
            require(mockCopyCalls>=3,"oversized interval was not split");
        });
        run("oversized_single_millisecond_is_explicitly_unprovable", [] {
            fixture(); mockHistory.assign(50001,trade(session+1000));
            for(int i=0;i<20 && !gWWFault;++i) WWService();
            require(gWWFault && !WWReady() && gWWProcessedTrades==0,"unbounded same-ms data processed");
        });
        std::cout << "RESULT " << passed << " adapter tests passed; broker API mocked, native MQL5/replay not executed\n";
    } catch(const std::exception &e) {
        std::cerr << "FAIL after " << passed << " adapter tests: " << e.what() << '\n'; return 1;
    }
}
