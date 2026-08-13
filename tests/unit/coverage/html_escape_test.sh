#!/usr/bin/env bash

# The HTML report escapes every source line it prints. It used to do that with
# a command substitution and a sed PER LINE -- about 22,000 processes for this
# repo, 58.7s of report (#1096) -- and now does it once per file. The two must
# produce the same bytes, or the report silently renders markup as markup.
#
# Escaping in pure Bash is not an option here, and the failure is silent both
# ways: Bash 5.2 made a bare `&` in a substitution REPLACEMENT mean "the
# matched text", so `${line//</&lt;}` yields `<lt;` on 5.2+, while writing it
# as `\&` for 5.2 emits a literal backslash on 3.2. These tests pin the output
# itself, so either mistake fails here rather than in a rendered page.

function fixture_with() { # $@ = lines
  local file
  file="$(bashunit::temp_file html_escape).txt"
  printf '%s\n' "$@" >"$file"
  echo "$file"
}

function test_the_whole_file_escaper_matches_the_per_line_one() {
  local file
  file="$(fixture_with \
    'a & b' \
    '<div class="x">' \
    'x > y && z' \
    'if [ "$a" -lt "$b" ]; then' \
    'printf "%s\n" "<tag>"' \
    '&amp; already escaped' \
    'back\slash <tag>' \
    'no specials here')"

  local expected=""
  local line
  while IFS= read -r line || [ -n "$line" ]; do
    expected="${expected}$(bashunit::coverage::html_escape "$line")
"
  done <"$file"

  assert_same "$expected" "$(bashunit::coverage::html_escape_file "$file")
"
}

# The three substitutions, spelled out. `<` must become `&lt;` and not `<lt;`,
# which is what a bare `&` in a Bash 5.2 replacement would produce.
function test_the_ampersand_is_not_a_backreference() {
  local file
  file="$(fixture_with '<a href="x">A & B</a>' 'x > y')"

  assert_same '&lt;a href="x"&gt;A &amp; B&lt;/a&gt;
x &gt; y' "$(bashunit::coverage::html_escape_file "$file")"
}

# `&` has to be replaced before `<` and `>`, or the `&` of an already-emitted
# `&lt;` gets escaped again into `&amp;lt;`.
function test_the_ampersand_is_replaced_before_the_angle_brackets() {
  local file
  file="$(fixture_with '<x>')"

  assert_same '&lt;x&gt;' "$(bashunit::coverage::html_escape_file "$file")"
}

function test_an_empty_line_stays_an_empty_line() {
  local file
  file="$(fixture_with 'a' '' 'b')"

  assert_same 'a

b' "$(bashunit::coverage::html_escape_file "$file")"
}
