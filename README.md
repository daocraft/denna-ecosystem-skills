# Denna Ecosystem Skills

An AI agent skills package for working with **Denna Specification** parameter files. These skills give your agent the domain knowledge needed to interpret, author, and audit `.denna-spec.json` configurations used in [sky-parameters](https://github.com/daocraft/sky-parameters) repositories.

Works with [Claude Code](https://docs.anthropic.com/en/docs/claude-code), [GitHub Copilot](https://github.com/features/copilot), [Gemini CLI](https://github.com/google-gemini/gemini-cli), and other agents that support the [Skills](https://github.com/anthropics/skills) format.

## Available Skills

| Skill | Description | Status |
|-------|-------------|--------|
| `denna-spec-reference` | Core knowledge skill for interpreting Denna Specification files | Stable |
| `denna-params-author` | Workflow skill for adding/modifying star positions | Stable |
| `denna-params-auditor` | Verification skill for auditing star configurations | Stable |

## Skill Summaries

### denna-spec-reference

Core knowledge skill that teaches Claude how to read and interpret `.denna-spec.json` files.

- **What it does** -- Provides interpretation rules for the Denna Specification envelope format, schema architecture, sky-parameters file structure, and value types.
- **How it works** -- Loads reference documents covering protocol-config structure, PnL awareness, value types, cross-file relationships, and common gotchas. Other denna skills depend on this one.
- **Key outputs** -- Contextual understanding (no file artifacts). Claude learns the spec grammar so it can correctly interpret any `.denna-spec.json` file fetched at runtime.

### denna-params-author

Workflow skill for translating any input format into valid denna-spec entries.

- **What it does** -- Accepts natural language, spreadsheets, address lists, or code snippets describing allocation changes and produces a PR-ready changeset for a sky-parameters repository.
- **How it works** -- Acquires context from the target repo, interprets user input to extract contract addresses / chains / types / tags, validates against existing data (duplicate check, type validation, address format), generates changes to `protocol-config.denna-spec.json`, `pnl-config.denna-spec.json`, and markdown docs.
- **Key outputs** -- Modified `protocol-config.denna-spec.json`, modified `pnl-config.denna-spec.json` (when PnL treatment is affected), updated markdown docs, and a `change-summary.md` suitable for PR descriptions.

### denna-params-auditor

Verification skill for auditing star configurations against the Denna Specification.

- **What it does** -- Runs a structured checklist across protocol-config and pnl-config files, checking schema validity, address formats, duplicate positions, tag/classification consistency, cross-file coherence, and feature-flag correctness.
- **How it works** -- Reads target star files plus shared config, runs checks organized by category (schema validation, protocol config, PnL config, cross-file consistency), classifies findings as `blocker`, `warning`, or `nit`.
- **Key outputs** -- `findings.json` (machine-readable array of finding objects with severity, type, location, explanation, and suggested action) and `report.md` (human-readable audit report with verdict: PASS or FAIL).

## Installation

### Skills CLI (recommended)

Works across Claude Code, GitHub Copilot, Gemini CLI, and other supported agents:

```bash
npx skills add daocraft/denna-ecosystem-skills
```

### Claude Code plugin

```bash
# Marketplace
/plugin marketplace add daocraft/denna-ecosystem-skills
/plugin install denna-ecosystem-skills@daocraft-denna-ecosystem-skills

# Local development
claude --plugin-dir ./denna-ecosystem-skills
```

### npm

```bash
npm install @daocraft/denna-ecosystem-skills
```

### Claude.ai (web)

Upload the pre-built bundles from `bundled/` as Project knowledge files. See [SETUP.md](./SETUP.md) for which files to include per task. Regenerate bundles after editing source files:

```bash
bash scripts/bundle.sh
```

A [CI check](.github/workflows/check-bundles.yml) will fail PRs that have stale bundles.

## Project Structure

```
denna-ecosystem-skills/
├── .claude-plugin/
│   ├── plugin.json
│   └── marketplace.json
├── skills/
│   ├── denna-spec-reference/
│   │   ├── SKILL.md
│   │   └── references/
│   │       ├── protocol-config.md
│   │       ├── pnl-awareness.md
│   │       ├── value-types.md
│   │       ├── relationships.md
│   │       └── gotchas.md
│   ├── denna-params-author/
│   │   ├── SKILL.md
│   │   └── references/
│   │       └── examples.md
│   └── denna-params-auditor/
│       ├── SKILL.md
│       └── references/
│           ├── audit-checklist.md
│           └── findings-schema.md
├── bundled/                        ← pre-built bundles for Claude.ai web
│   ├── denna-spec-reference.md
│   ├── denna-params-auditor.md
│   └── denna-params-author.md
├── scripts/
│   └── bundle.sh
├── package.json
├── SETUP.md
├── README.md
├── CHANGELOG.md
└── LICENSE
```

## Example Workflows

These gists walk through real-world usage of the skills:

- [Adding a Morpho vault to Grove on Base](https://gist.github.com/grace-tau37/d05c48522892da11ac0a8199aa512a0a#file-gist-morpho-example-md) -- uses `denna-params-author` to produce a complete PR changeset from a contract address and chain name.
- [Onboarding a new Star from scratch](https://gist.github.com/grace-tau37/d05c48522892da11ac0a8199aa512a0a#file-gist-new-star-example-md) -- uses all three skills end-to-end: reference for context, author for initial config, auditor to verify before merge.
- [Adding a SparkLend position to Spark on Ethereum](https://gist.github.com/grace-tau37/d05c48522892da11ac0a8199aa512a0a#file-gist-spark-example-md) -- uses `denna-params-author` to produce a complete PR changeset including PnL config changes for a SparkLend atoken with tags.

## Contributing

Contributions are welcome. Please open an issue in the [issue tracker](https://github.com/daocraft/denna-ecosystem-skills/issues) to discuss changes before submitting a pull request.

When adding or modifying a skill:
1. Follow the existing `SKILL.md` frontmatter and section conventions
2. Place supporting data in `references/` within the skill directory
3. Run `bash scripts/bundle.sh` to regenerate the Claude.ai bundles
4. Update this README if the skill table or project structure changes

## License

This project is licensed under [CC-BY-4.0](./LICENSE).
