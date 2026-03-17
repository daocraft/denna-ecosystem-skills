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
