---
name: bashunit-gh-issues
description: Use to work the queue of open unassigned or own GitHub issues, one at a time.
argument-hint: "[--limit N] [--label foo] [--dry-run]"
disable-model-invocation: true
allowed-tools: [read, shell, Skill]
---

# Process an issue queue

Run `bashunit-gh-issue` sequentially on open issues that are unassigned or assigned only to you, oldest first. Flags: `--limit N`, `--label foo`, `--dry-run` (discovery only).

## Discover

Get your login with `gh api user -q .login`. Fetch open issues with pagination:

```bash
gh api --paginate 'repos/{owner}/{repo}/issues?state=open&per_page=100'
```

Exclude pull requests, issues assigned to anyone else, and tracker issues whose body lists child issues. Deduplicate by number, apply the label filter, sort by `created_at`, then apply the requested limit. Print `#<number> <title> [unassigned|@me]`; stop if empty. Dry-run stops here.

## Process

1. Check `git status --porcelain`. Keep dirty work: stop or use an isolated worktree; never stash or reset it. Fetch main and update a clean main with `git pull --ff-only`.
2. Pick the validation mode (step 3) first. Re-read each issue's state and assignees before starting; skip closed or newly assigned issues. `bashunit-gh-issue` owns implementation, the quality gate, commit and PR. Run the gate once per complete issue; delegates run only focused checks.
3. If CI requires strict mode, run `./bashunit --parallel --simple --strict tests/` instead of the ordinary parallel gate before committing; check the current CI command first. Simple mode emits marker output: assert on helpers, not full messages. Under strict mode, use `if` instead of failing `[ condition ] && assignment`, initialize arrays with `=()`, read potentially empty elements as `${arr[i]:-}`, and keep `extdebug` inside a capture subshell.
4. Wait for `gh pr checks --watch`. Investigate red checks, including Bash 3.0 compatibility. Re-run a confirmed infrastructure failure with `gh run rerun <id> --failed`; not every registry failure is transient. Before calling a local failure pre-existing, run that test on unchanged main in an isolated checkout.
5. Merge only with the user's authorization and when checks and branch protection allow it; never bypass protection. After a merge, verify the issue closed (close it if needed) and tick its parent's checklist, escaping Markdown brackets and keeping the rest of the body.
6. Delete merged branches and worktrees per the global cleanup rules, fetch and prune, and fast-forward main before the next issue. Keep branches with open PRs or unpushed commits.

Stop and report the issue and cause on a hard failure, unresolved red check, dirty checkout, blocked merge, or reached limit; do not retry blindly. Without merge authorization, keep the PR open and report the remaining queue. Dry-run changes no assignment, branch or commit.
