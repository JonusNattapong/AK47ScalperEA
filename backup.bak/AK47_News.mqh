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
   string   systemPrompt;
   string   tinyFishKey;
   string   customInstruction;

   // AI Provider
   int      aiProvider;    // 0=OpenAI-compat, 1=Anthropic, 2=Ollama
   string   aiModel;

   // AI Decision Store
   string   lastAction;
   double   lastConfidence;
   string   lastInsight;

   string BuildRequestBody(string userContent)
   {
      if(aiProvider == 1) // Anthropic
      {
         return "{\"model\":\"" + aiModel + "\",\"max_tokens\":1024,\"system\":\"" + systemPrompt + "\",\"messages\":[{\"role\":\"user\",\"content\":\"" + userContent + "\"}]}";
      }
      // OpenAI-compat (0) & Ollama (2) use same format
      return "{\"model\":\"" + aiModel + "\",\"messages\":[{\"role\":\"system\",\"content\":\"" + systemPrompt + "\"},{\"role\":\"user\",\"content\":\"" + userContent + "\"}],\"temperature\":0.2}";
   }

   string BuildAuthHeader()
   {
      if(aiProvider == 1) // Anthropic
         return "Content-Type: application/json\r\nx-api-key: " + apiKey + "\r\nanthropic-version: 2023-06-01\r\n";
      if(aiProvider == 2) // Ollama (no auth)
         return "Content-Type: application/json\r\n";
      // OpenAI-compat
      return "Content-Type: application/json\r\nAuthorization: Bearer " + apiKey + "\r\n";
   }

   bool ParseResponse(string response)
   {
      // Extract content from provider-specific wrapper
      string content = "";

      if(aiProvider == 1) // Anthropic: {"content":[{"text":"..."}]}
      {
         int cs = StringFind(response, "\"text\":\"");
         if(cs < 0) return false;
         cs += 8;
         int ce = StringFind(response, "\"", cs);
         if(ce < 0) return false;
         content = StringSubstr(response, cs, ce - cs);
      }
      else if(aiProvider == 2) // Ollama: {"message":{"content":"..."}}
      {
         int cs = StringFind(response, "\"content\":\"");
         if(cs < 0) return false;
         cs += 11;
         int ce = StringFind(response, "\"", cs);
         if(ce < 0) return false;
         content = StringSubstr(response, cs, ce - cs);
      }
      else // OpenAI-compat: {"choices":[{"message":{"content":"..."}}]}
      {
         int cs = StringFind(response, "\"content\":\"");
         if(cs < 0) return false;
         cs += 11;
         int ce = StringFind(response, "\"", cs);
         if(ce < 0) return false;
         content = StringSubstr(response, cs, ce - cs);
      }

      if(content == "") return false;

      // Parse action/confidence/insight from content JSON
      lastAction = ExtractJsonValue(content, "action");
      string confStr = ExtractJsonValue(content, "confidence");
      lastConfidence = StringToDouble(confStr);

      int inStart = StringFind(content, "\"insight\":");
      if(inStart != -1)
      {
         inStart += 11;
         int inEnd = StringFind(content, "\"", inStart + 1);
         lastInsight = StringSubstr(content, inStart + 1, inEnd - inStart - 1);
      }

      return (lastAction != "");
   }

