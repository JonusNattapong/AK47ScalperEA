const express = require('express');
const http = require('http');
const { Server } = require('socket.io');
const path = require('path');
const cors = require('cors');
const db = require('../db');

const app = express();
const server = http.createServer(app);
const io = new Server(server, {
  cors: { origin: '*', methods: ['GET', 'POST'] }
});

const PORT = process.env.PORT || 3000;

app.use(cors());
app.use(express.json());
app.use(express.static(path.join(__dirname, '..', 'public')));

// Load config helper
function getAiConfig() {
  try {
    const fs = require('fs');
    const configPath = path.join(__dirname, '..', 'config.json');
    const content = fs.readFileSync(configPath, 'utf8');
    return JSON.parse(content);
  } catch (e) {
    console.error("Failed to load config.json:", e);
    return {};
  }
}

// AI Trading Assistant helper function
async function generateAiReply(userMessage) {
  const config = getAiConfig();
  const provider = config.provider || 'kilo';
  const provCfg = config[provider] || {};
  const apiKey = provCfg.apiKey || '';
  const apiUrl = provCfg.apiUrl || 'https://api.kilocode.ai/v1/chat/completions';
  const model = provCfg.model || 'kilo-alpha-1';

  // Fetch context from DB
  const state = db.getEaState() || {};
  const positions = db.getPositions() || [];
  const symbols = db.getSymbols() || [];
  const strategy = db.getStrategyConfig() || {};
  const recentSignals = db.getSignals(5) || [];

  // Format context for prompt
  const contextPrompt = `You are the AK47 Scalper EA Chat Companion, an expert AI assistant built into the trading terminal.
Below is the current live status of the trading EA:
- EA Status: ${state.status || 'STOPPED'} (Paused: ${state.is_global_paused ? 'YES' : 'NO'})
- Balance: $${(state.balance || 0).toFixed(2)} | Equity: $${(state.equity || 0).toFixed(2)}
- Daily P&L: $${(state.daily_pnl || 0).toFixed(2)} (${(state.daily_pct || 0).toFixed(2)}%)
- Active Positions: ${positions.length} open position(s)
${positions.map(p => `  * Ticket #${p.ticket}: ${p.type} ${p.volume} lot on ${p.symbol} (Profit: $${p.profit})`).join('\n')}
- Trading symbols basket: ${strategy.symbols || 'None'}
- Latest Symbol Signals:
${symbols.map(s => `  * ${s.name}: Last Action = ${s.last_action} (Conf: ${(s.last_confidence * 100).toFixed(0)}%), Insight: ${s.last_insight || 'N/A'}`).join('\n')}
- Recent Signal Alerts:
${recentSignals.map(s => `  * [${s.created_at}] ${s.symbol} -> ${s.action} (Conf: ${(s.confidence * 100).toFixed(0)}%), Insight: ${s.insight || 'N/A'}`).join('\n')}

Respond to the user's trading questions, summarize the EA status if asked, or help them with settings.
Note: The user's trading plan focuses heavily on high-risk, high-reward trading. Ensure all advice, recommendations, and insights align with aggressive trading principles (e.g., maximum capital efficiency, aggressive scaling, trailing profit locks, and high volatility tolerance).

You can also execute commands directly on the trading system by appending a JSON action block at the very end of your response, starting with the delimiter '[[ACTION]]'.
For example, if the user asks you to pause trading:
[[ACTION]]
{
  "type": "PAUSE_EA"
}

Available Actions:
1. PAUSE_EA (pauses all new trade executions)
2. RESUME_EA (resumes trade executions)
3. UPDATE_STRATEGY (updates strategy config inputs. Params: lot_size, max_daily_dd, daily_target, max_orders, max_spread, min_confidence, symbols, api_interval, trailing_start, trailing_stop)
   Example:
   [[ACTION]]
   {
     "type": "UPDATE_STRATEGY",
     "params": {
       "lot_size": 0.05,
       "max_orders": 6
     }
   }
4. ADD_JOURNAL (adds a note to the trading journal. Params: title, content, entry_type, symbol)
5. MODIFY_POSITION (updates Stop Loss and/or Take Profit of an open position. Params: ticket, sl, tp)
   Example:
   [[ACTION]]
   {
     "type": "MODIFY_POSITION",
     "params": {
       "ticket": 1234567,
       "sl": 1.1250,
       "tp": 1.1350
     }
   }

Only append the [[ACTION]] block if the user explicitly requests you to make a change, pause, resume, modify a trade, or log a journal. Do not append it for general analysis questions.

Keep your answers concise, informative, and professional.`;

  if (!apiKey && provider !== 'ollama') {
    return `I am the AK47 Trading Assistant. To enable full AI functionality, please configure your API key for the "${provider}" provider in your "web/config.json" file.

Currently, the EA is ${state.status || 'STOPPED'} with a balance of $${(state.balance || 0).toFixed(2)} and ${positions.length} open position(s).`;
  }

  try {
    let headers = { "Content-Type": "application/json" };
    if (apiKey) {
      if (provider === 'openai' || provider === 'kilo' || provider === 'deepseek') {
        headers["Authorization"] = `Bearer ${apiKey}`;
      }
    }

    const body = {
      model: model,
      messages: [
        { role: 'system', content: contextPrompt },
        { role: 'user', content: userMessage }
      ],
      temperature: config.settings?.temperature ?? 0.3,
      max_tokens: config.settings?.maxTokens ?? 500
    };

    if (typeof fetch === 'undefined') {
      return `Error: Global fetch is not supported in this Node.js environment. Please run with Node.js v18+ or Bun, or install node-fetch.`;
    }

    const response = await fetch(apiUrl, {
      method: 'POST',
      headers: headers,
      body: JSON.stringify(body)
    });

    if (!response.ok) {
      const errText = await response.text();
      throw new Error(`API returned status ${response.status}: ${errText}`);
    }

    const data = await response.json();
    const reply = data.choices?.[0]?.message?.content || "";
    return reply || "I could not generate a response.";
  } catch (err) {
    console.error("AI Error:", err);
    return `Error communicating with AI provider (${provider}): ${err.message}. Please verify your API key and network connection.`;
  }
}

// ========== REST API ==========

// --- EA State ---
app.get('/api/state', (req, res) => {
  res.json(db.getEaState());
});

app.post('/api/state', (req, res) => {
  db.updateEaState(req.body);
  // Record performance snapshot (throttled: one per row)
  db.addSnapshot({
    balance: req.body.balance || 0,
    equity: req.body.equity || 0,
    daily_pnl: req.body.daily_pnl || 0,
    daily_pct: req.body.daily_pct || 0
  });
  const state = db.getEaState();
  io.emit('ea:state', state);
  res.json(state);
});

// --- Symbols ---
app.get('/api/symbols', (req, res) => {
  res.json(db.getSymbols());
});

app.post('/api/symbols', (req, res) => {
  db.updateSymbol(req.body);
  const symbols = db.getSymbols();
  io.emit('ea:symbols', symbols);
  res.json(symbols);
});

// --- Positions ---
app.get('/api/positions', (req, res) => {
  res.json(db.getPositions());
});

app.get('/api/positions/history', (req, res) => {
  const limit = parseInt(req.query.limit) || 50;
  res.json(db.getPositionHistory(limit));
});

app.post('/api/positions', (req, res) => {
  db.upsertPosition(req.body);
  const positions = db.getPositions();
  io.emit('ea:positions', positions);
  res.json(positions);
});

app.post('/api/positions/close', (req, res) => {
  db.closePosition(req.body.ticket, req.body.profit);
  const positions = db.getPositions();
  io.emit('ea:positions', positions);
  res.json(positions);
});

app.post('/api/positions/modify', (req, res) => {
  const { ticket, sl, tp } = req.body;
  db.modifyPositionSlTp(ticket, sl, tp);
  const positions = db.getPositions();
  io.emit('ea:positions', positions);
  res.json({ success: true, positions });
});

app.get('/api/positions/updates', (req, res) => {
  const sqlite = db.getDb();
  const updates = sqlite.prepare("SELECT ticket, sl, tp FROM positions WHERE comment = 'MODIFIED_BY_WEB' AND status = 'OPEN'").all();
  res.json(updates);
});

// --- Chat ---
app.get('/api/chat', (req, res) => {
  const limit = parseInt(req.query.limit) || 100;
  res.json(db.getMessages(limit));
});

// Process action block helper
function handleAiAction(replyText) {
  const delimiter = "[[ACTION]]";
  const index = replyText.indexOf(delimiter);
  if (index === -1) return { cleanReply: replyText, action: null };

  const cleanReply = replyText.substring(0, index).trim();
  const actionJsonStr = replyText.substring(index + delimiter.length).trim();
  
  try {
    const action = JSON.parse(actionJsonStr);
    return { cleanReply, action };
  } catch (err) {
    console.error("Failed to parse action JSON:", err);
    return { cleanReply: replyText, action: null };
  }
}

app.post('/api/chat', async (req, res) => {
  const { role, content } = req.body;
  const msg = db.addMessage(role, content);
  io.emit('chat:message', msg);
  res.json(msg);

  // If message is from user, generate AI assistant reply asynchronously
  if (role === 'user') {
    const config = getAiConfig();
    if (config.ai_assistant_active === false) {
      return;
    }
    try {
      const rawReply = await generateAiReply(content);
      const { cleanReply, action } = handleAiAction(rawReply);
      
      const replyMsg = db.addMessage('assistant', cleanReply);
      io.emit('chat:message', replyMsg);
      
      // Execute the action if valid
      if (action && action.type) {
        console.log("[AI Action Executing]:", action);
        if (action.type === 'PAUSE_EA') {
          const state = db.getEaState();
          db.updateEaState({ ...state, is_global_paused: 1, status: 'PAUSED' });
          io.emit('ea:state', db.getEaState());
          
          const sysMsg = db.addMessage('system', "AI Trading Assistant has paused trading.");
          io.emit('chat:message', sysMsg);
        }
        else if (action.type === 'RESUME_EA') {
          const state = db.getEaState();
          db.updateEaState({ ...state, is_global_paused: 0, status: 'RUNNING' });
          io.emit('ea:state', db.getEaState());
          
          const sysMsg = db.addMessage('system', "AI Trading Assistant has resumed trading.");
          io.emit('chat:message', sysMsg);
        }
        else if (action.type === 'UPDATE_STRATEGY') {
          db.updateStrategyConfig(action.params);
          io.emit('ea:strategy', db.getStrategyConfig());
          
          const paramsStr = Object.entries(action.params).map(([k,v]) => `${k}=${v}`).join(', ');
          const sysMsg = db.addMessage('system', `AI Trading Assistant updated strategy inputs: ${paramsStr}`);
          io.emit('chat:message', sysMsg);
        }
        else if (action.type === 'ADD_JOURNAL') {
          db.addJournalEntry(action.params);
          const entry = db.getJournalEntries(1)[0];
          io.emit('journal:entry', entry);
        }
        else if (action.type === 'MODIFY_POSITION') {
          db.modifyPositionSlTp(action.params.ticket, action.params.sl, action.params.tp);
          io.emit('ea:positions', db.getPositions());
          
          const sysMsg = db.addMessage('system', `AI has updated position #${action.params.ticket} target: SL=${action.params.sl}, TP=${action.params.tp}`);
          io.emit('chat:message', sysMsg);
        }
      }
    } catch (err) {
      console.error("Failed to generate AI chat response:", err);
      const errMsg = db.addMessage('assistant', "Sorry, I encountered an error while processing your request.");
      io.emit('chat:message', errMsg);
    }
  }
});

