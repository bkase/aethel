#!/usr/bin/env bash
set -euo pipefail

# A4 Core vault initializer
# Usage:
#   ./init_a4_core.sh [VAULT_DIR] [REMOTE_URL]
#
# Examples:
#   ./init_a4_core.sh                          # uses $A4_VAULT_DIR or $HOME/Documents/a4-core
#   ./init_a4_core.sh ~/Documents/a4-core      # explicit path
#   ./init_a4_core.sh ~/Documents/a4-core git@github.com:you/a4-core.git

VAULT_DIR="${1:-${A4_VAULT_DIR:-$HOME/Documents/a4-core}}"
REMOTE_URL="${2:-}"

# Date bits (UTC for filenames; local used inside notes later by your apps/CLI)
UTC_Y="$(date -u +%Y)"
UTC_m="$(date -u +%m)"
UTC_d="$(date -u +%d)"
ISO_WEEK_YEAR="$(date -u +%G)" # ISO week-year
ISO_WEEK="$(date -u +%V)"      # 01-53

# Paths
CAPTURE_DIR="$VAULT_DIR/capture/$UTC_Y/$UTC_Y-$UTC_m"
TODAY_FILE="$CAPTURE_DIR/$UTC_Y-$UTC_m-$UTC_d.md"
WEEKLY_DIR="$VAULT_DIR/collections/weekly-plans/$ISO_WEEK_YEAR"
JOURNALS_DIR="$VAULT_DIR/collections/journals/$UTC_Y"
TEMPLATES_DIR="$VAULT_DIR/routines/templates"

echo "A4 vault: $VAULT_DIR"
mkdir -p "$VAULT_DIR"

# Core tree (with .gitkeep where useful)
mkdir -p \
  "$VAULT_DIR/inbox" \
  "$CAPTURE_DIR" \
  "$WEEKLY_DIR" \
  "$JOURNALS_DIR" \
  "$VAULT_DIR/collections/research-memos" \
  "$VAULT_DIR/collections/essays" \
  "$VAULT_DIR/projects" \
  "$VAULT_DIR/sources/articles" \
  "$VAULT_DIR/sources/transcripts" \
  "$VAULT_DIR/sources/books" \
  "$VAULT_DIR/routines/checklists" \
  "$TEMPLATES_DIR" \
  "$VAULT_DIR/.a4"

for d in \
  "$VAULT_DIR/inbox" \
  "$VAULT_DIR/collections/research-memos" \
  "$VAULT_DIR/collections/essays" \
  "$VAULT_DIR/projects" \
  "$VAULT_DIR/sources/articles" \
  "$VAULT_DIR/sources/transcripts" \
  "$VAULT_DIR/sources/books" \
  "$VAULT_DIR/routines/checklists" \
  "$VAULT_DIR/.a4"; do
  [ -f "$d/.gitkeep" ] || touch "$d/.gitkeep"
done

# .gitignore (don’t overwrite if exists)
if [ ! -f "$VAULT_DIR/.gitignore" ]; then
  cat >"$VAULT_DIR/.gitignore" <<'EOF'
.DS_Store
Thumbs.db
.obsidian/
.a4/cache/
.a4/tmp/
*.swp
*.swo
EOF
fi

# README (don’t overwrite)
if [ ! -f "$VAULT_DIR/README.md" ]; then
  cat >"$VAULT_DIR/README.md" <<EOF
# A4 Core Vault

Plain-Markdown, Git-native personal knowledge base.

- Daily-first: notes in \`capture/YYYY/YYYY-MM/YYYY-MM-DD.md\` (UTC filename).
- Append-only semantics under block anchors (e.g., \`^focus-0930\`).
- Front matter optional; used by apps for generated docs.
- Large assets live in a separate \`a4-assets\` repo (mounted at \`assets/\` if desired).

This repo is private by default; publishing happens via curated docs under \`collections/\`.
EOF
fi

# Templates (don’t overwrite)
if [ ! -f "$TEMPLATES_DIR/daily.md" ]; then
  cat >"$TEMPLATES_DIR/daily.md" <<'EOF'
---
kind: capture.day
created: {{now_utc}}
tags: [daily]
---
# Daily Note {{YYYY-MM-DD}}

## Intention
^intent-{{hhmm}}

## End of Day
^eod-{{hhmm}}
EOF
fi

# Create today's daily file:
# - If template exists, copy it (once).
# - Else, create a blank file.
if [ ! -f "$TODAY_FILE" ]; then
  if [ -f "$TEMPLATES_DIR/daily.md" ]; then
    cp "$TEMPLATES_DIR/daily.md" "$TODAY_FILE"
  else
    : >"$TODAY_FILE"
  fi
  echo "Created today: $TODAY_FILE"
else
  echo "Today already exists: $TODAY_FILE"
fi

# Initialize Git if needed
if [ ! -d "$VAULT_DIR/.git" ]; then
  # Use -b main when available; fallback for older Git
  if git -C "$VAULT_DIR" init -b main >/dev/null 2>&1; then
    true
  else
    git -C "$VAULT_DIR" init
    git -C "$VAULT_DIR" checkout -b main
  fi
  git -C "$VAULT_DIR" add .
  git -C "$VAULT_DIR" commit -m "a4: initial scaffold"
  echo "Initialized git repo with initial commit."
else
  echo "Git repo already exists. Adding any new files…"
  git -C "$VAULT_DIR" add .
  if ! git -C "$VAULT_DIR" diff --cached --quiet; then
    git -C "$VAULT_DIR" commit -m "a4: scaffold update"
    echo "Committed scaffold updates."
  else
    echo "No changes to commit."
  fi
fi

# Optional remote + push
if [ -n "$REMOTE_URL" ]; then
  if git -C "$VAULT_DIR" remote get-url origin >/dev/null 2>&1; then
    echo "Remote 'origin' already set."
  else
    git -C "$VAULT_DIR" remote add origin "$REMOTE_URL"
  fi
  git -C "$VAULT_DIR" push -u origin main
  echo "Pushed to $REMOTE_URL (branch: main)."
fi

echo "Done. Vault ready at: $VAULT_DIR"
