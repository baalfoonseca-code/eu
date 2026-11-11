// Objective matrix research candidate. No order, position or financial journal access.
#ifndef REMORA_OBJECTIVE_MATRIX_MQH
#define REMORA_OBJECTIVE_MATRIX_MQH

// All added defaults are engineering/research hypotheses, not optimized values.
input int Inp_BandsWarmupSec=300;
input int Inp_BandsMinTrades=2; // Logical minimum for two distinct trade prices.
input double Inp_BandsMinSigmaTicks=1.0; // Experimental minimum dispersion on the trade grid; equality allowed.
input int Inp_RegularSessionStartHHMM=-1; // -1: exactly one published broker session.
input int Inp_RegularSessionEndHHMM=-1; // Both overrides required; broker server clock.
input int Inp_FeedMaxGapSec=30; // Experimental coverage diagnostic, not proof of completeness.
input int Inp_WaveBaselineMin=3; // Experimental minimum of prior CLOSED waves, max10.
input double Inp_WaveReversalPts_WIN=60.0;
input double Inp_WaveReversalPts_WDO=2.0;
input int Inp_PathEventTicks=2; // Causal sampling scale; raw path remains observable.
input double Inp_CONT_MinPathEfficiency=0.60;
input double Inp_ABS_MaxPathEfficiency=0.30;
input double Inp_ABS_MinRejectionFraction=0.35;
input int Inp_DataChunkMsc=10000;
input int Inp_DataMaxChunkTrades=50000;
input int Inp_DataChunksPerTimer=4;
input double Inp_SigmaCheckToleranceTicks=0.000001;

