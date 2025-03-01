<a href="https://flotiq.com/">
    <img src="https://editor.flotiq.com/fonts/fq-logo.svg" alt="Flotiq logo" title="Flotiq" align="right" height="60" />
</a>

Check changelog and version action
===========================

This repository contains reusable action for checking whether the changelog and version was updated on pull request

Example usage, put below code into `changelog.yml` in `.github/workflows` directory:

```
name: Check Changelog and Version

on:
  pull_request:
    branches:
      - master
      - main

jobs:
  check-changelog:
    runs-on: ubuntu-latest
    env:
      CI_MERGE_REQUEST_SOURCE_BRANCH_NAME: ${{ github.event.pull_request.head.ref }}
      CI_MERGE_REQUEST_TARGET_BRANCH_NAME: ${{ github.event.pull_request.base.ref }}
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 100
      - uses: flotiq/check-changelog-and-version
        with:
          changelog_file: CHANGELOG.md
          version_file: package.json
```


## Collaborating

If you wish to talk with us about this project, feel free to hop on our [![Discord Chat](https://img.shields.io/discord/682699728454025410.svg)](https://discord.gg/FwXcHnX).

If you found a bug, please report it in [issues](https://github.com/flotiq/check-changelog-and-version/issues).