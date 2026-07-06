/* ============================================================
   AK47 Scalper EA — Web Console Client App
   Socket.IO real-time dashboard + chat + strategy management
   ============================================================ */

const socket = io();
let currentPage = 'chat';
let loadedMessages = [];

// ========== DOM REFS ==========
const $ = (sel) => document.querySelector(sel);
const pages = {
  chat: $('#page-chat'),
  dashboard: $('#page-dashboard'),
  strategy: $('#page-strategy'),
  positions: $('#page-positions'),
  journal: $('#page-journal')
};
const navBtns = document.querySelectorAll('.nav-btn');

// ========== NAVIGATION ==========
navBtns.forEach(btn => {
  btn.addEventListener('click', () => {
    const page = btn.dataset.page;
    showPage(page);
  });
});

function showPage(page) {
  currentPage = page;
  Object.keys(pages).forEach(k => pages[k].classList.remove('active'));
  navBtns.forEach(b => b.classList.remove('active'));
  pages[page].classList.add('active');
  document.querySelector(`.nav-btn[data-page="${page}"]`)?.classList.add('active');
}

// ========== CONNECTION STATUS ==========
const connDot = $('#connStatus .status-dot');
const connText = $('#connStatus .status-text');

socket.on('connect', () => {
  connDot.className = 'status-dot connected';
  connText.textContent = 'Connected';
});

socket.on('disconnect', () => {
  connDot.className = 'status-dot disconnected';
  connText.textContent = 'Disconnected';
});

// ========== EA STATE ==========
const eaStatusDot = $('#eaStatusBadge .status-dot');
const eaStatusText = $('#eaStatusBadge .status-text');

function updateEaState(state) {
  if (!state) return;
  const running = state.status === 'RUNNING';
  eaStatusDot.className = running ? 'status-dot running' : 'status-dot stopped';
  eaStatusText.textContent = state.is_global_paused ? 'EA PAUSED' : running ? 'EA RUNNING' : 'EA STOPPED';

  // Dashboard cards
  $('#dashBalanceVal').textContent = '$' + Number(state.balance).toFixed(2);
  $('#dashEquityVal').textContent = '$' + Number(state.equity).toFixed(2);

  const pnl = Number(state.daily_pnl);
  const pct = Number(state.daily_pct);
  const pnlEl = $('#dashPnlVal');
  const pctEl = $('#dashPnlPct');
  pnlEl.textContent = (pnl >= 0 ? '+' : '') + '$' + pnl.toFixed(2);
  pnlEl.className = 'card-value ' + (pnl >= 0 ? 'positive' : 'negative');
  pctEl.textContent = '(' + (pct >= 0 ? '+' : '') + pct.toFixed(2) + '%)';
  pctEl.className = 'card-sub ' + (pct >= 0 ? 'positive' : 'negative');

  $('#dashPosCount').textContent = state.total_positions;
}

function addSystemMessage(text) {
  addChatMessage('system', text);
}

// ========== CHAT ==========
const chatMessages = $('#chatMessages');
const chatInput = $('#chatInput');
const chatSendBtn = $('#chatSendBtn');

function addChatMessage(role, content) {
  const div = document.createElement('div');
  div.className = `chat-message ${role === 'user' ? 'user' : 'ai'}`;

  const avatar = document.createElement('div');
  avatar.className = 'chat-avatar';
  avatar.textContent = role === 'user' ? 'U' : 'AI';

  const bubble = document.createElement('div');
  bubble.className = 'chat-bubble';

  const text = document.createElement('div');
  text.textContent = content;
  bubble.appendChild(text);

  const time = document.createElement('span');
  time.className = 'msg-time';
  const now = new Date();
  time.textContent = now.toLocaleTimeString();
  bubble.appendChild(time);

  div.appendChild(avatar);
  div.appendChild(bubble);
  chatMessages.appendChild(div);
  chatMessages.scrollTop = chatMessages.scrollHeight;
}

function sendChatMessage() {
  const text = chatInput.value.trim();
  if (!text) return;
  chatInput.value = '';
  addChatMessage('user', text);

  fetch('/api/chat', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ role: 'user', content: text })
  }).catch(console.error);
}

