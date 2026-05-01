# Migration Prompts

Use these prompts when changing schema or projection logic.

## Prompt style

- preserve backward compatibility unless explicitly allowed otherwise
- name the source of truth
- describe how the projection will be rebuilt
- explain how existing rows are handled

## Example

> Modify the projection while keeping the source event log append-only.
> Describe how existing rows will be re-evaluated and how idempotency is preserved.

