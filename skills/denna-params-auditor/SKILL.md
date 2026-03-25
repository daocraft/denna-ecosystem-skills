---
name: denna-params-auditor
description: Use when verifying, auditing, or reviewing star configuration in a sky-parameters repo. Triggers on "audit config", "check star", "review denna PR", "validate parameters", "verify allocations".
user-invocable: true
---

## Goal

Verify completeness, consistency, and correctness of star configuration in a sky-parameters repository. This skill runs a structured checklist against protocol-config and pnl-config files, classifies findings by severity, and produces a machine-readable findings array alongside a human-readable audit report.

## Required Skills

`REQUIRED: denna-ecosystem-skills:denna-spec-reference` — read `../denna-spec-reference/references/*.md` before auditing.

## Trigger Conditions

Use this skill when:
- Auditing a star's configuration for completeness and consistency
- Reviewing a denna-spec PR (diff-only audit)
- Running a health check across one or all stars
- Verifying that allocations, classifications, and feature flags are coherent
- User says "audit config", "check star", "review denna PR", "validate parameters", "verify allocations"

Do not use for:
- Schema authoring or modifications (modifications to `denna-spec` or `denna-spec-schemas` repos)
- Creating new positions or chains (use `denna-params-author` instead)
- General questions about spec structure (use `denna-spec-reference` instead)

## Inputs / Outputs

| Item | Required | Notes |
|------|----------|-------|
| Target repo | Yes | Git repo following sky-parameters structure (fetched at runtime) |
| Star name | Yes | Which star to audit (grove, spark, obex, or `all` for cross-star audit) |
| Scope | Optional | `full` (default), `protocol-only`, `pnl-only`, or `pr` (diff-only) |
| `findings.json` | Output | Machine-readable findings array |
| `report.md` | Output | Human-readable audit report |

## Workflow

### Step 1 — Acquire Data

| Mode | When to use | Commands |
|------|-------------|----------|
| PR mode (scope: `pr`) | Auditing a specific PR | `gh pr diff --patch` for diff, read base from `origin/main`, head from working tree |
| Full mode (default) | Complete star audit | Read all star config files from working tree or `origin/main` |
| Protocol-only | Targeted protocol-config audit | Read only `protocol-config.denna-spec.json`, skip pnl-config checks |
| PnL-only | Targeted pnl-config audit | Read only `pnl-config.denna-spec.json`, skip protocol-config checks |

In any mode:
1. Read target star's `protocol-config.denna-spec.json` and `pnl-config.denna-spec.json` (as applicable for the scope)
2. Read `shared/` files (rates, stablecoin addresses, sUSDS addresses)
3. Read denna-spec-reference references (`../denna-spec-reference/references/*.md`) for interpretation rules
4. Fetch the declared `$schema` from the target file's `$schema` URL for runtime type/tag enum validation

### Step 2 — Run Checks

Checks organized by category. Run sequentially (v1 -- no subagent parallelism).

**Schema Validation (first -- structural correctness):**
- Validate `protocol-config.denna-spec.json` against its declared `$schema` (blocker if fails)
- Validate `pnl-config.denna-spec.json` against its declared `$schema` (blocker if fails)
- Always validate against the canonical schema at `spec.denna.io`, not extensions schemas at `schemas.denna.io` (see denna-spec-reference "Schema Architecture")

**Protocol Config:**
- Every chain has a valid `almProxy` address (42 chars: `0x` + 40 hex)
- `debtSource` is present with a valid `vatAddress`
- Every allocation has required fields: `contract`, `protocol`, `type`
- All addresses are valid EVM format (42 chars: `0x` + 40 hex)
- All `type` values are valid schema enum values (read from `$defs.allocation.properties.type.enum`)
- No duplicate contract addresses within the same chain (cross-star duplicates are valid)
- `activeFromBlock` or `activeFromDate` is present on every position
- Feature flags are consistent (e.g., `psm3: true` implies `psm3Contract` is set at the chain level)

