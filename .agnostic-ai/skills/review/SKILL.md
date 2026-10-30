---
name: review
description: Review a GitHub pull request, by default the current branch's
argument-hint: "[#N]"
allowed-tools: shell, read, Grep, Glob
---

# Review a pull request

Resolve the supplied PR number or the current branch's PR with `gh pr view`. If neither identifies one, list open PRs and request a selection. For an uncommitted diff, use `code-reviewer` instead.

Read `gh pr view <number> --json number,title,body,state,headRefName,baseRefName,url` and `gh pr diff <number>`. Follow the applicable source rules in `.agnostic-ai/AGNOSTIC_AI.md`.

Apply `.agnostic-ai/skills/review/references/checklist.md`. Report only verified defects; if none remain, state the scope checked.
