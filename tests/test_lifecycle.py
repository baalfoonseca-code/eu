#!/usr/bin/env python3
"""Portable execution of the actual analytical queue with mocked MQL services.
Not a MetaEditor compilation, financial protocol test, or MT5 replay.
"""
from pathlib import Path
import re
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
HELPER = ROOT / 'include' / 'SignalLifecycle1995.mqh'

SHIM = r'''
#include <algorithm>
#include <cassert>
#include <cmath>
#include <cstdint>
#include <iomanip>
#include <map>
#include <sstream>
#include <string>
#include <vector>
#include <iostream>
using ulong=unsigned long;
using uint=unsigned int;
using uchar=unsigned char;
struct string {
 std::string s;
 string()=default; string(const char*x):s(x){} string(const std::string&x):s(x){}
 template<class T> string(T x){std::ostringstream o;o<<x;s=o.str();}
 string&operator+=(const string&x){s+=x.s;return *this;}
 friend string operator+(string a,const string&b){a+=b;return a;}
 friend bool operator==(const string&a,const string&b){return a.s==b.s;}
 friend bool operator!=(const string&a,const string&b){return !(a==b);}
};
constexpr int INVALID_HANDLE=-1,FILE_WRITE=1,FILE_TXT=2,FILE_ANSI=4,FILE_SHARE_READ=8;
constexpr int CP_UTF8=65001,WHOLE_ARRAY=-1,ACCOUNT_LOGIN=1;
constexpr double EMPTY_VALUE=2147483647.0;
int StringLen(string x){return x.s.size();}
string StringSubstr(string x,int p,int n){return x.s.substr(p,n);}
void StringReplace(string&x,string a,string b){std::size_t p=0;while((p=x.s.find(a.s,p))!=std::string::npos){x.s.replace(p,a.s.size(),b.s);p+=b.s.size();}}
int StringToCharArray(string x,std::vector<uchar>&out,int,int,int){out.assign(x.s.begin(),x.s.end());out.push_back(0);return out.size();}
string DoubleToString(double x,int p){std::ostringstream o;o<<std::fixed<<std::setprecision(p)<<x;return o.str();}
string EnumToString(int x){return string(x);}
string StringFormat(const char*,...){return "mock-instance";}
bool MathIsValidNumber(double x){return std::isfinite(x);}
double MathCeil(double x){return std::ceil(x);} double MathFloor(double x){return std::floor(x);}
int MathMin(int a,int b){return std::min(a,b);}int MathMax(int a,int b){return std::max(a,b);}
struct OMDecision {int classification=0,dir=0,reasonCode=0;ulong waveID=0;double effort=0,pathEfficiency=0,netProgress=0,grossPath=0,eventPath=0,rejection=0,volume=0;long evidenceMsc=0;};
struct Entry {bool enabled=false,triggerReady=false,dispatchAttempted=false;double trigger=0;long thesisMsc=0;};
struct ArmedSignal {string signalID,route,mode;int dir=0;long armedAt=0;double regionHigh=0,regionLow=0,requestPrice=0,lots=0;Entry entry;};
struct MacroContext {int macroAbsDir=-1,macroContDir=1,status=1;long barTime=900;};
MacroContext gMacro;int gMagicCore=60001;double gTickSize=5,gBreakoutMargin=175;
struct MqlTick {long time_msc=1000000;double last=100000,bid=99995,ask=100000;};
template<class T>void ZeroMemory(T&x){x=T{};}
bool SymbolInfoTick(string,MqlTick&x){x=MqlTick{};return true;}
string Symbol(){return "WIN-test";}long AccountInfoInteger(int){return 1;}long ChartID(){return 2;}long TimeLocal(){return 1000;}long TimeTradeServer(){return 1000;}ulong GetMicrosecondCount(){return 1;}
std::vector<std::string> written;
int flushes=0,opens=0,closes=0,error=0;bool failWrite=false;
bool FileIsExist(string){return false;}
int FileOpen(string,int,int,int){opens++;return 3;}
uint FileWriteString(int,string payload){if(failWrite){error=5;return 0;}written.push_back(payload.s);return payload.s.size();}
void FileFlush(int){flushes++;}void FileClose(int){closes++;}
void ResetLastError(){error=0;}int GetLastError(){return error;}
void Print(const char*){}template<class...T>void PrintFormat(const char*,T...){}
'''

