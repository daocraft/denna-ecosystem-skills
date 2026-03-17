---
name: denna-params-author
description: Use when adding, modifying, or removing star allocation positions, chains, or protocol configuration in a sky-parameters repo. Triggers on "add position", "new allocation", "new chain", "update star config".
user-invocable: true
---

## Goal

Translate any input format (natural language, spreadsheet, address list, code snippet) into valid denna-spec entries and produce a PR-ready changeset for a sky-parameters repository.

## Required Skills

`REQUIRED: denna-ecosystem-skills:denna-spec-reference` — read `../denna-spec-reference/references/*.md` before generating any changes.

## Trigger Conditions

Use this skill when:
- Adding a new allocation position to a star
- Adding a new chain to a star's configuration
- Modifying an existing position (address change, cap update, tag change)
- Removing a position or chain
- User says "add position", "new allocation", "new chain", "update star config"

Do not use for:
- Schema changes (modifications to `denna-spec` or `denna-spec-schemas` repos)
- Shared rate modifications (`shared/rates.denna-spec.json` changes that affect all stars)
- General questions about spec structure (use `denna-spec-reference` instead)

## Inputs / Outputs

| Item | Required | Notes |
|------|----------|-------|
| Target repo | Yes | Git repo following sky-parameters structure (fetched at runtime) |
| Star name | Yes | Which star to modify (grove, spark, obex, or new) |
| Change description | Yes | Any format — natural language, spreadsheet, address list, code snippet |
| `protocol-config.denna-spec.json` (modified) | Output | Updated star protocol config |
| `pnl-config.denna-spec.json` (modified) | Output | Updated if change affects PnL treatment |
| `markdown/[star]/*.md` (modified) | Output | Corresponding human-readable docs |
| `change-summary.md` | Output | PR-ready description |

## Workflow

### Step 1 — Acquire Context

| Mode | When to use | Commands |
|------|-------------|----------|
| PR mode | Working on an existing branch with open PR | `gh pr view` for context, read files from working tree |
| Local mode | Starting fresh or no PR context | `git fetch origin main`, read files from `origin/main` |

In either mode, read:
1. Target star's `protocol-config.denna-spec.json`
2. Target star's `pnl-config.denna-spec.json`
3. `shared/` files (rates, stablecoin addresses, sUSDS addresses)
4. denna-spec-reference references (`../denna-spec-reference/references/*.md`)

### Step 2 — Interpret User Input

Extract the following from whatever format the user provides:

- **Contract address** — the on-chain address of the position
- **Chain** — which chain the position lives on
- **Protocol** — protocol or issuer name
- **Position type** — must match schema enum (see Position Type Resolution below)
- **Underlying asset** — e.g., USDC, USDS, DAI, RLUSD
- **Activation block/date** — `activeFromBlock` or `activeFromDate`
- **Tags** — infer from existing positions of the same type in the target star or other stars
- **Special treatment** — caps, pricing config, `extra` metadata

Rules:
- Ask clarifying questions for any ambiguous fields
- Never guess contract addresses — always require them from the user
- If the user provides a token symbol but no address, ask for the address

### Step 3 — Validate Against Existing Data

Run these checks before generating changes:

1. **Duplicate check** — same `contract` address + chain combination must not already exist within the same star. Cross-star duplicates are valid (different stars can hold the same position).
2. **Chain existence check** — if the position's chain is not in the star's `chains[]` array, flag that a new chain entry is needed.
3. **Type validation** — read the schema's `$defs.allocation.properties.type.enum` from the `$schema` URL to confirm the position type is valid.
4. **Address format** — must be 42 characters: `0x` followed by 40 hexadecimal characters.
5. **stabilityModules flag** — if adding a new chain that has `psm3: true`, a corresponding `stabilityModules` entry is needed in `pnl-config.denna-spec.json`.

### Step 4 — Generate Changes

Apply changes following these rules:

- **Add allocation entry** following the structure of existing entries in the same chain array. Match field order, formatting, and conventions.
- **Set tags** based on position type and PnL treatment. Cross-reference with `addressClassifications` and existing positions of the same type.
- **Update pnl-config** if the position requires special PnL treatment:
  - `addressClassifications` — for positions with `simple_period_return` or other special calculation methods
  - `assetCaps` — for positions with USD caps that affect PnL calculations
  - `stabilityModules` — for new PSM3 chains (add tokens: USDC, USDS, sUSDS with standard treatments)
  - `pricingConfig` — for positions that need custom pricing (e.g., Centrifuge token mappings)
  - `lendingProtocols` — for positions under lending protocol aggregation
- **Populate `extra`** for protocol-specific metadata (e.g., `centrifugeTokenId` for Centrifuge positions)
- **Update markdown docs** in `markdown/[star]/` to reflect the changes
- **Match existing file conventions** — indentation, field ordering, trailing newlines

### Step 5 — Produce Change Summary

Generate a summary using this template:

```markdown
## Summary
[1-2 sentence description]

## Changes
### protocol-config.denna-spec.json
- [Added/Modified/Removed]: [description] on [chain]
  - Contract: `0x...`
  - Protocol: [name]
  - Type: [type]
  - Tags: [list or "none"]

### pnl-config.denna-spec.json (if modified)
- [What was added and why]

## Open Questions
- [Any ambiguities that need resolution]

## Validation
- [ ] Schema-valid position type
- [ ] Address format verified
- [ ] No duplicate within star
- [ ] Tags consistent with classifications
```

## Position Type Resolution (runtime)

When determining which `type` value to use:

1. Read the schema's `$defs.allocation.properties.type.enum` for the complete list of valid types. Current valid types: `atoken`, `erc4626`, `erc20`, `centrifuge`, `centrifuge_feeder`, `buidl`, `superstate`, `curve`, `uni_v3_pool`, `uni_v3_lp`, `anchorage`, `ethena`, `galaxy_clo`, `securitize`, `maple`, `lp`.
2. Read existing positions in the target star and other stars to learn conventions (e.g., Morpho vaults use `erc4626`, not a Morpho-specific type).
3. Match by pattern — use the closest existing position as a template for field structure and tag assignment.

## Quality Bar

- **Never fabricate addresses** — if the user's input is unclear, ask rather than guess
- **Preserve file structure and ordering** — new entries go at the end of their array unless the user specifies otherwise
- **Every entry must have a real counterpart in user input** — do not add positions the user did not request
- **Flag novel position types** — if a position does not match any existing type, ask the user to confirm before using a generic type like `erc20` or `erc4626`
- **Tags and classifications in tandem** — if a tag implies a PnL classification (e.g., `simple_period_return` implies an `addressClassifications.simplePeriodReturn` entry), always update both files together

## References

- `references/examples.md` — worked examples of common authoring scenarios
- `../denna-spec-reference/references/*.md` — spec interpretation rules (protocol-config, pnl-awareness, value-types, relationships, gotchas)
