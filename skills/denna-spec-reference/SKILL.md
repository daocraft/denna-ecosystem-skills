---
name: denna-spec-reference
description: Use when working with Denna Specification files (.denna-spec.json), understanding spec structure, or when another denna skill requires it. Triggers on denna-spec, protocol-config, pnl-config, sky-parameters, star allocations.
user-invocable: true
---

## Goal

Provide interpretation rules for Denna Specification parameter files. This skill encodes **how to read** denna-spec files, not what they currently contain. Always fetch current data from git.

## Trigger Conditions

Use this skill when:
- Working with any `.denna-spec.json` file
- Asked about denna spec format, structure, or semantics
- Another denna skill requires it (e.g., `denna-params-author`, `denna-params-auditor`)

Do not use for general JSON Schema questions unrelated to denna.

## Key Concepts

### The Denna Spec Envelope

Every `.denna-spec.json` file has:
- `$schema` — URL pointing to the canonical schema at `spec.denna.io`
- `metadata` — `id`, `kind`, `name`, `version`, `description`, `source`
- Content fields specific to the `kind`

### Schema Architecture

Two schema repos exist:
- **`denna-spec`** (canonical, `spec.denna.io`) — official schemas. Data files always reference these.
- **`denna-spec-schemas`** (extensions, `schemas.denna.io`) — domain-specific extensions. Only used if a data file explicitly declares one.

**Rule:** Always validate against the `$schema` URL declared in the data file.

### Sky-Parameters File Structure

A typical sky-parameters repo:
```
[star]/protocol-config.denna-spec.json  — chains, wallets, allocation positions
[star]/pnl-config.denna-spec.json       — PnL calculation modules, classifications
shared/rates.denna-spec.json            — shared rate parameters
shared/stablecoin-addresses.denna-spec.json
shared/susds-addresses.denna-spec.json
markdown/[star]/*.md                    — human-readable docs
markdown/_template/                     — templates for new stars
```

## When To Read Which Reference

| Question | Read |
|----------|------|
| How is a protocol-config structured? | `references/protocol-config.md` |
| How does PnL treatment work? | `references/pnl-awareness.md` |
| What are the value types (address, cap, tags)? | `references/value-types.md` |
| What changes cascade across files? | `references/relationships.md` |
| What are common mistakes? | `references/gotchas.md` |

## Critical Rule

> Always fetch the latest `.denna-spec.json` files from the target git repo before answering questions. These references teach you how to **interpret**, not what the current values are.
