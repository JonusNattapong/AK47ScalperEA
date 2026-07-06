# Graph Report - web  (2026-07-06)

## Corpus Check
- 5 files · ~3,196 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 82 nodes · 103 edges · 7 communities (6 shown, 1 thin omitted)
- Extraction: 100% EXTRACTED · 0% INFERRED · 0% AMBIGUOUS
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `614d43da`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- [[_COMMUNITY_Community 0|Community 0]]
- [[_COMMUNITY_Community 1|Community 1]]
- [[_COMMUNITY_Community 2|Community 2]]
- [[_COMMUNITY_Community 3|Community 3]]
- [[_COMMUNITY_Community 4|Community 4]]
- [[_COMMUNITY_Community 5|Community 5]]
- [[_COMMUNITY_Community 6|Community 6]]

## God Nodes (most connected - your core abstractions)
1. `$()` - 35 edges
2. `getDb()` - 21 edges
3. `scripts` - 3 edges
4. `addChatMessage()` - 3 edges
5. `initSchema()` - 2 edges
6. `seedDefaults()` - 2 edges
7. `updateEaState()` - 2 edges
8. `getEaState()` - 2 edges
9. `updateSymbol()` - 2 edges
10. `getSymbols()` - 2 edges

## Surprising Connections (you probably didn't know these)
- `getDb()` --calls--> `seedDefaults()`  [EXTRACTED]
  db.js → db.js  _Bridges community 3 → community 2_

## Import Cycles
- None detected.

## Communities (7 total, 1 thin omitted)

### Community 0 - "Community 0"
Cohesion: 0.07
Nodes (21): $(), cfgFields, chatInput, chatMessages, chatSendBtn, connDot, connText, eaStatusDot (+13 more)

### Community 1 - "Community 1"
Cohesion: 0.14
Nodes (13): dependencies, better-sqlite3, cors, express, lightweight-charts, socket.io, description, main (+5 more)

### Community 2 - "Community 2"
Cohesion: 0.15
Nodes (12): Database, DB_PATH, getEaState(), getJournalEntries(), getPositions(), getSignals(), getSymbols(), path (+4 more)

### Community 3 - "Community 3"
Cohesion: 0.17
Nodes (12): addJournalEntry(), addMessage(), addSignal(), addSnapshot(), closePosition(), getDb(), getMessages(), getPositionHistory() (+4 more)

### Community 4 - "Community 4"
Cohesion: 0.22
Nodes (8): app, cors, db, express, http, io, path, { Server }

### Community 5 - "Community 5"
Cohesion: 0.67
Nodes (3): addChatMessage(), addSystemMessage(), sendChatMessage()

## Knowledge Gaps
- **42 isolated node(s):** `Database`, `path`, `DB_PATH`, `name`, `version` (+37 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **1 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `$()` connect `Community 0` to `Community 5`, `Community 6`?**
  _High betweenness centrality (0.162) - this node is a cross-community bridge._
- **Why does `getDb()` connect `Community 3` to `Community 2`?**
  _High betweenness centrality (0.029) - this node is a cross-community bridge._
- **What connects `Database`, `path`, `DB_PATH` to the rest of the system?**
  _42 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `Community 0` be split into smaller, more focused modules?**
  _Cohesion score 0.07142857142857142 - nodes in this community are weakly interconnected._
- **Should `Community 1` be split into smaller, more focused modules?**
  _Cohesion score 0.14285714285714285 - nodes in this community are weakly interconnected._