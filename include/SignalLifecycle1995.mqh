// Analytical lifecycle only. No order, position, risk, journal or entry decisions.
// Include after ArmedSignal, MacroContext, OMDecision and the original globals.
#ifndef REMORA_SIGNAL_LIFECYCLE_1995_MQH
#define REMORA_SIGNAL_LIFECYCLE_1995_MQH

#define LL_QUEUE_CAPACITY 512
string gLLRows[LL_QUEUE_CAPACITY];
int gLLHead=0,gLLCount=0,gLLHandle=INVALID_HANDLE;
ulong gLLSequence=0,gLLDropped=0,gLLWriteFailures=0,gLLCoalesced=0,gLLReportedDropped=0;
string gLLInstance="",gLLFile="",gLLLastKey="";
long gLLLastKeySecond=0;

string LLCell(string value)
{
   // Every cell is quoted, including commas, quotes and multiline reasons.
   // Diagnostic fields are bounded; truncation is explicit, never a decision.
   if(StringLen(value)>2048) value=StringSubstr(value,0,2020)+"[FIELD_TRUNCATED]";
   StringReplace(value,"\"","\"\"");
   return "\""+value+"\"";
}
void LLAdd(string &row,string value)
{ if(row!="") row+=","; row+=LLCell(value); }
string LLNumber(double value,bool available=true)
{ return available && MathIsValidNumber(value) && value!=EMPTY_VALUE?DoubleToString(value,8):""; }
string LLDirection(int dir)
{ return dir==1?"BUY":(dir==-1?"SELL":"NONE"); }
string LLCanonicalEvent(string event)
{
   if(event=="SIGNAL_END") return "SIGNAL_ENDED";
   if(event=="REAL_TRADE_CONFIRMED") return "TRIGGER_CONFIRMED";
   if(event=="FILL_CONFIRMED") return "DEAL_CONFIRMED";
   if(event=="FILL_INOUT_UNEXPECTED") return "DEAL_CONFIRMED_INOUT_UNEXPECTED";
   if(event=="DISPATCH_RESULT_BOUND") return "REQUEST_IDENTITY_BOUND";
   return event; // An unfamiliar event is never guessed to mean rejection/fill.
}
string LLHeader()
{
   return "SCHEMA,SEQUENCE,EVENT,ORIGINAL_EVENT,OBSERVED_TIME_MSC,SYMBOL,MAGIC,SIGNAL_ID,ROUTE,DIRECTION,MODE,REASON,WAVE_ID,CLASSIFICATION,WEIS_REASON_CODE,EVIDENCE_TIME_MSC,EFFORT,PATH_EFFICIENCY,NET_PROGRESS,GROSS_PATH,EVENT_PATH,REJECTION,EVIDENCE_VOLUME,WEIS_DIRECTION,MACRO_ABS_DIRECTION_OBSERVED,MACRO_CONT_DIRECTION_OBSERVED,MACRO_BAR_OPEN_OBSERVED,MACRO_AGE_SEC_OBSERVED,MACRO_STATUS_OBSERVED,THESIS_TIME_MSC,ARMED_AT,TRIGGER_PRICE,QUOTE_TIME_MSC,LAST_OBSERVED,BID_OBSERVED,ASK_OBSERVED,REQUEST_PRICE,REQUESTED_VOLUME,REQUEST_ID,ORDER_ID,DEAL_ID,RETCODE,FILL_TIME_MSC,FILL_PRICE,FILL_VOLUME,DISPATCH_ATTEMPTED,DROPPED_TOTAL,WRITE_FAILURES_TOTAL,COALESCED_TOTAL\r\n";
}
bool LLWrite(string payload)
{
   if(gLLHandle==INVALID_HANDLE) return false;
   uchar encoded[];
   int length=StringToCharArray(payload,encoded,0,WHOLE_ARRAY,CP_UTF8)-1;
   if(length<0) return false;
   ResetLastError();
   uint written=FileWriteString(gLLHandle,payload);
   return GetLastError()==0 && written==(uint)length;
}
bool LLInit()
{
   // Reinitialization cannot discard a pending queue silently.
   if(gLLHandle!=INVALID_HANDLE) return true;
   gLLInstance=StringFormat("%I64d_%s_%d_%I64d_%I64d_%I64u",
      AccountInfoInteger(ACCOUNT_LOGIN),Symbol(),gMagicCore,ChartID(),
      (long)TimeLocal(),GetMicrosecondCount());
   gLLFile="Scalper1995_WeisLifecycle_v1_"+gLLInstance+".csv";
   // A bounded collision search preserves existing analytical files.
   for(int collision=0;collision<100;collision++)
   {
      string candidate="Scalper1995_WeisLifecycle_v1_"+gLLInstance+
         (collision>0?"_"+(string)collision:"")+".csv";
      if(FileIsExist(candidate)) continue;
      gLLFile=candidate;
      gLLHandle=FileOpen(gLLFile,FILE_WRITE|FILE_TXT|FILE_ANSI|FILE_SHARE_READ,0,CP_UTF8);
      break;
   }
   if(gLLHandle==INVALID_HANDLE)
   { Print("[Scalper 1995][LIFECYCLE_UNAVAILABLE] Analytical file unavailable; execution and recovery are unchanged."); return false; }
   if(!LLWrite(LLHeader()))
   {
      gLLWriteFailures++;
      FileClose(gLLHandle); gLLHandle=INVALID_HANDLE;
      Print("[Scalper 1995][LIFECYCLE_HEADER_FAILED] Analytical file unavailable; execution and recovery are unchanged.");
      return false;
   }
   FileFlush(gLLHandle);
   return true;
}
void LLRecord(string event,const ArmedSignal &a,const OMDecision &d,string reason="",
              uint requestID=0,ulong orderID=0,ulong dealID=0,uint retcode=0,
              double fillPrice=0,double fillVolume=0,long fillMsc=0)
{
   MqlTick observed; ZeroMemory(observed);
   bool tickOK=SymbolInfoTick(Symbol(),observed) && observed.time_msc>0;
   long observedMsc=tickOK?observed.time_msc:(long)TimeTradeServer()*1000;
   string canonical=LLCanonicalEvent(event);
   // Coalesce only consecutive identical idle revalidations in the same second.
   // Lifecycle transitions, fills and requests retain their actual multiplicity.
   string key=a.signalID+"|"+event+"|"+reason+"|"+(string)d.waveID+"|"+
      (string)d.classification+"|"+(string)d.reasonCode;
   if(event=="THESIS_REVALIDATION" && key==gLLLastKey &&
      observedMsc/1000==gLLLastKeySecond)
   { gLLCoalesced++; return; }
   gLLLastKey=key; gLLLastKeySecond=observedMsc/1000;
   gLLSequence++;
   if(gLLCount>=LL_QUEUE_CAPACITY) { gLLDropped++; return; }
   bool evidence=d.waveID>0 && d.evidenceMsc>0;
   bool fill=dealID>0 && fillMsc>0 && MathIsValidNumber(fillPrice) && fillPrice>0 &&
      MathIsValidNumber(fillVolume) && fillVolume>0;
   bool trigger=a.entry.enabled?a.entry.triggerReady:
      (a.armedAt>0 && (a.dir==1 || a.dir==-1) && a.regionHigh>0 && a.regionLow>0);
   double triggerPrice=a.entry.enabled?a.entry.trigger:
      (a.dir==1?MathCeil((a.regionHigh+gBreakoutMargin)/gTickSize)*gTickSize:
       (a.dir==-1?MathFloor((a.regionLow-gBreakoutMargin)/gTickSize)*gTickSize:0));
   long macroAge=gMacro.barTime>0?observedMsc/1000-(long)gMacro.barTime:-1;
   string row="";
   LLAdd(row,"LIFECYCLE1995_1"); LLAdd(row,(string)gLLSequence);
   LLAdd(row,canonical); LLAdd(row,event); LLAdd(row,(string)observedMsc);
   LLAdd(row,Symbol()); LLAdd(row,(string)gMagicCore); LLAdd(row,a.signalID);
   LLAdd(row,a.route); LLAdd(row,LLDirection(a.dir)); LLAdd(row,a.mode);
   LLAdd(row,reason); LLAdd(row,d.waveID>0?(string)d.waveID:"");
   LLAdd(row,(string)d.classification); LLAdd(row,(string)d.reasonCode);
   LLAdd(row,d.evidenceMsc>0?(string)d.evidenceMsc:"");
   LLAdd(row,LLNumber(d.effort,evidence)); LLAdd(row,LLNumber(d.pathEfficiency,evidence));
   LLAdd(row,LLNumber(d.netProgress,evidence)); LLAdd(row,LLNumber(d.grossPath,evidence));
   LLAdd(row,LLNumber(d.eventPath,evidence)); LLAdd(row,LLNumber(d.rejection,evidence));
   LLAdd(row,LLNumber(d.volume,evidence)); LLAdd(row,LLDirection(d.dir));
   LLAdd(row,LLDirection(gMacro.macroAbsDir)); LLAdd(row,LLDirection(gMacro.macroContDir));
   LLAdd(row,gMacro.barTime>0?(string)(long)gMacro.barTime:"");
   LLAdd(row,macroAge>=0?(string)macroAge:""); LLAdd(row,EnumToString(gMacro.status));
   LLAdd(row,a.entry.thesisMsc>0?(string)a.entry.thesisMsc:"");
   LLAdd(row,a.armedAt>0?(string)(long)a.armedAt:"");
   LLAdd(row,LLNumber(triggerPrice,trigger && triggerPrice>0));
   LLAdd(row,tickOK?(string)observed.time_msc:"");
   LLAdd(row,LLNumber(observed.last,tickOK && observed.last>0));
   LLAdd(row,LLNumber(observed.bid,tickOK && observed.bid>0));
   LLAdd(row,LLNumber(observed.ask,tickOK && observed.ask>0));
   LLAdd(row,LLNumber(a.requestPrice,a.requestPrice>0));
   LLAdd(row,LLNumber(a.lots,a.lots>0)); // Unknown Stage-1 sizing stays empty.
   LLAdd(row,requestID>0?(string)requestID:""); LLAdd(row,orderID>0?(string)orderID:"");
   LLAdd(row,dealID>0?(string)dealID:""); LLAdd(row,retcode>0?(string)retcode:"");
   LLAdd(row,fill?(string)fillMsc:""); LLAdd(row,LLNumber(fillPrice,fill));
   LLAdd(row,LLNumber(fillVolume,fill)); LLAdd(row,a.entry.dispatchAttempted?"1":"0");
   LLAdd(row,(string)gLLDropped); LLAdd(row,(string)gLLWriteFailures);
   LLAdd(row,(string)gLLCoalesced);
   int tail=(gLLHead+gLLCount)%LL_QUEUE_CAPACITY;
   gLLRows[tail]=row+"\r\n"; gLLCount++;
}
void LLFlush(int maxRows=128)
{
   if(gLLHandle==INVALID_HANDLE) return;
   int budget=MathMin(LL_QUEUE_CAPACITY,MathMax(0,maxRows));
   for(int work=0;work<budget && gLLCount>0;work++)
   {
      if(!LLWrite(gLLRows[gLLHead]))
      {
         gLLWriteFailures++;
         // A partial disk row cannot safely be retried or called persisted.
         // Stop writing this stream; keep execution independent of telemetry.
         FileClose(gLLHandle); gLLHandle=INVALID_HANDLE;
         Print("[Scalper 1995][LIFECYCLE_WRITE_FAILED] Analytical persistence unconfirmed; execution and recovery are unchanged.");
         return;
      }
      gLLRows[gLLHead]=""; gLLHead=(gLLHead+1)%LL_QUEUE_CAPACITY; gLLCount--;
   }
   if(gLLDropped!=gLLReportedDropped)
   {
      // Explicit loss record, with no invented intention or market evidence.
      string loss="";
      for(int column=0;column<49;column++)
      {
         string cell="";
         if(column==0) cell="LIFECYCLE1995_1";
         // Metadata has no observation sequence; queued events keep theirs.
         if(column==2 || column==3) cell="TELEMETRY_DROPPED";
         if(column==4) cell=(string)((long)TimeTradeServer()*1000);
         if(column==5) cell=Symbol();
         if(column==6) cell=(string)gMagicCore;
         if(column==11) cell="QUEUE_FULL_ANALYTICAL_EVENTS_NOT_OBSERVED";
         if(column==46) cell=(string)gLLDropped;
         if(column==47) cell=(string)gLLWriteFailures;
         if(column==48) cell=(string)gLLCoalesced;
         LLAdd(loss,cell);
      }
      if(LLWrite(loss+"\r\n")) gLLReportedDropped=gLLDropped;
      else
      {
         gLLWriteFailures++; FileClose(gLLHandle); gLLHandle=INVALID_HANDLE;
         Print("[Scalper 1995][LIFECYCLE_WRITE_FAILED] Loss metadata persistence unconfirmed.");
         return;
      }
   }
   FileFlush(gLLHandle); // Timer/deinit only; LLRecord never writes or flushes.
   if(gLLDropped>0)
      PrintFormat("[Scalper 1995][LIFECYCLE_LOSS] dropped=%I64u queued=%d writeFailures=%I64u coalesced=%I64u",
         gLLDropped,gLLCount,gLLWriteFailures,gLLCoalesced);
}
void LLClose()
{
   if(gLLHandle==INVALID_HANDLE) return;
   LLFlush(LL_QUEUE_CAPACITY);
   if(gLLHandle!=INVALID_HANDLE)
   { FileFlush(gLLHandle); FileClose(gLLHandle); gLLHandle=INVALID_HANDLE; }
}
#endif
