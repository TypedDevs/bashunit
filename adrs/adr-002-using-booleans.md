# Title: Using native bash booleans

* Status: accepted
* Authors: @Chemaclass
* Date: 2024-10-03

Technical Story:
    - Pull Request: [TypedDevs/bashunit#345](https://github.com/TypedDevs/bashunit/pull/345#discussion_r1782226289)

## Context and Problem Statement

We are using booleans with different syntax in different parts of the project.

## Considered Options

* Use true and false as `0`, `1` native shell booleans
* Use true and false as strings: `"true"`, `"false"`
* Use true and false as native programs: `true`, `false`

## Decision Outcome

To keep consistency in the project, we want to use the standard and best practices of booleans while
keeping a great DX.

When using return, we must use a number:
- `return 0` # for success
- `return 1` # for failure

When using variables, we must use `true` and `false` as commands (not strings!):
- `true` is a command that always returns a successful exit code (0)
- `false` is a command that always returns a failure exit code (1)

When possible, extract a condition into a function. For example:
```bash
function env::is_show_header_enabled() {
    # this is a string comparison because it is coming from the .env
    [[ "$BASHUNIT_SHOW_HEADER" == "true" ]]
}
```
Usage
```bash
if env::is_show_header_enabled; then
    # ...
fi
```

### Positive Consequences

We keep the native shell boolean syntax in conditions.

### Negative Consequences

Not that I am aware of.