public:
   NewsAiClient(string key, string url="https://api.kilocode.ai/v1/chat/completions")
   {
      apiKey = key;
      apiUrl = url;
      lastUpdate = 0;
      lastAction = "WAIT";
      lastConfidence = 0.0;
      lastInsight = "Waiting for market signal...";
      systemPrompt = "You are the AK47 Master Trader. Your desk has MT5 candle data, indicators, and a REAL-TIME Economic Calendar. Respond in JSON format: {\"action\":\"BUY|SELL|WAIT\",\"confidence\":0.0-1.0,\"insight\":\"reason\"}";
      tinyFishKey = "";
      customInstruction = "";
      aiProvider = 0;
      aiModel = "kilo-alpha-1";
   }

   void SetSystemPrompt(string prompt) { systemPrompt = prompt; }
   void SetTinyFishKey(string key)     { tinyFishKey = key; }
   void SetInstruction(string instr)   { customInstruction = instr; }
   void SetProvider(int provider)      { aiProvider = provider; }
   void SetModel(string model)         { aiModel = model; }

   string GetAction()    { return lastAction; }
   double GetConfidence() { return lastConfidence; }
   string GetInsight()   { return lastInsight; }

   // simple JSON string parser
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

   // fetch upcoming economic calendar events from MT5
   string GetCalendarOutlook(string symbol)
   {
      MqlCalendarValue values[];
      datetime from = TimeCurrent();
      datetime to = from + 86400; // 24h lookahead

      string outlook = "CALENDAR_EVENTS: ";
      // CalendarSymbolCode removed - pass string directly
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

   // ---------------------------------------------------------------------------
   // FREE MODE: multi-timeframe + trend-aware + volatility-adjusted
   // Features layout:
   //   [3]  RSI/100            [4]  CCI/200+0.5       [5]  MACD/point10
   //   [6]  Stoch/100          [7]  ATR/point100       [8]  (close-MA20)/ATR
   //   [9]  VolumeRatio/2      [10] (MA1H-MA4H)/ATR    [11] Hurst exponent
   //   [12] DXY change         [13] SP500 change       [14] Market regime
   //   [15] Session quality    [16] Entropy            [17] Hurst (quantum)
   //   [18] Vol regime         [19] Momentum
   // ---------------------------------------------------------------------------
   void AnalyzeMarketFree(const double &features[])
   {
      double rsi         = features[3];
      double macd        = features[5];
      double stoch       = features[6];
      double trendMA     = features[8];    // (close-MA20)/ATR >0 = bullish
      double hiTrend     = features[10];   // (MA1H-MA4H)/ATR  >0 = H1 bullish
      double regime      = features[14];   // 0.75=trending 0.35=ranging 0.90=volatile 0.20=calm
      double sessionQ    = features[15];   // 0.0-1.0
      double volRegime   = features[18];   // >0.5 = high vol, <0.5 = low vol
      double momentum    = features[19];   // 0-1 price momentum

      // -- Determine H1 trend direction --
      bool h1Bullish = hiTrend > 0.0;
      bool h1Bearish = hiTrend < 0.0;
      // -- M1 trend --
      bool m1Bullish = trendMA > 0.0;
      bool m1Bearish = trendMA < 0.0;

      // -- Trend alignment score (0..1) --
      double trendScore = 0.5;
      if(h1Bullish && m1Bullish) trendScore = 0.80;  // aligned bullish
      else if(h1Bearish && m1Bearish) trendScore = 0.20;  // aligned bearish
      else if(!h1Bullish && !h1Bearish) trendScore = 0.50; // no trend
      else trendScore = h1Bullish ? 0.60 : 0.40; // conflicting: lean on H1

      // -- Volatility filter --
      bool isHighVol = volRegime > 0.65;
      bool isLowVol  = volRegime < 0.35;
      // -- Momentum direction --
      bool momUp   = momentum > 0.55;
      bool momDown = momentum < 0.45;
      // -- Session quality gate --
      bool goodSession = sessionQ > 0.40;

      // -- Decision logic with multi-confirmation --
      double conf = 0.0;
      string action = "WAIT", reasons = "";

      // === BUY signals ===
      bool buySignal = false;

      // Oversold bounce with trend alignment
      if(rsi < 0.35 && h1Bullish && macd > 0.0 && momUp && goodSession)
      {
         buySignal = true;
         conf = 0.78 + (0.35 - rsi) * 0.6 + (trendScore - 0.5) * 0.3 + (sessionQ - 0.5) * 0.15;
         reasons = "OVERSOLD+TREND+MACD+MOM";
      }
      // Trend pullback to MA20
      else if(rsi > 0.40 && rsi < 0.55 && h1Bullish && trendMA < 0.0 && trendMA > -2.0 && momUp && goodSession)
      {
         buySignal = true;
         conf = 0.72 + (1.0 - trendMA * -1.0) * 0.1 + sessionQ * 0.1;
         reasons = "PULLBACK+TREND";
      }
      // Momentum breakout
      else if(momUp && m1Bullish && h1Bullish && stoch < 0.70 && macd > 0.0 && isLowVol && goodSession)
      {
         buySignal = true;
         conf = 0.70 + momentum * 0.15 + sessionQ * 0.1;
         reasons = "MOMENTUM+BREAKOUT";
      }
      // RSI divergence + trend
      else if(rsi < 0.30 && trendMA < -1.0 && macd > 0.0 && goodSession)
      {
         buySignal = true;
         conf = 0.65 + (0.30 - rsi) * 0.5;
         reasons = "DIVERGENCE+BUY";
      }
      // Volatile breakdown reversal (high vol + strong bear -> reversal possible)
      else if(rsi < 0.25 && isHighVol && momentum < 0.30 && trendMA < -2.0 && goodSession)
      {
         buySignal = true;
         conf = 0.60;
         reasons = "CAPITULATION";
      }

      // === SELL signals ===
      bool sellSignal = false;

      if(rsi > 0.65 && h1Bearish && macd < 0.0 && momDown && goodSession)
      {
         sellSignal = true;
         conf = 0.78 + (rsi - 0.65) * 0.6 + (0.5 - trendScore) * 0.3 + (sessionQ - 0.5) * 0.15;
         reasons = "OVERBOUGHT+TREND+MACD+MOM";
      }
      else if(rsi < 0.60 && rsi > 0.45 && h1Bearish && trendMA > 0.0 && trendMA < 2.0 && momDown && goodSession)
      {
         sellSignal = true;
         conf = 0.72 + trendMA * 0.1 + sessionQ * 0.1;
         reasons = "PULLBACK+SELL";
      }
      else if(momDown && m1Bearish && h1Bearish && stoch > 0.30 && macd < 0.0 && isLowVol && goodSession)
      {
         sellSignal = true;
         conf = 0.70 + (1.0 - momentum) * 0.15 + sessionQ * 0.1;
         reasons = "MOMENTUM+BREAKDOWN";
      }
      else if(rsi > 0.70 && trendMA > 1.0 && macd < 0.0 && goodSession)
      {
         sellSignal = true;
         conf = 0.65 + (rsi - 0.70) * 0.5;
         reasons = "DIVERGENCE+SELL";
      }
      else if(rsi > 0.75 && isHighVol && momentum > 0.70 && trendMA > 2.0 && goodSession)
      {
         sellSignal = true;
         conf = 0.60;
         reasons = "EXHAUSTION";
      }

      // === Resolve conflict: prefer higher confidence signal ===
      if(buySignal && sellSignal)
      {
         double buyConf = conf; // save from last buy assignment
         // Re-evaluate both signals more strictly
         if(conf > 0.70 && trendScore < 0.50)
            buySignal = false; // SELL wins in bearish trend context
         else if(conf <= 0.70)
            sellSignal = false; // default to buy
      }

      if(buySignal)
      {
         action = "BUY";
         // Penalize low session quality
         if(sessionQ < 0.50) conf *= 0.90;
      }
      else if(sellSignal)
      {
         action = "SELL";
         if(sessionQ < 0.50) conf *= 0.90;
      }
      else
      {
         action = "WAIT";
         conf = 0.0;
         reasons = "NO_CLEAR_SIGNAL";
      }

      // clamp confidence
      if(conf > 1.0) conf = 1.0;
      if(conf < 0.0) conf = 0.0;

      lastAction     = action;
      lastConfidence = conf;
      lastInsight    = StringFormat("[FREE] RSI=%.1f Trend=%.2f H1=%.2f Reg=%.2f Sess=%.2f -> %s (%.0f%%) %s",
                                     rsi*100, trendMA, hiTrend, regime, sessionQ,
                                     action, conf*100, reasons);
      lastUpdate = (int)TimeCurrent();
   }

   // main analysis entry point - calls Kilo API or falls back to Free Mode
   bool AnalyzeMarketWithKilo(string symbol, const double &features[], string newsContext = "")
   {
      // ── FREE MODE FALLBACK ──
      if(apiKey == "" || apiKey == "YOUR_API_KEY_HERE" || apiKey == "YOUR_API_KEY")
      {
         if(TimeCurrent() < lastUpdate + 15) return true;   // rate-limit free mode to 15s
         AnalyzeMarketFree(features);
         return true;
      }

      if(TimeCurrent() < lastUpdate + 300) return true;

      char data[];char result[];string resultHeaders;
      MqlRates rates[];
      ArraySetAsSeries(rates, true);
      CopyRates(symbol, _Period, 0, 5, rates);

      string priceHistory = "";
      for(int i=0; i<5; i++) priceHistory += StringFormat("[Bar %d: O:%.5f, C:%.5f] ", i, rates[i].open, rates[i].close);

      // fetch economic calendar data
      string calData = GetCalendarOutlook(symbol);

      // Truncate news context to prevent oversized prompt
      string news = newsContext;
      if(StringLen(news) > 600)
         news = StringSubstr(news, 0, 600) + "...";

      // --- SYSTEM PROMPT (from active strategy profile) + full market context ---
      string instr = (customInstruction != "") ? (" USER_INSTRUCTION: " + customInstruction) : "";
      // Build rich market context from all features
      string regimeStr = "UNKNOWN";
      double regime = features[14];
      if(regime > 0.7) regimeStr = "TRENDING";
      else if(regime > 0.5) regimeStr = "VOLATILE";
      else if(regime > 0.3) regimeStr = "RANGING";
      else regimeStr = "CALM";

      double sessionQ = features[15];
      string sessionStr = (sessionQ > 0.7) ? "PRIME" : ((sessionQ > 0.4) ? "ACTIVE" : "OFF-HOURS");
      double momentum = features[19]; // 0-1
      string momStr = (momentum > 0.55) ? "BULLISH" : ((momentum < 0.45) ? "BEARISH" : "NEUTRAL");
      double entropy = features[16];
      string entropyStr = (entropy > 0.8) ? "HIGH" : ((entropy < 0.4) ? "LOW" : "MODERATE");
      double volRegime = features[18];
      string volStr = (volRegime > 0.6) ? "HIGH" : ((volRegime < 0.35) ? "LOW" : "NORMAL");

      string userContent = StringFormat(
         "TRADE SIGNAL for %s. "
         "MARKET: Regime=%s, Session=%s, Volatility=%s, Entropy=%s. "
         "TECHNICALS: RSI=%.1f, MACD=%.4f, Stoch=%.1f%%, Trend(MA20)=%.2f, H1Trend=%.2f. "
         "MOMENTUM=%s(%.2f). "
         "BARS: %s. "
         "NEWS: %s. "
         "CALENDAR: %s.%s "
         "Respond JSON: {\"action\":\"BUY|SELL|WAIT\",\"confidence\":0.0-1.0,\"insight\":\"1-sentence reason\"}",
         symbol,
         regimeStr, sessionStr, volStr, entropyStr,
         features[3]*100, features[5]*1000, features[6]*100, features[8], features[10],
         momStr, momentum,
         priceHistory,
         news,
         calData, instr);

      // Build provider-specific request
      string body = BuildRequestBody(userContent);
      string headers = BuildAuthHeader();

      StringToCharArray(body, data);
      ResetLastError();
      int res = WebRequest("POST", apiUrl, headers, 30000, data, result, resultHeaders);

      if(res == 200)
      {
         string response = CharArrayToString(result);
         if(ParseResponse(response))
         {
            lastUpdate = (int)TimeCurrent();
            return true;
         }
      }
      return false;
   }

   // -----------------------------------------------------------------------
   // TinyFish News Search - fetches latest news context for a symbol
   // Returns formatted string: "title1: snippet1 | title2: snippet2"
   // -----------------------------------------------------------------------
   bool SearchTinyFish(string symbol, int maxResults, string &outContext)
   {
      outContext = "";
      if(tinyFishKey == "") return false;

      string query = symbol + " forex news analysis";
      StringReplace(query, " ", "+");
      string url = "https://api.search.tinyfish.ai?query=" + query
                  + "&count=" + IntegerToString(MathMax(1, MathMin(maxResults, 5)));

      char data[], result[];
      string resultHeaders;
      string reqHeaders = "X-API-Key: " + tinyFishKey + "\r\n";

      ResetLastError();
      int res = WebRequest("GET", url, reqHeaders, 10000, data, result, resultHeaders);

      if(res != 200)
      {
         Print("TinyFish search failed for ", symbol, " error=", GetLastError());
         return false;
      }

      string response = CharArrayToString(result);
      if(response == "") return false;

      // Parse JSON results - extract title + snippet from each result
      string accumulated = "";
      string searchStr = "\"title\":\"";
      int pos = 0;

      for(int i=0; i<maxResults; i++)
      {
         // Find title
         int tStart = StringFind(response, searchStr, pos);
         if(tStart < 0) break;
         tStart += StringLen(searchStr);
         int tEnd = StringFind(response, "\"", tStart);
         if(tEnd < 0) break;
         string title = StringSubstr(response, tStart, tEnd - tStart);
         pos = tEnd;

         // Find snippet
         int sStart = StringFind(response, "\"snippet\":\"", pos);
         if(sStart < 0) break;
         sStart += 11;
         int sEnd = StringFind(response, "\"", sStart);
         if(sEnd < 0) break;
         string snippet = StringSubstr(response, sStart, sEnd - sStart);
         pos = sEnd;

         if(accumulated != "") accumulated += " | ";
         accumulated += title + ": " + snippet;
      }

      outContext = accumulated;
      return (accumulated != "");
   }
};
