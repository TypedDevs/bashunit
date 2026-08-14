#!/usr/bin/env bash

# Error messages that tell the reader what to run are the one place a wrong
# name costs the most: the message exists precisely because the reader is
# already stuck. Two shipped this year naming something that does not exist --
# `install.sh` advised a `-d` flag it never had (#1221), and the mock/spy
# refusal advised a bare `mock`, which is `command not found` (#1229).
#
# Both were string-matched by tests and neither was executed, so the scan here
# is static and deliberately narrow: every `bashunit::`-namespaced identifier
# that appears inside a *printed* string must be a function this tree defines.
# It cannot prove advice is good, but it does catch the rename that turns
# working advice into a dead name -- and that is the failure mode a test cannot
# notice, because the message still renders fine.

function set_up_before_script() {
  ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
}

# Identifiers named inside a double-quoted string on a non-comment line.
#
# Anchoring on the printing statement itself (`printf`, `fail_with`, …) was
# tried first and misses the case that matters: `fail_with` spans lines, and
# the spy advice -- the exact shape of #1229 -- sits on the continuation. So
# the rule is "quoted, and not a comment"; comments are excluded because src/
# is full of docstrings naming helpers, and prose is not advice.
#
# The character class includes digits: without them `decode_base64` truncates
# to `decode_base` and reports a name nothing defines.
function _advised_identifiers() { # $1 = dir to scan
  "$GREP" -rhE '^[^#]*"[^"]*bashunit::[a-z0-9_:]+' "$1" |
    "$GREP" -oE 'bashunit::[a-z0-9_:]+' | sort -u
}

# Those of them this tree does not define. Both definition styles count:
# `bashunit::sgr()` is written without the `function` keyword, and requiring it
# reported that one as missing -- the same trap as #1215.
function _undefined_advised_identifiers() { # $1 = dir to scan
  local fn
  while IFS= read -r fn; do
    [ -z "$fn" ] && continue
    if ! "$GREP" -rqE "^(function )?${fn}\(\)" "$1"; then
      printf '%s\n' "$fn"
    fi
  done <<EOF
$(_advised_identifiers "$1")
EOF
}

function test_every_helper_named_in_a_printed_message_exists() {
  local undefined
  undefined=$(_undefined_advised_identifiers "$ROOT_DIR/src")

  assert_empty "$undefined"
}

# A scan that cannot fail proves nothing: src/ is expected to be clean, so
# without this the check above would keep passing if the extraction silently
# stopped matching.
function test_the_scan_flags_a_message_naming_a_helper_that_does_not_exist() {
  local dir
  dir="$(bashunit::temp_dir)"
  {
    printf '%s\n' '#!/usr/bin/env bash'
    printf '%s\n' 'function bashunit::probe::real() { :; }'
    printf '%s\n' 'function bashunit::probe::advise() {'
    printf '%s\n' '  printf "call it first with %s\\n" "bashunit::probe::gone"'
    printf '%s\n' '}'
  } >"$dir/probe.sh"

  assert_same "bashunit::probe::gone" "$(_undefined_advised_identifiers "$dir")"
}

# And must not flag one that is defined, or the check above would be noise.
function test_the_scan_ignores_a_message_naming_a_helper_that_exists() {
  local dir
  dir="$(bashunit::temp_dir)"
  {
    printf '%s\n' '#!/usr/bin/env bash'
    printf '%s\n' 'function bashunit::probe::real() { :; }'
    printf '%s\n' 'function bashunit::probe::advise() {'
    printf '%s\n' '  printf "call it first with %s\\n" "bashunit::probe::real"'
    printf '%s\n' '}'
  } >"$dir/probe.sh"

  assert_empty "$(_undefined_advised_identifiers "$dir")"
}

# A helper named only in a comment or docstring is prose, not advice: flagging
# those would make the check fire on every renamed internal and get switched off.
function test_the_scan_ignores_a_helper_named_only_in_a_comment() {
  local dir
  dir="$(bashunit::temp_dir)"
  {
    printf '%s\n' '#!/usr/bin/env bash'
    printf '%s\n' '# See bashunit::probe::documented_elsewhere for the rationale.'
    printf '%s\n' 'function bashunit::probe::real() { :; }'
  } >"$dir/probe.sh"

  assert_empty "$(_undefined_advised_identifiers "$dir")"
}

# The advice this check exists for is written on a continuation line, below the
# call that prints it. Anchoring the scan on the printing statement passed the
# whole suite while seeing none of those -- including the one from #1229.
function test_the_scan_reaches_advice_on_a_continuation_line() {
  local dir
  dir="$(bashunit::temp_dir)"
  {
    printf '%s\n' '#!/usr/bin/env bash'
    printf '%s\n' 'function bashunit::probe::advise() {'
    # Double-quoted so the trailing backslash is a real line continuation in
    # the fixture rather than a quoted-escape ShellCheck flags (SC1003).
    printf '%s\n' "  bashunit::assert::fail_with \"\" \"\$1\" \\"
    printf '%s\n' '    "was never registered; call it first with" "bashunit::probe::gone"'
    printf '%s\n' '}'
  } >"$dir/probe.sh"

  assert_same "bashunit::probe::gone" "$(_undefined_advised_identifiers "$dir")"
}

# A name carrying digits must survive extraction intact.
function test_the_scan_keeps_digits_in_a_helper_name() {
  local dir
  dir="$(bashunit::temp_dir)"
  {
    printf '%s\n' '#!/usr/bin/env bash'
    printf '%s\n' 'function bashunit::probe::decode_base64() { :; }'
    printf '%s\n' 'function bashunit::probe::advise() {'
    printf '%s\n' '  printf "use %s\\n" "bashunit::probe::decode_base64"'
    printf '%s\n' '}'
  } >"$dir/probe.sh"

  assert_empty "$(_undefined_advised_identifiers "$dir")"
}

# And a helper defined without the `function` keyword is still defined.
function test_the_scan_accepts_a_definition_without_the_function_keyword() {
  local dir
  dir="$(bashunit::temp_dir)"
  {
    printf '%s\n' '#!/usr/bin/env bash'
    printf '%s\n' 'bashunit::probe::bare() { :; }'
    printf '%s\n' 'function bashunit::probe::advise() {'
    printf '%s\n' '  printf "use %s\\n" "bashunit::probe::bare"'
    printf '%s\n' '}'
  } >"$dir/probe.sh"

  assert_empty "$(_undefined_advised_identifiers "$dir")"
}
