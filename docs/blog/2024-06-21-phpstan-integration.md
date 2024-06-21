---
date: '2024-06-21'
title: 'PHPStan integration'
description: 'What a milestone! We finally made it into helping our friends from PHPStan. They started integrating bashunit in their end-to-end tests, which ended up creating a new feature, adding new assertions and improving multiline string comparisons.'
coverUrl: '/covers/2024-06-21-phpstan-integration.jpg'
coverAlt: 'bashunit integrated into PHPStan'

aside: false
---

# {{ $frontmatter.title }}

<time>{{ $formatDate($frontmatter.date) }}</time>

{{ $frontmatter.description }}

<img :src="$frontmatter.coverUrl" :alt="$frontmatter.coverAlt" width="100%">

Earlier this week, [PHPStan](https://phpstan.org/) started integrating `bashunit` in their **e2e tests** written in bash ([PR](https://github.com/phpstan/phpstan-src/pull/3160)).

However, they didn't want to use bashunit test runner, instead they were interested only in the **assert functions** standalone of the core library ([Issue](https://github.com/TypedDevs/bashunit/issues/257)).

> "Basically we want to use the nice assertions syntax of bashunit not to unit tests bash functions, but to end-to-end tests executables." `@ondrejmirtes`

This wasn't something that bashunit supported (yet), so `@staabm` created a [custom script](https://github.com/phpstan/phpstan-src/pull/3160#discussion_r1641646749) to allow this. That was the beginning of an intense couple of days discovering together how to implement bashunit in such a big existing system, and a motivation for us to support this feature natively from `bashunit` - which means, an optimized script and feature from within the library.

Additionally, we discovered that multiline string comparison didn't work as expected, so we fixed that. And `@staabm` helped us adding a new assert function to check the number of lines within a string.

**TL;DR**: From now on, you can run bashunit assertions standalone (without a test context) (see [docs](/standalone)), a new `assert-line-count` function ([docs](/assertions#assert-line-count)), and improved multiline-string comparison.
