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
