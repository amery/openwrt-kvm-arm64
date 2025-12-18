#!/bin/sh
# Bootstrap OpenWrt KVM build environment
set -eu

REPO_ROOT="$(cd "$(dirname "$0")" && pwd)"
OPENWRT="$REPO_ROOT/openwrt"
CONFIGS="$REPO_ROOT/configs"
PATCHES="$REPO_ROOT/patches"

die() { echo "bootstrap: $*" >&2; exit 1; }
info() { echo "==> $*"; }

restore_config() {
    local seed="$1"

    make -C "$OPENWRT" scripts/config/conf
    (
        set -eu
        cd "$OPENWRT"
        rm -f .config
        ./scripts/config/conf --allnoconfig -r "$seed" Config.in
        sed -i '/CONFIG_PACKAGE_kmod-/d' .config
        ./scripts/config/conf --olddefconfig -r "$seed" Config.in
    )
}

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
    matches=$(find "$CONFIGS" -maxdepth 1 -name "${TARGET}-*" -type f 2>/dev/null | wc -l)
    case "$matches" in
        0) die "No config found for target '$TARGET'" ;;
        1)
            config=$(find "$CONFIGS" -maxdepth 1 -name "${TARGET}-*" -type f)
            SUBTARGET="${config##*-}"
            ;;
        *)
            echo "Multiple configs for '$TARGET':" >&2
            find "$CONFIGS" -maxdepth 1 -name "${TARGET}-*" -type f -exec basename {} \; >&2
            die "Specify subtarget: $TARGET-<subtarget>"
            ;;
    esac
fi

info "Target: $TARGET/$SUBTARGET"

# Validate config exists
config="$CONFIGS/$TARGET-$SUBTARGET"
[ -f "$config" ] || die "No config: $config"

# Validate patches exist
patches="$PATCHES/$TARGET/$SUBTARGET"
[ -d "$patches" ] || die "No patches: $patches"

# Initialise submodule
if [ ! -f "$OPENWRT/Makefile" ]; then
    info "Initialising openwrt submodule"
    git -C "$REPO_ROOT" submodule update --init --depth 1 openwrt
fi

# Restore and expand config
info "Restoring config from configs/$TARGET-$SUBTARGET"
restore_config "$config"

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
