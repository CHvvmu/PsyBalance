# PsyBalance AI Operational Rules

## Tooling files

Temporary tooling/debug/analysis files:

- tmp_*.py
- tmp_*.sql
- tmp_*.txt

must NEVER:

- become production dependencies
- be imported into Flutter runtime
- replace canonical RPC/database logic
- be committed unless explicitly requested

Python may be used only for temporary diagnostics/refactoring/tooling.

Production stack is:

- Flutter
- Dart
- Supabase
- PostgreSQL
- RPC-first architecture

## Architectural invariants

- committed-state-first UI
- no fake optimistic state
- append-only behavioral truth
- projections are cached views
- DB is canonical source of truth
