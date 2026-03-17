# Denna Params Auditor

Skill and supporting references for auditing star configuration in sky-parameters repos.
Upload this file (along with `denna-spec-reference.md`) to your Claude.ai Project.

**Data repo:** https://github.com/daocraft/sky-parameters
— ask the user to paste file contents or use raw.githubusercontent.com URLs.

---


## Goal

Verify completeness, consistency, and correctness of star configuration in a sky-parameters repository. This skill runs a structured checklist against protocol-config and pnl-config files, classifies findings by severity, and produces a machine-readable findings array alongside a human-readable audit report.

## Required Skills

`REQUIRED: denna-ecosystem-skills:denna-spec-reference` — read `denna-spec-reference.md` before auditing.

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
3. Read denna-spec-reference references (`denna-spec-reference.md`) for interpretation rules
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
- `denna-spec-reference.md` -- spec interpretation rules (protocol-config, pnl-awareness, value-types, relationships, gotchas)

---

# Audit Checklist

Complete checklist for the denna-params-auditor skill. Each check includes its severity level and pass/fail criteria.

## Schema Validation

- [ ] **protocol-config validates against declared `$schema`** (blocker)
  - Pass: File parses as valid JSON and conforms to the schema at the declared `$schema` URL
  - Fail: Any schema violation (missing required fields, wrong types, unknown properties with `additionalProperties: false`)

- [ ] **pnl-config validates against declared `$schema`** (blocker)
  - Pass: File parses as valid JSON and conforms to the schema at the declared `$schema` URL
  - Fail: Any schema violation

## Protocol Config

- [ ] **Every chain has valid `almProxy`** (blocker)
  - Pass: Each chain entry has an `almProxy` field that is exactly 42 characters: `0x` followed by 40 hexadecimal characters (case-insensitive)
  - Fail: Missing `almProxy`, wrong length, or non-hex characters

- [ ] **`debtSource` present with valid `vatAddress`** (blocker)
  - Pass: `debtSource` object exists with a `vatAddress` field in valid EVM address format
  - Fail: Missing `debtSource`, missing `vatAddress`, or invalid address format

- [ ] **Every allocation has required fields: `contract`, `protocol`, `type`** (blocker)
  - Pass: Every entry in every chain's allocations array contains all three fields
  - Fail: Any allocation missing one or more of these fields

- [ ] **All addresses are valid EVM format** (blocker)
  - Pass: Every address field (`contract`, `almProxy`, `vatAddress`, `psm3Contract`, etc.) is exactly 42 characters: `0x` + 40 hex
  - Fail: Any address with wrong length or non-hex characters

- [ ] **All `type` values are valid schema enum values** (blocker)
  - Pass: Every allocation's `type` value appears in `$defs.allocation.properties.type.enum` from the declared schema
  - Fail: Any `type` value not in the enum

- [ ] **No duplicate contracts within same chain** (warning)
  - Pass: Within each chain's allocations array, all `contract` addresses are unique
  - Fail: Same `contract` address appears twice in the same chain (cross-star duplicates are valid)

- [ ] **Every position has `activeFromBlock` or `activeFromDate`** (warning)
  - Pass: Every allocation has at least one of `activeFromBlock` or `activeFromDate`
  - Fail: An allocation has neither field

- [ ] **Feature flags consistent** (blocker)
  - Pass: `psm3: true` on a chain implies `psm3Contract` is set with a valid address; no contradictory flag combinations
  - Fail: `psm3: true` without `psm3Contract`, or `psm3Contract` set with `psm3: false`

## PnL Config

- [ ] **Every `addressClassifications` address exists in protocol-config** (warning)
  - Pass: Every address listed in any `addressClassifications` array (`billAlways`, `skyTakesAll`, `simplePeriodReturn`, `directRate`, `ssrFunded`) corresponds to a `contract` in protocol-config allocations
  - Fail: An address in classifications does not appear in any allocation

- [ ] **Positions with `cap` field have corresponding `assetCaps` entry** (warning)
  - Pass: Every allocation that has a `cap` field (not a tag, but a numeric/object field) has a matching entry in pnl-config `assetCaps`
  - Fail: Allocation has `cap` but no corresponding `assetCaps` entry

