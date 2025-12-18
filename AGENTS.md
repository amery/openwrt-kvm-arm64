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
├── bootstrap.sh                    # Submodule init, restore config
├── sync.sh                         # Sync kernel config back to patches/
├── feeds.conf                      # Feed definitions (packages + ours)
├── configs/                        # Build configs per target
│   └── rockchip-armv8              # Minimal config seed
├── patches/                        # Kernel configs per target
│   └── rockchip/armv8/config-6.12  # KVM-enabled kernel config
├── packages/                       # "ours" feed
│   └── qemu-firmware-edk2-aarch64/Makefile
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

4. **Docker recommended**: Prefix commands with `x` for containerized builds
   (e.g., `x make packages`). Native builds require gawk (not mawk) for
   OpenWrt's build system. Docker provides the correct environment.
   Requires [docker-builder](https://github.com/amery/docker-builder).

## Build Workflow

### Full Build

```bash
make rockchip-armv8  # Bootstrap config
make prepare         # Sync feeds + build host tools
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
make prepare     # Sync feeds + build host tools (requires .config)
make clean       # Remove .config (for fresh start)
make distclean   # Clean + OpenWrt dirclean
```

### Syncing Kernel Config

After modifying kernel config (e.g., `make -C openwrt kernel_menuconfig`):

```bash
make sync  # Run savedefconfig and save to patches/
```

This runs kernel's `savedefconfig` to produce a minimal config, then copies
it to `patches/<target>/<subtarget>/config-<version>`. Target and version
are auto-detected.

## Supported Targets

| Target | Subtarget | SoCs | Status |
| ------ | --------- | ---- | ------ |
| rockchip | armv8 | RK3588, RK3582, RK3568 | Active |

KVM requires ARMv8.1+ with Virtualization Host Extensions (VHE).

## File Purposes

| File | Purpose |
| ---- | ------- |
| `configs/<target>-<subtarget>` | Minimal config seed (target + packages) |
| `patches/<target>/<subtarget>/config-*` | Kernel config with KVM enabled |
| `feeds.conf` | Feed definitions (packages for deps, ours for local) |
| `bootstrap.sh` | Submodule init, symlink keys, restore config |
| `sync.sh` | Run savedefconfig and save to patches/ |
| `Makefile` | Build driver, feeds sync, package compilation |
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

Kernel configs in `patches/.../config-*` must enable KVM support:

```text
CONFIG_VIRTUALIZATION=y
CONFIG_KVM=y
CONFIG_VHOST_NET=y
```

`CONFIG_VHOST` is auto-selected by `CONFIG_VHOST_NET`. Values may be `=y`
(built-in) or `=m` (module) depending on config.

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

2. Create kernel config with KVM:

   ```bash
   mkdir -p patches/<target>/<subtarget>
   # Start from upstream, add KVM options
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