chatSendBtn.addEventListener('click', sendChatMessage);
chatInput.addEventListener('keydown', (e) => {
  if (e.key === 'Enter' && !e.shiftKey) {
    e.preventDefault();
    sendChatMessage();
  }
});

socket.on('chat:message', (msg) => {
  if (msg.role !== 'user') addChatMessage(msg.role, msg.content);
});

// Load chat history
fetch('/api/chat?limit=50')
  .then(r => r.json())
  .then(msgs => msgs.forEach(m => addChatMessage(m.role, m.content)))
  .catch(() => addSystemMessage('Welcome to AK47 Trading Console'));

// ========== DASHBOARD: SYMBOLS ==========
const symbolBody = $('#symbolTableBody');

function renderSymbols(symbols) {
  symbolBody.innerHTML = '';
  symbols.forEach(s => {
    const tr = document.createElement('tr');
    if (s.is_disabled) tr.className = 'disabled-row';
    const action = (s.last_action || 'WAIT').toLowerCase();
    const badgeClass = action === 'buy' ? 'badge-buy' : action === 'sell' ? 'badge-sell' : 'badge-wait';
    tr.innerHTML = `
      <td>${s.name}</td>
      <td><span class="badge ${badgeClass}">${s.last_action || 'WAIT'}</span></td>
      <td>${(s.last_confidence * 100).toFixed(0)}%</td>
      <td>${s.is_disabled ? '❌ Disabled' : '✅ Active'}</td>
      <td>${s.last_insight || '-'}</td>
    `;
    symbolBody.appendChild(tr);
  });
}

// ========== DASHBOARD: SIGNALS ==========
const signalBody = $('#signalTableBody');

function renderSignals(signals) {
  signalBody.innerHTML = '';
  if (!signals || signals.length === 0) return;
  signals.slice(0, 20).forEach(s => {
    const tr = document.createElement('tr');
    const act = (s.action || '').toLowerCase();
    const badge = act === 'buy' ? 'badge-buy' : act === 'sell' ? 'badge-sell' : 'badge-wait';
    tr.innerHTML = `
      <td>${s.created_at || '-'}</td>
      <td>${s.symbol}</td>
      <td><span class="badge ${badge}">${s.action}</span></td>
      <td>${(s.confidence * 100).toFixed(0)}%</td>
      <td>${s.insight || '-'}</td>
    `;
    signalBody.appendChild(tr);
  });
}

// ========== POSITIONS ==========
const posBody = $('#positionsTableBody');
const posEmpty = $('#positionsEmpty');
const histBody = $('#historyTableBody');

function renderPositions(positions) {
  posBody.innerHTML = '';
  if (!positions || positions.length === 0) {
    posEmpty.style.display = 'block';
    return;
  }
  posEmpty.style.display = 'none';
  positions.forEach(p => {
    const tr = document.createElement('tr');
    const isBuy = p.type === 'buy' || p.type === 'POSITION_TYPE_BUY';
    tr.innerHTML = `
      <td>${p.ticket}</td>
      <td>${p.symbol}</td>
      <td><span class="badge ${isBuy ? 'badge-buy' : 'badge-sell'}">${isBuy ? 'BUY' : 'SELL'}</span></td>
      <td>${p.volume}</td>
      <td>${Number(p.open_price).toFixed(5)}</td>
      <td>${p.sl ? Number(p.sl).toFixed(5) : '-'}</td>
      <td>${p.tp ? Number(p.tp).toFixed(5) : '-'}</td>
      <td class="${Number(p.profit) >= 0 ? 'text-green' : 'text-red'}">${Number(p.profit).toFixed(2)}</td>
      <td>${p.open_time || '-'}</td>
    `;
    posBody.appendChild(tr);
  });
}

