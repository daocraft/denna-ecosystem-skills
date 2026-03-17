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
