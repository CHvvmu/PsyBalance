# Technical Constraints

These are the main constraints the system currently operates under.

## Platform constraints

- Flutter mobile client
- Supabase Auth + Postgres backend
- no separate service architecture in the MVP
- simple and explicit RPCs where write rules matter

## Data constraints

- schema is authoritative
- behavior history should remain append-only
- projections are caches and can be rebuilt
- raw event facts must not be hidden behind UI state

## Engineering constraints

- preserve backward compatibility in schema and RPC changes
- avoid major state-management rewrites unless truly necessary
- prefer incremental changes over architectural resets
- keep `flutter analyze` clean

## Product constraints

- low-friction daily use
- coach judgment stays central
- no autonomous therapy behavior
- no pressure-to-reply mechanics
- no hidden manipulation or addiction optimization

## Operational constraints

- support should remain explainable in production
- realtime should degrade safely to reloads
- write paths must stay idempotent where possible
- the system should remain understandable to a future human maintainer