function renderHistory(history) {
  histBody.innerHTML = '';
  if (!history || history.length === 0) return;
  history.slice(0, 30).forEach(p => {
    const tr = document.createElement('tr');
    const isBuy = p.type === 'buy' || p.type === 'POSITION_TYPE_BUY';
    tr.innerHTML = `
      <td>${p.ticket}</td>
      <td>${p.symbol}</td>
      <td><span class="badge ${isBuy ? 'badge-buy' : 'badge-sell'}">${isBuy ? 'BUY' : 'SELL'}</span></td>
      <td>${p.volume}</td>
      <td class="${Number(p.profit) >= 0 ? 'text-green' : 'text-red'}">${Number(p.profit).toFixed(2)}</td>
      <td>${p.open_time || '-'}</td>
    `;
    histBody.appendChild(tr);
  });
}

// ========== STRATEGY CONFIG ==========
const strategyForm = $('#strategyForm');
const cfgFields = [
  'cfg_lot_size', 'cfg_max_daily_dd', 'cfg_daily_target', 'cfg_max_orders',
  'cfg_max_spread', 'cfg_min_confidence', 'cfg_base_magic', 'cfg_trailing_start',
  'cfg_trailing_stop', 'cfg_symbols', 'cfg_api_interval'
];

function populateStrategy(config) {
  if (!config) return;
  cfgFields.forEach(id => {
    const el = document.getElementById(id);
    if (!el) return;
    const key = id.replace('cfg_', '');
    if (config[key] !== undefined) el.value = config[key];
  });
}

strategyForm.addEventListener('submit', (e) => {
  e.preventDefault();
  const data = {};
  cfgFields.forEach(id => {
    const el = document.getElementById(id);
    if (!el) return;
    const key = id.replace('cfg_', '');
    const val = el.value;
    data[key] = isNaN(val) ? val : Number(val);
  });
  fetch('/api/strategy', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(data)
  }).then(r => r.json()).then(() => {
    addSystemMessage('✅ Strategy configuration saved');
  }).catch(console.error);
});

// ========== JOURNAL ==========
const journalForm = $('#journalForm');
const journalEntries = $('#journalEntries');

journalForm.addEventListener('submit', (e) => {
  e.preventDefault();
  const data = {
    title: $('#journalTitle').value,
    entry_type: $('#journalType').value,
    symbol: $('#journalSymbol').value,
    content: $('#journalContent').value
  };
  fetch('/api/journal', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(data)
  }).then(r => r.json()).then(() => {
    journalForm.reset();
    loadJournal();
  }).catch(console.error);
});

function renderJournal(entries) {
  journalEntries.innerHTML = '';
  if (!entries || entries.length === 0) {
    journalEntries.innerHTML = '<p class="text-muted">No journal entries yet.</p>';
    return;
  }
  entries.forEach(e => {
    const div = document.createElement('div');
    div.className = 'journal-entry';
    div.innerHTML = `
      <div class="entry-header">
        <span class="entry-type-badge ${e.entry_type}">${e.entry_type}</span>
        <span class="entry-title">${e.title || 'Untitled'}</span>
        <span class="entry-meta">${e.created_at || ''} ${e.symbol ? '| ' + e.symbol : ''}</span>
      </div>
      <div class="entry-content">${e.content || ''}</div>
    `;
    journalEntries.appendChild(div);
  });
}

function loadJournal() {
  fetch('/api/journal?limit=50')
    .then(r => r.json())
    .then(renderJournal)
    .catch(() => {});
}

// ========== AI CONFIGURATION ==========
const aiForm = $('#aiConfigForm');
const providerSelect = $('#cfg_ai_provider');
const apiKeyInput = $('#cfg_ai_api_key');
const modelSelect = $('#cfg_ai_model');
const customModelInput = $('#cfg_ai_custom_model');
const customModelRow = $('#cfg_custom_model_row');

// Chat Toolbar Elements
const chatProviderSelect = $('#chat_ai_provider');
const chatModelSelect = $('#chat_ai_model');
const chatToggleBtn = $('#chat_ai_toggle_btn');

let currentAiConfig = {};

