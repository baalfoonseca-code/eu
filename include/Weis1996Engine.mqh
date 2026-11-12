// Rêmora 1.995 reconstruction: executed-trade adapter for the verified 1.996 kernel.
// Analytical state only. No order/position/journal access and no new entry clock.
#ifndef REMORA_1995_WEIS_1996_ENGINE_MQH
#define REMORA_1995_WEIS_1996_ENGINE_MQH
#include "Weis1996Kernel.mqh"

// Exact Weis defaults from the verified module. Existing effort/move inputs stay.
input int Inp_WaveBaselineMin=3;
input double Inp_WaveReversalPts_WIN=60.0;
input double Inp_WaveReversalPts_WDO=2.0;
input int Inp_PathEventTicks=2;
input double Inp_CONT_MinPathEfficiency=0.60;
input double Inp_ABS_MaxPathEfficiency=0.30;
input double Inp_ABS_MinRejectionFraction=0.35;
// 1.995 CONT drawdown only; independent of trajectory sampling.
input int Inp_CONT_MaxRecuoTicks_WIN=2;
input int Inp_CONT_MaxRecuoTicks_WDO=2;

// Collector work limits are the reference defaults, not strategic thresholds.
const int WW_CHUNK_MSC=10000;
const int WW_MAX_CHUNK_TRADES=50000;
const int WW_CHUNKS_PER_SERVICE=4;
OMWaveBook gWWWaves;
OMDecision gWWClosed;
datetime gWWClosedBar=0;
long gWWCursor=0,gWWLastTradeMsc=0,gWWAttachMsc=0,gWWBoundaryMsc=0;
long gWWSessionStart=0; // broker calendar-day replay origin; not an entry-session gate
MqlTick gWWBoundary[];
string gWWReason="NOT_INITIALIZED",gWWSymbol="";
int gWWDay=-1,gWWSource=0,gWWChunkMsc=WW_CHUNK_MSC;
bool gWWFault=false,gWWVerified=false,gWWCaughtUp=false;
double gWWLastPrice=0;
ulong gWWEpoch=0,gWWProcessedTrades=0;
ulong gWWServiceCosts[128],gWWLastServiceUs=0,gWWLastHistoryUs=0;
int gWWCostNext=0,gWWCostCount=0;
long gWWLastLagMsc=0;

