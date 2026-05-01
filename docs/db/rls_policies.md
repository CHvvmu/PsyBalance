# RLS Policies

Row-level security is part of the product contract.

## Philosophy

- clients can see and write their own data where appropriate
- coaches can access only their own clients
- participants can interact only with allowed conversations and tasks
- append-only logs are protected from mutation

## Why it matters

PsyBalance is a trust-sensitive product.
Behavioral data must stay bounded by role and relationship.

