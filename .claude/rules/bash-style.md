---
paths:
  - "src/**/*.sh"
  - "tests/**/*.sh"
---

# Bash Style & Compatibility Rules

## Bash 3.0+ Compatibility (Critical)

bashunit must work on **Bash 3.0+** (macOS default). These features are **prohibited**:

### ❌ Forbidden Features

**Associative arrays** (Bash 4.0+):
```bash
# ❌ DON'T
declare -A map
map["key"]="value"

# ✅ DO - Use indexed arrays or workarounds
declare -a keys=("key1" "key2")
declare -a values=("val1" "val2")
```

**`[[` test operator** - Use `[` instead:
```bash
# ❌ DON'T
if [[ "$var" == "value" ]]; then

# ✅ DO
if [ "$var" = "value" ]; then
```

**Case conversion** (`${var,,}`, `${var^^}`):
```bash
# ❌ DON'T
lowercase="${var,,}"

# ✅ DO
lowercase=$(echo "$var" | tr '[:upper:]' '[:lower:]')
```

**Negative array indexing** (`${array[-1]}`):
```bash
# ❌ DON'T
last="${array[-1]}"

# ✅ DO
last="${array[${#array[@]}-1]}"
```

**`&>>` redirect** (Bash 4.0+):
```bash
# ❌ DON'T
command &>> file

# ✅ DO
command >> file 2>&1
```

## Coding Style

Follow [Google Shell Style Guide](https://google.github.io/styleguide/shellguide.html) with these specifics:

### Indentation & Formatting

- **2 spaces** (no tabs)
- Use `shfmt -w .` to format
- Maximum line length: 120 characters (soft limit)

### Function Naming

**Namespace all public functions:**
```bash
# ✅ Public functions
function bashunit::assert_equals() { ... }
function bashunit::mock() { ... }

# ✅ Private/internal functions (leading underscore)
function _internal_helper() { ... }
```

### Variable Naming

```bash
# ✅ Local variables - lowercase with underscores
local test_name="example"
local file_path="/path/to/file"

# ✅ Global/exported - uppercase
export BASHUNIT_LOG_JUNIT="false"
readonly BASHUNIT_VERSION="0.32.0"

# ✅ Function parameters - clear names
function process_file() {
  local input_file="$1"
  local output_dir="${2:-./output}"
}
```

### Quoting

**Always quote variables** unless you explicitly need word splitting:

```bash
# ✅ DO
echo "$variable"
[[ -f "$file_path" ]]
command --arg="$value"

# ❌ DON'T (unless intentional word splitting)
echo $variable
[[ -f $file_path ]]
```

### Error Handling

Use `set -euo pipefail` judiciously:

```bash
# ✅ In scripts
#!/usr/bin/env bash
set -euo pipefail

# ⚠️ In functions - be cautious
# Don't use in functions that expect to handle failures
function might_fail() {
  local result
  result=$(command_that_might_fail) || return 1
  echo "$result"
}
```

### Function Documentation

Document all public functions:

```bash
##
# Brief description of what the function does
#
# Arguments:
#   $1 - First parameter description
#   $2 - Second parameter description (optional, default: "value")
#
# Returns:
#   0 on success
#   1 on validation failure
#   2 on execution error
#
# Example:
#   bashunit::my_function "input" "optional"
##
function bashunit::my_function() {
  local required="$1"
  local optional="${2:-default}"

  # Implementation
}
```

## ShellCheck Compliance

All code must pass ShellCheck:

```bash
make sa
# or
shellcheck -x $(find . -name "*.sh")
```

**Common directives:**

```bash
# Disable specific check with reason
# shellcheck disable=SC2034  # Variable appears unused
local unused_var="value"

# Source external file for shellcheck
# shellcheck source=src/assertions.sh
source "$(dirname "${BASH_SOURCE[0]}")/assertions.sh"
```

## Portability

### Path Handling

```bash
# ✅ Use BASH_SOURCE for relative paths
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ✅ Use dirname/basename
parent_dir="$(dirname "$file_path")"
filename="$(basename "$file_path")"
```

### Command Substitution

```bash
# ✅ Use $() instead of backticks
result=$(command arg1 arg2)

# ❌ DON'T
result=`command arg1 arg2`
```

### Temporary Files

```bash
# ✅ Use bashunit globals
echo "content" > "$temp_file"
mkdir -p "$temp_dir"

# ⚠️ If creating manually, ensure cleanup
cleanup() {
  rm -rf "$temp_file"
}
trap cleanup EXIT
```

## Performance Considerations

### Avoid Subshells When Possible

```bash
# ✅ Better
local count=0
while read -r line; do
  ((count++))
done < file

# ⚠️ Slower (creates subshell)
local count
count=$(wc -l < file)
```

### Use Built-ins Over External Commands

```bash
# ✅ Built-in
[[ -f "$file" ]] && echo "exists"

# ⚠️ External command (slower)
test -f "$file" && echo "exists"
```

## Code Organization

### File Structure

```bash
#!/usr/bin/env bash
# Brief file description

# Constants
readonly CONSTANT_VALUE="value"

# Global variables
declare -g global_var=""

# Private functions
function _private_helper() { ... }

# Public functions
function bashunit::public_function() { ... }
```

### Sourcing Dependencies

```bash
# ✅ Relative to script location
source "$(dirname "${BASH_SOURCE[0]}")/dependency.sh"

# ✅ With error checking
if [[ ! -f "$dependency_path" ]]; then
  echo "Error: Cannot find dependency" >&2
  return 1
fi
source "$dependency_path"
```

## Security

### Input Validation

```bash
# ✅ Validate inputs
function process_user_input() {
  local input="$1"

  if [[ -z "$input" ]]; then
    echo "Error: Input required" >&2
    return 1
  fi

  # Process sanitized input
}
```

### Safe File Operations

```bash
# ✅ Check before operations
if [[ -w "$file" ]]; then
  echo "data" > "$file"
fi

# ✅ Use -- to prevent flag injection
rm -- "$user_provided_file"
```

## Anti-Patterns to Avoid

❌ **Global state without cleanup**
❌ **Unquoted variables**
❌ **Ignoring command failures silently**
❌ **Using eval without sanitization**
❌ **Hardcoded paths** (use relative or configurable)
❌ **Functions > 50 lines** (refactor into smaller pieces)
❌ **Deep nesting** (> 3 levels, extract functions)

## Validation

Before committing:
```bash
make sa          # ShellCheck
make lint        # EditorConfig
shfmt -w .       # Format
./bashunit tests/  # All tests pass
```