// OM_KERNEL_BEGIN
// This numeric kernel is compiled unchanged by the portable C++ harness.
// No MetaTrader services or financial state are used inside these markers.
struct OMBands
{
   bool ready;
   long asofMsc;
   double vwap,sigma,weight,width,upper1,upper2,upper3,lower1,lower2,lower3;
   long trades;
};
struct OMWeighted
{
   double weight,mean,m2;
   long trades;
   double minimum,maximum;
};
void OMWeightedReset(OMWeighted &s) { ZeroMemory(s); }
bool OMNumber(double n) { return MathIsValidNumber(n) && n!=EMPTY_VALUE; }
bool OMWeightedAdd(OMWeighted &s,double p,double w)
{
   if(!OMNumber(p) || !OMNumber(w) || p<=0 || w<=0 || s.trades>=2147483646)
      return false;
   OMWeighted next=s;
   double total=s.weight+w;
   if(!OMNumber(total) || total<=s.weight) return false;
   if(s.trades==0)
   { next.mean=p; next.m2=0; next.minimum=p; next.maximum=p; }
   else
   {
      double delta=p-s.mean;
      next.mean=s.mean+(w/total)*delta;
      next.m2=s.m2+w*delta*(p-next.mean);
      next.minimum=MathMin(s.minimum,p); next.maximum=MathMax(s.maximum,p);
   }
   next.weight=total; next.trades++;
   if(!OMNumber(next.mean) || !OMNumber(next.m2) || next.m2<0) return false;
   s=next;
   return true;
}
bool OMBuildBands(const OMWeighted &s,double k,long asof,OMBands &b)
{
   ZeroMemory(b); b.asofMsc=asof; b.weight=s.weight; b.trades=s.trades;
   if(s.trades<2 || !OMNumber(s.weight) || s.weight<=0 || !OMNumber(s.m2) ||
      s.m2<=0 || !OMNumber(k) || k<=0 || s.maximum<=s.minimum) return false;
   b.vwap=s.mean; b.sigma=MathSqrt(s.m2/s.weight); b.width=k*b.sigma;
   b.upper1=b.vwap+b.width; b.upper2=b.vwap+2*b.width; b.upper3=b.vwap+3*b.width;
   b.lower1=b.vwap-b.width; b.lower2=b.vwap-2*b.width; b.lower3=b.vwap-3*b.width;
   b.ready=OMNumber(b.upper3) && OMNumber(b.lower3) && b.width>0 && b.lower3>0;
   return b.ready;
}
struct OMWave
{
   ulong id;
   int dir;
   long startMsc,lastMsc,peakMsc,recognitionMsc;
   double start,last,high,low,volume,grossPath,eventPath,eventPrice,baseline;
   int baselineCount;
   double peakVolume,peakRaw,peakEvent,peakNet,peakEventNet;
   OMBands attemptBands;
};
struct OMWaveBook
{
   OMWave active,previous;
   double closedVolume[10];
   int count,next;
   ulong serial;
};
void OMWaveReset(OMWaveBook &b) { ZeroMemory(b); }
double OMBaseline(const OMWaveBook &b)
{
   double sum=0;
   for(int i=0;i<b.count;i++) sum+=b.closedVolume[i];
   return b.count>0?sum/b.count:0;
}
void OMStartWave(OMWaveBook &b,double p,double v,long msc,const OMBands &bands,int dir)
{
   ZeroMemory(b.active); b.serial++;
   b.active.id=b.serial; b.active.dir=dir;
   b.active.startMsc=msc; b.active.lastMsc=msc; b.active.peakMsc=msc;
   b.active.recognitionMsc=dir==0?0:msc;
   b.active.start=p; b.active.last=p; b.active.high=p; b.active.low=p;
   b.active.eventPrice=p; b.active.volume=v;
   b.active.baseline=OMBaseline(b); b.active.baselineCount=b.count;
   b.active.attemptBands=bands;
}
bool OMWavePush(OMWaveBook &b,double p,double v,long msc,double reversal,
                double eventStep,const OMBands &bands)
{
   if(!OMNumber(p) || !OMNumber(v) || p<=0 || v<=0 || msc<=0 ||
      !OMNumber(reversal) || reversal<=0 || !OMNumber(eventStep) || eventStep<=0)
      return false;
   if(b.active.id==0) { OMStartWave(b,p,v,msc,bands,0); return true; }
   OMWave w=b.active;
   if(msc<w.lastMsc) return false;
   // Recognition is contemporaneous. The pivot is never assigned a past entry.
   bool reversed=w.dir!=0 &&
      (w.dir==1?w.high-p>=reversal:p-w.low>=reversal);
   if(reversed)
   {
      b.previous=w;
      b.closedVolume[b.next]=w.volume;
      b.next=(b.next+1)%10; if(b.count<10) b.count++;
      OMStartWave(b,p,v,msc,bands,-w.dir);
      return true; // This actual trade belongs once, to the new recognized wave.
   }
   w.volume+=v; w.grossPath+=MathAbs(p-w.last);
   if(MathAbs(p-w.eventPrice)>=eventStep)
   { w.eventPath+=MathAbs(p-w.eventPrice); w.eventPrice=p; }
   w.last=p; w.lastMsc=msc;
   w.high=MathMax(w.high,p); w.low=MathMin(w.low,p);
   if(w.dir==0 && MathAbs(p-w.start)>=reversal)
   { w.dir=p>w.start?1:-1; w.recognitionMsc=msc; }
   if(w.dir!=0)
   {
      double progress=w.dir*(p-w.start);
      // Original effort snapshot frozen at the last newly observed extreme,
      // before subsequent rejection. Rejection cannot lower this efficiency.
      if(progress>w.peakNet)
      {
         w.peakNet=progress; w.peakVolume=w.volume; w.peakMsc=msc;
         w.peakRaw=w.grossPath; w.peakEvent=w.eventPath;
         w.peakEventNet=w.dir*(w.eventPrice-w.start);
      }
   }
   if(!OMNumber(w.volume) || !OMNumber(w.grossPath) || !OMNumber(w.eventPath)) return false;
   b.active=w;
   return true;
}
struct OMConfig
{
   double tick,reversal,eventStep,absEffort,contEffort,minCont,minAbs;
   double contEfficiency,absEfficiency,minRejection;
   int minWaves;
};
struct OMDecision
{
   int classification,dir,reasonCode;
   ulong waveID;
   double effort,netProgress,grossPath,eventPath,pathEfficiency,rejection,volume,velocity;
   long evidenceMsc;
};
// Codes:0 NEUTRO,1 CONT_BUY,2 CONT_SELL,3 ABS_BUY,4 ABS_SELL.
// Reason codes:1 baseline unavailable,2 trajectory unavailable,3 no proved thesis,4 conflict.
bool OMAbsEvidence(const OMWave &w,double close,long msc,const OMConfig &c,
                   OMDecision &d)
{
   if(w.dir==0 || w.baselineCount<c.minWaves || w.baseline<=0 ||
      w.peakNet<c.minAbs || w.peakEvent<=0 || w.peakEventNet<=0 ||
      w.peakVolume<=0 || msc<=w.peakMsc) return false;
   // Up attempt rejects downward, down attempt upward.
   double rejection=w.dir==1?w.high-close:close-w.low;
   if(rejection<c.tick || rejection<c.minRejection*w.peakNet ||
      w.peakVolume/w.baseline<c.absEffort ||
      w.peakEventNet/w.peakEvent>c.absEfficiency) return false;
   ZeroMemory(d); d.classification=w.dir==1?4:3; d.dir=-w.dir; d.waveID=w.id;
   d.effort=w.peakVolume/w.baseline; d.netProgress=w.peakNet;
   d.grossPath=w.peakRaw; d.eventPath=w.peakEvent;
   d.pathEfficiency=w.peakEventNet/w.peakEvent; d.rejection=rejection;
   d.volume=w.peakVolume; d.evidenceMsc=msc;
   d.velocity=w.peakMsc>w.startMsc?1000*w.peakVolume/(w.peakMsc-w.startMsc):0;
   return true;
}
void OMClassify(const OMWaveBook &b,double close,long msc,const OMConfig &c,OMDecision &d)
{
   ZeroMemory(d); d.reasonCode=3;
   const OMWave w=b.active;
   if(w.id==0 || !OMNumber(close) || close<=0 || msc<w.lastMsc)
   { d.reasonCode=2; return; }
   OMDecision cont,absNow,absPrevious;
   ZeroMemory(cont); ZeroMemory(absNow); ZeroMemory(absPrevious);
   if(w.baselineCount<c.minWaves || w.baseline<=0) d.reasonCode=1;
   if(w.dir!=0 && w.baselineCount>=c.minWaves && w.baseline>0 && w.eventPath>0)
   {
      double net=w.dir*(close-w.start);
      double eventNet=w.dir*(w.eventPrice-w.start);
      double efficiency=eventNet/w.eventPath;
      double drawdown=w.dir==1?w.high-close:close-w.low;
      if(net>=c.minCont && eventNet>0 && efficiency>=c.contEfficiency &&
         w.volume/w.baseline>=c.contEffort && drawdown<c.eventStep)
      {
         cont.classification=w.dir==1?1:2; cont.dir=w.dir; cont.waveID=w.id;
         cont.effort=w.volume/w.baseline; cont.netProgress=net;
         cont.grossPath=w.grossPath; cont.eventPath=w.eventPath;
         cont.pathEfficiency=efficiency; cont.volume=w.volume; cont.evidenceMsc=msc;
         cont.velocity=w.lastMsc>w.startMsc?1000*w.volume/(w.lastMsc-w.startMsc):0;
      }
   }
   bool a=OMAbsEvidence(w,close,msc,c,absNow);
   bool p=b.previous.id>0 && OMAbsEvidence(b.previous,close,msc,c,absPrevious);
   int candidates=(cont.classification>0?1:0)+(a?1:0)+(p?1:0);
   if(candidates>1) { d.reasonCode=4; return; } // No arbitrary priority, even same side.
   if(cont.classification>0) d=cont;
   else if(a) d=absNow;
   else if(p) d=absPrevious;
}
bool OMLocationEligible(int classification,double price,const OMBands &b)
{
   if(!b.ready || !OMNumber(price) || price<=0 || price==b.vwap) return false;
   if(classification==1) return price>b.vwap && price<=b.upper2;
   if(classification==2) return price<b.vwap && price>=b.lower2;
   if(classification==3) return price<b.vwap;
   if(classification==4) return price>b.vwap;
   return false;
}
bool OMInsideB3(int dir,double price,const OMBands &b)
{
   return b.ready && OMNumber(price) && price>0 &&
      (dir==1?price<b.upper3:(dir==-1?price>b.lower3:false));
}
// OM_KERNEL_END

