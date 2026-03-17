# Denna Params Author

Skill and supporting references for adding, modifying, or removing star configuration
in sky-parameters repos. Upload this file (along with `denna-spec-reference.md`) to
your Claude.ai Project.

---


## Goal

Translate any input format (natural language, spreadsheet, address list, code snippet) into valid denna-spec entries and produce a PR-ready changeset for a sky-parameters repository.

## Required Skills

`REQUIRED: denna-ecosystem-skills:denna-spec-reference` — read `denna-spec-reference.md` before generating any changes.

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
4. denna-spec-reference references (`denna-spec-reference.md`)

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
- `denna-spec-reference.md` — spec interpretation rules (protocol-config, pnl-awareness, value-types, relationships, gotchas)

---

# denna-params-author Examples

Worked examples showing how to translate user requests into denna-spec file changes. Each example shows user input, before/after file state, and which files are affected.

---

## Example 1 — Adding a Morpho vault to Grove on Base

### User Input

> "We're adding a second Morpho vault on Base at 0xaa11bb22cc33dd44ee55ff6677889900aabb1122 with USDC underlying, markets [0xmarket1aabbccdd, 0xmarket2eeff0011]"

### Analysis

- **Star:** Grove
- **Chain:** Base (already exists in `chains[]`)
- **Protocol:** Morpho
- **Type:** `erc4626` (Morpho vaults use ERC-4626 type — confirmed by existing Base Morpho entry)
- **Underlying:** USDC
- **PnL impact:** None — standard Morpho vault, no special pricing or caps needed

### Before — `grove/protocol-config.denna-spec.json` (allocations.base)

```json
"base": [
  {
    "contract": { "value": "0xbeef2d50b428675a1921bc6bbf4bfb9d8cf1461a", "format": "evm" },
    "protocol": "Morpho", "type": "erc4626", "underlying": "USDC",
    "notes": "Multi-market USDC vault. 6 markets."
  }
]
```

### After — `grove/protocol-config.denna-spec.json` (allocations.base)

```json
"base": [
  {
    "contract": { "value": "0xbeef2d50b428675a1921bc6bbf4bfb9d8cf1461a", "format": "evm" },
    "protocol": "Morpho", "type": "erc4626", "underlying": "USDC",
    "notes": "Multi-market USDC vault. 6 markets."
  },
  {
    "contract": { "value": "0xaa11bb22cc33dd44ee55ff6677889900aabb1122", "format": "evm" },
    "protocol": "Morpho", "type": "erc4626", "underlying": "USDC",
    "markets": ["0xmarket1aabbccdd", "0xmarket2eeff0011"],
    "notes": "Multi-market USDC vault. 2 markets."
  }
]
```

### Files Changed

| File | Changed | Why |
|------|---------|-----|
| `grove/protocol-config.denna-spec.json` | Yes | New allocation entry in `allocations.base` |
| `grove/pnl-config.denna-spec.json` | No | Standard Morpho vault — no special PnL treatment needed |
| `markdown/grove/*.md` | Yes | Update allocation docs to list the new position |

### Key Decisions

- Used `erc4626` type, not a Morpho-specific type — follows the pattern of the existing Morpho entry on Base
- Included `markets` array since the user specified market IDs
- No `tags` needed — existing Base Morpho entry has no tags
- No `activeFromBlock` — user did not specify one; ask if one is needed

---

## Example 2 — Adding a new chain (Arbitrum) to Grove

### User Input

> "We're expanding Grove to Arbitrum. ALM proxy is at 0x1234567890abcdef1234567890abcdef12345678, PSM3 at 0xabcdef1234567890abcdef1234567890abcdef12. First position is an Aave aToken for USDC at 0x9876543210fedcba9876543210fedcba98765432, active from block 280000000."

### Analysis

- **Star:** Grove
- **Chain:** Arbitrum (new — does not exist in `chains[]`)
- **New chain features:** ALM + PSM3
- **First allocation:** Aave aToken, USDC underlying
- **PnL impact:** Yes — new PSM3 chain requires `stabilityModules` entry in pnl-config
- **Multi-file cascade:** protocol-config (chain + allocation) and pnl-config (stabilityModules)

### Changes — `grove/protocol-config.denna-spec.json`

#### chains[] — add new entry