**PnL Config:**
- Every address in `addressClassifications` exists in protocol-config allocations
- Positions with a `cap` field have a corresponding `assetCaps` entry
- Tags are consistent with classifications -- only these tags have classification counterparts: `bill_always` <-> `billAlways[]`, `sky_takes_all` <-> `skyTakesAll[]`, `simple_period_return` <-> `simplePeriodReturn[]`, `direct_rate` <-> `directRate[]`, `ssr_funded` <-> `ssrFunded[]`; other tags (`rwa`, `psm3`, `excluded_spread`, `sky_direct_exposure`, `idle_lending`, `ssr_address`) are standalone and do not have classification counterparts
- Enabled modules are consistent with chain features (e.g., `psm3Idle` enabled implies at least one chain with `psm3: true`)
- `stabilityModules` entries reference chains that exist in protocol-config or are documented as PnL-only
- `lendingProtocols` mappings reference positions that exist in protocol-config (Spark-specific)
- `pricingConfig` references valid position types
- `knownIssues` entries have a `status` field

**Cross-File Consistency:**
- Chains in protocol-config match chains referenced in pnl-config stability modules (accounting for intentional PnL-only chains documented with `notes`)
- Shared stablecoin/sUSDS address registries cover all chains the star operates on
- Markdown docs match JSON data (addresses, chain lists, position counts)
- **Manifest consistency** — verify `denna-repo.denna-spec.json` entries match actual files on disk, `metadata.version` matches `package.json`

**PR-Specific Checks (scope: `pr` only):**
- New positions have all required fields
- Removed positions are also removed from pnl-config classifications
- New tags have corresponding classification entries (and vice versa)
- New chains with PSM3 have corresponding `stabilityModules` entries
- No unrelated changes mixed in

See `references/audit-checklist.md` for the complete checklist with pass/fail criteria.

### Step 3 — Classify Findings

| Severity | Meaning |
|----------|---------|
| `blocker` | Broken config -- schema violation, missing required field, invalid address, contradictory flags. Would cause runtime errors or incorrect calculations. |
| `warning` | Likely mistake -- orphaned classification, tag/classification mismatch, missing markdown update, inconsistent feature flags. Should be investigated. |
| `nit` | Style/completeness -- missing optional `notes` field, ordering inconsistency, documentation gaps. |

### Step 4 — Produce Report

Output two artifacts:

**1. `findings.json`** -- array of finding objects following the contract in `references/findings-schema.md`:

```json
[
  {
    "severity": "blocker",
    "type": "invalid_address",
    "file": "grove/protocol-config.denna-spec.json",
    "location": "allocations.monad[2].contract",
    "explanation": "Address has 41 hex characters (expected 40). Total length is 43 instead of 42.",
    "suggested_action": "Verify address on block explorer and correct to 42 characters",
    "confidence": 0.99
  }
]
```

The `type` enum: `schema_violation`, `missing_field`, `invalid_address`, `orphaned_reference`, `tag_classification_mismatch`, `inconsistency`, `style`.

Empty array `[]` means no issues found.

Note: denna uses `file` + `location` (JSON paths) instead of atlas-lint's `edited_unit`/`related_units` (markdown anchors), because denna files are JSON (addressable by path) rather than markdown (addressable by anchor).

**2. `report.md`** -- structured audit report:

```markdown
# Audit Report: [star]

**Star:** [star name]
**Scope:** [full / protocol-only / pnl-only / pr]
**Date:** [YYYY-MM-DD]
**Files checked:** [list of files]

## Summary
[total findings] findings: [n] blockers, [n] warnings, [n] nits

## Blockers
[list each with explanation, evidence (file path + JSON path), and suggested action]

## Warnings
[list with evidence]

## Nits
[list]

## Verdict
PASS (no blockers) / FAIL (blockers found)
```

## Quality Bar

- **Conservative** -- do not flag speculative issues without evidence
- **Blocker only for real breakage** -- things that would break consumption of the spec or violate the schema
- **Account for intentional differences** -- a chain in pnl-config `stabilityModules` but not in protocol-config `chains` may be documented with a `notes` field explaining why; do not flag as blocker
- **No false-positive blockers** -- if confidence < 0.7, use `warning` instead of `blocker`
- **Every finding must include a concrete `suggested_action`**
- **Every finding must point to a specific file and field**
- **Clean pass is explicit** -- if no issues found, report explicitly says PASS with empty findings

## References

- `references/audit-checklist.md` -- complete checklist with pass/fail criteria for all checks
- `references/findings-schema.md` -- JSON Schema for the findings output contract
- `../denna-spec-reference/references/*.md` -- spec interpretation rules (protocol-config, pnl-awareness, value-types, relationships, gotchas)
