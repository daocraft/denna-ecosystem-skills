# Setup Guide

How to use the Denna Ecosystem Skills depending on your environment.

## Claude.ai (Web)

Upload the bundled files from `bundled/` to your Claude.ai Project as knowledge files.

### Which files to include

| Task | Files to upload |
|------|-----------------|
| Auditing star configuration | `denna-spec-reference.md` + `denna-params-auditor.md` |
| Authoring / modifying configuration | `denna-spec-reference.md` + `denna-params-author.md` |
| Both auditing and authoring | All three bundled files |

The reference file (`denna-spec-reference.md`) is **always required** — it provides the interpretation rules that the auditor and author skills depend on.

### Regenerating bundles

If the source files change, regenerate the bundles:

```bash
bash scripts/bundle.sh
```

## Claude Code / Local Projects

No bundling needed. The individual source files under `skills/` are loaded automatically by the Claude Code plugin system. Each skill references its own `references/` directory for supporting documentation.

### File structure

```
skills/
  denna-spec-reference/     — interpretation rules for denna-spec files
    SKILL.md
    references/
      protocol-config.md
      pnl-awareness.md
      value-types.md
      relationships.md
      gotchas.md
  denna-params-auditor/     — star configuration auditing
    SKILL.md
    references/
      audit-checklist.md
      findings-schema.md
  denna-params-author/      — star configuration authoring
    SKILL.md
    references/
      examples.md
```

Install via any of:

- Skills CLI: `npx skills add daocraft/denna-ecosystem-skills`
- Claude Code plugin: `/plugin marketplace add daocraft/denna-ecosystem-skills`
- npm: `npm install @daocraft/denna-ecosystem-skills`
