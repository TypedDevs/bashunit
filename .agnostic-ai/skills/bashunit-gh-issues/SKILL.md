---
name: bashunit-gh-issues
description: Work open unassigned or own GitHub issues one at a time.
argument-hint: "[--limit N] [--label foo] [--dry-run]"
disable-model-invocation: true
allowed-tools: read, shell, Skill
---

# Process an issue queue

Process open issues that are unassigned or assigned only to the authenticated user, oldest first, using {{$SKILL:bashunit-gh-issue}} sequentially. Accept `--limit N`, `--label foo`, and `--dry-run` (discovery only).

## Discover

Resolve the current login with `gh api user -q .login`. Fetch open issues with pagination:

```bash
gh api --paginate 'repos/{owner}/{repo}/issues?state=open&per_page=100'
```

Exclude pull requests, issues assigned to anyone else, and tracker issues whose body lists child issues. Deduplicate by number, apply the label filter, sort by `created_at`, then apply the requested limit. Print `#<number> <title> [unassigned|@me]`; stop if empty. Dry-run stops here.

## Process

1. Check `git status --porcelain`. Preserve dirty work and stop or use an isolated worktree; never auto-stash or reset it. Fetch main and update a clean main with `git pull --ff-only`. A divergent branch needs a deliberate resolution.
2. Re-read each issue's state and assignees before starting; skip closed or newly assigned issues. Invoke {{$SKILL:bashunit-gh-issue}}, which owns implementation, the canonical quality gate, commit, and PR. The coordinator runs that gate once per complete issue; delegates run only focused checks.
3. The gate includes `make test/strict`, which is what CI's strict job runs. Simple mode emits marker output; assert on helpers when testing full messages. Under strict mode, use `if` instead of failing `[ condition ] && assignment`, initialize arrays with `=()`, read potentially empty elements as `${arr[i]:-}`, and keep `extdebug` inside a capture subshell.
4. Wait for `gh pr checks --watch`. Investigate red checks, including Bash 3.0 compatibility. Re-run an identified infrastructure failure with `gh run rerun <id> --failed`; do not classify every registry failure as transient. If a local failure appears unrelated, compare the relevant test on unchanged main in an isolated checkout before claiming it predates the change.
5. Merge only when the user's authorization covers it and checks and branch protection allow it. Do not bypass protection. After an authorized merge, verify issue closure; close a completed issue if needed and update its parent's checklist. Escape Markdown brackets as literals when editing checkbox text and preserve the rest of the body.
6. Delete merged branches and worktrees according to the global cleanup rules, fetch and prune, and fast-forward main before the next issue. Keep branches with open PRs or unpushed commits.

Stop and report the issue and cause on a hard failure, unresolved red check, dirty checkout after processing, blocked merge, or reached limit. Do not retry blindly. If merging is outside authorization, retain the open PR and report the remaining queue. No issue assignment, branch, or commit changes in dry-run mode.