- [ ] **Tags consistent with classifications** (warning)
  - Pass: Tag-classification pairs are coherent. Only these tags have classification counterparts:
    - `bill_always` <-> `billAlways[]`
    - `sky_takes_all` <-> `skyTakesAll[]`
    - `simple_period_return` <-> `simplePeriodReturn[]`
    - `direct_rate` <-> `directRate[]`
    - `ssr_funded` <-> `ssrFunded[]`
  - Standalone tags (`rwa`, `psm3`, `excluded_spread`, `sky_direct_exposure`, `idle_lending`, `ssr_address`) do not require classification counterparts
  - Fail: A position has a tag that implies a classification entry but is missing from the corresponding array, or vice versa

- [ ] **Enabled modules consistent with chain features** (warning)
  - Pass: If `psm3Idle` module is enabled, at least one chain has `psm3: true`; similar consistency for other module/feature pairs
  - Fail: Module enabled without supporting chain features

- [ ] **`stabilityModules` chains exist in protocol-config or documented as PnL-only** (warning)
  - Pass: Every chain key in `stabilityModules` either exists in protocol-config's `chains` array or has a `notes` field explaining its PnL-only status
  - Fail: Chain referenced in `stabilityModules` not found in protocol-config and not documented

- [ ] **`lendingProtocols` mappings reference existing positions** (warning)
  - Pass: Every position referenced in `lendingProtocols` exists in protocol-config allocations
  - Fail: Reference to a non-existent position (Spark-specific check)

- [ ] **`pricingConfig` references valid position types** (warning)
  - Pass: Position types referenced in `pricingConfig` are valid schema enum values
  - Fail: Reference to an unknown position type

- [ ] **`knownIssues` entries have `status` field** (nit)
  - Pass: Every entry in `knownIssues` has a `status` field
  - Fail: Entry missing `status`

## Cross-File Consistency

- [ ] **Protocol-config chains match pnl-config stability module chains** (warning)
  - Pass: Every chain with `psm3: true` in protocol-config has a corresponding `stabilityModules` entry in pnl-config, and vice versa (accounting for documented PnL-only chains)
  - Fail: Mismatch without documented reason

- [ ] **Shared address registries cover all star chains** (warning)
  - Pass: Shared stablecoin and sUSDS address files contain entries for all chains the star operates on
  - Fail: A star chain is missing from shared address registries

- [ ] **Markdown docs match JSON data** (nit)
  - Pass: Addresses, chain lists, and position counts in markdown docs are consistent with the JSON config files
  - Fail: Stale or mismatched documentation

## PR-Specific (scope: pr)

- [ ] **New positions have all required fields** (blocker)
  - Pass: Every newly added allocation has `contract`, `protocol`, `type`, and at least `activeFromBlock` or `activeFromDate`
  - Fail: A new position is missing required fields

- [ ] **Removed positions also removed from pnl-config** (warning)
  - Pass: If a position was removed from protocol-config, its address is also removed from all `addressClassifications` arrays, `assetCaps`, and other pnl-config references
  - Fail: Orphaned reference to a removed position

- [ ] **New tags have corresponding classification entries** (warning)
  - Pass: If a new allocation uses a tag that has a classification counterpart, the corresponding classification array is updated
  - Fail: Tag added without matching classification entry (or vice versa)

- [ ] **New PSM3 chains have `stabilityModules` entries** (blocker)
  - Pass: If a new chain is added with `psm3: true`, a corresponding `stabilityModules` entry exists in pnl-config
  - Fail: New PSM3 chain without stability module configuration

- [ ] **No unrelated changes mixed in** (nit)
  - Pass: All changes in the PR are related to the stated purpose
  - Fail: Unrelated formatting changes, unrelated position modifications, or other changes that should be in a separate PR

---

# Findings Schema

JSON Schema definition for the `findings.json` output produced by the denna-params-auditor skill.

## Schema

