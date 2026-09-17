#!/usr/bin/env bash
set -eu

VFOX_VERSION="${VFOX_VERSION:-latest}"
FLUTTER_VERSION="${FLUTTER_VERSION:-3.47.4}"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
WORK="$(mktemp -d)"

if [ "$VFOX_VERSION" = main ]; then
    git clone --depth 1 https://github.com/version-fox/vfox "$WORK/src"
    (cd "$WORK/src" && go build -trimpath -o /usr/local/bin/vfox .)
else
    curl -sSL https://raw.githubusercontent.com/version-fox/vfox/main/install.sh | bash
fi

(cd "$REPO_ROOT" && zip -qr "$WORK/flutter.zip" metadata.lua hooks lib)

echo 'eval "$(vfox activate bash)"' >> ~/.bashrc
bash -ic "
vfox add flutter --source '$WORK/flutter.zip' &&
vfox install flutter@$FLUTTER_VERSION &&
vfox use --global flutter@$FLUTTER_VERSION &&
source ~/.bashrc &&
dart --version &&
flutter --version --no-version-check
"