```json
{
  "id": "arbitrum",
  "name": "Arbitrum",
  "almProxy": { "value": "0x1234567890abcdef1234567890abcdef12345678", "format": "evm" },
  "features": { "alm": true, "psm3": true, "inPnlChains": false },
  "psm3Contract": { "value": "0xabcdef1234567890abcdef1234567890abcdef12", "format": "evm" }
}
```

#### allocations — add new chain key with first position

```json
"arbitrum": [
  {
    "contract": { "value": "0x9876543210fedcba9876543210fedcba98765432", "format": "evm" },
    "protocol": "Aave", "type": "atoken", "underlying": "USDC",
    "activeFromBlock": 280000000
  }
]
```

### Changes — `grove/pnl-config.denna-spec.json`

#### stabilityModules[] — add new entry

A new PSM3 chain requires a `stabilityModules` entry with standard token treatments. The pattern is taken from existing entries (Base, Optimism, Unichain all follow this structure):

```json
{
  "chain": "arbitrum",
  "tokens": [
    { "token": "USDC",  "module": "skyDirectExposure", "treatment": "MAX(0, baseCost - actualYield) reimbursement" },
    { "token": "USDS",  "module": "psm3Idle",          "treatment": "Idle reimbursement" },
    { "token": "sUSDS", "module": "psm3Susds",         "treatment": "30bps spread credit" }
  ]
}
```

Note: Grove's pnl-config already has an Arbitrum `stabilityModules` entry. In a real scenario, verify whether the entry already exists before adding a duplicate.

### Files Changed

| File | Changed | Why |
|------|---------|-----|
| `grove/protocol-config.denna-spec.json` | Yes | New chain in `chains[]` + new `allocations.arbitrum` array |
| `grove/pnl-config.denna-spec.json` | Yes | New `stabilityModules` entry for PSM3 on Arbitrum |
| `markdown/grove/chains.md` | Yes | Document the new chain, ALM proxy, PSM3 contract |
| `markdown/grove/allocations.md` | Yes | Document the first Arbitrum allocation |

### Key Decisions

- Set `inPnlChains: false` — follows the pattern of other L2 chains in Grove (Base, Avalanche, Plume, Monad are all `false`)
- PSM3 stability module tokens follow the standard 3-token pattern (USDC/USDS/sUSDS)
- No `vaultProxy` on Arbitrum — that field is Ethereum-only for MCD vault
- No `notes` on chain entry — add only if there is something noteworthy about the chain config

---

## Example 3 — Adding an RWA position with cap and pricing (Centrifuge)

### User Input

> "Adding a new Centrifuge RWA vault to Grove on Ethereum. Contract 0xdead000000000000000000000000000000000001, vault address 0xdead000000000000000000000000000000000002, symbol ACMECO, underlying USDC, Centrifuge token ID 0x00020000000000010000000000000001. Cap at $100M USD."

### Analysis

- **Star:** Grove
- **Chain:** Ethereum (already exists)
- **Protocol:** Centrifuge
- **Type:** `centrifuge`
- **PnL impact:** Yes, multiple sections — this is the most complex case:
  - `pricingConfig.centrifugeTokenMappings` — new mapping for NAV pricing
  - `assetCaps` — $100M cap that affects reimbursement calculation
- **Reference pattern:** Existing JHLCO entry in Grove (contract `0x5a0f...`, with cap, extra, and pricing mapping)

### Changes — `grove/protocol-config.denna-spec.json`

#### allocations.ethereum[] — add new entry

Pattern follows the existing JHLCO entry:

```json
{
  "contract": { "value": "0xdead000000000000000000000000000000000001", "format": "evm" },
  "protocol": "Centrifuge", "type": "centrifuge", "underlying": "USDC", "symbol": "ACMECO",
  "vaultAddress": { "value": "0xdead000000000000000000000000000000000002", "format": "evm" },
  "cap": { "value": 100000000, "currency": "USD" },
  "notes": "ACME Co Fund. Cap $100M.",
  "extra": { "centrifugeTokenId": "0x00020000000000010000000000000001" }
}
```

Compare with existing JHLCO entry for reference:

