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
