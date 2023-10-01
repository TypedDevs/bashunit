# Test doubles

When creating tests, you might need to override existing function to be able to write isolated tests from external behaviour. To accomplish this, you can use mocks. You can also check that a function was called with certain arguments or even a number of times with a spy.

## mock
> `mock "function" "body"`

Override the behaviour of a function.

*Example:*
```bash
function test_success() {
  mock ps echo hello world

  assert_equals "hello world" "$(ps)"
}
```

## spy
> `spy "function"`

Spies are mocks that record some information based on how they were called.

*Example:*
```bash
function test_success_spy_call_with() {
  spy ps
  ps a_random_parameter_1 a_random_parameter_2

  assert_have_been_called_with "a_random_parameter_1 a_random_parameter_2" ps
  assert_have_been_called ps
}
```

### assert_have_been_called
> `assert_have_been_called ["a spy"]`

Informs you if the `spy` has been called at least once.

*Example:*
```bash
function test_that_spy_has_been_called() {
  spy ps

  assert_have_been_called ps
}
```

### assert_have_been_called_with
> `assert_have_been_called_with ["arguments"] ["a spy"]`

Informs you if the `spy` has been called with the arguments passed.

*Example:*
```bash
function test_that_spy_has_been_called_with() {
  spy ps
  ps foo bar

  assert_have_been_called_with "foo bar" ps
}
```

### assert_have_been_called_times
> assert_have_been_called_times [a spy]

Informs you if the `spy` has been called a certain amount of times.

*Example:*
```bash
function test_that_spy_has_been_called_times() {
  spy ps

  ps
  ps

  assert_have_been_called_times 2 ps
}
```
