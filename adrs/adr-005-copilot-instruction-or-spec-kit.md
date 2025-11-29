# Choose Copilot Custom Instructions over Spec Kit for bashunit

* Status: proposed
* Deciders: @khru
* Date: 2025-09-17

Technical Story: We need a lightweight, high leverage AI assist that improves contribution quality and speed without adding process overhead to a small Bash library.

## Context and Problem Statement

bashunit is a compact open source Bash testing library. We want AI assistance that nudges contributors toward consistent style, portability, and test structure. Two candidates exist: GitHub Copilot Custom Instructions and GitHub Spec Kit. Which approach best fits bashunit’s size and workflow?

## Decision Drivers

* Keep contributor workflow simple and fast
* Enforce consistent Bash and test conventions with minimal tooling
* Reduce review friction and style nitpicks
* Avoid heavy bootstrapping or new runtime dependencies
* Leave room to explore structured specs later if needed

## Considered Options

* Copilot Custom Instructions at repository scope
* Spec Kit as the core workflow
* Hybrid approach: Copilot now, Spec Kit only for large initiatives

## Decision Outcome

Chosen option: "Copilot Custom Instructions at repository scope", because it delivers immediate guidance in Chat, coding agent, and code review with near zero overhead, matches bashunit’s scale, and supports path specific rules for Bash and docs. Spec Kit is valuable for multi phase feature work but introduces extra setup and process that bashunit does not currently need.

### Positive Consequences

* Faster, more consistent PRs with fewer style and portability fixes
* Guidance lives in the repo, visible and versioned with code
* Path specific rules help tailor guidance for `lib/`, `tests/`, and docs

### Negative Consequences

* Possible conflicts with personal or organization instructions, require clear precedence awareness
* Preview features in Copilot instructions can change, we must monitor docs

## Pros and Cons of the Options

### Copilot Custom Instructions at repository scope

* Good, because setup is trivial, just add `.github/copilot-instructions.md` and optional `.github/instructions/*.instructions.md`
* Good, because guidance is applied in Chat, coding agent, and code review where contributors already work
* Good, because path based `applyTo` rules let us enforce Bash portability and test naming in specific folders
* Bad, because it is not a full specification or planning framework if we ever need complex multi step delivery

### Spec Kit as the core workflow

* Good, because it structures specs, plans, and tasks for complex features and parallel exploration
* Good, because it can coordinate with multiple agents and make specifications executable
* Bad, because it adds Python and `uv` dependencies plus a new CLI and multi step process
* Bad, because that overhead is unnecessary for a small Bash library with simple APIs and docs

### Hybrid approach

* Good, because we keep the repo light while reserving Spec Kit for large, time boxed initiatives
* Good, because it lets us validate Spec Kit on a real feature without changing the whole workflow
* Bad, because it introduces two patterns to maintain if used frequently
* Bad, because contributors may be unsure when to use which process without clear guidance

## Links

* Spec Kit repository: [https://github.com/github/spec-kit](https://github.com/github/spec-kit)
* Spec Kit blog overview: [https://github.blog/ai-and-ml/generative-ai/spec-driven-development-with-ai-get-started-with-a-new-open-source-toolkit/](https://github.blog/ai-and-ml/generative-ai/spec-driven-development-with-ai-get-started-with-a-new-open-source-toolkit/)
* Copilot repository instructions: [https://docs.github.com/es/copilot/how-tos/configure-custom-instructions/add-repository-instructions](https://docs.github.com/es/copilot/how-tos/configure-custom-instructions/add-repository-instructions)
* Copilot personal instructions: [https://docs.github.com/es/copilot/how-tos/configure-custom-instructions/add-personal-instructions](https://docs.github.com/es/copilot/how-tos/configure-custom-instructions/add-personal-instructions)
* Copilot organization instructions: [https://docs.github.com/es/copilot/how-tos/configure-custom-instructions/add-organization-instructions](https://docs.github.com/es/copilot/how-tos/configure-custom-instructions/add-organization-instructions)
