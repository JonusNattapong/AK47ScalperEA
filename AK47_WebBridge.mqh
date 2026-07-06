//+------------------------------------------------------------------+
//|                                              AK47_WebBridge.mqh  |
//|                        Web Dashboard Bridge for AK47ScalperEA    |
//|                        Sends EA data to local Node.js server     |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, AK47 Scalper EA"
#property strict

//+------------------------------------------------------------------+
//| Configuration (set before first use)                             |
//+------------------------------------------------------------------+
static string   g_webHost   = "127.0.0.1";
static int      g_webPort   = 3000;
static bool     g_webEnabled = false;
static datetime g_lastStateSend = 0;
static datetime g_lastSignalSend = 0;

//+------------------------------------------------------------------+
//| Init / Enable                                                   |
//+------------------------------------------------------------------+
void WebBridgeEnable(string host = "127.0.0.1", int port = 3000)
{
   g_webHost = host;
   g_webPort = port;
   g_webEnabled = true;
   Print("WebBridge: enabled -> http://", g_webHost, ":", g_webPort);
}

void WebBridgeDisable()
{
   g_webEnabled = false;
}

bool WebBridgeIsEnabled()
{
   return g_webEnabled;
}

//+------------------------------------------------------------------+
//| Internal: POST JSON to endpoint                                  |
//+------------------------------------------------------------------+
bool WebBridgePost(string endpoint, string jsonBody)
{
   if(!g_webEnabled) return false;

   string url = "http://" + g_webHost + ":" + IntegerToString(g_webPort) + endpoint;
   string headers = "Content-Type: application/json\r\n";

   char data[];
   char result[];
   string resultHeaders;
   StringToCharArray(jsonBody, data);

   ResetLastError();
   int res = WebRequest("POST", url, headers, 3000, data, result, resultHeaders);

   if(res == -1)
   {
      int err = GetLastError();
      if(err != 0 && err != 4060) // ignore common non-fatal errors
         Print("WebBridge POST ", endpoint, " error=", err);
      return false;
   }
   return (res == 200 || res == 201);
}

//+------------------------------------------------------------------+
//| Internal: GET JSON from endpoint                                 |
//+------------------------------------------------------------------+
string WebBridgeGet(string endpoint)
{
   if(!g_webEnabled) return "";

   string url = "http://" + g_webHost + ":" + IntegerToString(g_webPort) + endpoint;
   string headers = "";

   char data[];
   char result[];
   string resultHeaders;

   ResetLastError();
   int res = WebRequest("GET", url, headers, 3000, data, result, resultHeaders);

   if(res == 200)
      return CharArrayToString(result);

   return "";
}

//+------------------------------------------------------------------+
//| Send EA State (balance, equity, P&L, positions)                  |
//+------------------------------------------------------------------+
void WebBridgeSendState(double balance, double equity, double dailyPnl, double dailyPct,
                         int totalPositions, int maxOrders, bool isPaused, string status)
{
   if(!g_webEnabled) return;
   if(TimeCurrent() < g_lastStateSend + 2) return; // max every 2s
   g_lastStateSend = TimeCurrent();

   string json = StringFormat("{"
      "\"status\":\"%s\","
      "\"balance\":%.2f,"
      "\"equity\":%.2f,"
      "\"daily_pnl\":%.2f,"
      "\"daily_pct\":%.2f,"
      "\"total_positions\":%d,"
      "\"max_orders\":%d,"
      "\"is_global_paused\":%d"
      "}", status, balance, equity, dailyPnl, dailyPct, totalPositions, maxOrders, isPaused ? 1 : 0);

   WebBridgePost("/api/state", json);
}

