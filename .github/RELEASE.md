# Release

This is a guide to know the steps to create a new release.

1. Update the version in [BASHUNIT_VERSION](../bashunit)
1. Update the version in [CHANGELOG.md](../CHANGELOG.md)
1. Update the version in [package.json](../package.json)
1. Create a [new release](https://github.com/TypedDevs/bashunit/releases/new) from GitHub
1. Attach the latest executable to the release
    1. Generate a new bashunit with `build.sh`
    1. Attach the generated file to the release page on GitHub
    1. Keep the name `bashunit`
1. Attach the sha256sum for that executable as a new file `checksum`
1. Commit and push
1. Rebase `latest` branch from the new created tag and push
    1. This will trigger "build and deploy" the docs