```json
{
  "contract": { "value": "0x5a0f93d040de44e78f251b03c43be9cf317dcf64", "format": "evm" },
  "protocol": "Centrifuge", "type": "centrifuge", "underlying": "USDC", "symbol": "JHLCO",
  "vaultAddress": { "value": "0x4880799eE5200fC58DA299e965df644fBf46780B", "format": "evm" },
  "cap": { "value": 325000000, "currency": "USD" },
  "notes": "Janus Henderson Anemoy AAA CLO Fund. Cap $325M — pro-rata reimbursement when exceeded.",
  "extra": { "centrifugeTokenId": "0x00010000000000070000000000000001" }
}
```

### Changes — `grove/pnl-config.denna-spec.json`

#### pricingConfig.centrifugeTokenMappings[] — add new mapping

This tells the PnL system how to fetch the NAV price for this Centrifuge token:

```json
{ "address": { "value": "0xdead000000000000000000000000000000000001", "format": "evm" }, "tokenId": "0x00020000000000010000000000000001", "asset": "ACMECO" }
```

This follows the existing mappings pattern:

```json
"centrifugeTokenMappings": [
  { "address": { "value": "0x5a0f93d040de44e78f251b03c43be9cf317dcf64", "format": "evm" }, "tokenId": "0x00010000000000070000000000000001", "asset": "JHLCO" },
  { "address": { "value": "0x8c213ee79581ff4984583c6a801e5263418c4b86", "format": "evm" }, "tokenId": "0x00010000000000060000000000000001", "asset": "JHST" },
  { "address": { "value": "0xdead000000000000000000000000000000000001", "format": "evm" }, "tokenId": "0x00020000000000010000000000000001", "asset": "ACMECO" }
]
```

#### pricingConfig.sources[] — add pricing source

```json
{ "asset": "ACMECO", "source": "Centrifuge GraphQL API", "method": "NAV price from https://api.centrifuge.io/graphql" }
```

#### assetCaps[] — add cap entry

The cap in protocol-config defines the position's limit. The cap in pnl-config defines how the PnL calculation handles the limit:

```json
{
  "asset": "ACMECO",
  "cap": { "value": 100000000, "currency": "USD" },
  "effect": "When balance exceeds cap, Sky Direct Exposure reimbursement is calculated pro-rata. Excess reverts to standard allocation treatment."
}
```

This follows the existing JHLCO cap pattern:

```json
"assetCaps": [
  {
    "asset": "JHLCO",
    "cap": { "value": 325000000, "currency": "USD" },
    "effect": "When balance exceeds cap, Sky Direct Exposure reimbursement is calculated pro-rata. Excess reverts to standard allocation treatment."
  },
  {
    "asset": "ACMECO",
    "cap": { "value": 100000000, "currency": "USD" },
    "effect": "When balance exceeds cap, Sky Direct Exposure reimbursement is calculated pro-rata. Excess reverts to standard allocation treatment."
  }
]
```

### Files Changed

| File | Changed | Why |
|------|---------|-----|
| `grove/protocol-config.denna-spec.json` | Yes | New allocation in `allocations.ethereum[]` with cap and extra |
| `grove/pnl-config.denna-spec.json` | Yes | New `centrifugeTokenMappings` entry, new `sources` entry, new `assetCaps` entry |
| `markdown/grove/allocations.md` | Yes | Document the new Centrifuge position |
| `markdown/grove/pnl.md` | Yes | Document the new pricing source and cap |

### Key Decisions

- Used `centrifuge` type (not `centrifuge_feeder`) — Ethereum mainnet Centrifuge positions use `centrifuge`; `centrifuge_feeder` is for cross-chain feeders on L2s like Plume
- Included `vaultAddress` — required for Centrifuge positions (used for redemption interactions)
- `extra.centrifugeTokenId` — required for Centrifuge pricing to work; maps to the Centrifuge subgraph token ID
- Cap appears in **both** files: protocol-config records the contractual cap, pnl-config records how the cap affects calculations
- The `effect` text on `assetCaps` follows the existing JHLCO pattern verbatim — this wording maps to specific calculation logic in the debt-pnl service
- No `tags` added — existing Centrifuge entries (JHLCO, JHST) do not have explicit tags; their RWA treatment is driven by the `skyDirectExposure` calculation module and `centrifugeTokenMappings`, not by tags
- The `calculationModules` entry for `skyDirectExposure` already covers all RWA assets — no change needed there
