# Release

This is a guide to know the steps to create a new release.

1. Create a new commit updating the [CHANGELOG.md](../CHANGELOG.md) and  [package.json](../package.json) using the new tag version.
2. Create a [new release](https://github.com/TypedDevs/bashunit/releases/new) from GitHub.
3. Attach the latest executable to the release
    1. Generate a new bashunit with `install.sh`
    2. Attach the generated file to the release page on GitHub
    3. Keep the name `bashunit`
