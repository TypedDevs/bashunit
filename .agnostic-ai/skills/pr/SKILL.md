---
name: pr
description: Push branch and create a GitHub PR with concise, issue-linked description
argument-hint: "[#issue]"
allowed-tools: shell, read, Grep, Glob
---

# Create a pull request

Use this skill for PR creation. Repository paths are relative to the repository root.

1. Inspect the current branch, `git status --short`, `git log main..HEAD --oneline`, and `git diff main..HEAD --stat`. Keep the user's edits and scope.
2. Verify `CHANGELOG.md` describes public behavior changes under `Unreleased`, with issue references where applicable. Contributor-only changes can update the existing contributor entry; do not add a self-referential changelog note for a changelog edit.
3. Complete the quality gate and commit workflow in `.agnostic-ai/AGNOSTIC_AI.md` and {{$SKILL:commit}}. Reuse passing checks for unchanged content. Do not rely on an optional Git hook being installed. Obtain the required diff review before pushing.
4. Push with `git push -u origin HEAD` when authorized. If it fails, diagnose and fix the cause; never bypass hooks or branch protection.
5. Read `.github/PULL_REQUEST_TEMPLATE.md` and follow its current headings and checklist. Use a conventional title under 70 characters. Link an actual issue with `Related #N`, never invent one. Explain the problem and resulting behavior in 1-2 background sentences and 2-4 change bullets, including concise validation. Avoid file inventories and conversational history.
6. Write the exact PR body to a temporary file; create with `gh pr create --title <title> --assignee @me --label <label> --body-file <file>`. Select one label: `bug`, `enhancement`, `documentation`, `refactor`, `ui`, or `investigation`, according to the change. Report the URL.
7. If an issue has a configured project in `.agnostic-ai/local/github-project.json`, use its actual IDs to move the issue to In Review. Do not assume project access or invent a missing configuration; report an unavailable update separately.

Respect existing publishing authorization. Creating a PR does not authorize merging it.
