# AGENTS.md

Project-level guidance for AI agents working in this repo (opencode reads this
into every session).

## Code navigation
Graphify is configured (remote MCP + local `/graphify`). For structure questions,
prefer the graph tools before grep/glob:
- `graphify_find` — where a symbol is defined
- `query_graph` — how a behavior works
- `graphify_callers` / `graphify_callees` — call relationships
- `graphify_impact` — change impact ranking
- `graphify_tests_for` / `graphify_file_neighbors`

Refresh the local index with `/graphify . --code-only`.
