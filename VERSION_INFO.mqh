//+------------------------------------------------------------------+
//|                                           VERSION_INFO.mqh      |
//|                        Copyright 2025, JonusNattapong           |
//|                                https://github.com/JonusNattapong |
//+------------------------------------------------------------------+

// Version Information
#define EA_VERSION_MAJOR    1
#define EA_VERSION_MINOR    01
#define EA_VERSION_BUILD    20250912
#define EA_VERSION_STRING   "1.01"

// Build Information
#define EA_BUILD_DATE       "2025.09.12"
#define EA_BUILD_TIME       "15:40:00"
#define EA_COMPILER         "MetaTrader 5"
#define EA_PLATFORM         "MQL5"

// Changelog for Version 1.01
/*
=================================================================
                    AK47ScalperEA v1.01 Changelog
                        Release: 2025-09-12
=================================================================

CRITICAL FIXES:
- Fixed iATR function parameter count issues (7 instances)
- Updated MQL4 style iATR calls to proper MQL5 syntax
- Implemented correct buffer handling with CopyBuffer()
- Removed unnecessary include dependencies

COMPILATION STATUS:
- Errors: 0 ✅
- Warnings: 0 ✅  
- Output: AK47ScalperEA.ex5 (65,616 bytes)
- Status: SUCCESSFULLY COMPILED

FILES AFFECTED:
- AK47_SMC_Module.mqh (Lines: 367, 391, 524, 768, 769, 787, 788)

DEPLOYMENT:
- Files copied to MetaTrader 5 Experts folder
- EA ready for XAUUSD trading
- Installation verified

TECHNICAL CHANGES:
OLD (MQL4 Style - INCORRECT):
  double atr = iATR(_Symbol, PERIOD_M1, 14, 0);

NEW (MQL5 Style - CORRECT):
  int atrHandle = iATR(_Symbol, PERIOD_M1, 14);
  double atrBuffer[];
  ArraySetAsSeries(atrBuffer, true);
  CopyBuffer(atrHandle, 0, 0, 1, atrBuffer);
  double atr = atrBuffer[0];

REMOVED INCLUDES:
- #include <Arrays\ArrayObj.mqh>     (unused)
- #include <Arrays\ArrayDouble.mqh>  (unused)

=================================================================
*/

// Previous Version Information
/*
Version 1.00 (2025-04-08) - Initial Release:
- Smart Money Concepts (SMC) Analysis
- AI Signal Integration  
- Advanced Risk Management
- Comprehensive Reporting
- XAUUSD M1 Scalping Strategy
- Modular Architecture Design
*/

// Version Check Function
string GetEAVersion()
{
    return EA_VERSION_STRING;
}

string GetEABuildInfo()
{
    return "v" + EA_VERSION_STRING + " (" + EA_BUILD_DATE + " " + EA_BUILD_TIME + ")";
}

string GetEAFullInfo()
{
    return "AK47ScalperEA v" + EA_VERSION_STRING + 
           " | Build: " + EA_BUILD_DATE + 
           " | Platform: " + EA_PLATFORM +
           " | Target: XAUUSD M1 Scalping";
}