const modelOptions = {
  kilo: [
    { value: 'kilo-auto/free', text: 'kilo-auto/free (Free)' },
    { value: 'openrouter/free', text: 'openrouter/free (Free)' },
    { value: 'poolside/laguna-m.1:free', text: 'poolside/laguna-m.1:free (Free)' },
    { value: 'cohere/north-mini-code:free', text: 'cohere/north-mini-code:free (Free)' },
    { value: 'nvidia/nemotron-3-nano-omni-30b-a3b-reasoning:free', text: 'nvidia/nemotron-3-nano... (Free)' },
    { value: 'deepseek/deepseek-chat', text: 'deepseek/deepseek-chat (Paid)' },
    { value: 'openai/gpt-4o', text: 'openai/gpt-4o (Paid)' },
    { value: 'openai/gpt-4o-mini', text: 'openai/gpt-4o-mini (Paid)' },
    { value: 'anthropic/claude-3-5-sonnet', text: 'anthropic/claude-3-5-sonnet (Paid)' },
    { value: 'custom', text: '-- Custom Model ID --' }
  ],
  openai: [
    { value: 'gpt-4o', text: 'gpt-4o (Paid)' },
    { value: 'gpt-4o-mini', text: 'gpt-4o-mini (Paid)' },
    { value: 'gpt-4', text: 'gpt-4 (Paid)' },
    { value: 'gpt-3.5-turbo', text: 'gpt-3.5-turbo (Paid)' },
    { value: 'custom', text: '-- Custom Model ID --' }
  ],
  deepseek: [
    { value: 'deepseek-chat', text: 'deepseek-chat (Paid)' },
    { value: 'deepseek-reasoner', text: 'deepseek-reasoner (Paid)' },
    { value: 'custom', text: '-- Custom Model ID --' }
  ],
  ollama: [
    { value: 'llama3', text: 'llama3 (Local)' },
    { value: 'mistral', text: 'mistral (Local)' },
    { value: 'phi4', text: 'phi4 (Local)' },
    { value: 'custom', text: '-- Custom Model ID --' }
  ]
};

function populateAiConfig(config) {
  currentAiConfig = config;
  const provider = config.provider || 'kilo';
  
  // Strategy page
  providerSelect.value = provider;
  const provCfg = config[provider] || {};
  apiKeyInput.value = provCfg.apiKey || '';
  updateModelDropdown(modelSelect, provider, provCfg.model || '');
  
  // Chat toolbar
  if (chatProviderSelect) chatProviderSelect.value = provider;
  updateModelDropdown(chatModelSelect, provider, provCfg.model || '');
  
  // Active state
  const isActive = config.ai_assistant_active !== false;
  updateToggleState(isActive);
}

function updateModelDropdown(selectEl, provider, activeModel) {
  if (!selectEl) return;
  selectEl.innerHTML = '';
  const options = modelOptions[provider] || [{ value: 'custom', text: '-- Custom Model ID --' }];
  
  let found = false;
  options.forEach(opt => {
    const el = document.createElement('option');
    el.value = opt.value;
    el.textContent = opt.text;
    if (opt.value === activeModel) {
      el.selected = true;
      found = true;
    }
    selectEl.appendChild(el);
  });
  
  if (!found && activeModel) {
    const el = document.createElement('option');
    el.value = 'custom';
    el.textContent = '-- Custom Model ID --';
    el.selected = true;
    selectEl.appendChild(el);
    if (selectEl === modelSelect) {
      customModelRow.style.display = 'grid';
      customModelInput.value = activeModel;
    }
  } else {
    if (selectEl === modelSelect) {
      customModelRow.style.display = 'none';
      customModelInput.value = '';
    }
  }
}

function updateToggleState(isActive) {
  if (!chatToggleBtn) return;
  if (isActive) {
    chatToggleBtn.classList.add('active');
    chatToggleBtn.querySelector('.btn-text').textContent = 'AI Active';
  } else {
    chatToggleBtn.classList.remove('active');
    chatToggleBtn.querySelector('.btn-text').textContent = 'AI Paused';
  }
}

providerSelect.addEventListener('change', () => {
  const provider = providerSelect.value;
  const provCfg = currentAiConfig[provider] || {};
  apiKeyInput.value = provCfg.apiKey || '';
  updateModelDropdown(modelSelect, provider, provCfg.model || '');
});

modelSelect.addEventListener('change', () => {
  if (modelSelect.value === 'custom') {
    customModelRow.style.display = 'grid';
  } else {
    customModelRow.style.display = 'none';
  }
});

