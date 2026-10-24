---
name: review
description: Review a GitHub pull request; defaults to the current branch's PR when no number is given
argument-hint: "[#N]"
allowed-tools: shell, read, Grep, Glob
---

# Review a pull request

Resolve the supplied PR number or the current branch's PR with `gh pr view`. If neither identifies one, list open PRs and request a selection. For an uncommitted diff, use `code-reviewer` instead.

Read `gh pr view <number> --json number,title,body,state,headRefName,baseRefName,url` and `gh pr diff <number>`. Follow the applicable source rules in `.agnostic-ai/AGNOSTIC_AI.md`.

- Verify changed behavior, failure paths, Bash compatibility, dynamic scope, subshell state, parallel isolation and cleanup. Prefer `[ ]` for ordinary tests; `[[ ]]` works on Bash 3.0 and is not a compatibility defect.
- Check tests exercise the failure and the requested outcome. Respect process budgets and public behavior; require changelog and documentation where needed.
- For specs, check canonical sources, generated references, model resolution and preserved target behavior.
- Review read-only. Do not run the full gate, edit files, or post comments without authorization.

Report only verified defects, most severe first: `path:line, severity, failing input, smallest fix`. Do not add style nits or speculate. If none remain, say so and name the scope checked.
