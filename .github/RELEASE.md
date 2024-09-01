# Release

This is a guide to know the steps to create a new release.

1. Update the version in [BASHUNIT_VERSION](../bashunit)
1. Update the version in [CHANGELOG.md](../CHANGELOG.md)
1. Update the version in [package.json](../package.json)
1. Build the project `./build.sh bin`
    1. This will generate `bin/bashunit` and `bin/checksum`
1. Update the checksum(sha256) in [package.json](../package.json)
1. Create a [new release](https://github.com/TypedDevs/bashunit/releases/new) from GitHub
1. Attach the latest executable and checksum to the release
    1. `bin/bashunit`
    1. `bin/checksum`
    1. Keep the same name
1. Commit and push
    1. It is OK that `tests/acceptance/bashunit_upgrade_test.sh` fails
1. Rebase `latest` branch from the newly created tag and push
    1. This will trigger "build and deploy" the docs
