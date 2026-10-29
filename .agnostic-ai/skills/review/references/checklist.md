# Review checks

Trace changed behavior through callers and tests. Verify failure paths and the requested outcome, Bash 3.0 parsing, dynamic scope, subshell state, worker isolation, cleanup, and hot-path process costs. Prefer `[ ]` for ordinary tests; `[[ ]]` is supported on Bash 3.0 and is not a compatibility defect.

Preserve public behavior unless the task changes it; require docs and CHANGELOG for user-visible changes. For spec changes verify clean-clone generation, canonical references, model resolution, and preserved native behavior.

Stay read-only. Do not run full suites or post without authorization. Report verified defects only, most severe first: file:line, severity, failing input, smallest fix. If none remain, state the scope checked.
