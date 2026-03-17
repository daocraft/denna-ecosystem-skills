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
