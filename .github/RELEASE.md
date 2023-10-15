# Release

This is a guide to know the steps to create a new release.

1. Update the version in [BASHUNIT_VERSION](../bashunit)
2. Update the version in [CHANGELOG.md](../CHANGELOG.md)
3. Update the version in [package.json](../package.json)
4. Commit and push
5. Create a [new release](https://github.com/TypedDevs/bashunit/releases/new) from GitHub
6. Attach the latest executable to the release
    1. Generate a new bashunit with `build.sh`
    2. Attach the generated file to the release page on GitHub
    3. Keep the name `bashunit`
