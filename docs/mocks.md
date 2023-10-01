# Mocks

When creating tests, you might need to override existing function to be able to write isolated tests from external behaviour. To accomplish this, you can use mocks. You can also check that a function was called with certain arguments or even a number of times with a spy.

## mock
> `mock "function" "body"`

Override the behaviour of a function

*Example:*
```bash
function test_success() {
  mock ps echo hello world
  assert_equals "hello world" "$(ps)"
}
```

## spy
> `spy "function"

Override the behaviour of a function

*Example:*
```bash
function test_success_spy_call_with() {
  spy ps
  ps a_random_parameter_1 a_random_parameter_2

  assert_have_been_called_with "a_random_parameter_1 a_random_parameter_2" ps
  assert_have_been_called ps
}

function test_success_spy_called_times() {
  spy ps

  ps
  ps

  assert_have_been_called_times 2 ps
}
```