struct OMThesis
{
   bool detected,eligible;
   int dir,classification;
   string route,reason;
   ulong waveID,dataEpoch;
   double price,effort,netProgress,grossPath,eventPath,pathEfficiency,rejection;
   double testHigh,testLow,velocity,rawEfficiency,residual;
   long evidenceMsc;
   OMBands bands,attemptBands;
};
OMWeighted gOMWeighted,gOMReference;
OMWaveBook gOMWaves;
OMBands gOMLive,gOMContext;
OMThesis gOMClosed;
datetime gOMSessionOpen=0,gOMSessionEnd=0,gOMClosedBar=0,gOMContextBar=0;
long gOMCursor=0,gOMLastTradeMsc=0,gOMAttachMsc=0,gOMBoundaryMsc=0;
MqlTick gOMBoundary[];
bool gOMFault=false,gOMConnected=false,gOMVerified=false;
int gOMSource=0,gOMDay=-1;
ulong gOMEpoch=0;
string gOMReason="NOT_INITIALIZED",gOMLastReportedReason="";
double gOMLastPrice=0,gOMErrorMean=0,gOMErrorSigma=0;
int gOMLog=INVALID_HANDLE;
long gOMLastFlush=0,gOMFirstReady=0,gOMLastMetricMsc=0;
ulong gOMServiceCosts[128];
int gOMCostNext=0,gOMCostCount=0;
long gOMZoneTrades[4],gOMZoneMsc[4],gOMVisits[3],gOMFirstVisit[3];
double gOMZoneVolume[4];
int gOMPreviousZone=-1;
double gOMMinSigma=0,gOMMaxSigma=0;
double gOMPreMinSigma=0,gOMPreMaxSigma=0,gOMPriorSigma=0,gOMRelativeSigmaChange=0;

