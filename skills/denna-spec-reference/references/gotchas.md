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
