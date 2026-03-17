# Denna Spec Reference

Combined reference for interpreting Denna Specification (.denna-spec.json) files.
Always include this file in your Claude.ai Project when working with sky-parameters.

This document covers: protocol-config structure, PnL configuration, value types,
cross-file relationships, and common gotchas.

## Source of Truth

The canonical sky-parameters data lives at:
**https://github.com/daocraft/sky-parameters**

> **Claude.ai users:** GitHub URLs cannot be fetched directly from Claude.ai.
> To work with sky-parameters data, ask the user to paste the relevant file contents
> (e.g., `protocol-config.denna-spec.json`, `pnl-config.denna-spec.json`) into the
> conversation, or use the raw URL format:
> `https://raw.githubusercontent.com/daocraft/sky-parameters/main/<path>`

---

# Protocol Config Reference

How to read and interpret `protocol-config.denna-spec.json` files.

## 1. File Identity

Every protocol-config file begins with the denna-spec envelope:

- **`$schema`** — Must be `"https://spec.denna.io/v1/defi/protocol-config.schema.json"`. This is the canonical schema URL. Always validate against it.
- **`metadata`** — Contains:
  - `id` — kebab-case unique identifier (e.g., `"grove-protocol-config"`)
  - `kind` — always `"io.denna.defi.protocol-config"` for this file type. The `kind` is the reverse-domain identifier that tells you which schema governs the file.
  - `name` — human-readable star name (e.g., `"Grove"`)
  - `version` — semver string (e.g., `"1.0.0"`)
  - `description` — brief description of the file's contents
  - `source.references` — array of source code file paths this config was derived from

The `kind` field is authoritative: if `kind` is `io.denna.defi.protocol-config`, this is a protocol-config file regardless of filename.

## 2. Chains Array

The `chains` array lists every blockchain network the star operates on. Each entry is a chain configuration object.

**Fields per chain entry:**

| Field | Required | Type | Description |
|-------|----------|------|-------------|
| `id` | Yes | string | Chain identifier (e.g., `"ethereum"`, `"base"`, `"arbitrum"`). Lowercase, matches the `chain` type pattern `^[a-z][a-z0-9_-]*$`. |
| `name` | No | string | Human-readable chain name (e.g., `"Ethereum"`, `"Base"`). |
| `almProxy` | No | address | ALM proxy contract address — holds allocated funds on this chain. |
| `vaultProxy` | No | address | Vault proxy contract address. Ethereum-only for MCD vault interactions. |
| `psm3Contract` | No | address | PSM3 contract address on this chain. Set when the chain has PSM3 active. |
| `susdsOracle` | No | address | sUSDS price oracle address. Used on L2 chains where sUSDS is a plain ERC20. |
| `features` | No | object | Boolean feature flags (see below). |
| `notes` | No | string | Free-text documentation about this chain's configuration. |

Only `id` is required. A minimal chain entry can be just `{ "id": "ethereum" }`.

## 3. Feature Flags

The `features` object on each chain entry contains boolean flags that control which calculation modules apply to that chain.

| Flag | Meaning |
|------|---------|
| `alm` | ALM (Asset Liability Management) module is active on this chain. |
| `psm3` | PSM3 (Peg Stability Module v3) is active on this chain. When true, `psm3Contract` should be set. |
| `lending` | Lending protocol positions (SparkLend, Aave, Morpho, etc.) exist on this chain. |
| `idleStablecoins` | Idle stablecoin reimbursement module is active on this chain. |
| `susds` | sUSDS positions exist on this chain. |
| `rwa` | Real World Asset positions exist on this chain. |
| `inPnlChains` | Chain is included in the active chains for debt PnL calculations. A chain can have `alm: true` but `inPnlChains: false` if its positions are not yet included in PnL. |

All flags default to absent (falsy). Only explicitly set flags appear in the file.

## 4. Debt Source

The `debtSource` object identifies where on-chain debt data is sourced from.

| Field | Type | Description |
|-------|------|-------------|
| `chain` | string | Always `"ethereum"`. Debt is sourced from Ethereum mainnet. |
| `vatAddress` | address | The MakerDAO/Sky Vat contract: `0x35d1b3f3d7966a1dfe207aa4514c12a259a0492b`. |
| `notes` | string | Optional documentation. |

