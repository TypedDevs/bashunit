# Title: Using native bash booleans

* Status: accepted
* Authors: @Chemaclass
* Date: 2024-10-03

Technical Story:
    - Pull Request: [TypedDevs/bashunit#345](https://github.com/TypedDevs/bashunit/pull/345#discussion_r1782226289)

## Context and Problem Statement

We are using booleans with different syntax in different parts of the project.

## Considered Options

* Use true and false as strings
* Use true and false as native programs
* Use true and false as 0,1 native shell booleans

## Decision Outcome

To keep consistency in the project, we want to use the standard and best practices of booleans
within shell scripting which is `0:true`, `1:false`

### Positive Consequences

We keep the native shell boolean syntax.

### Negative Consequences

For devs without experience in bash it might be odd at the beginning, but one cat get use to it.