bool OMClockHHMM(int h) { return h>=0 && h/100<24 && h%100<60; }
bool OMValidateInputs()
{
   double reversal=gIsIndexFamily?Inp_WaveReversalPts_WIN:Inp_WaveReversalPts_WDO;
   bool overrides=Inp_RegularSessionStartHHMM!=-1 || Inp_RegularSessionEndHHMM!=-1;
   if(overrides && (!OMClockHHMM(Inp_RegularSessionStartHHMM) ||
      !OMClockHHMM(Inp_RegularSessionEndHHMM) ||
      Inp_RegularSessionStartHHMM>=Inp_RegularSessionEndHHMM)) return false;
   return Inp_BandsWarmupSec>=0 && Inp_BandsMinTrades>=2 &&
      OMNumber(Inp_BandsMinSigmaTicks) && Inp_BandsMinSigmaTicks>0 &&
      Inp_FeedMaxGapSec>0 && Inp_WaveBaselineMin>=1 && Inp_WaveBaselineMin<=10 &&
      OMNumber(reversal) && reversal>=gTickSize &&
      MathAbs(reversal/gTickSize-MathRound(reversal/gTickSize))<=1e-6 &&
      Inp_PathEventTicks>=1 && reversal>=Inp_PathEventTicks*gTickSize &&
      OMNumber(Inp_CONT_MinPathEfficiency) && Inp_CONT_MinPathEfficiency>0 &&
      Inp_CONT_MinPathEfficiency<=1 && OMNumber(Inp_ABS_MaxPathEfficiency) &&
      Inp_ABS_MaxPathEfficiency>=0 && Inp_ABS_MaxPathEfficiency<Inp_CONT_MinPathEfficiency &&
      OMNumber(Inp_ABS_MinRejectionFraction) && Inp_ABS_MinRejectionFraction>0 &&
      Inp_ABS_MinRejectionFraction<=1 && Inp_DataChunkMsc>=1 && Inp_DataChunkMsc<=60000 &&
      Inp_DataMaxChunkTrades>=2 && Inp_DataMaxChunkTrades<=1000000 &&
      Inp_DataChunksPerTimer>=1 && Inp_DataChunksPerTimer<=16 &&
      OMNumber(Inp_SigmaCheckToleranceTicks) && Inp_SigmaCheckToleranceTicks>0;
}
OMConfig OMConfiguration()
{
   OMConfig c;
   c.tick=gTickSize;
   c.reversal=gIsIndexFamily?Inp_WaveReversalPts_WIN:Inp_WaveReversalPts_WDO;
   c.eventStep=Inp_PathEventTicks*gTickSize; c.absEffort=Inp_ABS_Effort;
   c.contEffort=Inp_CONT_Effort; c.minCont=gCONT_MinDisplPts; c.minAbs=gABS_MinDisplPts;
   c.contEfficiency=Inp_CONT_MinPathEfficiency; c.absEfficiency=Inp_ABS_MaxPathEfficiency;
   c.minRejection=Inp_ABS_MinRejectionFraction; c.minWaves=Inp_WaveBaselineMin;
   return c;
}
void OMClose()
{
   if(gOMLog!=INVALID_HANDLE)
   { FileFlush(gOMLog); FileClose(gOMLog); gOMLog=INVALID_HANDLE; }
}
void OMReset()
{
   OMWeightedReset(gOMWeighted); OMWeightedReset(gOMReference); OMWaveReset(gOMWaves);
   gOMEpoch++;
   ZeroMemory(gOMLive); ZeroMemory(gOMContext); ZeroMemory(gOMClosed);
   gOMSessionOpen=0; gOMSessionEnd=0; gOMCursor=0; gOMLastTradeMsc=0;
   gOMClosedBar=0; gOMContextBar=0; gOMBoundaryMsc=0; ArrayResize(gOMBoundary,0);
   gOMFault=false; gOMVerified=false; gOMSource=0; gOMReason="SESSION_NOT_RESOLVED";
   gOMLastPrice=0; gOMErrorMean=0; gOMErrorSigma=0; gOMFirstReady=0;
   gOMLastMetricMsc=0; gOMPreviousZone=-1; gOMMinSigma=0; gOMMaxSigma=0;
   gOMPreMinSigma=0; gOMPreMaxSigma=0; gOMPriorSigma=0; gOMRelativeSigmaChange=0;
   ArrayInitialize(gOMZoneTrades,0); ArrayInitialize(gOMZoneMsc,0);
   ArrayInitialize(gOMZoneVolume,0); ArrayInitialize(gOMVisits,0);
   ArrayInitialize(gOMFirstVisit,0);
   MqlTick tick;
   gOMAttachMsc=SymbolInfoTick(Symbol(),tick)?tick.time_msc:(long)TimeTradeServer()*1000;
   MqlDateTime day; TimeToStruct(TimeTradeServer(),day);
   gOMDay=day.year*1000+day.day_of_year;
   gOMConnected=TerminalInfoInteger(TERMINAL_CONNECTED)!=0 || MQLInfoInteger(MQL_TESTER)!=0;
   if(gOMLog==INVALID_HANDLE)
   {
      string path="ScalperObjective_v1_"+Symbol()+"_"+(string)TimeLocal()+"_"+
         (string)GetMicrosecondCount()+".csv";
      gOMLog=FileOpen(path,FILE_WRITE|FILE_TXT|FILE_ANSI|FILE_SHARE_READ);
      if(gOMLog!=INVALID_HANDLE)
         FileWriteString(gOMLog,"EVENT,ASOF_MSC,REASON,READY,W,TRADES,VWAP,SIGMA,B1_UP,B2_UP,B3_UP,B1_DN,B2_DN,B3_DN,MEAN_ERROR_TICKS,SIGMA_ERROR_TICKS,CLASSIFICATION,DIRECTION,LOCATION_ELIGIBLE,WAVE_ID,EFFORT,NET,RAW_PATH,EVENT_PATH,EVENT_EFFICIENCY,RAW_EFFICIENCY,EVENT_RESIDUAL,REJECTION,VOLUME_PER_SEC,ATTEMPT_ASOF,ELAPSED_SESSION_SEC,FIRST_READY_SEC,SIGMA_MIN,SIGMA_MAX,B1_VISITS,B2_VISITS,B3_VISITS,B1_FIRST_SEC,B2_FIRST_SEC,B3_FIRST_SEC,Z0_TRADES,Z1_TRADES,Z2_TRADES,Z3_TRADES,Z0_MSC,Z1_MSC,Z2_MSC,Z3_MSC,Z0_VOLUME,Z1_VOLUME,Z2_VOLUME,Z3_VOLUME,SERVICE_P95_US,SERVICE_P99_US,SERVICE_MAX_US,VOLUME_SOURCE,ACTIVE_WAVE_DIRECTION,ACTIVE_START_MSC,ACTIVE_RECOGNITION_MSC,ACTIVE_PEAK_MSC,PRE_READY_SIGMA_MIN,PRE_READY_SIGMA_MAX,RELATIVE_SIGMA_CHANGE,LAST_PRICE,SIGNED_DISTANCE_TO_B1,SIGNED_DISTANCE_TO_B2,SIGNED_DISTANCE_TO_B3,ATTEMPT_VWAP,ATTEMPT_SIGMA,ATTEMPT_WIDTH\r\n");
   }
}
void OMFail(string reason,bool permanent=false)
{
   gOMReason=reason; gOMLive.ready=false; gOMVerified=false;
   if(permanent) gOMFault=true;
}
bool OMResolveSession()
{
   MqlDateTime day; TimeToStruct(TimeTradeServer(),day);
   day.hour=0; day.min=0; day.sec=0; datetime midnight=StructToTime(day);
   datetime from,to; int count=0;
   datetime onlyFrom=0,onlyTo=0;
   for(uint index=0;index<16;index++)
   {
      if(!SymbolInfoSessionTrade(Symbol(),(ENUM_DAY_OF_WEEK)day.day_of_week,index,from,to)) break;
      count++; onlyFrom=from; onlyTo=to;
   }
   if(count==0) { OMFail("SESSION_SCHEDULE_UNAVAILABLE"); return false; }
   if(Inp_RegularSessionStartHHMM>=0)
   {
      gOMSessionOpen=midnight+(Inp_RegularSessionStartHHMM/100)*3600+
         (Inp_RegularSessionStartHHMM%100)*60;
      gOMSessionEnd=midnight+(Inp_RegularSessionEndHHMM/100)*3600+
         (Inp_RegularSessionEndHHMM%100)*60;
      bool covered=false;
      for(uint index=0;index<(uint)count;index++)
      {
         if(!SymbolInfoSessionTrade(Symbol(),(ENUM_DAY_OF_WEEK)day.day_of_week,index,from,to)) return false;
         long a=(long)from%86400,b=(long)to%86400;
         if(b==0 && to>from) b=86400;
         if(midnight+a<=gOMSessionOpen && midnight+b>=gOMSessionEnd) covered=true;
      }
      if(!covered) { OMFail("REGULAR_OVERRIDE_OUTSIDE_PUBLISHED_SESSION"); return false; }
   }
   else
   {
      if(count!=1) { OMFail("SESSION_AMBIGUOUS_SET_REGULAR_HHMM"); return false; }
      long a=(long)onlyFrom%86400,b=(long)onlyTo%86400;
      if(b==0 && onlyTo>onlyFrom) b=86400;
      if(b<=a) { OMFail("OVERNIGHT_SESSION_REQUIRES_SUPPORTED_DAY_MAPPING"); return false; }
      gOMSessionOpen=midnight+a; gOMSessionEnd=midnight+b;
   }
   gOMCursor=(long)gOMSessionOpen*1000;
   return true;
}
bool OMTradeValid(const MqlTick &t,double &volume,int &source)
{
   if(t.time_msc<=0 || t.time<=0 || (long)t.time!=t.time_msc/1000 ||
      !OMNumber(t.last) || t.last<=0 || gTickSize<=0 ||
      MathAbs(t.last/gTickSize-MathRound(t.last/gTickSize))>1e-6 ||
      !OMNumber(t.volume_real) || t.volume_real<0 ||
      (t.flags&(TICK_FLAG_LAST|TICK_FLAG_VOLUME|TICK_FLAG_BUY|TICK_FLAG_SELL))==0)
      return false;
   source=t.volume_real>0?1:2;
   volume=source==1?t.volume_real:(double)t.volume;
   return OMNumber(volume) && volume>0;
}
bool OMTickEqual(const MqlTick &a,const MqlTick &b)
{
   return a.time_msc==b.time_msc && a.time==b.time && a.last==b.last &&
      a.volume==b.volume && a.volume_real==b.volume_real && a.flags==b.flags;
}
// No timestamp deduplication: the complete ordered same-ms multiplicity is proof.
bool OMVerifyBoundary()
{
   if(gOMBoundaryMsc==0) return true;
   MqlTick ticks[];
   ResetLastError(); int n=CopyTicksRange(Symbol(),ticks,COPY_TICKS_TRADE,
      (ulong)gOMBoundaryMsc,(ulong)gOMBoundaryMsc);
   int error=GetLastError(),old=ArraySize(gOMBoundary);
   if(n<0 || error!=0) { OMFail("BOUNDARY_HISTORY_UNAVAILABLE"); return false; }
   if(n<old || n>Inp_DataMaxChunkTrades)
   { OMFail("BOUNDARY_MULTIPLICITY_REVISED_REBUILD_REQUIRED",true); return false; }
   for(int i=0;i<old;i++)
      if(!OMTickEqual(ticks[i],gOMBoundary[i]))
      { OMFail("BOUNDARY_PREFIX_REVISED_REBUILD_REQUIRED",true); return false; }
   if(n==old) return true;
   MqlTick suffix[];
   int appended=n-old;
   if(ArrayResize(suffix,appended)!=appended)
   { OMFail("BOUNDARY_ALLOCATION_FAILED"); return false; }
   for(int i=0;i<appended;i++) suffix[i]=ticks[old+i];
   // Valid append-only same-ms records count exactly once. An already frozen
   // close is invalidated, never retrospectively replaced as an old signal.
   if(!OMApplyBatch(suffix,appended,gOMBoundaryMsc,gOMBoundaryMsc+1)) return false;
   if(gOMClosedBar>0 && gOMClosed.bands.asofMsc>=gOMBoundaryMsc)
   { gOMEpoch++; ZeroMemory(gOMClosed); gOMClosedBar=0; }
   if(ArrayResize(gOMBoundary,n)!=n)
   { OMFail("BOUNDARY_ALLOCATION_FAILED_AFTER_COMMIT",true); return false; }
   for(int i=0;i<n;i++) gOMBoundary[i]=ticks[i];
   gOMVerified=true; OMUpdateReadiness(gOMCursor-1);
   return !gOMFault;
}
// Independent two-pass batch variance then Chan merge. Same exact records;
// no raw moment subtraction at the large absolute futures-price scale.
bool OMReferenceBatch(MqlTick &ticks[],int count,OMWeighted &reference)
{
   if(count==0) return true;
   double origin=ticks[0].last,total=0,sumOffset=0;
   for(int i=0;i<count;i++)
   {
      double volume; int source;
      if(!OMTradeValid(ticks[i],volume,source)) return false;
      total+=volume; sumOffset+=volume*(ticks[i].last-origin);
   }
   if(!OMNumber(total) || total<=0 || !OMNumber(sumOffset)) return false;
   double mean=origin+sumOffset/total,m2=0;
   for(int i=0;i<count;i++)
   {
      double volume; int source;
      if(!OMTradeValid(ticks[i],volume,source)) return false;
      double delta=ticks[i].last-mean;
      m2+=volume*delta*delta;
   }
   double all=reference.weight+total,delta=mean-reference.mean;
   if(!OMNumber(m2) || !OMNumber(all) || all<=reference.weight) return false;
   if(reference.trades==0) { reference.mean=mean; reference.m2=m2; }
   else
   {
      reference.m2+=m2+delta*delta*(reference.weight/all)*total;
      reference.mean+=(total/all)*delta;
   }
   reference.weight=all; reference.trades+=count;
   return OMNumber(reference.m2) && reference.m2>=0 && OMNumber(reference.mean);
}
void OMUpdateReadiness(long asof)
{
   OMBuildBands(gOMWeighted,gBandMultiplier,asof,gOMLive);
   if(!gOMLive.ready) { OMFail("DISPERSION_UNAVAILABLE"); return; }
   gOMRelativeSigmaChange=gOMPriorSigma>0?(gOMLive.sigma-gOMPriorSigma)/gOMPriorSigma:0;
   gOMPriorSigma=gOMLive.sigma;
   if(gOMFirstReady==0)
   {
      if(gOMPreMinSigma==0 || gOMLive.sigma<gOMPreMinSigma) gOMPreMinSigma=gOMLive.sigma;
      gOMPreMaxSigma=MathMax(gOMPreMaxSigma,gOMLive.sigma);
   }
   if(gOMWeighted.trades<Inp_BandsMinTrades) { OMFail("TRADE_COUNT_NOT_READY"); return; }
   if(gOMLive.sigma<Inp_BandsMinSigmaTicks*gTickSize)
   { OMFail("DISPERSION_BELOW_GRID_SCALE"); return; }
   if(asof-(long)gOMSessionOpen*1000<(long)Inp_BandsWarmupSec*1000)
   { OMFail("BANDS_WARMUP"); return; }
   if(!gOMVerified || gOMFault) { OMFail("INDEPENDENT_CHECK_NOT_READY"); return; }
   gOMLive.ready=true; gOMReason="BANDS_READY";
   if(gOMFirstReady==0) gOMFirstReady=asof;
   if(gOMMinSigma==0 || gOMLive.sigma<gOMMinSigma) gOMMinSigma=gOMLive.sigma;
   gOMMaxSigma=MathMax(gOMMaxSigma,gOMLive.sigma);
}
void OMMetric(const MqlTick &t,double volume,const OMBands &b)
{
   if(!b.ready || b.width<=0) return;
   double z=MathAbs(t.last-b.vwap)/b.width;
   int zone=z>=3?3:(z>=2?2:(z>=1?1:0));
   gOMZoneTrades[zone]++; gOMZoneVolume[zone]+=volume;
   if(gOMLastMetricMsc>0 && t.time_msc>=gOMLastMetricMsc && gOMPreviousZone>=0)
      gOMZoneMsc[gOMPreviousZone]+=t.time_msc-gOMLastMetricMsc;
   for(int i=0;i<3;i++)
      if(zone>=i+1 && gOMPreviousZone<i+1)
      {
         gOMVisits[i]++;
         if(gOMFirstVisit[i]==0) gOMFirstVisit[i]=t.time_msc;
      }
   gOMLastMetricMsc=t.time_msc; gOMPreviousZone=zone;
}
string OMObserved(double value,int precision=8)
{ return value==EMPTY_VALUE || !OMNumber(value)?"":DoubleToString(value,precision); }
string OMClassName(int c)
{
   if(c==1) return "CONT_BUY"; if(c==2) return "CONT_SELL";
   if(c==3) return "ABS_BUY"; if(c==4) return "ABS_SELL";
   return "NEUTRO";
}
void OMCaptureThesis(long msc,OMThesis &out)
{
   ZeroMemory(out); out.dataEpoch=gOMEpoch; out.bands=gOMLive; out.price=gOMLastPrice;
   OMConfig cfg=OMConfiguration(); OMDecision d;
   OMClassify(gOMWaves,out.price,msc,cfg,d);
   out.classification=d.classification; out.dir=d.dir; out.waveID=d.waveID;
   out.detected=d.classification!=0;
   out.route=d.classification==1 || d.classification==2?"CONT":
      (d.classification==3 || d.classification==4?"ABS":"NONE");
   out.effort=d.effort; out.netProgress=d.netProgress; out.grossPath=d.grossPath;
   out.eventPath=d.eventPath; out.pathEfficiency=d.pathEfficiency;
   out.rejection=d.rejection; out.velocity=d.velocity; out.evidenceMsc=d.evidenceMsc;
   OMWave w=gOMWaves.active;
   if(out.detected && gOMWaves.active.id!=d.waveID) w=gOMWaves.previous;
   if(!out.detected)
   {
      out.waveID=w.id; out.netProgress=w.dir*(out.price-w.start);
      out.grossPath=w.grossPath; out.eventPath=w.eventPath;
      out.pathEfficiency=w.eventPath>0?w.dir*(w.eventPrice-w.start)/w.eventPath:EMPTY_VALUE;
      out.effort=w.baseline>0?w.volume/w.baseline:EMPTY_VALUE;
      out.velocity=w.lastMsc>w.startMsc?1000*w.volume/(w.lastMsc-w.startMsc):0;
   }
   out.testHigh=w.high; out.testLow=w.low; out.attemptBands=w.attemptBands;
   double numerator=out.route=="ABS"?w.peakNet:w.dir*(out.price-w.start);
   out.rawEfficiency=d.grossPath>0?numerator/d.grossPath:EMPTY_VALUE;
   out.residual=out.price-w.eventPrice;
   out.eligible=out.detected && OMLocationEligible(d.classification,out.price,out.bands);
   out.reason=!out.bands.ready?gOMReason:(!out.detected?
      (d.reasonCode==1?"WAVE_BASELINE_NOT_READY":(d.reasonCode==2?
       "TRAJECTORY_INDETERMINATE":(d.reasonCode==4?"THESIS_CONFLICT":"NO_CONFIRMED_THESIS"))):
      (out.eligible?"SIGNAL_DETECTED":(out.price==out.bands.vwap?
       "VWAP_EQUALITY_INELIGIBLE":"LOCATION_INELIGIBLE")));
   if(!out.detected && out.bands.ready && d.reasonCode!=4 && w.eventPath<=0)
      out.reason="TRAJECTORY_INDETERMINATE_ZERO_EVENT_PATH";
   else if(!out.detected && out.bands.ready && d.reasonCode!=4 && w.dir==0)
      out.reason="CANDIDATE_REVERSAL_THRESHOLD_NOT_RECOGNIZED";
}
void OMTelemetry(string event,const OMThesis &s)
{
   if(gOMLog==INVALID_HANDLE) return;
   ulong sorted[]; int n=gOMCostCount;
   ArrayResize(sorted,n);
   for(int i=0;i<n;i++) sorted[i]=gOMServiceCosts[i];
   ArraySort(sorted);
   ulong p95=n>0?sorted[(int)MathFloor((n-1)*0.95)]:0;
   ulong p99=n>0?sorted[(int)MathFloor((n-1)*0.99)]:0;
   ulong maximum=n>0?sorted[n-1]:0;
   string line=event+","+(string)s.bands.asofMsc+","+s.reason+","+(s.bands.ready?"1":"0")+","+
      DoubleToString(s.bands.weight,8)+","+(string)s.bands.trades+","+
      DoubleToString(s.bands.vwap,12)+","+DoubleToString(s.bands.sigma,12);
   line+=","+DoubleToString(s.bands.upper1,12)+","+DoubleToString(s.bands.upper2,12)+","+
      DoubleToString(s.bands.upper3,12)+","+DoubleToString(s.bands.lower1,12)+","+
      DoubleToString(s.bands.lower2,12)+","+DoubleToString(s.bands.lower3,12)+","+
      DoubleToString(gOMErrorMean,12)+","+DoubleToString(gOMErrorSigma,12)+","+
      OMClassName(s.classification)+","+(string)s.dir+","+(s.eligible?"1":"0")+","+
      (string)s.waveID+","+OMObserved(s.effort)+","+DoubleToString(s.netProgress,8)+","+
      DoubleToString(s.grossPath,8)+","+DoubleToString(s.eventPath,8)+","+
      OMObserved(s.pathEfficiency)+","+
      (s.rawEfficiency==EMPTY_VALUE?"":DoubleToString(s.rawEfficiency,8))+","+
      DoubleToString(s.residual,8)+","+DoubleToString(s.rejection,8)+","+
      DoubleToString(s.velocity,8)+","+(string)s.attemptBands.asofMsc+","+
      DoubleToString((s.bands.asofMsc-(long)gOMSessionOpen*1000)/1000.0,3)+","+
      (gOMFirstReady>0?DoubleToString((gOMFirstReady-(long)gOMSessionOpen*1000)/1000.0,3):"")+","+
      DoubleToString(gOMMinSigma,8)+","+DoubleToString(gOMMaxSigma,8);
   for(int i=0;i<3;i++) line+=","+(string)gOMVisits[i];
   for(int i=0;i<3;i++) line+=","+(gOMFirstVisit[i]>0?
      DoubleToString((gOMFirstVisit[i]-(long)gOMSessionOpen*1000)/1000.0,3):"");
   for(int i=0;i<4;i++) line+=","+(string)gOMZoneTrades[i];
   for(int i=0;i<4;i++) line+=","+(string)gOMZoneMsc[i];
   for(int i=0;i<4;i++) line+=","+DoubleToString(gOMZoneVolume[i],8);
   line+=","+(string)p95+","+(string)p99+","+(string)maximum+","+
      (gOMSource==1?"VOLUME_REAL":(gOMSource==2?"VOLUME_INTEGER":"UNAVAILABLE"))+","+
      (string)gOMWaves.active.dir+","+(string)gOMWaves.active.startMsc+","+
      (string)gOMWaves.active.recognitionMsc+","+(string)gOMWaves.active.peakMsc+","+
      DoubleToString(gOMPreMinSigma,8)+","+DoubleToString(gOMPreMaxSigma,8)+","+
      DoubleToString(gOMRelativeSigmaChange,12)+","+OMObserved(s.price)+",";
   // Signed geometric residuals, not stops: negative means price is beyond
   // the respective band on its current side. Attempt width and VWAP retain
   // all six frozen original band levels by the exact same 1/2/3 formula.
   for(int i=1;i<=3;i++)
      line+=(s.bands.width>0?OMObserved(i*s.bands.width-MathAbs(s.price-s.bands.vwap)):"")+",";
   line+=OMObserved(s.attemptBands.vwap)+","+OMObserved(s.attemptBands.sigma)+","+
      OMObserved(s.attemptBands.width)+"\r\n";
   FileWriteString(gOMLog,line);
}
// Shared commit path for fresh intervals and append-only current boundaries.
// Input batch is validated before any analytical state mutation.
bool OMApplyBatch(MqlTick &ticks[],int n,long from,long endExclusive)
{
   double volumes[];
   if(ArrayResize(volumes,n)!=n) { OMFail("CHUNK_ALLOCATION_FAILED"); return false; }
   int source=gOMSource; long previous=gOMLastTradeMsc;
   for(int i=0;i<n;i++)
   {
      int observed;
      if(ticks[i].time_msc<from || ticks[i].time_msc>=endExclusive ||
         ticks[i].time_msc<previous || !OMTradeValid(ticks[i],volumes[i],observed))
      { OMFail("TRADE_RECORD_INVALID",true); return false; }
      if(source==0) source=observed;
      if(source!=observed) { OMFail("VOLUME_SOURCE_MIXED",true); return false; }
      long anchor=previous>0?previous:(long)gOMSessionOpen*1000;
      if(ticks[i].time_msc-anchor>(long)Inp_FeedMaxGapSec*1000)
      { OMFail("FEED_COVERAGE_GAP",true); return false; }
      previous=ticks[i].time_msc;
   }
   if(previous==0 && endExclusive-(long)gOMSessionOpen*1000>(long)Inp_FeedMaxGapSec*1000)
   { OMFail("OPENING_COVERAGE_NOT_PROVEN",true); return false; }
   if(previous>0 && endExclusive-previous>(long)Inp_FeedMaxGapSec*1000)
   { OMFail("TRAILING_FEED_GAP",true); return false; }
   OMWeighted reference=gOMReference;
   if(!OMReferenceBatch(ticks,n,reference))
   { OMFail("INDEPENDENT_BATCH_INVALID",true); return false; }
   OMConfig cfg=OMConfiguration();
   for(int i=0;i<n;i++)
   {
      OMBands before=gOMLive;
      if(!OMWeightedAdd(gOMWeighted,ticks[i].last,volumes[i]) ||
         !OMWavePush(gOMWaves,ticks[i].last,volumes[i],ticks[i].time_msc,
            cfg.reversal,cfg.eventStep,before))
      { OMFail("INCREMENTAL_ARITHMETIC_INVALID",true); return false; }
      gOMLastTradeMsc=ticks[i].time_msc; gOMLastPrice=ticks[i].last;
      OMMetric(ticks[i],volumes[i],before);
      // Intrachunk maps are numeric only until independent verification ends.
      OMBuildBands(gOMWeighted,gBandMultiplier,ticks[i].time_msc,gOMLive);
      gOMLive.ready=before.ready;
   }
   gOMReference=reference; gOMSource=source;
   double refSigma=reference.weight>0?MathSqrt(reference.m2/reference.weight):0;
   double sigma=gOMWeighted.weight>0?MathSqrt(gOMWeighted.m2/gOMWeighted.weight):0;
   gOMErrorMean=MathAbs(reference.mean-gOMWeighted.mean)/gTickSize;
   gOMErrorSigma=MathAbs(refSigma-sigma)/gTickSize;
   if(reference.trades!=gOMWeighted.trades || MathAbs(reference.weight-gOMWeighted.weight)>MathMax(1.0,gOMWeighted.weight)*1e-12 ||
      !OMNumber(gOMErrorMean) || !OMNumber(gOMErrorSigma) ||
      gOMErrorMean>Inp_SigmaCheckToleranceTicks || gOMErrorSigma>Inp_SigmaCheckToleranceTicks)
   { OMFail("INDEPENDENT_SIGMA_MISMATCH",true); return false; }
   return true;
}
// Each chunk ends at/before the next M1 boundary. No future trade is consumed
// before its closed-bar snapshot and independent variance verification.
bool OMReadChunk(long endExclusive)
{
   MqlTick ticks[];
   long from=gOMCursor;
   ResetLastError(); int n=CopyTicksRange(Symbol(),ticks,COPY_TICKS_TRADE,
      (ulong)from,(ulong)(endExclusive-1));
   if(n<0 || GetLastError()!=0) { OMFail("TRADE_HISTORY_UNAVAILABLE"); return false; }
   if(n>Inp_DataMaxChunkTrades) { OMFail("CHUNK_RECORD_BUDGET_EXCEEDED",true); return false; }
   if(!OMApplyBatch(ticks,n,from,endExclusive)) return false;
   if(n>0)
   {
      long boundary=ticks[n-1].time_msc; int start=n-1;
      while(start>0 && ticks[start-1].time_msc==boundary) start--;
      int count=n-start;
      if(ArrayResize(gOMBoundary,count)!=count)
      { OMFail("BOUNDARY_ALLOCATION_FAILED_AFTER_COMMIT",true); return false; }
      for(int i=0;i<count;i++) gOMBoundary[i]=ticks[start+i];
      gOMBoundaryMsc=boundary;
   }
   gOMCursor=endExclusive; gOMVerified=true;
   OMUpdateReadiness(endExclusive-1);
   if(endExclusive%60000==0)
   {
      OMCaptureThesis(endExclusive-1,gOMClosed);
      gOMClosedBar=(datetime)(endExclusive/1000-60);
      if(endExclusive>gOMAttachMsc) OMTelemetry("M1_CLOSED",gOMClosed);
   }
   int contextSeconds=PeriodSeconds(Inp_ContextTF);
   if(contextSeconds>0 && endExclusive%((long)contextSeconds*1000)==0)
   { gOMContext=gOMLive; gOMContextBar=(datetime)(endExclusive/1000-contextSeconds); }
   return true;
}
void OMServiceStep()
{
   ulong begin=GetMicrosecondCount();
   bool connected=TerminalInfoInteger(TERMINAL_CONNECTED)!=0 || MQLInfoInteger(MQL_TESTER)!=0;
   if(!connected) { gOMConnected=false; OMFail("TERMINAL_DISCONNECTED"); return; }
   MqlDateTime day; TimeToStruct(TimeTradeServer(),day);
   int key=day.year*1000+day.day_of_year;
   if(!gOMConnected || key!=gOMDay) OMReset();
   gOMConnected=true;
   if(gOMFault) return;
   if(gOMSessionOpen==0 && !OMResolveSession()) return;
   MqlTick latest;
   if(!SymbolInfoTick(Symbol(),latest) || latest.time_msc<=0 ||
      latest.time_msc>(long)TimeTradeServer()*1000+999 ||
      TimeTradeServer()-(datetime)(latest.time_msc/1000)>Inp_FeedMaxGapSec)
   { OMFail("BROKER_TICK_CLOCK_OR_FRESHNESS_INVALID"); return; }
   if(latest.time_msc<(long)gOMSessionOpen*1000)
   { OMFail("REGULAR_SESSION_NOT_OPEN"); return; }
   long until=MathMin(latest.time_msc+1,(long)gOMSessionEnd*1000);
   if(!SymbolIsSynchronized(Symbol()) ||
      !SeriesInfoInteger(Symbol(),Inp_SignalTF,SERIES_SYNCHRONIZED))
   { OMFail("SYMBOL_OR_M1_HISTORY_NOT_SYNCHRONIZED"); return; }
   if(!OMVerifyBoundary()) return;
   for(int work=0;work<Inp_DataChunksPerTimer && gOMCursor<until;work++)
   {
      long nextMinute=(gOMCursor/60000+1)*60000;
      long end=MathMin(until,MathMin(gOMCursor+(long)Inp_DataChunkMsc,nextMinute));
      if(!OMReadChunk(end)) break;
      if(GetMicrosecondCount()-begin>=10000) break; // Soft CPU budget after bounded IO.
   }
   if(gOMCursor<until && !gOMFault && gOMReason=="BANDS_READY")
      gOMReason="HISTORY_CATCHUP_PENDING";
}
void OMService()
{
   ulong begin=GetMicrosecondCount();
   OMServiceStep();
   ulong elapsed=GetMicrosecondCount()-begin;
   gOMServiceCosts[gOMCostNext]=elapsed; gOMCostNext=(gOMCostNext+1)%128;
   if(gOMCostCount<128) gOMCostCount++;
   long now=(long)TimeTradeServer();
   bool transition=gOMLastReportedReason!=gOMReason;
   if(transition || now-gOMLastFlush>=30)
   {
      OMThesis live;
      OMCaptureThesis(gOMCursor>0?gOMCursor-1:now*1000,live);
      live.reason=gOMReason;
      OMTelemetry(transition?"ENGINE_TRANSITION":"ENGINE_STATUS",live);
      gOMLastReportedReason=gOMReason;
   }
   if(now-gOMLastFlush>=30)
   {
      gOMLastFlush=now;
      if(gOMLog!=INVALID_HANDLE) FileFlush(gOMLog);
   }
}
bool OMLiveReady(long tickMsc)
{
   if(gOMFault || !gOMVerified || !gOMLive.ready || gOMReason!="BANDS_READY" ||
      tickMsc<=0 || gOMCursor<=tickMsc || tickMsc<gOMLastTradeMsc ||
      tickMsc-gOMLastTradeMsc>(long)Inp_FeedMaxGapSec*1000) return false;
   MqlTick latest;
   if(!SymbolInfoTick(Symbol(),latest) || latest.time_msc!=tickMsc ||
      latest.last!=gOMLastPrice) return false;
   uint flags=TICK_FLAG_LAST|TICK_FLAG_VOLUME|TICK_FLAG_BUY|TICK_FLAG_SELL;
   if((latest.flags&flags)!=0)
   {
      int count=ArraySize(gOMBoundary);
      if(latest.time_msc!=gOMLastTradeMsc || count<=0 ||
         !OMTickEqual(latest,gOMBoundary[count-1])) return false;
   }
   // Quote-only updates may retain independently verified Last evidence.
   // An additional byte-identical same-ms print cannot be distinguished here;
   // its multiplicity is reconciled by the next timer boundary read.
   return true;
}
bool OMGetClosed(datetime signalBarOpen,OMThesis &out)
{
   out=gOMClosed;
   long end=((long)signalBarOpen+PeriodSeconds(Inp_SignalTF))*1000;
   if(PeriodSeconds(Inp_SignalTF)!=60 || gOMClosedBar!=signalBarOpen ||
      end<=gOMAttachMsc || !out.bands.ready || gOMFault || !gOMVerified)
      return false;
   return true;
}
int OMRevalidate(const OMThesis &frozen,string &reason)
{
   reason="EVIDENCE_UNAVAILABLE";
   MqlTick latest;
   if(!SymbolInfoTick(Symbol(),latest) || !OMLiveReady(latest.time_msc)) return 0;
   if(!frozen.detected || frozen.waveID==0 || frozen.evidenceMsc<=0) return 0;
   if(frozen.dataEpoch!=gOMEpoch)
   { reason="FROZEN_EVIDENCE_REVISED"; return -1; }
   if(latest.time_msc<frozen.evidenceMsc) return 0;
   if(gOMWaves.active.id!=frozen.waveID && gOMWaves.previous.id!=frozen.waveID)
   { reason="WAVE_EVIDENCE_SUPERSEDED"; return -1; }
   OMConfig cfg=OMConfiguration();
   if(frozen.route=="CONT")
   {
      OMWave w=gOMWaves.active;
      if(w.id!=frozen.waveID || w.dir!=frozen.dir)
      { reason="CONT_WAVE_REVERSED"; return -1; }
      double net=w.dir*(gOMLastPrice-w.start);
      double drawdown=w.dir==1?w.high-gOMLastPrice:gOMLastPrice-w.low;
      double eventNet=w.dir*(w.eventPrice-w.start);
      if(w.eventPath<=0 || w.baseline<=0) return 0;
      if(net<cfg.minCont || eventNet/w.eventPath<cfg.contEfficiency ||
         w.volume/w.baseline<cfg.contEffort || drawdown>=cfg.eventStep)
      { reason="CONT_PROGRESS_OR_SUSTAINMENT_LOST"; return -1; }
   }
   else if(frozen.route=="ABS")
   {
      double reclaimed=frozen.dir==1?frozen.testLow-gOMLastPrice:gOMLastPrice-frozen.testHigh;
      if(reclaimed>=0) { reason="ABS_TEST_EXTREME_RECLAIMED"; return -1; }
      OMWave w=gOMWaves.active;
      if(w.id!=frozen.waveID) w=gOMWaves.previous;
      OMDecision abs; if(!OMAbsEvidence(w,gOMLastPrice,latest.time_msc,cfg,abs))
      { reason="ABS_REJECTION_LOST"; return -1; }
   }
   else return 0;
   reason="THESIS_VALID";
   return 1;
}
#endif
