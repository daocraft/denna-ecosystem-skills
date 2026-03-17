# Findings Schema

JSON Schema definition for the `findings.json` output produced by the denna-params-auditor skill.

## Schema

```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "title": "denna-params-auditor findings",
  "type": "array",
  "items": {
    "type": "object",
    "required": ["severity", "type", "file", "location", "explanation", "suggested_action", "confidence"],
    "additionalProperties": false,
    "properties": {
      "severity": {
        "type": "string",
        "enum": ["blocker", "warning", "nit"]
      },
      "type": {
        "type": "string",
        "enum": [
          "schema_violation",
          "missing_field",
          "invalid_address",
          "orphaned_reference",
          "tag_classification_mismatch",
          "inconsistency",
          "style"
        ]
      },
      "file": {
        "type": "string",
        "description": "Relative path to the file containing the issue"
      },
      "location": {
        "type": "string",
        "description": "JSON path to the specific field (e.g., allocations.ethereum[3].contract)"
      },
      "explanation": {
        "type": "string",
        "description": "What is wrong and why it matters"
      },
      "suggested_action": {
        "type": "string",
        "description": "How to fix the issue"
      },
      "confidence": {
        "type": "number",
        "minimum": 0,
        "maximum": 1,
        "description": "Confidence in the finding (0-1). Use warning instead of blocker if < 0.7"
      }
    }
  }
}
```

## Conventions

### Empty Array

An empty array `[]` means no issues were found. The audit passed cleanly.

### Severity Levels

| Severity | Meaning | Examples |
|----------|---------|----------|
| `blocker` | Broken config that would cause runtime errors or incorrect calculations | Schema violation, missing required field, invalid address, contradictory feature flags |
| `warning` | Likely mistake or inconsistency that should be investigated | Orphaned classification entry, tag/classification mismatch, missing markdown update |
| `nit` | Style issues, missing optional fields, documentation gaps | Missing optional `notes` field, ordering inconsistency, stale markdown |

### Finding Types

| Type | Description |
|------|-------------|
| `schema_violation` | File does not conform to its declared `$schema` |
| `missing_field` | A required or expected field is absent |
| `invalid_address` | An address does not conform to EVM format (42 chars: `0x` + 40 hex) |
| `orphaned_reference` | A reference points to something that does not exist (e.g., classification for a removed position) |
| `tag_classification_mismatch` | A tag and its corresponding classification array are inconsistent |
| `inconsistency` | Cross-file or cross-field inconsistency (e.g., chain mismatch between protocol-config and pnl-config) |
| `style` | Formatting, ordering, or documentation issues |

### Confidence Score

The `confidence` field (0 to 1) reflects how certain the auditor is about the finding:
- **0.9 -- 1.0**: Deterministic check (schema validation, address format, required field presence)
- **0.7 -- 0.9**: High-confidence heuristic (tag/classification matching, cross-file consistency)
- **0.5 -- 0.7**: Moderate confidence (may be an intentional exception; use `warning` severity, not `blocker`)
- **Below 0.5**: Do not report. The finding is too speculative.

Rule: Never assign `blocker` severity when confidence is below 0.7. Use `warning` instead.

## Differences from Atlas-Lint Contract

The denna-params-auditor findings contract differs from atlas-lint's contract in several ways:

| Aspect | atlas-lint | denna-params-auditor | Reason |
|--------|-----------|---------------------|--------|
| Location reference | `edited_unit` + `related_units` (markdown anchors) | `file` + `location` (JSON paths) | Denna files are JSON, not markdown. JSON paths provide precise field references. |
| Evidence | `evidence[]` array of text excerpts | Inline in `explanation` | JSON fields are short and self-contained; a separate evidence array adds overhead without clarity. |
| Confidence | Not present | `confidence` (0-1) | Denna cross-file checks have varying certainty; confidence helps distinguish deterministic checks from heuristics. |
| Finding type | Implicit in explanation | Explicit `type` enum | Enables machine filtering and aggregation of findings by category. |

## Example

```json
[
  {
    "severity": "blocker",
    "type": "invalid_address",
    "file": "grove/protocol-config.denna-spec.json",
    "location": "allocations.monad[2].contract",
    "explanation": "Address has 41 hex characters (expected 40). Total length is 43 instead of 42.",
    "suggested_action": "Verify address on block explorer and correct to 42 characters",
    "confidence": 0.99
  },
  {
    "severity": "warning",
    "type": "orphaned_reference",
    "file": "grove/pnl-config.denna-spec.json",
    "location": "addressClassifications.simplePeriodReturn[5]",
    "explanation": "Address 0xABC...123 appears in simplePeriodReturn classifications but does not match any contract in protocol-config allocations.",
    "suggested_action": "Remove the orphaned entry from simplePeriodReturn or add the corresponding allocation to protocol-config",
    "confidence": 0.85
  },
  {
    "severity": "nit",
    "type": "style",
    "file": "grove/protocol-config.denna-spec.json",
    "location": "allocations.base[7]",
    "explanation": "Position is missing the optional 'notes' field. Other positions of the same type in this star include notes for context.",
    "suggested_action": "Consider adding a 'notes' field describing the position purpose",
    "confidence": 0.60
  }
]
```
