#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUNDLED="$REPO_ROOT/bundled"
SKILLS="$REPO_ROOT/skills"

# Clean and create output directory
rm -rf "$BUNDLED"
mkdir -p "$BUNDLED"

# Strip YAML frontmatter (content between opening --- and closing --- at file start)
strip_frontmatter() {
  local file="$1"
  if head -1 "$file" | grep -q '^---$'; then
    tail -n +2 "$file" | sed '1,/^---$/d'
  else
    cat "$file"
  fi
}

# Append source file to bundle with --- separator, stripping frontmatter
append_file() {
  local dest="$1"
  local src="$2"
  printf '\n---\n\n' >> "$dest"
  strip_frontmatter "$src" >> "$dest"
}

###############################################################################
# 1. bundled/denna-spec-reference.md
###############################################################################
OUT="$BUNDLED/denna-spec-reference.md"

cat > "$OUT" << 'EOF'
# Denna Spec Reference

Combined reference for interpreting Denna Specification (.denna-spec.json) files.
Always include this file in your Claude.ai Project when working with sky-parameters.

This document covers: protocol-config structure, PnL configuration, value types,
cross-file relationships, and common gotchas.

## Source of Truth

The canonical sky-parameters data lives at:
**https://github.com/daocraft/sky-parameters**

> **Claude.ai users:** GitHub URLs cannot be fetched directly from Claude.ai.
> To work with sky-parameters data, ask the user to paste the relevant file contents
> (e.g., `protocol-config.denna-spec.json`, `pnl-config.denna-spec.json`) into the
> conversation, or use the raw URL format:
> `https://raw.githubusercontent.com/daocraft/sky-parameters/main/<path>`
EOF

REF="$SKILLS/denna-spec-reference/references"
for f in protocol-config.md pnl-awareness.md value-types.md relationships.md gotchas.md; do
  append_file "$OUT" "$REF/$f"
done

###############################################################################
# 2. bundled/denna-params-auditor.md
###############################################################################
OUT="$BUNDLED/denna-params-auditor.md"

cat > "$OUT" << 'EOF'
# Denna Params Auditor

Skill and supporting references for auditing star configuration in sky-parameters repos.
Upload this file (along with `denna-spec-reference.md`) to your Claude.ai Project.

**Data repo:** https://github.com/daocraft/sky-parameters
— ask the user to paste file contents or use raw.githubusercontent.com URLs.
EOF

append_file "$OUT" "$SKILLS/denna-params-auditor/SKILL.md"
append_file "$OUT" "$SKILLS/denna-params-auditor/references/audit-checklist.md"
append_file "$OUT" "$SKILLS/denna-params-auditor/references/findings-schema.md"

# Rewrite cross-bundle references to point to bundled filenames
sed -i '' 's|\.\./denna-spec-reference/references/\*\.md|denna-spec-reference.md|g' "$OUT"

###############################################################################
# 3. bundled/denna-params-author.md
###############################################################################
OUT="$BUNDLED/denna-params-author.md"

cat > "$OUT" << 'EOF'
# Denna Params Author

Skill and supporting references for adding, modifying, or removing star configuration
in sky-parameters repos. Upload this file (along with `denna-spec-reference.md`) to
your Claude.ai Project.

**Data repo:** https://github.com/daocraft/sky-parameters
— ask the user to paste file contents or use raw.githubusercontent.com URLs.
EOF

append_file "$OUT" "$SKILLS/denna-params-author/SKILL.md"
append_file "$OUT" "$SKILLS/denna-params-author/references/examples.md"

# Rewrite cross-bundle references to point to bundled filenames
sed -i '' 's|\.\./denna-spec-reference/references/\*\.md|denna-spec-reference.md|g' "$OUT"

###############################################################################
# Summary
###############################################################################
echo ""
echo "=== Bundled files generated ==="
echo ""
for f in "$BUNDLED"/*.md; do
  size=$(wc -c < "$f" | tr -d ' ')
  lines=$(wc -l < "$f" | tr -d ' ')
  name=$(basename "$f")
  printf "  %-30s %6s bytes  %4s lines\n" "$name" "$size" "$lines"
done
echo ""
echo "Output directory: $BUNDLED"