```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "title": "denna-params-auditor findings",
  "type": "array",
  "items": {
    "type": "object",
    "required": ["severity", "type", "file", "location", "explanation", "suggested_action", "confidence"],
    "additionalProperties": false,
    "properties": {
      "severity": {
        "type": "string",
        "enum": ["blocker", "warning", "nit"]
      },
      "type": {
        "type": "string",
        "enum": [
          "schema_violation",
          "missing_field",
          "invalid_address",
          "orphaned_reference",
          "tag_classification_mismatch",
          "inconsistency",
          "style"
        ]
      },
      "file": {
        "type": "string",
        "description": "Relative path to the file containing the issue"
      },
      "location": {
        "type": "string",
        "description": "JSON path to the specific field (e.g., allocations.ethereum[3].contract)"
      },
      "explanation": {
        "type": "string",
        "description": "What is wrong and why it matters"
      },
      "suggested_action": {
        "type": "string",
        "description": "How to fix the issue"
      },
      "confidence": {
        "type": "number",
        "minimum": 0,
        "maximum": 1,
        "description": "Confidence in the finding (0-1). Use warning instead of blocker if < 0.7"
      }
    }
  }
}
```

## Conventions

### Empty Array

An empty array `[]` means no issues were found. The audit passed cleanly.

### Severity Levels

| Severity | Meaning | Examples |
|----------|---------|----------|
| `blocker` | Broken config that would cause runtime errors or incorrect calculations | Schema violation, missing required field, invalid address, contradictory feature flags |
| `warning` | Likely mistake or inconsistency that should be investigated | Orphaned classification entry, tag/classification mismatch, missing markdown update |
| `nit` | Style issues, missing optional fields, documentation gaps | Missing optional `notes` field, ordering inconsistency, stale markdown |

### Finding Types

| Type | Description |
|------|-------------|
| `schema_violation` | File does not conform to its declared `$schema` |
| `missing_field` | A required or expected field is absent |
| `invalid_address` | An address does not conform to EVM format (42 chars: `0x` + 40 hex) |
| `orphaned_reference` | A reference points to something that does not exist (e.g., classification for a removed position) |
| `tag_classification_mismatch` | A tag and its corresponding classification array are inconsistent |
| `inconsistency` | Cross-file or cross-field inconsistency (e.g., chain mismatch between protocol-config and pnl-config) |
| `style` | Formatting, ordering, or documentation issues |

### Confidence Score

The `confidence` field (0 to 1) reflects how certain the auditor is about the finding:
- **0.9 -- 1.0**: Deterministic check (schema validation, address format, required field presence)
- **0.7 -- 0.9**: High-confidence heuristic (tag/classification matching, cross-file consistency)
- **0.5 -- 0.7**: Moderate confidence (may be an intentional exception; use `warning` severity, not `blocker`)
- **Below 0.5**: Do not report. The finding is too speculative.

Rule: Never assign `blocker` severity when confidence is below 0.7. Use `warning` instead.

## Differences from Atlas-Lint Contract

The denna-params-auditor findings contract differs from atlas-lint's contract in several ways:

| Aspect | atlas-lint | denna-params-auditor | Reason |
|--------|-----------|---------------------|--------|
| Location reference | `edited_unit` + `related_units` (markdown anchors) | `file` + `location` (JSON paths) | Denna files are JSON, not markdown. JSON paths provide precise field references. |
| Evidence | `evidence[]` array of text excerpts | Inline in `explanation` | JSON fields are short and self-contained; a separate evidence array adds overhead without clarity. |
| Confidence | Not present | `confidence` (0-1) | Denna cross-file checks have varying certainty; confidence helps distinguish deterministic checks from heuristics. |
| Finding type | Implicit in explanation | Explicit `type` enum | Enables machine filtering and aggregation of findings by category. |

## Example

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
  },
  {
    "severity": "warning",
    "type": "orphaned_reference",
    "file": "grove/pnl-config.denna-spec.json",
    "location": "addressClassifications.simplePeriodReturn[5]",
    "explanation": "Address 0xABC...123 appears in simplePeriodReturn classifications but does not match any contract in protocol-config allocations.",
    "suggested_action": "Remove the orphaned entry from simplePeriodReturn or add the corresponding allocation to protocol-config",
    "confidence": 0.85
  },
  {
    "severity": "nit",
    "type": "style",
    "file": "grove/protocol-config.denna-spec.json",
    "location": "allocations.base[7]",
    "explanation": "Position is missing the optional 'notes' field. Other positions of the same type in this star include notes for context.",
    "suggested_action": "Consider adding a 'notes' field describing the position purpose",
    "confidence": 0.60
  }
]
```
