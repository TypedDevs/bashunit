# Release

This is a guide to know the steps to create a new release.

1. Update the version in [BASHUNIT_VERSION](../bashunit)
2. Update the version in [LATEST_BASHUNIT_VERSION](../install.sh)
3. Update the version in [CHANGELOG.md](../CHANGELOG.md)
4. Update the version in [package.json](../package.json)
5. Commit and push
6. Create a [new release](https://github.com/TypedDevs/bashunit/releases/new) from GitHub
7. Attach the latest executable to the release
    1. Generate a new bashunit with `build.sh`
    2. Attach the generated file to the release page on GitHub
    3. Keep the name `bashunit`
8. Rebase `latest` branch from the new created tag and push
    1. This will trigger "build and deploy" the docs
