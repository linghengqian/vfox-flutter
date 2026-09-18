# OpenHarmony builds

Third-party OpenHarmony Flutter releases from [gitcode.com](https://gitcode.com/CPF-Flutter/flutter_flutter/releases)
are also available, for example:

```bash
vfox install flutter@3.41.10-ohos-1.0.0
```

These are source checkouts that need `git`, so they behave differently from
official releases.

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

- **`git` is required.** The Flutter tool refuses to run outside a git checkout, so
  the plugin checks the release's commit out of gitcode.com's
  `CPF-Flutter/flutter_flutter` repository and installs the result as a real
  checkout. Keeping the pinned engine versions committed is what stops the
  toolchain from falling back to content-aware hash resolution against git
  history. No git identity is written to your global config.
- **The vfox home cannot contain spaces on Windows.** The checkout is created by
  shelling out to `git`, and that call cannot be given a quoted path, so a home such
  as `C:\Users\John Doe\.vfox` is not supported.
- **The plugin closes every file it opens before returning the checkout.** vfox
  installs a local checkout by moving its directories, and Windows refuses to move
  a directory that still holds an open file, so a leaked handle would abort the
  install with an access-denied error.
- **The pinned commit is used, not the branch.** Each release records the commit it
  was cut from, and that is what gets checked out, so a moving branch cannot change
  what an installed version contains.
- **They are source, not prebuilt SDKs.** On first use the Flutter tool builds
  itself and downloads the Dart SDK and engine artifacts from Huawei's OBS, so
  the first `flutter` command needs a network connection and takes longer than
  an official release.
- **No checksum is verified.** A git checkout has no published checksum, so vfox
  skips verification with a warning; git's own history is the integrity check.
  This is a third-party fork; review its source before trusting it.
- **No architecture variants.** Each version is a single architecture-independent
  checkout, so `vfox install flutter@3.41.10-ohos-1.0.0-x64` is not supported.
- **`linux-arm64` is limited.** The OpenHarmony toolchain needs a matching
  `dart-sdk-linux-arm64` artifact, which upstream does not publish for some
  releases. On `linux-arm64`, versions such as `3.41.10-ohos-1.0.0` may fail to
  download their Dart SDK; use an older `3.2x.x-ohos-*` version there.

The source is fetched over git's wire protocol from gitcode.com, so an OpenHarmony
install does not require `storage.googleapis.com` to be reachable and does not
depend on the `FLUTTER_STORAGE_BASE_URL` mirror.

## Building OpenHarmony applications

Installing the toolchain is only the first step. Building OpenHarmony
applications additionally requires DevEco Studio and the OpenHarmony SDK, which
vfox does not install.
