#!/usr/bin/env bash
set -eu

if [ -n "${1:-}" ]; then
  export AGNOSTIC_AI_TARGET="$1"
fi

project_root=$(git rev-parse --show-toplevel)
agnostic_ai="$project_root/node_modules/.bin/agnostic-ai"
if [ ! -x "$agnostic_ai" ]; then
  agnostic_ai=$(command -v agnostic-ai) || exit 0
fi
files=$("$agnostic_ai" hook paths) || exit 1
printf '%s\n' "$files" | while IFS= read -r file; do
  case "$file" in
    *.sh)
      if [ -f "$file" ]; then
        shellcheck -x "$file" 2>&1 | head -20
      fi
      ;;
  esac
done
