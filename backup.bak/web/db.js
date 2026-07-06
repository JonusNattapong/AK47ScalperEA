const Database = require('better-sqlite3');
const path = require('path');

const DB_PATH = path.join(__dirname, 'ak47_data.db');

let db;

function getDb() {
  if (!db) {
    db = new Database(DB_PATH);
    db.pragma('journal_mode = WAL');
    db.pragma('foreign_keys = ON');
    initSchema();
    seedDefaults();
  }
  return db;
}

function initSchema() {
  db.exec(`
    CREATE TABLE IF NOT EXISTS ea_state (
      id          INTEGER PRIMARY KEY CHECK (id = 1),
      status      TEXT DEFAULT 'STOPPED',
      balance     REAL DEFAULT 0,
      equity      REAL DEFAULT 0,
      daily_pnl   REAL DEFAULT 0,
      daily_pct   REAL DEFAULT 0,
      total_positions INTEGER DEFAULT 0,
      max_orders  INTEGER DEFAULT 4,
      is_global_paused INTEGER DEFAULT 1,
      last_updated TEXT
    );

    CREATE TABLE IF NOT EXISTS symbols (
      id          INTEGER PRIMARY KEY AUTOINCREMENT,
      name        TEXT UNIQUE,
      magic       INTEGER,
      last_action TEXT DEFAULT 'WAIT',
      last_confidence REAL DEFAULT 0,
      last_insight TEXT,
      is_disabled INTEGER DEFAULT 0,
      last_updated TEXT
    );

    CREATE TABLE IF NOT EXISTS positions (
      id          INTEGER PRIMARY KEY AUTOINCREMENT,
      ticket      INTEGER UNIQUE,
      symbol      TEXT,
      type        TEXT,
      volume      REAL,
      open_price  REAL,
      sl          REAL,
      tp          REAL,
      open_time   TEXT,
      magic       INTEGER,
      comment     TEXT,
      profit      REAL DEFAULT 0,
      status      TEXT DEFAULT 'OPEN'
    );

    CREATE TABLE IF NOT EXISTS chat_messages (
      id          INTEGER PRIMARY KEY AUTOINCREMENT,
      role        TEXT,
      content     TEXT,
      created_at  TEXT DEFAULT (datetime('now','localtime'))
    );

    CREATE TABLE IF NOT EXISTS signals (
      id          INTEGER PRIMARY KEY AUTOINCREMENT,
      symbol      TEXT,
      action      TEXT,
      confidence  REAL,
      insight     TEXT,
      features    TEXT,
      created_at  TEXT DEFAULT (datetime('now','localtime'))
    );

    CREATE TABLE IF NOT EXISTS strategy_config (
      id          INTEGER PRIMARY KEY CHECK (id = 1),
      lot_size    REAL DEFAULT 0.01,
      max_daily_dd REAL DEFAULT 4.0,
      daily_target REAL DEFAULT 2.5,
      base_magic  INTEGER DEFAULT 4747,
      max_orders  INTEGER DEFAULT 4,
      max_spread  INTEGER DEFAULT 35,
      trailing_start INTEGER DEFAULT 100,
      trailing_stop  INTEGER DEFAULT 30,
      symbols     TEXT DEFAULT 'XAUUSD,EURUSD,GBPUSD,USDJPY',
      api_interval INTEGER DEFAULT 15,
      min_confidence REAL DEFAULT 0.82,
      updated_at  TEXT DEFAULT (datetime('now','localtime'))
    );

    CREATE TABLE IF NOT EXISTS performance_snapshots (
      id          INTEGER PRIMARY KEY AUTOINCREMENT,
      balance     REAL DEFAULT 0,
      equity      REAL DEFAULT 0,
      daily_pnl   REAL DEFAULT 0,
      daily_pct   REAL DEFAULT 0,
      created_at  TEXT DEFAULT (datetime('now','localtime'))
    );

    CREATE TABLE IF NOT EXISTS journal_entries (
      id          INTEGER PRIMARY KEY AUTOINCREMENT,
      title       TEXT,
      content     TEXT,
      entry_type  TEXT DEFAULT 'note',
      symbol      TEXT,
      created_at  TEXT DEFAULT (datetime('now','localtime'))
    );
  `);
}

