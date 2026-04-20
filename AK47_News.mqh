//+------------------------------------------------------------------+
//|                                                    AK47_News.mqh |
//|                        Copyright 2026, AK47 Scalper EA Developer |
//|                                             https://github.com/  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, AK47 Scalper EA"
#property link      ""
#property version   "1.20"
#property strict

//+------------------------------------------------------------------+
//| Kilo AI Agent Workspace Client                                   |
//+------------------------------------------------------------------+
class NewsAiClient
{
private:
   string   apiKey;
   string   apiUrl;
   int      lastUpdate;
   
   // AI Decision Store
   string   lastAction;
   double   lastConfidence;
   string   lastInsight;

public:
   NewsAiClient(string key, string url="https://api.kilocode.ai/v1/chat/completions")
   {
      apiKey = key;
      apiUrl = url;
      lastUpdate = 0;
      lastAction = "WAIT";
      lastConfidence = 0.0;
      lastInsight = "Waiting for market signal...";
   }

   string GetAction()    { return lastAction; }
   double GetConfidence() { return lastConfidence; }
   string GetInsight()   { return lastInsight; }

   // ฟังก์ชันดึงค่าจาก JSON แบบ Simple String Parsing
   string ExtractJsonValue(string json, string key)
   {
      string searchKey = "\"" + key + "\":";
      int start = StringFind(json, searchKey);
      if(start == -1) return "";
      
      start += StringLen(searchKey);
      int end = StringFind(json, ",", start);
      if(end == -1) end = StringFind(json, "}", start);
      
      string val = StringSubstr(json, start, end - start);
      val = StringReplace(val, "\"", "");
      val = StringReplace(val, " ", "");
      return val;
   }

   // ฟังก์ชันดึงข่าวจาก Economic Calendar ของ MT5 โดยตรง (พลังแฝง MT5)
   string GetCalendarOutlook(string symbol)
   {
      MqlCalendarValue values[];
      datetime from = TimeCurrent();
      datetime to = from + 86400; // ดูล่วงหน้า 24 ชม.
      
      string outlook = "CALENDAR_EVENTS: ";
      if(CalendarValueHistory(values, from, to, symbol) > 0)
      {
         for(int i=0; i<MathMin(ArraySize(values), 3); i++)
         {
            MqlCalendarEvent event;
            if(CalendarEventById(values[i].event_id, event))
               outlook += StringFormat("[%s: Importance:%d] ", event.name, event.importance);
         }
      }
      else outlook += "No major events found.";
      return outlook;
   }

   // ฟังก์ชันจำลอง "โต๊ะทำงาน" (Workspace) ให้ AI ตัดสินใจแบบ Full-Auto (อัปเกรด Calendar)
   bool AnalyzeMarketWithKilo(string symbol, const double &features[])
   {
      if(apiKey == "" || apiKey == "YOUR_API_KEY") return false;
      if(TimeCurrent() < lastUpdate + 300) return true;

      char data[];char result[];string resultHeaders;
      MqlRates rates[];
      ArraySetAsSeries(rates, true);
      CopyRates(symbol, _Period, 0, 5, rates);
      
      string priceHistory = "";
      for(int i=0; i<5; i++) priceHistory += StringFormat("[Bar %d: O:%.5f, C:%.5f] ", i, rates[i].open, rates[i].close);
      
      // ดึงข่าวเศรษฐกิจล่วงหน้าจาก MT5
      string calData = GetCalendarOutlook(symbol);

      // --- ADVANCED SYSTEM PROMPT ---
      string sysPrompt = "You are the AK47 Master Trader. Your desk has MT5 candle data, indicators, and a REAL-TIME Economic Calendar.";
                         
      string userContent = StringFormat("Analysis for %s. LIVE_DATA: %s. INDICATORS: RSI=%.2f. %s. DECIDE NOW.", 
                                        symbol, priceHistory, features[3]*100, calData);

      string body = "{\"model\": \"kilo-alpha-1\", \"messages\": ["
                    "{\"role\": \"system\", \"content\": \"" + sysPrompt + "\"},"
                    "{\"role\": \"user\", \"content\": \"" + userContent + "\"}"
                    "], \"temperature\": 0.2}";
      
      StringToCharArray(body, data);
      string headers = "Content-Type: application/json\r\nAuthorization: Bearer " + apiKey + "\r\n";

      ResetLastError();
      int res = WebRequest("POST", apiUrl, headers, 30000, data, result, resultHeaders);

      if(res == 200)
      {
         string response = CharArrayToString(result);
         
         // --- LIGHTWEIGHT JSON PARSER ---
         lastAction = ExtractJsonValue(response, "action");
         string confStr = ExtractJsonValue(response, "confidence");
         lastConfidence = StringToDouble(confStr);
         
         int inStart = StringFind(response, "\"insight\":");
         if(inStart != -1) {
            inStart += 11;
            int inEnd = StringFind(response, "\"", inStart + 1);
            lastInsight = StringSubstr(response, inStart + 1, inEnd - inStart - 1);
         }

         lastUpdate = (int)TimeCurrent();
         return true;
      }
      return false;
   }
};
