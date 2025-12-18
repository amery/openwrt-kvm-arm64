#!/bin/sh
# Sync kernel config from OpenWrt build back to patches/
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

# Find kernel build directory
LINUX_DIR=$(find "$OPENWRT/build_dir" -maxdepth 4 -type d -name "linux-*" -path "*/linux-${TARGET}_${SUBTARGET}/linux-*" 2>/dev/null | head -1)
[ -d "$LINUX_DIR" ] || die "Kernel build directory not found"

# Extract kernel version (major.minor only, matching OpenWrt convention)
KVER=$(basename "$LINUX_DIR" | sed 's/^linux-\([0-9]*\.[0-9]*\).*/\1/')
info "Found kernel $KVER at $LINUX_DIR"

# Run savedefconfig
info "Running savedefconfig"
make -C "$LINUX_DIR" savedefconfig

# Copy to patches
dst="$REPO_ROOT/patches/$TARGET/$SUBTARGET"
mkdir -p "$dst"
info "Saving config-$KVER to patches/$TARGET/$SUBTARGET"
cp "$LINUX_DIR/defconfig" "$dst/config-$KVER"

info "Done"
