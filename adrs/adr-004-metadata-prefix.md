# Title: Prefix metadata comments with @

* Status: accepted
* Authors: @Chemaclass
* Date: 2025-05-29


## Context and Problem Statement

Data providers are defined via a special comment `# data_provider`. We want to
clearly differentiate these meta comments from ordinary comments.

## Considered Options

* Keep using `# data_provider` as is.
* Introduce an `@` prefix for special comments while supporting the old syntax.

## Decision Outcome

We decided to prefix the metadata provider directives with `@`,
eg: using `# @data_provider provider_name`.

> The previous form without the prefix is still supported for backward compatibility but is now deprecated.

### Positive Consequences

* Highlights special bashunit directives clearly.
* Allows future directives to consistently use the `@` prefix.

### Negative Consequences

* Projects must eventually update old comments to the new syntax.

## Technical Details

`helper::get_provider_data` now matches both `# @data_provider` and the old
`# data_provider` when locating provider functions.
