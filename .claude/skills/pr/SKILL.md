---
name: pr
description: Push branch and create a GitHub PR with concise, issue-linked description
user-invocable: true
argument-hint: "[#issue]"
disable-model-invocation: true
allowed-tools: Bash, Read, Grep, Glob
---

# Create Pull Request

Push branch and create a PR with a concise, issue-linked description.

## Current Branch Context
- Branch: !`git branch --show-current`
- Commits: !`git log main..HEAD --oneline 2>/dev/null`
- Changed files: !`git diff main..HEAD --stat 2>/dev/null`

## Arguments
- `$ARGUMENTS` - Issue reference (optional, e.g., `#42` or `42`). If provided, the PR will be linked to this issue.

## Instructions

1. **Review the branch context above** — the commits and changed files are already loaded.

2. **Check CHANGELOG.md** — if it wasn't updated for these changes, update it now and commit:
  ```bash
  git add CHANGELOG.md && git commit -m "docs: update changelog"
  ```

3. **Push branch**:
  ```bash
  git push -u origin HEAD
  ```
  - The `pre-push` git hook automatically runs the full test suite (BE & FE in parallel).
  - If the hook fails, read the output, fix the issue, commit the fix, and retry the push. Do NOT use `--no-verify` to bypass.

4. **Generate PR title**:
  - If `$ARGUMENTS` contains an issue number, fetch the issue title:
    ```bash
    gh issue view <number> --json title -q '.title'
    ```
  - PR title format: `<type>(<scope>): <short description>` (conventional commit style, under 70 chars)
  - Derive the type from the branch prefix (`feat/` → feat, `fix/` → fix, `docs/` → docs)

5. **Create PR** using the template from `.github/PULL_REQUEST_TEMPLATE.md`:
  ```bash
  gh pr create --title "<title>" --assignee @me --label "<label>" --body "$(cat <<'EOF'
  ## 🤔 Background

  Related #<issue-number>

  <1-2 sentences: motivation and context for the changes>

  ## 💡 Changes

  - <bullet 1: what changed and why>
  - <bullet 2>
  - <bullet 3> (optional)
  - <bullet 4> (optional)
  EOF
  )"
  ```

  **MANDATORY:** Always follow the PR template structure (`## 🤔 Background` + `## 💡 Changes`). Never use a different format.

  **Assignee:** Always assign to `@me` (the PR creator).

  **Labels:** Add the single most relevant label based on the branch prefix and change context:
  - `bug` — branch starts with `fix/` and addresses a defect
  - `enhancement` — branch starts with `feat/` or adds new functionality
  - `documentation` — branch starts with `docs/` or only changes docs
  - `refactor` — code restructuring with no behavior change
  - `ui` — visual/frontend-only changes
  - `investigation` — spikes, research, or exploratory work

  **Body guidelines:**
  - **Background**: Link the issue with `Related #<number>`, then 1-2 sentences of context. **NEVER use `Closes` or `Fixes`.**
  - **Changes**: 2-4 short bullet points. Focus on *what* and *why*, not implementation details.
  - **No file lists, no class names, no code snippets** in the body.
  - Keep the entire body under 15 lines.

6. **Move issue to "In Review"** in GitHub Project (if issue number provided):
  ```bash
  # Read project config from .claude/github-project.json
  ITEM_ID=$(gh project item-list PROJECT_NUMBER --owner OWNER --format json \
    | jq -r '.items[] | select(.content.number == ISSUE_NUMBER) | .id')

  gh project item-edit \
    --id "$ITEM_ID" \
    --project-id "PROJECT_ID" \
    --field-id "STATUS_FIELD_ID" \
    --single-select-option-id "IN_REVIEW_OPTION_ID"
  ```

  **Note:** Requires `project` scope. Run `gh auth refresh -s project` if needed.

7. **Report the PR URL** to the user.

## Example Usage

```
/pr
/pr #42
/pr 15
```
