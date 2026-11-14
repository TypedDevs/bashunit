# Release

This is a guide to knowing the steps to create a new release.

1. Update the version in [BASHUNIT_VERSION](../bashunit)
1. Update the version in [LATEST_BASHUNIT_VERSION](../install.sh)
1. Update the version in [CHANGELOG.md](../CHANGELOG.md)
1. Update the version in [package.json](../package.json) and [docs/package.json](../docs/package.json)
1. Build the project `./build.sh bin`
    1. This will generate `bin/bashunit` and `bin/checksum`
1. Update the checksum(sha256) in [package.json](../package.json)
1. Create a [new release](https://github.com/TypedDevs/bashunit/releases/new) from GitHub
1. Attach the latest executable and checksum to the release
    1. `bin/bashunit`
    1. `bin/checksum`
    1. Keep the same name
1. Commit and push
1. Rebase `latest` branch from the newly created tag and push
    1. This will trigger "build and deploy" the docs

## Changelog archive

Keep [CHANGELOG.md](../CHANGELOG.md) focused on the current block of ten minor versions. The current block starts at 0.50.0.

Before releasing 0.60.0, move all completed releases below 0.60.0 to the top of [docs/CHANGELOG-archive.md](../docs/CHANGELOG-archive.md), below its introduction. Repeat at 0.70.0, 0.80.0, and each later multiple of ten minor versions. Start a new block for a new major version too.

Keep `Unreleased` and the new release notes in the main changelog. Move whole release sections, including patch releases, in newest-first order. Preserve their dates and comparison links, update relative links for the archive location, and update the archive introduction and current block noted here.

Prepare the archive change in a PR before running `./release.sh`.