Each star has exactly one `debtSource`. It always points to the Ethereum Vat contract.

## 5. Allocations Object

The `allocations` object maps chain ID strings to arrays of position entries.

```
"allocations": {
  "ethereum": [ ...positions... ],
  "base": [ ...positions... ]
}
```

- Keys are chain ID strings (must match an `id` in the `chains` array).
- Values are arrays of position entry objects.
- Only chains that have positions appear as keys. A chain can exist in `chains` but have no entry in `allocations`.

## 6. Position Entry Anatomy

Each position in an allocations array represents a single on-chain position held by the star.

| Field | Required | Type | Description |
|-------|----------|------|-------------|
| `contract` | **Yes** | address | Contract address of the position. Format: `{ "value": "0x...", "format": "evm" }`. |
| `protocol` | **Yes** | string | Protocol or issuer name (e.g., `"Centrifuge"`, `"Morpho"`, `"Aave"`, `"Blackrock"`, `"Ripple"`). |
| `type` | **Yes** | string (enum) | Position type. Valid values from schema: `atoken`, `erc4626`, `erc20`, `centrifuge`, `centrifuge_feeder`, `buidl`, `superstate`, `curve`, `uni_v3_pool`, `uni_v3_lp`, `anchorage`, `ethena`, `galaxy_clo`, `securitize`, `maple`, `lp`. |
| `underlying` | No | string | Underlying asset symbol (e.g., `"USDC"`, `"RLUSD"`, `"USDS"`). |
| `underlyingAddress` | No | address | Contract address of the underlying asset. |
| `symbol` | No | string | Token or position symbol (e.g., `"JHLCO"`, `"BUIDL"`, `"AUSD"`). |
| `tags` | No | array of strings | Classification tags governing PnL treatment. Valid values: `idle_lending`, `bill_always`, `sky_takes_all`, `simple_period_return`, `direct_rate`, `ssr_funded`, `ssr_address`, `rwa`, `psm3`, `excluded_spread`, `sky_direct_exposure`. See `pnl-awareness.md`. |
| `activeFromBlock` | No | integer | Block number from which this position became active. |
| `activeFromDate` | No | string (YYYY-MM-DD) | Date from which this position became active. Mutually exclusive with `activeFromBlock`. |
| `cap` | No | object | USD cap on position value: `{ "value": number, "currency": "USD" }`. |
| `markets` | No | array of strings | Morpho market IDs for multi-market vaults (hex strings). |
| `vaultAddress` | No | address | Associated vault address (used with Centrifuge positions). |
| `extra` | No | object | Open object (`additionalProperties: true`) for protocol-specific metadata. Common use: `centrifugeTokenId` for NAV pricing. |
| `notes` | No | string | Free-text documentation about this position. |

## 7. Required vs Optional

Per the schema, only three fields are required on a position entry:

1. `contract` — the on-chain address
2. `protocol` — who operates it
3. `type` — what kind of position it is

Everything else is optional. Notably:

- `underlying` is **not required**. Some positions (e.g., Ripple RLUSD token typed as `erc20`, Agora AUSD) omit it entirely. Do not flag a missing `underlying` as an error.
- `symbol` is optional and often omitted when it can be inferred.
- `tags` defaults to an empty set (no special PnL treatment).
- `activeFromBlock`/`activeFromDate` are omitted for positions active since inception.
- `cap` is only set when the position has an allocation cap that affects PnL calculations.

---

# PnL Awareness Reference

How to read and interpret PnL-related configuration in denna-spec files. Covers the pnl-config file (`pnl-config.denna-spec.json`) and the PnL-relevant fields in protocol-config.

## 1. Two Distinct PnL Mechanisms

Denna-spec files use two separate but overlapping systems for PnL classification:

1. **Tags** — defined on allocation entries in `protocol-config.denna-spec.json`, in the `tags` array. Tags use **snake_case** (e.g., `bill_always`, `sky_takes_all`).

2. **Address classifications** — defined in `pnl-config.denna-spec.json` under `parameters.addressClassifications`. Classification keys use **camelCase** (e.g., `billAlways`, `skyTakesAll`).

Both systems must be set in tandem for classifications that have tag counterparts. A tag on a position without a corresponding classification entry (or vice versa) creates an inconsistency.