// Chat toolbar event bindings
if (chatProviderSelect) {
  chatProviderSelect.addEventListener('change', () => {
    const provider = chatProviderSelect.value;
    const provCfg = currentAiConfig[provider] || {};
    const model = provCfg.model || 'kilo-auto/free';
    
    fetch('/api/aiconfig', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ provider, model })
    })
    .then(r => r.json())
    .then(res => {
      if (res.success) {
        populateAiConfig(res.config);
        addSystemMessage(`🔌 Switched AI Provider to ${provider}`);
      }
    })
    .catch(console.error);
  });
}

if (chatModelSelect) {
  chatModelSelect.addEventListener('change', () => {
    let model = chatModelSelect.value;
    if (model === 'custom') {
      addSystemMessage('ℹ️ Please configure custom Model ID on the Strategy page.');
      document.querySelector('[data-page="strategy"]').click();
      return;
    }
    const provider = chatProviderSelect.value;
    
    fetch('/api/aiconfig', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ provider, model })
    })
    .then(r => r.json())
    .then(res => {
      if (res.success) {
        populateAiConfig(res.config);
        addSystemMessage(`🤖 Model changed to ${model}`);
      }
    })
    .catch(console.error);
  });
}

if (chatToggleBtn) {
  chatToggleBtn.addEventListener('click', () => {
    const isActive = !chatToggleBtn.classList.contains('active');
    updateToggleState(isActive);
    
    fetch('/api/aiconfig', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ ai_assistant_active: isActive })
    })
    .then(r => r.json())
    .then(res => {
      if (res.success) {
        currentAiConfig = res.config;
        addSystemMessage(isActive ? '✅ AI Assistant Enabled' : '⏸️ AI Assistant Paused (Chat is now manual commands only)');
      }
    })
    .catch(console.error);
  });
}

aiForm.addEventListener('submit', (e) => {
  e.preventDefault();
  const provider = providerSelect.value;
  const apiKey = apiKeyInput.value;
  let model = modelSelect.value;
  
  if (model === 'custom') {
    model = customModelInput.value;
  }
  
  fetch('/api/aiconfig', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ provider, apiKey, model })
  })
  .then(r => r.json())
  .then(res => {
    if (res.success) {
      currentAiConfig = res.config;
      populateAiConfig(res.config);
      addSystemMessage('✅ AI configuration saved successfully');
    }
  })
  .catch(err => {
    console.error(err);
    addSystemMessage('❌ Error saving AI configuration');
  });
});

// ========== INITIAL LOAD ==========
function loadInitial() {
  fetch('/api/state').then(r => r.json()).then(updateEaState).catch(() => {});
  fetch('/api/symbols').then(r => r.json()).then(renderSymbols).catch(() => {});
  fetch('/api/positions').then(r => r.json()).then(renderPositions).catch(() => {});
  fetch('/api/positions/history?limit=30').then(r => r.json()).then(renderHistory).catch(() => {});
  fetch('/api/strategy').then(r => r.json()).then(populateStrategy).catch(() => {});
  fetch('/api/aiconfig').then(r => r.json()).then(populateAiConfig).catch(() => {});
  fetch('/api/signals?limit=20').then(r => r.json()).then(renderSignals).catch(() => {});
  loadJournal();
}
loadInitial();

// ========== SOCKET.IO REAL-TIME EVENTS ==========
socket.on('ea:state', updateEaState);
socket.on('ea:symbols', renderSymbols);
socket.on('ea:positions', renderPositions);
socket.on('ea:signal', (signal) => {
  if (signal) addSystemMessage(`📡 Signal: ${signal.symbol} ${signal.action} (${(signal.confidence * 100).toFixed(0)}%)`);
  fetch('/api/signals?limit=20').then(r => r.json()).then(renderSignals).catch(() => {});
});
socket.on('ea:strategy', populateStrategy);
socket.on('journal:entry', () => loadJournal());

// ========== KEYBOARD SHORTCUTS ==========
document.addEventListener('keydown', (e) => {
  if (e.altKey || e.metaKey) return;
  if (e.key === 'Escape' && currentPage === 'chat') {
    chatInput.blur();
  }
});

console.log('AK47 Web Console loaded ✅');
