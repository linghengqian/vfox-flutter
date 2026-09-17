# OpenHarmony builds

Third-party OpenHarmony Flutter releases from [gitcode.com](https://gitcode.com/CPF-Flutter/flutter_flutter/releases)
are also available, for example:

```bash
vfox install flutter@3.41.10-ohos-1.0.0
```

These are source archives that need `git` and a no-checksum download, so they
behave differently from official releases.

## Install

```bash
vfox install flutter@3.41.10-ohos-1.0.0
vfox use --global flutter@3.41.10-ohos-1.0.0
```

The known versions are `3.41.10-ohos-1.0.0`, `3.35.8-ohos-1.0.3`, and
`3.27.5-ohos-1.0.7`. Run `vfox search flutter` or check the release page above for
the full list.

OpenHarmony versions are listed after the official releases, so `@latest` and the
`stable`/`beta`/`dev` channels never select one. They must be installed by exact
version.

## How these builds differ

- **`git` is required.** gitcode.com serves plain source trees without a `.git`
  directory, and the Flutter tool refuses to run outside a git checkout. After
  extracting the archive, the plugin initializes a local repository, commits the
  pinned engine versions, and tags it with the version. Committing the version
  files is what stops the toolchain from falling back to content-aware hash
  resolution against git history. No git identity is written to your global
  config.
- **They are source, not prebuilt SDKs.** On first use the Flutter tool builds
  itself and downloads the Dart SDK and engine artifacts from Huawei's OBS, so
  the first `flutter` command needs a network connection and takes longer than
  an official release.
- **No checksum is verified.** gitcode.com does not publish archive checksums, so
  vfox skips verification with a warning. This is a third-party fork; review its
  source before trusting it.
- **No architecture variants.** Each version is a single architecture-independent
  archive, so `vfox install flutter@3.41.10-ohos-1.0.0-x64` is not supported.
- **`linux-arm64` is limited.** The OpenHarmony toolchain needs a matching
  `dart-sdk-linux-arm64` artifact, which upstream does not publish for some
  releases. On `linux-arm64`, versions such as `3.41.10-ohos-1.0.0` may fail to
  bootstrap; use an older `3.2x.x-ohos-*` version there.

The archives are fetched directly from gitcode.com, so an OpenHarmony install does
not require `storage.googleapis.com` to be reachable and does not depend on the
`FLUTTER_STORAGE_BASE_URL` mirror.

## Building OpenHarmony applications

Installing the toolchain is only the first step. Building OpenHarmony
applications additionally requires DevEco Studio and the OpenHarmony SDK, which
vfox does not install.
