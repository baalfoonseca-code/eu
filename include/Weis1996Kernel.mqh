// Extracted literally from baalfoonseca-code/Bf ObjectiveMatrix.mqh.
// Verified Git blob: e0bacb9fa1e003ddb57c658c9cc8860e208cfbfc.
// OMBands is an inert compatibility payload in OMWave; no bands calculation
// or location/session/sigma/financial policy from 1.996 is imported here.
#ifndef REMORA_1995_WEIS_1996_KERNEL_MQH
#define REMORA_1995_WEIS_1996_KERNEL_MQH

struct OMBands
{
   bool ready;
   long asofMsc;
   double vwap,sigma,weight,width,upper1,upper2,upper3,lower1,lower2,lower3;
   long trades;
};
bool OMNumber(double n) { return MathIsValidNumber(n) && n!=EMPTY_VALUE; }
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

#endif
