---
date: '2024-06-21'
title: 'PHPStan integration'
description: 'PHPStan adopted bashunit for end-to-end tests, leading to standalone assertions, a line-count assertion and fixes for multiline string comparisons.'
coverUrl: '/covers/2024-06-21-phpstan-integration.jpg'
coverAlt: 'bashunit integrated into PHPStan'

aside: false
---

# {{ $frontmatter.title }}

<time>{{ $formatDate($frontmatter.date) }}</time>

{{ $frontmatter.description }}

<img :src="$frontmatter.coverUrl" :alt="$frontmatter.coverAlt" width="100%">

You can now run assertions [standalone](/standalone), without a test context. This release also adds [assert_line_count](/assertions#assert-line-count) and fixes multiline string comparisons.

---

Earlier this week, [PHPStan](https://phpstan.org/) started integrating `bashunit` in their **e2e tests** ([PR](https://github.com/phpstan/phpstan-src/pull/3160)).

They wanted the **assertion functions** without the bashunit test runner ([Issue](https://github.com/TypedDevs/bashunit/issues/257)).

> "Basically we want to use the nice assertions syntax of bashunit not to unit tests bash functions, but to end-to-end tests executables." `@ondrejmirtes`

bashunit did not support this, so `@staabm` created a [custom script](https://github.com/phpstan/phpstan-src/pull/3160#discussion_r1641646749). Working through that integration led us to add native support for standalone assertions.

Their [implementation](https://github.com/phpstan/phpstan-src/pull/3160/files#diff-194218c48b9a0cdd03974145733804c2d992ca818529fe2fa69a501d8b5b1cc3L197) replaces shell checks with assertions:

```diff
- [ $(echo "$OUTPUT" | wc -l) -eq 1 ]
- grep 'Method TraitsCachingIssue\\TestClassUsingTrait::doBar() should return stdClass but returns Exception.' <<< "$OUTPUT"
+ ../bashunit -a line_count 1 "$OUTPUT"
+ ../bashunit -a contains 'Method TraitsCachingIssue\TestClassUsingTrait::doBar() should return stdClass but returns Exception.' "$OUTPUT"
```

`./bashunit -a|--assert [...args]` allows you to call any [assertion](/assertions) outside the test runner, which means you can run them [standalone](/standalone).

The integration also exposed a bug in multiline string comparison, which we fixed. `@staabm` helped add an assertion to check the number of lines in a string.

These changes are available from [0.13](https://github.com/TypedDevs/bashunit/releases) onwards.
