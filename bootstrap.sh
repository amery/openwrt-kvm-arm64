#!/bin/sh
# Bootstrap OpenWrt KVM build environment
set -eu

REPO_ROOT="$(cd "$(dirname "$0")" && pwd)"
OPENWRT="$REPO_ROOT/openwrt"

die() { echo "bootstrap: $*" >&2; exit 1; }
info() { echo "==> $*"; }

# Parse target spec (e.g., "rockchip" or "rockchip-armv8")
SPEC="${1:-}"
[ -n "$SPEC" ] || die "Usage: bootstrap.sh <target>[-<subtarget>]"

# Split on first dash: TARGET-SUBTARGET
case "$SPEC" in
    *-*)
        TARGET="${SPEC%%-*}"
        SUBTARGET="${SPEC#*-}"
        ;;
    *)
        TARGET="$SPEC"
        SUBTARGET=""
        ;;
esac

# If no subtarget, find from configs/
if [ -z "$SUBTARGET" ]; then
    matches=$(find "$REPO_ROOT/configs" -maxdepth 1 -name "${TARGET}-*" -type f 2>/dev/null | wc -l)
    case "$matches" in
        0) die "No config found for target '$TARGET'" ;;
        1)
            config=$(find "$REPO_ROOT/configs" -maxdepth 1 -name "${TARGET}-*" -type f)
            SUBTARGET="${config##*-}"
            ;;
        *)
            echo "Multiple configs for '$TARGET':" >&2
            find "$REPO_ROOT/configs" -maxdepth 1 -name "${TARGET}-*" -type f -exec basename {} \; >&2
            die "Specify subtarget: $TARGET-<subtarget>"
            ;;
    esac
fi

info "Target: $TARGET/$SUBTARGET"

# Validate config exists
config="$REPO_ROOT/configs/$TARGET-$SUBTARGET"
[ -f "$config" ] || die "No config: $config"

# Validate patches exist
patches="$REPO_ROOT/patches/$TARGET/$SUBTARGET"
[ -d "$patches" ] || die "No patches: $patches"

# Initialise submodule
if [ ! -f "$OPENWRT/Makefile" ]; then
    info "Initialising openwrt submodule"
    git -C "$REPO_ROOT" submodule update --init --depth 1 openwrt
fi

# Create feeds.conf symlink
if [ ! -e "$OPENWRT/feeds.conf" ]; then
    info "Creating feeds.conf symlink"
    ln -s ../feeds.conf "$OPENWRT/feeds.conf"
fi

# Update and install feeds (skip if already done)
cd "$OPENWRT"
if [ ! -d "feeds/ours" ]; then
    info "Updating feeds"
    ./scripts/feeds update -a
    ./scripts/feeds install -a
fi

# Copy base config
info "Copying config from configs/$TARGET-$SUBTARGET"
cp "$config" "$OPENWRT/.config"

# Copy kernel config from patches (only if newer)
dst="$OPENWRT/target/linux/$TARGET/$SUBTARGET"

for cfg in "$patches"/config-*; do
    [ -f "$cfg" ] || continue
    base="$(basename "$cfg")"
    if [ ! -f "$dst/$base" ] || [ "$cfg" -nt "$dst/$base" ]; then
        info "Copying $base from patches/$TARGET/$SUBTARGET"
        cp "$cfg" "$dst/"
    fi
done

info "Done"