## 2. Tags

Tags appear on allocation entries in protocol-config under the `tags` array. They are string enums defined in the schema at `$defs.allocation.properties.tags.items.enum`.

**Valid tag values:**

| Tag | Meaning |
|-----|---------|
| `idle_lending` | Position is idle lending (reimbursement for idle capital) |
| `bill_always` | Always charged at full base rate regardless of actual APY |
| `sky_takes_all` | Protocol takes all profit; entity is not charged for underperformance |
| `simple_period_return` | Period return is treated as annual rate, not annualized |
| `direct_rate` | Use liquidity index growth instead of borrow rate conversion |
| `ssr_funded` | Idle capital SSR cost deducted from entity revenue |
| `ssr_address` | Address is an SSR-related address |
| `rwa` | Real World Asset position |
| `psm3` | PSM3-related position |
| `excluded_spread` | Spread calculation excluded for this position |
| `sky_direct_exposure` | Sky direct exposure (RWA reimbursement treatment) |

A position with no tags receives default PnL treatment. Tags are additive.

## 3. Address Classifications

Address classifications live in `pnl-config.denna-spec.json` at `parameters.addressClassifications`. Each classification is an array of objects with:

- `address` — address object (`{ "value": "0x...", "format": "evm" }`)
- `asset` — asset symbol string (e.g., `"RLUSD"`, `"USDC"`)
- `reason` — optional string explaining why this address has this classification

**Classification arrays:**

| Classification | Description |
|----------------|-------------|
| `billAlways[]` | Assets always charged at full base rate regardless of APY |
| `skyTakesAll[]` | Protocol takes all profit; entity doesn't pay for underperformance |
| `simplePeriodReturn[]` | Period return treated as annual rate (not annualized) |
| `directRate[]` | Use liquidity index growth instead of borrow rate conversion |
| `ssrFunded[]` | Assets with idle capital SSR cost deducted from entity revenue |
| `usdsSsr[]` | Use sUSDS price growth as custom base rate |

## 4. Tag-to-Classification Mapping

Some tags have direct classification counterparts. When a tag is set on a position, the corresponding classification entry must also exist in pnl-config, and vice versa.

| Tag (protocol-config, snake_case) | Classification (pnl-config, camelCase) |
|---|---|
| `bill_always` | `billAlways[]` |
| `sky_takes_all` | `skyTakesAll[]` |
| `simple_period_return` | `simplePeriodReturn[]` |
| `direct_rate` | `directRate[]` |
| `ssr_funded` | `ssrFunded[]` |

**Standalone tags** (no classification counterpart):
- `rwa` — signals RWA treatment; handled by calculation modules, not classifications
- `psm3` — signals PSM3 involvement; handled by stability modules
- `excluded_spread` — spread exclusion; handled by calculation logic
- `sky_direct_exposure` — Sky direct exposure; handled by the `skyDirectExposure` module
- `idle_lending` — idle lending reimbursement; handled by the `idleStablecoins` module
- `ssr_address` — SSR address identification; no classification counterpart

`usdsSsr` has no direct tag counterpart. It serves a distinct purpose (sUSDS price growth as custom base rate) from `ssrFunded` (SSR cost deduction), even though both relate to SSR.

## 5. Calculation Modules

Calculation modules are defined in `parameters.calculationModules` as an array of objects. Each module has:

- `id` — module identifier string
- `name` — human-readable name
- `enabled` — boolean, whether this module is active
- `notes` — optional documentation

**Module IDs:**

| Module ID | Purpose |
|-----------|---------|
| `maxDebtFees` | Step 1: TWA Debt x Base Rate calculation |
| `idleStablecoins` | Step 2: Idle stablecoin reimbursement |
| `susdsProfitL2` | Step 3: sUSDS profit on L2 chains |
| `psm3Idle` | USDS idle in PSM3 on L2 chains |
| `psm3Susds` | sUSDS in PSM3 on L2 chains |
| `skyDirectExposure` | Step 4: RWA Sky Direct Exposure reimbursement |
| `borrowRateSubsidy` | Borrow rate subsidy calculation |

Modules are enabled or disabled per star. A disabled module means that calculation step is skipped entirely.