MAIN = r'''
int main(){
 assert(LLInit());assert(opens==1);assert(written.size()==1);
 assert(written[0].find("WEIS_DIRECTION")!=std::string::npos);
 ArmedSignal a;a.signalID="S1";a.route="ABS";a.mode="BASE";a.dir=1;
 OMDecision d;d.waveID=3;d.evidenceMsc=999000;d.dir=1;
 d.effort=1.5;d.pathEfficiency=0.2;d.classification=3;
 int beforeFlush=flushes;
 LLRecord("SIGNAL_CANDIDATE",a,d,"reason, with \"quotes\"");
 assert(written.size()==1);assert(flushes==beforeFlush);assert(gLLCount==1);
 LLFlush();assert(gLLCount==0);assert(written.size()==2);assert(flushes==beforeFlush+1);
 assert(written[1].find("\"reason, with \"\"quotes\"\"\"")!=std::string::npos);
 assert(written[1].find("0.00000000")!=std::string::npos); // Metrics may legitimately be zero.
 assert(written[1].find("\"175.00000000\"")==std::string::npos); // Candidate has no frozen trigger.
 for(int i=0;i<513;i++)LLRecord("SEND_ATTEMPT",a,d,"observed");
 assert(gLLCount==512);assert(gLLDropped==1);
 auto start=written.size();LLFlush();assert(gLLCount==384);assert(written.size()==start+129);
 assert(written.back().find("TELEMETRY_DROPPED")!=std::string::npos);
 LLClose();assert(gLLCount==0);assert(gLLHandle==INVALID_HANDLE);
 // Repeated fill events retain multiplicity and only carry known fill data.
 assert(LLInit());start=written.size();
 LLRecord("FILL_CONFIRMED",a,d,"",11,22,33,10009,100005,1,1000001);
 LLRecord("FILL_CONFIRMED",a,d,"",11,22,34,10009,100005,0.5,1000001);
 LLFlush();assert(written.size()==start+2);
 assert(written[start].find("DEAL_CONFIRMED")!=std::string::npos);
 // A write failure stops analytical persistence, without modifying signal state.
 LLRecord("SIGNAL_END",a,d,"request unresolved");failWrite=true;LLFlush();
 assert(gLLHandle==INVALID_HANDLE);assert(gLLWriteFailures==1);
 assert(a.signalID=="S1" && a.dir==1 && !a.entry.dispatchAttempted);
 std::cout<<"lifecycle queue: PASS (memory-only enqueue, bounded drain/drop, UTF-8 byte count, fill identity, write failure)\n";
}
'''

class Lifecycle(unittest.TestCase):
    def test_schema_and_no_record_io(self):
        source = HELPER.read_text()
        header = re.search(r'string LLHeader\(\).*?return "(.*?)";', source, re.S)[1]
        self.assertEqual(len(header.split(',')), 49)
        record = source.split('void LLRecord(',1)[1].split('void LLFlush(',1)[0]
        self.assertEqual(len(re.findall(r'LLAdd\(row,',record)),49)
        self.assertNotRegex(record,r'File(Open|Write|Flush|Close)|PositionOpen|OrderSend|Persist|ResetPending')

    def test_actual_queue_portable(self):
        source = HELPER.read_text().replace('uchar encoded[];', 'std::vector<uchar> encoded;')
        with tempfile.TemporaryDirectory(prefix='remora-lifecycle-') as tmp:
            cpp = Path(tmp)/'lifecycle.cpp'
            binary = Path(tmp)/'lifecycle'
            cpp.write_text(SHIM+'\n'+source+'\n'+MAIN)
            subprocess.run(['g++','-std=c++17','-Wall','-Wextra','-Werror',str(cpp),'-o',str(binary)],check=True)
            subprocess.run([str(binary)],check=True)

if __name__ == '__main__':
    unittest.main()