function seedDefaults() {
  // Ensure ea_state row exists
  const state = db.prepare('SELECT id FROM ea_state WHERE id = 1').get();
  if (!state) {
    db.prepare('INSERT INTO ea_state (id) VALUES (1)').run();
  }
  // Ensure strategy_config row exists
  const cfg = db.prepare('SELECT id FROM strategy_config WHERE id = 1').get();
  if (!cfg) {
    db.prepare('INSERT INTO strategy_config (id) VALUES (1)').run();
  }
}

// --- EA State ---
function updateEaState(data) {
  getDb();
  db.prepare(`
    UPDATE ea_state SET
      status = ?, balance = ?, equity = ?, daily_pnl = ?,
      daily_pct = ?, total_positions = ?, is_global_paused = ?,
      last_updated = datetime('now','localtime')
    WHERE id = 1
  `).run(
    data.status || 'RUNNING',
    data.balance || 0,
    data.equity || 0,
    data.daily_pnl || 0,
    data.daily_pct || 0,
    data.total_positions || 0,
    data.is_global_paused || 0
  );
}

function getEaState() {
  getDb();
  return db.prepare('SELECT * FROM ea_state WHERE id = 1').get();
}

// --- Symbols ---
function updateSymbol(data) {
  getDb();
  const existing = db.prepare('SELECT id FROM symbols WHERE name = ?').get(data.name);
  if (existing) {
    db.prepare(`
      UPDATE symbols SET magic=?, last_action=?, last_confidence=?,
        last_insight=?, is_disabled=?, last_updated=datetime('now','localtime')
      WHERE name = ?
    `).run(data.magic, data.last_action, data.last_confidence, data.last_insight, data.is_disabled || 0, data.name);
  } else {
    db.prepare(`
      INSERT INTO symbols (name, magic, last_action, last_confidence, last_insight, is_disabled, last_updated)
      VALUES (?, ?, ?, ?, ?, ?, datetime('now','localtime'))
    `).run(data.name, data.magic, data.last_action || 'WAIT', data.last_confidence || 0, data.last_insight || '', data.is_disabled || 0);
  }
}

function getSymbols() {
  getDb();
  return db.prepare('SELECT * FROM symbols ORDER BY name').all();
}

// --- Positions ---
function upsertPosition(data) {
  getDb();
  const existing = db.prepare('SELECT id FROM positions WHERE ticket = ?').get(data.ticket);
  if (existing) {
    db.prepare(`
      UPDATE positions SET profit=?, sl=?, tp=?, status=?
      WHERE ticket = ?
    `).run(data.profit || 0, data.sl || 0, data.tp || 0, data.status || 'OPEN', data.ticket);
  } else {
    db.prepare(`
      INSERT INTO positions (ticket, symbol, type, volume, open_price, sl, tp, open_time, magic, comment, profit, status)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'OPEN')
    `).run(data.ticket, data.symbol, data.type, data.volume, data.open_price, data.sl || 0, data.tp || 0, data.open_time || '', data.magic || 0, data.comment || '');
  }
}

function getPositions() {
  getDb();
  return db.prepare("SELECT * FROM positions WHERE status = 'OPEN' ORDER BY open_time DESC").all();
}

function getPositionHistory(limit = 50) {
  getDb();
  return db.prepare("SELECT * FROM positions ORDER BY open_time DESC LIMIT ?").all(limit);
}

function closePosition(ticket, profit) {
  getDb();
  db.prepare("UPDATE positions SET status='CLOSED', profit=? WHERE ticket=?").run(profit || 0, ticket);
}