> **Note:** `lpPoolHandling` is NOT a calculation module. It is a separate configuration section at `parameters.lpPoolHandling` (see section 12).

## 6. Subsidy Programs

The `parameters.subsidyPrograms` array defines subsidy programs the star participates in.

Each entry has:

| Field | Required | Type | Description |
|-------|----------|------|-------------|
| `name` | No | string | Program name or identifier |
| `eligible` | **Yes** | boolean | Whether the star is eligible for this program |
| `cap` | No | amount | Maximum amount: `{ "value": number, "currency": "USD" }` |
| `capPeriod` | No | string | Period for the cap (e.g., `"per day"`) |
| `start` | No | date | Program start date (YYYY-MM-DD) |
| `duration` | No | duration | Program duration: `{ "value": number, "unit": "months" }` |

## 7. Stability Modules

The `parameters.stabilityModules` array defines PSM3 token composition per chain.

Each entry has:

| Field | Type | Description |
|-------|------|-------------|
| `address` | address | Stability module contract address (optional) |
| `chain` | string | Chain identifier (e.g., `"base"`, `"arbitrum"`) |
| `tokens` | array | Token composition entries |

Each token entry has:

| Field | Required | Type | Description |
|-------|----------|------|-------------|
| `token` | **Yes** | string | Token symbol (e.g., `"USDC"`, `"USDS"`, `"sUSDS"`) |
| `module` | **Yes** | string | Which calculation module handles this token (e.g., `"skyDirectExposure"`, `"psm3Idle"`, `"psm3Susds"`) |
| `treatment` | **Yes** | string | How this token is treated in PnL (e.g., `"Idle reimbursement"`, `"30bps spread credit"`) |

Stability modules may reference chains that do not appear in protocol-config's `chains` array. This is intentional — those chains are PnL-relevant through PSM3 only, not through direct allocations.

## 8. Asset Caps

The `parameters.assetCaps` array defines per-asset allocation caps that affect PnL calculations.

Each entry has:

| Field | Required | Type | Description |
|-------|----------|------|-------------|
| `asset` | **Yes** | string | Asset symbol (e.g., `"JHLCO"`) |
| `cap` | **Yes** | amount | Cap amount: `{ "value": number, "currency": "USD" }` |
| `effect` | No | string | Description of what happens when the cap is exceeded |

Asset caps in pnl-config should correspond to `cap` fields on positions in protocol-config.

## 9. Lending Protocols

The `parameters.lendingProtocols` array configures lending protocol integrations (primarily SparkLend, also Aave, Morpho).

Each entry has:

| Field | Type | Description |
|-------|------|-------------|
| `protocol` | string | Lending protocol name (e.g., `"sparklend"`, `"aave"`, `"morpho"`) |
| `poolAddress` | address | Lending pool contract address |
| `underlyingMappings` | array | Token-to-underlying mappings |

Each underlying mapping has:

| Field | Required | Type | Description |
|-------|----------|------|-------------|
| `spToken` | **Yes** | address | The spToken/aToken address |
| `underlying` | **Yes** | address | The underlying asset address |
| `symbol` | **Yes** | string | The underlying asset symbol |

## 10. Pricing Config

The `parameters.pricingConfig` object defines how assets are priced.

**`sources`** — array of pricing source entries:

| Field | Required | Type | Description |
|-------|----------|------|-------------|
| `asset` | **Yes** | string | Asset symbol |
| `source` | **Yes** | string | Pricing source (e.g., `"Centrifuge GraphQL API"`, `"On-chain"`) |
| `method` | **Yes** | string | How the price is obtained |

**`centrifugeTokenMappings`** — array mapping Centrifuge token addresses to their token IDs for NAV pricing:

| Field | Required | Type | Description |
|-------|----------|------|-------------|
| `address` | **Yes** | address | Centrifuge token contract address |
| `tokenId` | **Yes** | string | Centrifuge token ID (hex string) |
| `asset` | **Yes** | string | Asset symbol |

**`prePeriodBuffer`** / **`postPeriodBuffer`** — duration objects defining how much buffer to add before/after the calculation period when fetching price data.

## 11. Known Issues

The `parameters.knownIssues` array documents known bugs or issues in the PnL calculation.

Each entry has:

| Field | Required | Type | Description |
|-------|----------|------|-------------|
| `id` | **Yes** | string | Issue identifier (e.g., `"BUG-1"`) |
| `description` | **Yes** | string | What the issue is |
| `status` | **Yes** | string | Current status (e.g., `"Confirmed. Fix pending."`) |
| `source` | No | string | Source code reference where the bug exists |

Known issues are documentation only — they do not affect schema validation but signal to auditors and operators where calculations may be incorrect.

## 12. LP Pool Handling

The `parameters.lpPoolHandling` array defines special handling rules for LP pools across protocols. This is a standalone configuration section, not a calculation module.

Each entry has:

| Field | Required | Type | Description |
|-------|----------|------|-------------|
| `lpAddress` | **Yes** | address | LP pool contract address |
| `name` | **Yes** | string | Pool name |
| `protocol` | No | string | LP protocol (e.g., `"curve"`, `"uniswap-v3"`, `"balancer"`) |
| `activeFrom` | No | date | Date from which the pool is active (YYYY-MM-DD) |
| `treatment` | No | string | How the pool is treated in PnL calculations |

## 13. Direct Exposures

The `parameters.directExposures` array defines direct on-chain exposure positions within stability modules (e.g., USDC within PSM3 treated as direct exposure).

Each entry has:

| Field | Required | Type | Description |
|-------|----------|------|-------------|
| `chain` | **Yes** | string | Chain identifier (e.g., `"base"`, `"arbitrum"`) |
| `moduleAddress` | **Yes** | address | The stability module contract address |
| `assetAddress` | **Yes** | address | The asset contract address within the module |
| `notes` | No | string | Additional context about the exposure |

## 14. One-Time Adjustments

The `parameters.oneTimeAdjustments` array defines one-time revenue adjustments applied in specific months.

Each entry has:

| Field | Required | Type | Description |
|-------|----------|------|-------------|
| `month` | **Yes** | string | Year-month of the adjustment (YYYY-MM format) |
| `address` | **Yes** | address | Address the adjustment applies to |
| `amount` | **Yes** | amount | Adjustment amount: `{ "value": number, "currency": "USD" }` |
| `description` | **Yes** | string | Explanation of the adjustment |

## 15. Prepayments

The `parameters.prepayments` array defines prepayment amounts for specific assets.

Each entry has:

| Field | Required | Type | Description |
|-------|----------|------|-------------|
| `asset` | **Yes** | string | Asset symbol (e.g., `"PYUSD"`) |
| `address` | **Yes** | address | Address associated with the prepayment |
| `amount` | **Yes** | amount | Prepayment amount: `{ "value": number, "currency": "USD" }` |

## 16. PSM3 Chains

The `parameters.psm3Chains` array lists chain ID strings where PSM3 is processed for debt PnL. This may include chains that do not appear in the entity's own chain list — those chains are PnL-relevant through PSM3 processing only.

Each item is a chain identifier string (e.g., `"base"`, `"arbitrum"`).

## 17. Accounting Notes

The `parameters.accountingNotes` field is a string containing human-readable accounting methodology notes. It typically documents settlement formulas, asset treatment details, and any special accounting considerations for the entity.

---

# Value Types Reference

The primitive and compound types used across denna-spec files. These are defined in the canonical `denna-types.schema.json` and the domain schemas.

## 1. Address

```json
{ "value": "0x35d1b3f3d7966a1dfe207aa4514c12a259a0492b", "format": "evm" }
```

- **`value`** — the address string. For EVM addresses: exactly 42 characters (`0x` prefix + 40 hexadecimal digits). Validated by the pattern `^0x[0-9a-fA-F]{40}$`.
- **`format`** — identifies the chain family. For all current denna-spec DeFi files, this is always `"evm"`. The schema supports other formats (`solana`, `cosmos`, `bitcoin`, `aptos`, `sui`, `tron`) with format-specific validation patterns. Custom formats are accepted without pattern enforcement.

Both fields are required. No additional properties are allowed.

## 2. Tags Array

```json
["bill_always", "rwa", "sky_direct_exposure"]
```

An array of string values from the schema enum. Tags are defined on allocation positions in protocol-config at `$defs.allocation.properties.tags.items.enum`.

**Do not hardcode valid tag values** — always check the schema for the current enum. As of the current schema version, valid values are:

`idle_lending`, `bill_always`, `sky_takes_all`, `simple_period_return`, `direct_rate`, `ssr_funded`, `ssr_address`, `rwa`, `psm3`, `excluded_spread`, `sky_direct_exposure`

Tags control PnL treatment. See `pnl-awareness.md` for semantics.

## 3. Activation

Indicates when a position becomes active for calculations. Two mutually exclusive formats:

**Block-based:**
```json
{ "activeFromBlock": 22319334 }
```
- Type: integer
- The Ethereum (or chain-specific) block number from which this position is active.

**Date-based:**
```json
{ "activeFromDate": "2026-01-15" }
```
- Type: string, format YYYY-MM-DD
- The date from which this position is active.

Use one or the other, never both. If neither is set, the position is considered active since inception.

## 4. Cap

```json
{ "value": 325000000, "currency": "USD" }
```

- **`value`** — numeric amount (no units in the number; the unit is in `currency`).
- **`currency`** — always `"USD"` in current denna-spec files.

Caps limit the position value used in PnL calculations. When a position's balance exceeds its cap, the excess may revert to standard treatment (see the `effect` field on `assetCaps` in pnl-config).

This uses the same structure as the `amount` type (see below) but appears specifically on allocation positions in protocol-config.

## 5. Markets

```json
["0xb323495f7e4...", "0xa9710663c0..."]
```

An array of hex strings. Used on Morpho multi-market vault positions to identify specific market IDs the vault participates in.

Each string is a Morpho market identifier (typically a long hex hash). The schema does not enforce a specific pattern — these are opaque identifiers passed through to the PnL calculation engine.

## 6. Extra

```json
{ "centrifugeTokenId": "0x00010000000000070000000000000001" }
```

An open object with `additionalProperties: true`. The schema does not validate its contents — any key-value pairs are accepted.

Common uses:
- `centrifugeTokenId` — hex string identifying a Centrifuge tranche for NAV pricing lookup
- Custom protocol-specific identifiers

Since `extra` is unvalidated, mistakes in its contents will not be caught by schema validation. Use the `pricingConfig.centrifugeTokenMappings` in pnl-config to cross-reference Centrifuge token IDs.

## 7. Chain IDs

```json
"ethereum"
```

A lowercase string identifier for a blockchain network. Must match the pattern `^[a-z][a-z0-9_-]*$` (starts with a lowercase letter, followed by lowercase letters, digits, underscores, or hyphens).

Chain IDs are not an enum in the schema — they are pattern-validated strings, allowing new chains to be added without schema changes. Current examples in use:

`ethereum`, `base`, `arbitrum`, `optimism`, `unichain`, `avalanche`, `plume`, `monad`

Chain IDs are used as:
- `id` in chain entries
- Keys in the `allocations` object
- `chain` in stability modules and direct exposures

## 8. Amount

```json
{ "value": 1000000000, "currency": "USD" }
```

- **`value`** — numeric amount (type: `number`).
- **`currency`** — ISO 4217 currency code or well-known token symbol (e.g., `"USD"`, `"USDC"`, `"ETH"`).

Both fields are required. No additional properties allowed.

Used in:
- `cap` on allocation positions (protocol-config)
- `cap` on asset caps (pnl-config)
- `cap` on subsidy programs (pnl-config)
- `amount` on one-time adjustments (pnl-config)
- `amount` on prepayments (pnl-config)

## 9. Duration

```json
{ "value": 24, "unit": "months" }
```

- **`value`** — numeric duration value (type: `number`).
- **`unit`** — one of: `"months"`, `"days"`, `"hours"`, `"seconds"`.

Both fields are required. No additional properties allowed.

Used in:
- `duration` on subsidy programs (pnl-config)
- `prePeriodBuffer` and `postPeriodBuffer` on pricing config (pnl-config)

## 10. Date

```json
"2026-01-01"
```

An ISO 8601 date string in YYYY-MM-DD format. Validated by the pattern `^\d{4}-\d{2}-\d{2}$`.

Used in:
- `activeFromDate` on allocation positions (protocol-config)
- `start` on subsidy programs (pnl-config)
- `activeFrom` on LP pool configs (pnl-config)
- `lastUpdated` in metadata

---

# Relationships Reference

