# OpenWrt KVM ARM64 - Agent Guidelines

## Quick Context

**Goal**: Build KVM-enabled kernel packages for ARM64 OpenWrt.

**Repo**: `github.com/amery/openwrt-kvm-arm64`

**Output**: APK package repository (kernel + kmods + qemu-firmware)

**Docker**: Recommended. Prefix commands with `x` for containerized builds.

## Repository Layout

```text
~/projects/openwrt-kvm-arm64/
├── Makefile                        # Build driver
├── bootstrap.sh                    # Sync submodule, restore config
├── feeds.conf                      # Feed definitions (src-link)
├── feeds/                          # Feed sources
│   ├── packages/                   # Submodule - OpenWrt packages feed
│   └── ours/                       # Custom packages
│       └── qemu-firmware-edk2-aarch64/Makefile
├── configs/                        # Build configs per target
│   └── rockchip-armv8              # Minimal config seed
├── patches/                        # Patches + kernel config fragments
│   ├── openwrt/                    # Patch series for the openwrt tree
│   └── rockchip/armv8/kernel-config  # KVM kernel config fragment
├── keys/                           # Signing keys
│   ├── openwrt-kvm-arm64.key       # Build only (untracked)
│   └── openwrt-kvm-arm64.pub       # Distribute to users
├── openwrt/                        # Submodule - OpenWrt source
│   ├── feeds.conf -> ../feeds.conf
│   ├── private-key.pem -> ../keys/openwrt-kvm-arm64.key
│   ├── public-key.pem -> ../keys/openwrt-kvm-arm64.pub
│   └── .config                     # Generated from configs/
└── docker/                         # Build container
```

## Critical Understanding

1. **Overlay repo**: We build kernel + kmods to overlay on stock OpenWrt.
   Users replace the kernel, keeping their existing setup.

2. **vermagic**: Our kernel has different vermagic than stock OpenWrt.
   Users must install ALL kmods from our repo, not mix with stock.

3. **Minimal scope**: Only kernel packages + our custom packages.
   Not a full OpenWrt build. Rootfs/image generation is disabled in config.

4. **Branch-tracking submodules**: Both `openwrt` and `feeds/packages`
   track the `openwrt-25.12` branch. Bootstrap syncs all submodules to
   their branch tips via `--remote`, cleaning stale metadata on update.

5. **Docker recommended**: Prefix commands with `x` for containerized builds
   (e.g., `x make packages`). Native builds require gawk (not mawk) for
   OpenWrt's build system. Docker provides the correct environment.
   Requires [docker-builder](https://github.com/amery/docker-builder).

## Build Workflow

### Full Build

```bash
make rockchip-armv8  # Bootstrap config
make prepare         # Sync feeds + build toolchain
make                 # Build packages + index
```

Or step by step for more control.

### Incremental Builds

After target is configured:

```bash
make             # Build all (packages + index)
make packages    # Build all packages (kernel + kmods + feeds)
make index       # Generate packages.adb indexes only
```

### Setup Commands

```bash
make prepare     # Ensure .config + feeds are synced (requires bootstrap first)
make clean       # Remove openwrt/tmp/ and .config (for fresh start)
make distclean   # Clean + OpenWrt dirclean (nukes toolchain)
```

### Editing the Kernel Config

Bootstrap links `patches/<target>/<subtarget>/kernel-config` into
OpenWrt's native `env/kernel-config` slot, merged last into the kernel
config. Edit it through the build system:

```bash
x make -C openwrt kernel_menuconfig CONFIG_TARGET=env
```

This writes the filtered config diff back through the link. After a
kernel bump, refresh the fragment non-interactively:

```bash
yes '' | x make -C openwrt kernel_oldconfig CONFIG_TARGET=env
```

The fragment is machine-maintained; hand-written comments are lost on
regeneration.

## Supported Targets

| Target | Subtarget | SoCs | Status |
| ------ | --------- | ---- | ------ |
| rockchip | armv8 | RK3588, RK3582, RK3568 | Active |

KVM requires ARMv8.1+ with Virtualization Host Extensions (VHE).

## File Purposes

| File | Purpose |
| ---- | ------- |
| `configs/<target>-<subtarget>` | Minimal config seed (target + packages) |
| `patches/<target>/<subtarget>/kernel-config` | Kernel config fragment (KVM deltas) |
| `feeds.conf` | Feed definitions (src-link to feeds/) |
| `feeds/packages/` | Submodule - OpenWrt packages feed (kmod deps) |
| `feeds/ours/` | Custom packages (qemu-firmware) |
| `bootstrap.sh` | Sync submodules, link kernel config + keys, restore config |
| `Makefile` | Build driver: feeds sync, package compilation |
| `keys/` | Signing keys (*.pub distributed, *.key untracked) |

## Build Output

```text
openwrt/bin/targets/<target>/<subtarget>/packages/
├── packages.adb                    # Signed package index
├── kernel*.apk                     # Kernel image
├── kmod-*.apk                      # Kernel modules
└── ...

openwrt/bin/packages/aarch64_generic/ours/
├── packages.adb                    # Signed package index
└── qemu-firmware-edk2-aarch64_*.apk
```

## KVM Kernel Options

The fragment `patches/.../kernel-config` builds KVM in:

```text
CONFIG_VIRTUALIZATION=y
CONFIG_KVM=y
```

VHOST is not in the fragment: the `kmod-vhost` and `kmod-vhost-net`
packages selected in the config seed build it as modules.

## Adding a New Target

1. Create config seed:

   ```bash
   cat > configs/<target>-<subtarget> <<'EOF'
   CONFIG_TARGET_<target>=y
   CONFIG_TARGET_<target>_<subtarget>=y
   CONFIG_TARGET_MULTI_PROFILE=y
   CONFIG_ALL_KMODS=y
   CONFIG_KERNEL_KEYS=y
   CONFIG_PACKAGE_kmod-vhost=y
   CONFIG_PACKAGE_kmod-vhost-net=y
   CONFIG_PACKAGE_qemu-firmware-edk2-aarch64=y
   # CONFIG_TARGET_ROOTFS_SQUASHFS is not set
   # CONFIG_TARGET_ROOTFS_EXT4FS is not set
   # CONFIG_TARGET_ROOTFS_CPIOGZ is not set
   # CONFIG_TARGET_ROOTFS_TARGZ is not set
   EOF
   ```

2. Create an empty kernel config fragment:

   ```bash
   mkdir -p patches/<target>/<subtarget>
   touch patches/<target>/<subtarget>/kernel-config
   ```

   After bootstrap, add the KVM options through the build system:

   ```bash
   x make -C openwrt kernel_menuconfig CONFIG_TARGET=env
   ```

3. Add Makefile rules:

   <!-- markdownlint-disable MD010 -->
   ```makefile
   .PHONY: <target> <target>-%

   <target>: <target>-<default-subtarget>

   <target>-%:
   	./bootstrap.sh $@
   ```
   <!-- markdownlint-enable MD010 -->

4. Build:

   ```bash
   make <target>-<subtarget>
   make prepare
   make
   ```

## Constraints

- **One target at a time**: Clean between target switches
- **vermagic**: Kmods tied to exact kernel config
- **No interactive prompts**: Bootstrap uses allnoconfig to expand seed

## Troubleshooting

| Problem | Solution |
| ------- | -------- |
| Config prompt during build | Re-run `make <target>-<subtarget>` to restore config |
| `asort` function not defined | Use Docker (`x make`) or install gawk |
| Clock skew warnings | Ignore (NFS artefact) |
| Submodule dirty | Expected - build modifies openwrt/ |
