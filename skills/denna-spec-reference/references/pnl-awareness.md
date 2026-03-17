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
