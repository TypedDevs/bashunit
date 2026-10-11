# Formatting

Match the surrounding 2-space style by hand and verify with `make lint`. There is
no `shfmt` target, and **`shfmt -w .` must not be run**, it fights `.editorconfig`
two ways:

- `.editorconfig` sets `indent_size = unset` for `tests/acceptance/**.sh` and
  `src/console/header.sh`; shfmt reads `unset` as "use my default", which is tabs,
  while `[*]` sets `indent_style = space`. Any new file under `tests/acceptance/`
  therefore shows up shfmt-dirty, that is expected, not a defect.
- shfmt collapses `\`-continued strings onto one line, which would push
  the payload record writers past `max_line_length = 120`.

To check you introduced no new drift, compare the dirty-file *list* against main
rather than requiring it to be empty:

```bash
git ls-files -z '*.sh' bashunit | xargs -0 shfmt -d 2>/dev/null \
  | grep '^--- ' | sed 's|--- ||; s|\.orig.*||' | sort
```