How denna-spec files relate to each other and what changes cascade across files.

## 1. Protocol-Config and PnL-Config

These two files are tightly coupled. For every star, both files must be consistent.

**Address consistency:** Every address that appears in pnl-config `parameters.addressClassifications` (under any classification array: `billAlways`, `skyTakesAll`, `simplePeriodReturn`, `directRate`, `ssrFunded`, `usdsSsr`) must exist as a position in protocol-config `allocations`. An address classification without a corresponding allocation entry is an error.

**Tag-classification consistency:** Tags on protocol-config positions should have corresponding classification entries in pnl-config for tags that have counterparts:
- Position with `bill_always` tag → address in `addressClassifications.billAlways[]`
- Position with `sky_takes_all` tag → address in `addressClassifications.skyTakesAll[]`
- Position with `simple_period_return` tag → address in `addressClassifications.simplePeriodReturn[]`
- Position with `direct_rate` tag → address in `addressClassifications.directRate[]`
- Position with `ssr_funded` tag → address in `addressClassifications.ssrFunded[]`

**Cap consistency:** If a protocol-config position has a `cap` field, pnl-config should have a corresponding entry in `parameters.assetCaps` with the same asset and cap value. The `effect` field in pnl-config documents what happens when the cap is exceeded.

**Module-feature consistency:** Calculation modules in pnl-config correspond to feature flags in protocol-config. For example, if `idleStablecoins` module is enabled, at least one chain should have `features.idleStablecoins: true`.

## 2. Protocol-Config and Shared Files

The sky-parameters repo contains shared files alongside per-star files:

- **Shared stablecoin/sUSDS address registries** (`shared/stablecoin-addresses.denna-spec.json`, `shared/susds-addresses.denna-spec.json`) should cover all chains a star operates on. When a star adds a new chain, verify the shared registries include that chain.

- **Shared rates** (`shared/rates.denna-spec.json`) define rate parameters and subsidy programs. The `subsidyPrograms` entries in pnl-config reference these shared programs. When a subsidy program is modified in shared rates, all stars referencing it should be reviewed.

## 3. What Cascades When Adding a Position

When adding a new allocation position:

1. **Protocol-config:** Add the position entry to `allocations[chainId]` with at minimum `contract`, `protocol`, and `type`.

2. **If the position has special PnL treatment:**
   - Add the appropriate tag(s) to the position's `tags` array in protocol-config.
   - Add the address to the corresponding `addressClassifications` array in pnl-config (for tags that have classification counterparts).
   - Both must be set — tag alone or classification alone creates an inconsistency.

3. **If the position has a cap:**
   - Set the `cap` field on the position in protocol-config.
   - Add a corresponding `assetCaps` entry in pnl-config with the same asset symbol and cap value.

4. **If the position needs non-standard pricing:**
   - Add an entry to `pricingConfig.sources` in pnl-config.
   - For Centrifuge positions: add to `pricingConfig.centrifugeTokenMappings` and set `extra.centrifugeTokenId` on the position.

5. **Markdown docs:** Update the star's markdown documentation in `markdown/[star]/` to reflect the new position.

## 4. What Cascades When Adding a Chain

When adding a new chain for a star:

1. **Protocol-config:**
   - Add a chain entry to `chains[]` with `id`, `name`, `almProxy` address, and appropriate `features` flags.
   - If Ethereum: set `vaultProxy` for MCD vault access.
   - If the chain has PSM3: set `features.psm3: true` and add the `psm3Contract` address.
   - If the chain has an sUSDS oracle: set `susdsOracle`.

2. **Protocol-config allocations:** Add an `allocations[chainId]` array with position entries for the new chain.

3. **PnL-config stability modules:** If the chain has PSM3:
   - Add a `stabilityModules` entry with `chain`, optional `address`, and `tokens[]` defining how each token (USDC, USDS, sUSDS) is treated.
   - Potentially add a `directExposures` entry if USDC in the PSM3 is treated as direct exposure.

4. **Shared files:** Verify shared stablecoin and sUSDS address registries include the new chain.

5. **Markdown docs:** Update documentation.

## 5. What Cascades When Adding a New Star

When creating a new star from scratch:

1. **Protocol-config:** Create `[star]/protocol-config.denna-spec.json` with:
   - `$schema` pointing to `https://spec.denna.io/v1/defi/protocol-config.schema.json`
   - `metadata` with unique `id`, `kind` = `io.denna.defi.protocol-config`, `name`, `version`
   - At minimum one chain entry (Ethereum) with `almProxy` and `vaultProxy` addresses
   - `debtSource` pointing to the Ethereum Vat (`0x35d1b3f3d7966a1dfe207aa4514c12a259a0492b`)
   - Initial `allocations` for the chain(s)

2. **PnL-config:** Create `[star]/pnl-config.denna-spec.json` with:
   - `$schema` pointing to `https://spec.denna.io/v1/defi/pnl-config.schema.json`
   - `metadata` with unique `id`, `kind` = `io.denna.defi.pnl-config`, `name`, `version`
   - `parameters.calculationModules` — at minimum `maxDebtFees` must be enabled
   - Any applicable address classifications, asset caps, pricing config, stability modules

3. **Markdown docs:** Create documentation from `markdown/_template/` as a starting point.

4. **Shared files:** Verify the new star's chains are covered by shared registries.

---

# Common Gotchas

Mistakes that are easy to make when working with denna-spec files.

## 1. Not all positions need `underlying`

Schema requires only `contract`, `protocol`, `type`. Many positions omit `underlying` (e.g., Ripple RLUSD token, Agora AUSD). Don't flag missing `underlying` as an error.

## 2. Tags drive PnL, not decorative

A missing tag means default PnL treatment. If a position should be "bill always" but lacks the `bill_always` tag, it will get standard treatment — silently wrong.

## 3. Tags AND classifications must both be set

Setting `bill_always` tag on an allocation without adding the address to `addressClassifications.billAlways[]` in pnl-config (or vice versa) creates an inconsistency. Both must be updated in tandem.

## 4. L2 sUSDS is ERC20, not ERC4626

On Ethereum, sUSDS is an ERC4626 vault (you deposit USDS, get sUSDS). On L2 chains (Base, Arbitrum, Optimism, Unichain), sUSDS is a plain ERC20 token — the vault mechanics don't apply. This affects how pricing and spread calculations work.

## 5. PSM3 chains may appear in pnl-config but not protocol-config

This is intentional. Chains like Arbitrum, Optimism, Unichain may be in pnl-config `stabilityModules` for PSM3 processing without having a corresponding entry in protocol-config `chains`. These are PnL-relevant through PSM3 only, not through direct allocations.

## 6. Morpho vaults use `erc4626` type, not `morpho`

`morpho` is not a schema-valid type. Morpho vaults are typed as `erc4626` with a `markets` array containing market IDs. If someone says "add a Morpho vault", the `type` is `erc4626`.

## 7. Fluid vaults also use `erc4626` type

Same pattern as Morpho. Fluid lending vaults use the generic `erc4626` type.

## 8. Two schema repos exist

- `denna-spec` (canonical, `spec.denna.io`) — data files reference these
- `denna-spec-schemas` (extensions, `schemas.denna.io`) — domain-specific

Data files always declare `$schema` pointing to `spec.denna.io`. When validating, use the canonical schema. Do not confuse with the extensions repo.

## 9. `subsidyPrograms` is in the canonical pnl-config schema

Don't confuse with the `denna-spec-schemas` extensions repo which has a different structure (`borrowRateSubsidy` as a single object). The canonical schema at `spec.denna.io` defines `subsidyPrograms` as an array. Always reference the canonical schema.

## 10. Cross-star address reuse is valid

The same contract (e.g., BUIDL at `0x6a9da2d...`) can appear in multiple stars. This is expected — multiple stars can hold the same asset. Duplicate checks are within a single star only.

## 11. `extra` field is unvalidated

Schema allows `additionalProperties: true` on `extra`. Use it for protocol-specific data like `centrifugeTokenId`. Since it's unvalidated, mistakes here won't be caught by schema validation.

## 12. Address format: 0x + 40 hex = 42 chars total

A valid EVM address is exactly 42 characters: `0x` prefix followed by 40 hexadecimal digits. Watch for:
- 41 hex digits (43 chars total) — typo, extra digit
- Mixed case — EVM addresses are case-insensitive but checksum-sensitive
- Missing `0x` prefix