OMConfig WWConfiguration()
{
   OMConfig c;
   c.tick=gTickSize;
   c.reversal=gIsIndexFamily?Inp_WaveReversalPts_WIN:Inp_WaveReversalPts_WDO;
   c.eventStep=Inp_PathEventTicks*gTickSize; c.absEffort=Inp_ABS_Effort;
   c.contMaxRecuo=(gIsIndexFamily?Inp_CONT_MaxRecuoTicks_WIN:Inp_CONT_MaxRecuoTicks_WDO)*gTickSize;
   c.contEffort=Inp_CONT_Effort; c.minCont=gCONT_MinDisplPts; c.minAbs=gABS_MinDisplPts;
   c.contEfficiency=Inp_CONT_MinPathEfficiency; c.absEfficiency=Inp_ABS_MaxPathEfficiency;
   c.minRejection=Inp_ABS_MinRejectionFraction; c.minWaves=Inp_WaveBaselineMin;
   return c;
}
bool WWValidateInputs()
{
   OMConfig c=WWConfiguration();
   return OMNumber(c.tick) && c.tick>0 && Inp_WaveBaselineMin>=1 &&
      Inp_WaveBaselineMin<=10 && OMNumber(c.reversal) && c.reversal>=c.tick &&
      MathAbs(c.reversal/c.tick-MathRound(c.reversal/c.tick))<=1e-6 &&
      Inp_PathEventTicks>=1 && c.reversal>=c.eventStep &&
      Inp_CONT_MaxRecuoTicks_WIN>0 && Inp_CONT_MaxRecuoTicks_WDO>0 &&
      OMNumber(Inp_CONT_MaxRecuoTicks_WIN*c.tick) &&
      OMNumber(Inp_CONT_MaxRecuoTicks_WDO*c.tick) &&
      OMNumber(c.contMaxRecuo) && c.contMaxRecuo>0 &&
      OMNumber(c.contEfficiency) && c.contEfficiency>0 && c.contEfficiency<=1 &&
      OMNumber(c.absEfficiency) && c.absEfficiency>=0 && c.absEfficiency<c.contEfficiency &&
      OMNumber(c.minRejection) && c.minRejection>0 && c.minRejection<=1 &&
      OMNumber(c.absEffort) && c.absEffort>0 && OMNumber(c.contEffort) && c.contEffort>0 &&
      OMNumber(c.minAbs) && c.minAbs>0 && OMNumber(c.minCont) && c.minCont>0;
}
void WWFail(string reason,bool permanent=false)
{
   gWWReason=reason; gWWVerified=false;
   if(permanent) { gWWFault=true; gWWEpoch++; }
}
void WWResetSession()
{
   OMWaveReset(gWWWaves); ZeroMemory(gWWClosed); gWWClosedBar=0;
   gWWCursor=0; gWWLastTradeMsc=0; gWWLastPrice=0; gWWSource=0;
   gWWBoundaryMsc=0; ArrayResize(gWWBoundary,0); gWWChunkMsc=WW_CHUNK_MSC;
   gWWFault=false; gWWVerified=false; gWWCaughtUp=false; gWWEpoch++;
   gWWSymbol=Symbol();
   MqlDateTime day; TimeToStruct(TimeTradeServer(),day);
   gWWDay=day.year*1000+day.day_of_year;
   day.hour=0; day.min=0; day.sec=0;
   long midnight=(long)StructToTime(day)*1000;
   // DailyReset already uses the broker calendar day. D1 calculation hours
   // are not entry-session boundaries and must not gate this analytical replay.
   gWWSessionStart=midnight;
   gWWCursor=gWWSessionStart;
   // A reconstructed close cannot become an entry retrospectively.
   gWWAttachMsc=(long)TimeTradeServer()*1000;
   MqlTick latest;
   if(SymbolInfoTick(Symbol(),latest) && latest.time_msc>gWWAttachMsc)
      gWWAttachMsc=latest.time_msc;
   gWWReason="HISTORY_CATCHUP_PENDING";
}
bool WWInit()
{
   if(!WWValidateInputs()) { WWFail("WEIS_INPUT_INVALID",true); return false; }
   gWWProcessedTrades=0; gWWCostNext=0; gWWCostCount=0;
   gWWLastServiceUs=0; gWWLastHistoryUs=0; gWWLastLagMsc=0;
   ArrayInitialize(gWWServiceCosts,0);
   WWResetSession();
   return true;
}
// Record validation follows the reference feed contract, without importing its
// experimental time-gap, dispersion, bands warmup or broker-session vetoes.
bool WWTradeValid(const MqlTick &t,double &volume,int &source)
{
   if(t.time_msc<=0 || t.time<=0 || (long)t.time!=t.time_msc/1000 ||
      !OMNumber(t.last) || t.last<=0 || !OMNumber(gTickSize) || gTickSize<=0 ||
      MathAbs(t.last/gTickSize-MathRound(t.last/gTickSize))>1e-6 ||
      !OMNumber(t.volume_real) || t.volume_real<0 ||
      (t.flags&(TICK_FLAG_LAST|TICK_FLAG_VOLUME|TICK_FLAG_BUY|TICK_FLAG_SELL))==0)
      return false;
   source=t.volume_real>0?1:2;
   volume=source==1?t.volume_real:(double)t.volume;
   return OMNumber(volume) && volume>0;
}
bool WWTickEqual(const MqlTick &a,const MqlTick &b)
{
   return a.time_msc==b.time_msc && a.time==b.time && a.last==b.last &&
      a.volume==b.volume && a.volume_real==b.volume_real && a.flags==b.flags;
}
// Validate the complete batch before committing numerical state. Same-ms prints
// remain separate records, including byte-identical prints with multiplicity.
bool WWApplyBatch(MqlTick &ticks[],int n,long from,long endExclusive)
{
   if(n<0 || n>WW_MAX_CHUNK_TRADES || n>ArraySize(ticks))
   { WWFail("CHUNK_SIZE_INVALID",true); return false; }
   int source=gWWSource; long previous=gWWLastTradeMsc;
   for(int i=0;i<n;i++)
   {
      double volume; int observed;
      if(ticks[i].time_msc<from || ticks[i].time_msc>=endExclusive ||
         ticks[i].time_msc<previous || !WWTradeValid(ticks[i],volume,observed))
      { WWFail("TRADE_RECORD_INVALID",true); return false; }
      if(source==0) source=observed;
      if(source!=observed) { WWFail("VOLUME_SOURCE_MIXED",true); return false; }
      previous=ticks[i].time_msc;
   }
   OMConfig c=WWConfiguration(); OMWaveBook next=gWWWaves;
   OMBands inert; ZeroMemory(inert);
   for(int i=0;i<n;i++)
   {
      double volume; int observed;
      if(!WWTradeValid(ticks[i],volume,observed) ||
         !OMWavePush(next,ticks[i].last,volume,ticks[i].time_msc,c.reversal,c.eventStep,inert))
      { WWFail("WAVE_ARITHMETIC_INVALID",true); return false; }
   }
   gWWWaves=next; gWWSource=source;
   if(n>0) { gWWLastTradeMsc=ticks[n-1].time_msc; gWWLastPrice=ticks[n-1].last; }
   gWWProcessedTrades+=(ulong)n;
   return true;
}
// Re-read the entire final millisecond and compare the old ordered prefix.
// Timestamp-only deduplication would discard legitimate trades, so is not used.
bool WWVerifyBoundary()
{
   if(gWWBoundaryMsc==0) return true;
   MqlTick ticks[]; ResetLastError();
   int n=CopyTicksRange(Symbol(),ticks,COPY_TICKS_TRADE,(ulong)gWWBoundaryMsc,(ulong)gWWBoundaryMsc);
   int error=GetLastError(),old=ArraySize(gWWBoundary);
   if(n<0 || error!=0) { WWFail("BOUNDARY_HISTORY_UNAVAILABLE"); return false; }
   if(n<old || n>WW_MAX_CHUNK_TRADES)
   { WWFail("BOUNDARY_MULTIPLICITY_REVISED_RESTART_REQUIRED",true); return false; }
   for(int i=0;i<old;i++)
      if(!WWTickEqual(ticks[i],gWWBoundary[i]))
      { WWFail("BOUNDARY_PREFIX_REVISED_RESTART_REQUIRED",true); return false; }
   if(n==old) return true;
   MqlTick suffix[]; int appended=n-old;
   if(ArrayResize(suffix,appended)!=appended)
   { WWFail("BOUNDARY_ALLOCATION_FAILED"); return false; }
   for(int i=0;i<appended;i++) suffix[i]=ticks[old+i];
   if(!WWApplyBatch(suffix,appended,gWWBoundaryMsc,gWWBoundaryMsc+1)) return false;
   // A frozen past close is never silently recomputed with newly discovered data.
   if(gWWClosedBar>0 && ((long)gWWClosedBar+PeriodSeconds(Inp_SignalTF))*1000>gWWBoundaryMsc)
   { ZeroMemory(gWWClosed); gWWClosedBar=0; gWWEpoch++; }
   if(!ArraySwap(gWWBoundary,ticks))
   { WWFail("BOUNDARY_SWAP_FAILED_AFTER_COMMIT",true); return false; }
   return true;
}
void WWFreezeClosed(long endExclusive)
{
   int period=PeriodSeconds(Inp_SignalTF);
   if(period<=0 || endExclusive%((long)period*1000)!=0) return;
   // During initial/reconnect catchup, historical closes are warmup only.
   if(!gWWCaughtUp || endExclusive<=gWWAttachMsc || gWWLastTradeMsc<=0) return;
   datetime bar=(datetime)(endExclusive/1000-period);
   if(bar!=iTime(Symbol(),Inp_SignalTF,1)) return;
   OMConfig c=WWConfiguration();
   OMClassify(gWWWaves,gWWLastPrice,endExclusive-1,c,gWWClosed);
   gWWClosedBar=bar;
}
// Each fresh chunk ends at/before an M1 boundary. The close snapshot is taken
// before consuming any trade of the next bar, even while recovering history.
bool WWReadChunk(long endExclusive)
{
   if(endExclusive<=gWWCursor) return false;
   MqlTick ticks[]; ResetLastError(); ulong begin=GetMicrosecondCount();
   int n=CopyTicksRange(Symbol(),ticks,COPY_TICKS_TRADE,(ulong)gWWCursor,(ulong)(endExclusive-1));
   gWWLastHistoryUs=GetMicrosecondCount()-begin;
   int error=GetLastError();
   if(n<0 || error!=0) { WWFail("TICK_HISTORY_UNAVAILABLE"); return false; }
   if(n>WW_MAX_CHUNK_TRADES)
   {
      // Do not commit or advance on an oversized interval. Halving is bounded
      // by one millisecond; a single-ms batch above the cap cannot be proved.
      if(endExclusive-gWWCursor<=1)
      { WWFail("SINGLE_MILLISECOND_TRADE_CAP_EXCEEDED",true); return false; }
      gWWChunkMsc=(int)MathMax(1,(endExclusive-gWWCursor)/2);
      WWFail("CHUNK_CAP_REDUCE_INTERVAL"); return false;
   }
   int boundaryStart=n; MqlTick boundary[];
   if(n>0)
   {
      boundaryStart=n-1;
      while(boundaryStart>0 && ticks[boundaryStart-1].time_msc==ticks[n-1].time_msc) boundaryStart--;
      if(ArrayResize(boundary,n-boundaryStart)!=n-boundaryStart)
      { WWFail("BOUNDARY_ALLOCATION_FAILED"); return false; }
      for(int i=boundaryStart;i<n;i++) boundary[i-boundaryStart]=ticks[i];
      // Reserve before committing the wave, but keep the old prefix intact on
      // any validation failure. ArraySwap below has no allocation after commit.
   }
   if(!WWApplyBatch(ticks,n,gWWCursor,endExclusive)) return false;
   if(n>0)
   {
      if(!ArraySwap(gWWBoundary,boundary))
      { WWFail("BOUNDARY_SWAP_FAILED_AFTER_COMMIT",true); return false; }
      gWWBoundaryMsc=ticks[n-1].time_msc;
   }
   gWWCursor=endExclusive; gWWVerified=true;
   WWFreezeClosed(endExclusive);
   return true;
}
void WWServiceStep()
{
   MqlDateTime day; TimeToStruct(TimeTradeServer(),day);
   int key=day.year*1000+day.day_of_year;
   if(gWWDay!=key || gWWSymbol!=Symbol()) WWResetSession();
   if(gWWFault) return;
   bool connected=TerminalInfoInteger(TERMINAL_CONNECTED)!=0 || MQLInfoInteger(MQL_TESTER)!=0;
   if(!connected)
   { gWWCaughtUp=false; ZeroMemory(gWWClosed); gWWClosedBar=0; WWFail("TERMINAL_DISCONNECTED"); return; }
   MqlTick latest;
   if(!SymbolInfoTick(Symbol(),latest) || latest.time_msc<=0 || latest.time<=0 ||
      (long)latest.time!=latest.time_msc/1000)
   { WWFail("BROKER_CLOCK_UNAVAILABLE"); return; }
   if(latest.time_msc<gWWLastTradeMsc || latest.time_msc+1<gWWCursor)
   { WWFail("BROKER_CLOCK_REGRESSED"); return; }
   if(latest.time_msc<gWWSessionStart)
   { WWFail("BROKER_DAY_TICK_UNAVAILABLE"); return; }
   if(!SymbolIsSynchronized(Symbol()) || !SeriesInfoInteger(Symbol(),Inp_SignalTF,SERIES_SYNCHRONIZED))
   { WWFail("HISTORY_NOT_SYNCHRONIZED"); return; }
   if(!WWVerifyBoundary()) return;
   long until=latest.time_msc+1;
   int period=PeriodSeconds(Inp_SignalTF);
   if(period<=0) { WWFail("SIGNAL_TIMEFRAME_UNAVAILABLE"); return; }
   ulong begin=GetMicrosecondCount();
   for(int work=0;work<WW_CHUNKS_PER_SERVICE && gWWCursor<until;work++)
   {
      long nextBar=(gWWCursor/((long)period*1000)+1)*((long)period*1000);
      long end=MathMin(until,MathMin(gWWCursor+(long)gWWChunkMsc,nextBar));
      if(!WWReadChunk(end)) break;
      if(GetMicrosecondCount()-begin>=10000) break; // soft CPU budget after bounded I/O
   }
   gWWLastLagMsc=latest.time_msc-gWWLastTradeMsc;
   if(gWWCursor<until) { if(gWWVerified) gWWReason="HISTORY_CATCHUP_PENDING"; return; }
   if(gWWLastTradeMsc<=0) { WWFail("EXECUTED_TRADES_UNAVAILABLE"); return; }
   gWWCaughtUp=true; gWWVerified=true; gWWReason="WEIS_READY";
}
void WWService()
{
   ulong begin=GetMicrosecondCount(); WWServiceStep();
   gWWLastServiceUs=GetMicrosecondCount()-begin;
   gWWServiceCosts[gWWCostNext]=gWWLastServiceUs; gWWCostNext=(gWWCostNext+1)%128;
   if(gWWCostCount<128) gWWCostCount++;
}
bool WWReady()
{
   return !gWWFault && gWWVerified && gWWCaughtUp && gWWReason=="WEIS_READY" &&
      gWWWaves.active.id>0;
}
bool WWLiveReady(long tickMsc)
{
   if(!WWReady() || tickMsc<=0 || gWWCursor<=tickMsc || tickMsc<gWWLastTradeMsc) return false;
   MqlTick latest;
   if(!SymbolInfoTick(Symbol(),latest) || latest.time_msc!=tickMsc) return false;
   uint flags=TICK_FLAG_LAST|TICK_FLAG_VOLUME|TICK_FLAG_BUY|TICK_FLAG_SELL;
   if((latest.flags&flags)!=0)
   {
      int n=ArraySize(gWWBoundary);
      if(latest.time_msc!=gWWLastTradeMsc || n<=0 || !WWTickEqual(latest,gWWBoundary[n-1])) return false;
   }
   // A quote-only update does not create a trade or replace its verified price.
   // Fresh SymbolInfoTick is only a clock/dispatch quote; the collector owns Last.
   return true;
}
bool WWGetClosed(datetime barOpen,OMDecision &d)
{
   ZeroMemory(d); int period=PeriodSeconds(Inp_SignalTF);
   long end=((long)barOpen+period)*1000;
   if(!WWReady() || period<=0 || barOpen!=gWWClosedBar ||
      barOpen!=iTime(Symbol(),Inp_SignalTF,1) || end<=gWWAttachMsc) return false;
   d=gWWClosed; return true;
}
bool WWLive(OMDecision &d)
{
   ZeroMemory(d); MqlTick latest;
   if(!SymbolInfoTick(Symbol(),latest) || !WWLiveReady(latest.time_msc)) return false;
   OMConfig c=WWConfiguration(); OMClassify(gWWWaves,gWWLastPrice,gWWCursor-1,c,d);
   return true;
}
bool WWFindWave(ulong id,OMWave &w)
{
   ZeroMemory(w);
   if(id==0) return false;
   if(gWWWaves.active.id==id) { w=gWWWaves.active; return true; }
   if(gWWWaves.previous.id==id) { w=gWWWaves.previous; return true; }
   return false;
}
// Stage 2 preserves 1.995 direction/effort semantics on the new causal active
// wave. It does not rerun C1 efficiency/rejection or import OMRevalidate policy.
bool WWLiveWave(double &effort,double &curVol,double &avgVol,int &dir)
{
   effort=0; curVol=0; avgVol=0; dir=0; MqlTick latest;
   if(!SymbolInfoTick(Symbol(),latest) || !WWLiveReady(latest.time_msc)) return false;
   OMWave w=gWWWaves.active;
   if(w.dir==0 || w.baselineCount<Inp_WaveBaselineMin || w.baseline<=0) return false;
   curVol=w.volume; avgVol=w.baseline; effort=curVol/avgVol; dir=w.dir;
   return OMNumber(effort) && OMNumber(curVol) && curVol>0;
}
void WWShutdown() { /* no file handles or processes owned by the analytical engine */ }
#endif
