#!/usr/bin/env bash
# Install the pinned Zig toolchain from ziglang.org, with a checksum.
set -euo pipefail

version="0.17.0"
root="${ZIG_INSTALL_ROOT:-$HOME/.local/share/zig}"
os="${RUNNER_OS:-$(uname -s)}"
arch="${RUNNER_ARCH:-$(uname -m)}"

case "$os" in
  Linux) platform=linux ;;
  macOS) platform=macos ;;
  Windows) platform=windows ;;
  *) echo "unsupported OS: $os" >&2; exit 1 ;;
esac

case "$arch" in
  X64|x86_64|amd64) machine=x86_64 ;;
  ARM64|arm64|aarch64) machine=aarch64 ;;
  *) echo "unsupported architecture: $arch" >&2; exit 1 ;;
esac

if [[ "$platform" == windows ]]; then
  archive="zig-${machine}-windows-${version}.zip"
  case "$machine" in
    x86_64) sum="b5663f69581dcf391293fbf16c06cb80d81d806545ce618b4d0bab7f0eb8c428" ;;
    aarch64) sum="0a59d91fa1cb40cf068e9b0954434ce973500c7a2ea749f1e01af62cdab52d26" ;;
  esac
else
  archive="zig-${machine}-${platform}-${version}.tar.xz"
  case "${machine}-${platform}" in
    x86_64-linux) sum="1cbe9df9f27e6b78d14ccbca43b6703a404ef79ef1c463de901d7f088d4e2026" ;;
    aarch64-linux) sum="9e8d11661d4ae3bd57702a3832781e23ad151dde5798e16a5ccd503f65234ff8" ;;
    x86_64-macos) sum="4f9a1c5269aa17ebda5e6d3c2b89d6cbf36f7d2b22a0306e9ab98f25f95529c6" ;;
    aarch64-macos) sum="b607e9b9234790a008116ae5bdb71c6243b84b9fb42a53a9e70fde41c06c536a" ;;
    *) echo "no checksum for ${machine}-${platform}" >&2; exit 1 ;;
  esac
fi

mkdir -p "$root"
if [[ ! -x "$root/zig-${machine}-${platform}-${version}/zig" && ! -f "$root/zig-${machine}-${platform}-${version}/zig.exe" ]]; then
  url="https://ziglang.org/download/${version}/${archive}"
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' EXIT
  curl -fsSL "$url" -o "$tmp/$archive"
  printf '%s  %s\n' "$sum" "$tmp/$archive" | sha256sum -c -
  if [[ "$archive" == *.zip ]]; then
    unzip -q "$tmp/$archive" -d "$root"
  else
    tar -xJf "$tmp/$archive" -C "$root"
  fi
fi

zig_dir="$root/zig-${machine}-${platform}-${version}"
if [[ -n "${GITHUB_PATH:-}" ]]; then
  echo "$zig_dir" >> "$GITHUB_PATH"
else
  export PATH="$zig_dir:$PATH"
fi
"$zig_dir/zig" version