// --- Signals ---
app.get('/api/signals', (req, res) => {
  const limit = parseInt(req.query.limit) || 50;
  res.json(db.getSignals(limit));
});

app.post('/api/signals', (req, res) => {
  db.addSignal(req.body);
  const signals = db.getSignals(10);
  io.emit('ea:signal', signals[0]);
  res.json(signals[0]);
});

// --- Performance History ---
app.get('/api/performance', (req, res) => {
  const limit = parseInt(req.query.limit) || 500;
  res.json(db.getSnapshots(limit));
});

// --- Strategy Config ---
app.get('/api/strategy', (req, res) => {
  res.json(db.getStrategyConfig());
});

app.post('/api/strategy', (req, res) => {
  db.updateStrategyConfig(req.body);
  const config = db.getStrategyConfig();
  io.emit('ea:strategy', config);
  res.json(config);
});

// --- AI Config ---
app.get('/api/aiconfig', (req, res) => {
  res.json(getAiConfig());
});

app.post('/api/aiconfig', (req, res) => {
  const { provider, apiKey, model, ai_assistant_active } = req.body;
  const config = getAiConfig();
  
  if (provider) {
    config.provider = provider;
    if (!config[provider]) {
      config[provider] = {};
    }
    if (apiKey !== undefined) config[provider].apiKey = apiKey;
    if (model !== undefined) config[provider].model = model;
  }
  
  if (ai_assistant_active !== undefined) {
    config.ai_assistant_active = !!ai_assistant_active;
  }
  
  const fs = require('fs');
  fs.writeFileSync(path.join(__dirname, '..', 'config.json'), JSON.stringify(config, null, 2), 'utf8');
  res.json({ success: true, config });
});

// --- Journal ---
app.get('/api/journal', (req, res) => {
  const limit = parseInt(req.query.limit) || 100;
  res.json(db.getJournalEntries(limit));
});

app.post('/api/journal', (req, res) => {
  const entry = db.addJournalEntry(req.body);
  io.emit('journal:entry', entry);
  res.json(entry);
});

// ========== SOCKET.IO ==========
io.on('connection', (socket) => {
  console.log(`[WS] Client connected: ${socket.id}`);

  // Send initial state on connect
  socket.emit('ea:state', db.getEaState());
  socket.emit('ea:symbols', db.getSymbols());
  socket.emit('ea:positions', db.getPositions());
  socket.emit('ea:strategy', db.getStrategyConfig());

  socket.on('disconnect', () => {
    console.log(`[WS] Client disconnected: ${socket.id}`);
  });
});

// ========== START ==========
server.listen(PORT, () => {
  console.log(`\n  AK47 Web Console running at:`);
  console.log(`  ➜  http://localhost:${PORT}`);
  console.log(`  ➜  WS/Socket.IO on port ${PORT}\n`);
});
