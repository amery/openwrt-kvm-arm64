#!/bin/sh
# Sync kernel config from OpenWrt build back to patches/
# Reads TARGET/SUBTARGET directly from .config
set -eu

REPO_ROOT="$(cd "$(dirname "$0")" && pwd)"
OPENWRT="$REPO_ROOT/openwrt"
CONFIG="$OPENWRT/.config"

die() { echo "sync: $*" >&2; exit 1; }
info() { echo "==> $*"; }

[ -f "$CONFIG" ] || die "No .config found - run make prepare first"

# Parse TARGET from CONFIG_TARGET_<target>=y
TARGET=$(sed -n 's/^CONFIG_TARGET_\([a-z]*\)=y$/\1/p' "$CONFIG" | head -1)
[ -n "$TARGET" ] || die "Could not determine TARGET from .config"

# Parse SUBTARGET from CONFIG_TARGET_<target>_<subtarget>=y
SUBTARGET=$(sed -n "s/^CONFIG_TARGET_${TARGET}_\([a-z0-9]*\)=y$/\1/p" "$CONFIG" | head -1)
[ -n "$SUBTARGET" ] || die "Could not determine SUBTARGET from .config"

info "Detected target: $TARGET/$SUBTARGET"

src="$OPENWRT/target/linux/$TARGET/$SUBTARGET"
dst="$REPO_ROOT/patches/$TARGET/$SUBTARGET"

[ -d "$src" ] || die "No build directory: $src"
mkdir -p "$dst"

synced=0
for cfg in "$src"/config-*; do
    [ -f "$cfg" ] || continue
    base="$(basename "$cfg")"
    if [ ! -f "$dst/$base" ] || [ "$cfg" -nt "$dst/$base" ]; then
        info "Syncing $base"
        cp "$cfg" "$dst/"
        synced=$((synced + 1))
    fi
done

if [ "$synced" -eq 0 ]; then
    info "Nothing to sync"
else
    info "Synced $synced file(s) to patches/$TARGET/$SUBTARGET"
fi
