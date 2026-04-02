#!/bin/sh
set -eu

# Install location can be overridden:
#   curl -fsSL https://trnsys.github.io/trn-releases/install.sh | TRN_INSTALL_DIR=~/bin sh

RELEASES="https://github.com/trnsys/trn-releases/releases"
BIN_DIR="${TRN_INSTALL_DIR:-$HOME/.local/bin}"

OS="$(uname -s)"
ARCH="$(uname -m)"

case "${OS}-${ARCH}" in
    Darwin-arm64)  TARGET="aarch64-apple-darwin" ;;
    Linux-x86_64)  TARGET="x86_64-unknown-linux-gnu" ;;
    *)
        echo "error: unsupported platform: ${OS} ${ARCH}" >&2
        echo "  Supported: macOS arm64, Linux x86_64" >&2
        exit 1
        ;;
esac

# Resolve the latest tag via redirect header to avoid GitHub API rate limits.
TAG=$(curl -sI "${RELEASES}/latest" \
    | grep -i "^location:" \
    | sed 's|.*releases/tag/||' \
    | tr -d '[:space:]')

if [ -z "$TAG" ]; then
    echo "error: could not resolve latest release version." >&2
    exit 1
fi

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

ARCHIVE="trn-${TAG}-${TARGET}.tar.gz"
URL="${RELEASES}/download/${TAG}/${ARCHIVE}"

echo "Downloading trn ${TAG} for ${TARGET}..."
curl -fsSL --output "${TMP_DIR}/${ARCHIVE}" "$URL"

tar -xzf "${TMP_DIR}/${ARCHIVE}" -C "$TMP_DIR" trn

mkdir -p "$BIN_DIR"
chmod +x "${TMP_DIR}/trn"
mv "${TMP_DIR}/trn" "${BIN_DIR}/trn"

echo "Installed trn ${TAG} to ${BIN_DIR}/trn"

case ":${PATH}:" in
    *":${BIN_DIR}:"*) ;;
    *)
        echo ""
        echo "note: ${BIN_DIR} is not on your PATH."
        echo "      You may want to add it to use trn from any terminal."
        ;;
esac