//+------------------------------------------------------------------+
//| Send Symbol Update (signal + insight)                            |
//+------------------------------------------------------------------+
void WebBridgeSendSignal(string symbol, int magic, string action, double confidence, string insight)
{
   if(!g_webEnabled) return;

   // Don't send every tick — only when action changed or every 60s
   if(TimeCurrent() < g_lastSignalSend + 60) return;

   string json = StringFormat("{"
      "\"symbol\":\"%s\","
      "\"action\":\"%s\","
      "\"confidence\":%.2f,"
      "\"insight\":\"%s\""
      "}", symbol, action, confidence, insight);

   // Update symbol in DB
   string symJson = StringFormat("{"
      "\"name\":\"%s\","
      "\"magic\":%d,"
      "\"last_action\":\"%s\","
      "\"last_confidence\":%.2f,"
      "\"last_insight\":\"%s\""
      "}", symbol, magic, action, confidence, insight);

   WebBridgePost("/api/symbols", symJson);

   // Also post as signal if action is BUY or SELL
   if(action == "BUY" || action == "SELL")
   {
      WebBridgePost("/api/signals", StringFormat("{"
         "\"symbol\":\"%s\","
         "\"action\":\"%s\","
         "\"confidence\":%.2f,"
         "\"insight\":\"%s\""
         "}", symbol, action, confidence, insight));
   }

   g_lastSignalSend = TimeCurrent();
}

//+------------------------------------------------------------------+
//| Send Position Update                                             |
//+------------------------------------------------------------------+
void WebBridgeSendPosition(ulong ticket, string symbol, string type, double volume,
                            double openPrice, double sl, double tp, double profit,
                            string openTime, int magic, string comment)
{
   if(!g_webEnabled) return;

   string json = StringFormat("{"
      "\"ticket\":%lld,"
      "\"symbol\":\"%s\","
      "\"type\":\"%s\","
      "\"volume\":%.2f,"
      "\"open_price\":%.5f,"
      "\"sl\":%.5f,"
      "\"tp\":%.5f,"
      "\"profit\":%.2f,"
      "\"open_time\":\"%s\","
      "\"magic\":%d,"
      "\"comment\":\"%s\""
      "}", ticket, symbol, type, volume, openPrice, sl, tp, profit, openTime, magic, comment);

   WebBridgePost("/api/positions", json);
}

//+------------------------------------------------------------------+
//| Close Position                                                   |
//+------------------------------------------------------------------+
void WebBridgeClosePosition(ulong ticket, double profit)
{
   if(!g_webEnabled) return;

   string json = StringFormat("{\"ticket\":%lld,\"profit\":%.2f}", ticket, profit);
   WebBridgePost("/api/positions/close", json);
}

//+------------------------------------------------------------------+
//| Send Chat Message                                                |
//+------------------------------------------------------------------+
void WebBridgeSendChat(string role, string content)
{
   if(!g_webEnabled) return;

   string json = StringFormat("{\"role\":\"%s\",\"content\":\"%s\"}", role, content);
   WebBridgePost("/api/chat", json);
}

//+------------------------------------------------------------------+
//| Fetch Strategy Config from Web Dashboard                         |
//+------------------------------------------------------------------+
bool WebBridgeFetchStrategy(double &lotSize, double &maxDD, double &dailyTarget,
                             int &maxOrders, int &maxSpread, double &minConf)
{
   if(!g_webEnabled) return false;

   string response = WebBridgeGet("/api/strategy");
   if(response == "") return false;

   // Simple JSON extraction
   lotSize     = StringToDouble(ExtractJson(response, "lot_size"));
   maxDD       = StringToDouble(ExtractJson(response, "max_daily_dd"));
   dailyTarget = StringToDouble(ExtractJson(response, "daily_target"));
   maxOrders   = (int)StringToInteger(ExtractJson(response, "max_orders"));
   maxSpread   = (int)StringToInteger(ExtractJson(response, "max_spread"));
   minConf     = StringToDouble(ExtractJson(response, "min_confidence"));

   return (lotSize > 0);
}

//+------------------------------------------------------------------+
//| Simple JSON field extractor (no dependencies)                    |
//+------------------------------------------------------------------+
string ExtractJson(string json, string key)
{
   string search = "\"" + key + "\":";
   int start = StringFind(json, search);
   if(start < 0) return "";

   start += StringLen(search);
   if(start >= StringLen(json)) return "";

   // Skip spaces
   while(start < StringLen(json) && json.CharAt(start) == ' ') start++;

   // Check type
   if(json.CharAt(start) == '\"')
   {
      // String value
      start++;
      int end = StringFind(json, "\"", start);
      if(end < 0) return "";
      return StringSubstr(json, start, end - start);
   }

   // Number or other
   int end = start;
   while(end < StringLen(json))
   {
      int c = json.CharAt(end);
      if(c == ',' || c == '}' || c == ']' || c == ' ') break;
      end++;
   }
   return StringSubstr(json, start, end - start);
}
//+------------------------------------------------------------------+
