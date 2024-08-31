# Parameterized tests

**bashunit** offers two ways to parameterize your test functions:
- **Data providers**: offer a simple alternative for cases when the test function needs to accept only a single word as an argument.
- **Multi-invokers**: are a flexible option, as they allow passing multiple arguments to the test function and permit arguments containing whitespace.

---

Both of these are specified using a special comment before the test function declaration. The comment specifies the name of a separate auxiliary bash function which **bashunit** will invoke prior to the test. This auxiliary function will determine how many times the test function will be invoked, and what arguments will be passed to the test function each time.

The benefit of this is that each of these invocations is a full test itself, and can succeed or fail independently of the other tests. Also, [set_up](/test-files#set-up-function) and [tear_down](/test-files#tear-down-function) are called before and after each invocation of the test function. Using these tools can often result in less code repetition in your test files, and a clearer way to develop a suite of closely related tests quickly.

:::tip
The same multi-invoker or data provider function can be specified for multiple tests. This allows developing tests for related tools quickly. For example, if you had a tool that creates directories and another which removes directories, you could write one test for each tool and parameterize them to operate on the same set of directories.
:::

## Data providers

A data provider function is specified as follows:

::: code-group
```bash [Example]
# data_provider provider_function_name
function test_my_test_case() {
  ...
}
```
:::

The provider function can return a space-separated list of values like `one two three` or a single value `one`. In case of a list of values, the test function will be invoked multiple times, each time being passed a different value from the list.

::: code-group
```bash [Example]
function provider_directories() {
  local directories=("/usr" "/etc" "/var")
  echo "${directories[@]}"
}

# data_provider provider_directories
function test_directory_exists_from_data_provider() {
  local directory=$1

  assert_directory_exists "$directory"
}
```
:::

In this example, the `provider_directories` function will be executed before running the test. **bashunit** will iterate the list of simple strings provided by this function, and the test function will be executed passing each time the current iteration value as the first argument.

## Multi-invokers

A multi-invoker function is specified as follows:

::: code-group
```bash [Example]
# multi_invoker invoker_function_name
function test_my_test_case() {
  ...
}
```
:::

The invoker function should call the special function `run_test`, passing any arbitrary arguments to that function. **bashunit** will invoke the original test function each time `run_test` is called, passing the corresponding arguments.

::: code-group
```bash [Example]
function invoker_with_args() {
  run_test arg1 arg2
  run_test "arg1 with spaces" "arg2 with more spaces" "and even arg3"
}

# multi_invoker invoker_with_args
function test_command_with_args() {
  command_we_want_to_test "$@"

  assert_exit_code "0"
}
```
:::

In this example, the `invoker_with_args` will be executed instead of invoking `test_command_with_args` directly. Each time `invoker_with_args` calls `run_test` with some arguments, **bashunit** will call the original test function with those arguments. In this case the test simply verifies that `command_we_want_to_test` can accept these arguments without raising an error, but it could also verify other behaviors of the command. In this next example, we test that a `mkdir_command` we are developing can create a new directory with specified octal permissions.

::: code-group
```bash [Example]
function invoker_for_mkdir() {
  run_test /tmp/dirA 755
  run_test "/tmp/private dir" 700
}

# multi_invoker invoker_with_args
function test_command_with_args() {
  local directory="$1"
  local perms="$2"

  assert_directory_not_exists "$directory"
  mkdir_command "${directory}" --perms "${perms}"
  assert_directory_exists "$directory"
  assert_equals "$perm" "$(stat --format %a "$directory")
}
```
:::