// --- Chat ---
function addMessage(role, content) {
  getDb();
  db.prepare("INSERT INTO chat_messages (role, content) VALUES (?, ?)").run(role, content);
  return db.prepare("SELECT * FROM chat_messages WHERE id = last_insert_rowid()").get();
}

function getMessages(limit = 100) {
  getDb();
  return db.prepare("SELECT * FROM chat_messages ORDER BY created_at ASC LIMIT ?").all(limit);
}

// --- Signals ---
function addSignal(data) {
  getDb();
  db.prepare(`
    INSERT INTO signals (symbol, action, confidence, insight, features)
    VALUES (?, ?, ?, ?, ?)
  `).run(data.symbol, data.action, data.confidence, data.insight || '', data.features || '');
}

function getSignals(limit = 50) {
  getDb();
  return db.prepare("SELECT * FROM signals ORDER BY created_at DESC LIMIT ?").all(limit);
}

// --- Strategy Config ---
function getStrategyConfig() {
  getDb();
  return db.prepare('SELECT * FROM strategy_config WHERE id = 1').get();
}

function updateStrategyConfig(data) {
  getDb();
  db.prepare(`
    UPDATE strategy_config SET
      lot_size = COALESCE(?, lot_size),
      max_daily_dd = COALESCE(?, max_daily_dd),
      daily_target = COALESCE(?, daily_target),
      base_magic = COALESCE(?, base_magic),
      max_orders = COALESCE(?, max_orders),
      max_spread = COALESCE(?, max_spread),
      trailing_start = COALESCE(?, trailing_start),
      trailing_stop = COALESCE(?, trailing_stop),
      symbols = COALESCE(?, symbols),
      api_interval = COALESCE(?, api_interval),
      min_confidence = COALESCE(?, min_confidence),
      updated_at = datetime('now','localtime')
    WHERE id = 1
  `).run(
    data.lot_size ?? null,
    data.max_daily_dd ?? null,
    data.daily_target ?? null,
    data.base_magic ?? null,
    data.max_orders ?? null,
    data.max_spread ?? null,
    data.trailing_start ?? null,
    data.trailing_stop ?? null,
    data.symbols ?? null,
    data.api_interval ?? null,
    data.min_confidence ?? null
  );
}

// --- Journal ---
function addJournalEntry(data) {
  getDb();
  db.prepare("INSERT INTO journal_entries (title, content, entry_type, symbol) VALUES (?, ?, ?, ?)")
    .run(data.title || '', data.content || '', data.entry_type || 'note', data.symbol || '');
  return db.prepare("SELECT * FROM journal_entries WHERE id = last_insert_rowid()").get();
}

function getJournalEntries(limit = 100) {
  getDb();
  return db.prepare("SELECT * FROM journal_entries ORDER BY created_at DESC LIMIT ?").all(limit);
}

// --- Performance Snapshots ---
function addSnapshot(data) {
  getDb();
  db.prepare(`
    INSERT INTO performance_snapshots (balance, equity, daily_pnl, daily_pct)
    VALUES (?, ?, ?, ?)
  `).run(data.balance || 0, data.equity || 0, data.daily_pnl || 0, data.daily_pct || 0);
}

function getSnapshots(limit = 500) {
  getDb();
  return db.prepare("SELECT * FROM performance_snapshots ORDER BY created_at ASC LIMIT ?").all(limit);
}

function modifyPositionSlTp(ticket, sl, tp) {
  getDb();
  db.prepare("UPDATE positions SET sl = ?, tp = ?, comment = 'MODIFIED_BY_WEB' WHERE ticket = ?").run(sl, tp, ticket);
}

module.exports = {
  getDb,
  updateEaState, getEaState,
  updateSymbol, getSymbols,
  upsertPosition, getPositions, getPositionHistory, closePosition, modifyPositionSlTp,
  addMessage, getMessages,
  addSignal, getSignals,
  getStrategyConfig, updateStrategyConfig,
  addJournalEntry, getJournalEntries,
  addSnapshot, getSnapshots
};
