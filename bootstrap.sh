#!/bin/sh
# Bootstrap OpenWrt KVM build environment
set -eu

REPO_ROOT="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT_FROM_OPENWRT=".."
OPENWRT="$REPO_ROOT/openwrt"
CONFIGS="$REPO_ROOT/configs"
PATCHES="$REPO_ROOT/patches"

# Pinned OpenWrt release. Bump this ref to move to a newer release;
# the packages feed pin follows from the release's feeds.conf.default.
OPENWRT_REF="v25.12.4"

die() { echo "bootstrap: $*" >&2; exit 1; }
info() { echo "==> $*"; }

init_submodule() {
    local dir="$1"

    if [ ! -e "$REPO_ROOT/$dir/.git" ]; then
        info "Initialising $dir"
        git -C "$REPO_ROOT" submodule update --init "$dir"
    fi
}

checkout_ref() {
    local dir="$1" ref="$2"
    local head want

    if ! git -C "$REPO_ROOT/$dir" rev-parse --verify --quiet "$ref^{commit}" > /dev/null; then
        info "$dir: fetching $ref"
        git -C "$REPO_ROOT/$dir" fetch --tags origin
    fi

    head=$(git -C "$REPO_ROOT/$dir" rev-parse HEAD)
    want=$(git -C "$REPO_ROOT/$dir" rev-parse "$ref^{commit}")

    if [ "$head" != "$want" ]; then
        info "$dir: checking out $ref"
        git -C "$REPO_ROOT/$dir" checkout "$ref"
    fi
}

# Commit hash a feed is pinned to in the release's feeds.conf.default
feed_pin() {
    local name="$1"

    sed -n "s|^src-git $name .*\^||p" "$OPENWRT/feeds.conf.default"
}

patch_applied() {
    local dir="$1" patch="$2"

    git -C "$dir" apply --reverse --check "$patch" 2> /dev/null
}

reverse_patches() {
    local dir="$1" patches="$2"
    local p list=""

    # reverse in reverse order so stacked patches unwind cleanly
    for p in "$patches"/*.patch; do
        [ -f "$p" ] || continue

        list="$p $list"
    done

    for p in $list; do
        if patch_applied "$dir" "$p"; then
            info "Reverting ${p##*/}"
            git -C "$dir" apply --reverse "$p"
        fi
    done
}

apply_patches() {
    local dir="$1" patches="$2"
    local p

    for p in "$patches"/*.patch; do
        [ -f "$p" ] || continue

        if patch_applied "$dir" "$p"; then
            info "Already applied: ${p##*/}"
        elif git -C "$dir" apply --check "$p" 2> /dev/null; then
            info "Applying ${p##*/}"
            git -C "$dir" apply "$p"
        else
            die "Patch does not apply: $p"
        fi
    done
}

sync_openwrt() {
    local ref="$1"
    local prev want

    init_submodule openwrt

    if ! git -C "$OPENWRT" rev-parse --verify --quiet "$ref^{commit}" > /dev/null; then
        info "openwrt: fetching $ref"
        git -C "$OPENWRT" fetch --tags origin
    fi

    prev=$(git -C "$OPENWRT" rev-parse HEAD)
    want=$(git -C "$OPENWRT" rev-parse "$ref^{commit}")

    if [ "$prev" != "$want" ]; then
        info "openwrt: checking out $ref"
        reverse_patches "$OPENWRT" "$PATCHES/openwrt"
        git -C "$OPENWRT" checkout "$ref"
        rm -rf "$OPENWRT/tmp"
    fi

    apply_patches "$OPENWRT" "$PATCHES/openwrt"
}

sync_feeds() {
    local pin

    pin=$(feed_pin packages)
    [ -n "$pin" ] || die "feeds.conf.default: no pin for feed 'packages'"

    init_submodule feeds/packages
    checkout_ref feeds/packages "$pin"
}

copy_kernel_configs() {
    local patches="$1" dst="$2"
    local cfg base

    for cfg in "$patches"/config-*; do
        [ -f "$cfg" ] || continue

        base="$(basename "$cfg")"

        if [ ! -f "$dst/$base" ] || [ "$cfg" -nt "$dst/$base" ]; then
            info "Copying $base from ${patches#"$REPO_ROOT"/}"
            cp "$cfg" "$dst/"
        fi
    done
}

setup_keys() {
    local name="$1"
    local key="$REPO_ROOT/keys/$name.key"
    local pub="$REPO_ROOT/keys/$name.pub"

    mkdir -p "$REPO_ROOT/keys"

    if [ ! -s "$key" ]; then
        info "Generating $name.key"
        openssl ecparam -name prime256v1 -genkey -noout -out "$key"
        rm -f "$pub"
    fi

    if [ ! -s "$pub" ]; then
        info "Generating $name.pub"
        openssl ec -in "$key" -pubout -out "$pub" 2>/dev/null
    fi

    [ -L "$OPENWRT/private-key.pem" ] || ln -snf "$REPO_ROOT_FROM_OPENWRT/keys/$name.key" "$OPENWRT/private-key.pem"
    [ -L "$OPENWRT/public-key.pem" ] || ln -snf "$REPO_ROOT_FROM_OPENWRT/keys/$name.pub" "$OPENWRT/public-key.pem"
}

restore_config() {
    local seed="$1"

    make -C "$OPENWRT" prepare-tmpinfo scripts/config/conf
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

sync_openwrt "$OPENWRT_REF"
sync_feeds

# Setup signing keys
setup_keys "openwrt-kvm-arm64"

# Restore and expand config
info "Restoring config from configs/$TARGET-$SUBTARGET"
restore_config "$config"

copy_kernel_configs "$patches" "$OPENWRT/target/linux/$TARGET/$SUBTARGET"

info "Done"
