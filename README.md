# OpenWrt KVM ARM64

KVM-enabled kernel packages for ARM64 OpenWrt devices.

## Overview

Stock OpenWrt kernels lack KVM support. This project provides:

- Kernel packages with KVM/vhost enabled
- UEFI firmware for ARM64 virtual machines
- APK repository for easy installation

**Use case**: Run VMs with hardware acceleration on ARM64 routers and SBCs
(Home Assistant OS, containers with KVM isolation, etc.)

## Supported Targets

| Target | Subtarget | SoCs | Devices |
| ------ | --------- | ---- | ------- |
| rockchip | armv8 | RK3588, RK3582, RK3568 | E52C, ROCK 5B+, NanoPi R6S |

KVM requires ARMv8.1+ with Virtualization Host Extensions (VHE).

## Quick Start

### Prerequisites

- ARM64 build host (native compilation)
- Docker (recommended) or gawk - OpenWrt requires gawk, not mawk
- [docker-builder](https://github.com/amery/docker-builder) for the `x` wrapper

### Build

```bash
git clone --recurse-submodules \
    https://github.com/amery/openwrt-kvm-arm64.git
cd openwrt-kvm-arm64

x make rockchip-armv8  # Bootstrap config
x make prepare         # Ensure feeds are synced
x make                 # Build packages + index
```

The `x` wrapper (from docker-builder) runs commands inside a Docker
container with the correct build environment. Submodules (`openwrt` and
`feeds/packages`) track the `openwrt-25.12` branch and are synced
automatically during bootstrap.

### Output

```text
openwrt/bin/targets/rockchip/armv8/packages/   # Kernel + kmods
openwrt/bin/packages/aarch64_generic/ours/     # qemu-firmware
```

## Installing on Device

### Option 1: APK Repository

Host the build output on a web server. The repository URL structure
should be `<repo>/rockchip/armv8/` (without `bin/targets/` prefix).

```bash
# On device - add repository feeds
REPO="https://your-server/openwrt-kvm"
echo "$REPO/rockchip/armv8/packages.adb" \
    >> /etc/apk/repositories.d/kvm.list
echo "$REPO/aarch64_generic/ours/packages.adb" \
    >> /etc/apk/repositories.d/kvm.list

# Install signing key
wget "$REPO/keys/openwrt-kvm-arm64.pub" -O /etc/apk/keys/openwrt-kvm-arm64.pub

# Replace kernel and install kmods from this repo
apk update
apk add kernel qemu-firmware-edk2-aarch64
apk add kmod-vhost kmod-vhost-net  # From this repo, not stock!
reboot
```

**Important**: Install ALL kmods from this repo. Our kernel has different
vermagic than stock OpenWrt - mixing kmods will cause module load failures.

### Option 2: Manual Install

Download signing key, then copy `.apk` files to device and install
with `apk add`.

## Verifying KVM

```bash
ls -la /dev/kvm
lsmod | grep -E 'kvm|vhost'
```

## Repository Structure

```text
openwrt-kvm-arm64/
├── Makefile              # Build driver
├── bootstrap.sh          # Sync submodule + restore config
├── sync.sh               # Sync kernel config to patches/
├── feeds.conf            # Feed config (src-link)
├── feeds/                # Feed sources
│   ├── packages/         # Submodule - OpenWrt packages
│   └── ours/             # Custom packages
│       └── qemu-firmware-edk2-aarch64/
├── configs/              # Build configs per target
├── patches/              # Kernel configs with KVM
├── keys/                 # Signing keys
│   └── openwrt-kvm-arm64.pub  # Distribute to users
├── openwrt/              # OpenWrt source (submodule)
└── docker/               # Build container
```

## Custom Packages

| Package | Description |
| ------- | ----------- |
| qemu-firmware-edk2-aarch64 | EDK2 UEFI firmware for ARM64 VMs |

## Licence

- Build scripts: [MIT](LICENCE)
- Custom packages: See individual package licences
- OpenWrt: GPL-2.0
