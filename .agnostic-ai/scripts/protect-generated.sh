#!/usr/bin/env bash
set -eu

if [ -n "${1:-}" ]; then
  export AGNOSTIC_AI_TARGET="$1"
fi

project_root=$(git rev-parse --show-toplevel)
agnostic_ai="$project_root/node_modules/.bin/agnostic-ai"
if [ ! -x "$agnostic_ai" ]; then
  agnostic_ai=$(command -v agnostic-ai) || {
    echo "Install contributor dependencies with npm ci before editing agent configuration." >&2
    exit 2
  }
fi
changes=$("$agnostic_ai" hook paths --action) || exit 2
while IFS=$'\t' read -r _action file; do
  key=$(printf '%s' "$file" | tr '[:upper:]' '[:lower:]')
  case "$key" in
    agents.md | */agents.md | claude.md | */claude.md | .claude/rules/* | .claude/agents/* | \
      .claude/skills/* | .claude/hooks/* | .claude/settings.json | .codex/* | .agents/skills/*)
      echo "Generated file: $file. Edit .agnostic-ai/ and run npm run agents:sync." >&2
      exit 2
      ;;
  esac
done <<<"$changes"
