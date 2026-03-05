#!/bin/sh
set -eu

# Install location can be overridden:
#   curl -fsSL https://trnsys.github.io/trn-releases/install.sh | TRN_INSTALL_DIR=~/bin sh

RELEASES="https://github.com/trnsys/trn-releases/releases"
BIN_DIR="${TRN_INSTALL_DIR:-$HOME/.local/bin}"

# ── Platform detection ────────────────────────────────────────────────────────

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

# ── Downloader ────────────────────────────────────────────────────────────────

if command -v curl > /dev/null 2>&1; then
    HAS_CURL=1
elif command -v wget > /dev/null 2>&1; then
    HAS_CURL=0
else
    echo "error: neither curl nor wget found — install one and try again." >&2
    exit 1
fi

download() {
    # download <url> <dest>
    if [ "$HAS_CURL" = "1" ]; then
        curl -fsSL --output "$2" "$1"
    else
        wget -qO "$2" "$1"
    fi
}

# Fetch response headers for a URL without downloading the body.
fetch_headers() {
    if [ "$HAS_CURL" = "1" ]; then
        curl -sI "$1"
    else
        wget --spider -S -q "$1" 2>&1
    fi
}

# ── Resolve latest version ────────────────────────────────────────────────────

TAG=$(fetch_headers "${RELEASES}/latest" \
    | grep -i "^location:" \
    | sed 's|.*releases/tag/||' \
    | tr -d '[:space:]')

if [ -z "$TAG" ]; then
    echo "error: could not resolve latest release version." >&2
    exit 1
fi

# ── Temp dir, cleaned up on exit ─────────────────────────────────────────────

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

# ── Download and extract ──────────────────────────────────────────────────────

ARCHIVE="trn-${TAG}-${TARGET}.tar.gz"
URL="${RELEASES}/download/${TAG}/${ARCHIVE}"

echo "Downloading trn ${TAG} for ${TARGET}..."
download "$URL" "${TMP_DIR}/${ARCHIVE}"

tar -xzf "${TMP_DIR}/${ARCHIVE}" -C "$TMP_DIR" trn

# ── Install ───────────────────────────────────────────────────────────────────

mkdir -p "$BIN_DIR"
chmod +x "${TMP_DIR}/trn"
mv "${TMP_DIR}/trn" "${BIN_DIR}/trn"

echo "Installed trn ${TAG} to ${BIN_DIR}/trn"

# ── PATH hint ─────────────────────────────────────────────────────────────────

case ":${PATH}:" in
    *":${BIN_DIR}:"*) ;;
    *)
        echo ""
        echo "note: ${BIN_DIR} is not on your PATH."
        echo "      You may want to add it to use trn from any terminal."
        ;;
esac
