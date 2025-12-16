# OpenWrt KVM ARM64 - Agent Guidelines

## Quick Context

**Goal**: Build KVM-enabled kernel packages for ARM64 OpenWrt.

**Repo**: `github.com/amery/openwrt-kvm-arm64`

**Output**: APK package repository (kernel + kmods + qemu-firmware)

**Build host**: `compute1` (192.168.24.12) - ROCK 5B+ with 32GB RAM, ARM64.

**Docker**: Recommended. Prefix commands with `x` for containerized builds.

## Repository Layout

```text
~/projects/openwrt-kvm-arm64/
├── Makefile                        # Build driver
├── bootstrap.sh                    # Setup: submodule, feeds, copy configs
├── sync.sh                         # Sync kernel config back to patches/
├── feeds.conf                      # Feed definitions (just "ours")
├── configs/                        # Build configs per target
│   └── rockchip-armv8              # Minimal config seed
├── patches/                        # Kernel configs per target
│   └── rockchip/armv8/config-6.12  # KVM-enabled kernel config
├── packages/                       # "ours" feed
│   └── qemu-firmware-edk2-aarch64/Makefile
├── openwrt/                        # Submodule - OpenWrt source
│   ├── feeds.conf -> ../feeds.conf
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

### Full Build (configure + build)

```bash
make rockchip    # Configure for rockchip-armv8 + full build
```

This runs: bootstrap → prepare (defconfig + host tools) → packages → index

### Incremental Builds

After target is configured:

```bash
make             # Build all (packages + index)
make packages    # Build all packages (kernel + kmods + feeds)
make index       # Generate packages.adb indexes only
```

### Setup Commands

```bash
make prepare     # defconfig + build host tools (requires .config)
make sync        # Save kernel config back to patches/
make clean       # Remove .config (for fresh start)
make distclean   # Clean + OpenWrt dirclean
```

### Modifying Kernel Config

After changing config (e.g., `make -C openwrt kernel_menuconfig`):

```bash
make sync  # Save config back to patches/
```

Copies `openwrt/target/linux/.../config-*` back to `patches/` for VCS.
Target is auto-detected from `.config`.

## Supported Targets

| Target | Subtarget | SoCs | Status |
| ------ | --------- | ---- | ------ |
| rockchip | armv8 | RK3588, RK3582, RK3568 | Active |

KVM requires ARMv8.1+ with Virtualization Host Extensions (VHE).

## File Purposes

| File | Purpose |
| ---- | ------- |
| `configs/<target>-<subtarget>` | Minimal config seed (target + packages) |
| `patches/<target>/<subtarget>/config-*` | Full kernel config with KVM |
| `feeds.conf` | Just `src-link ours ../../packages` |
| `bootstrap.sh` | Setup script (submodule, feeds, copy configs) |
| `sync.sh` | Sync kernel config back to patches/ (infers target from .config) |
| `Makefile` | Build driver |

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

All `patches/.../config-*` files must contain:

```text
CONFIG_VIRTUALIZATION=y
CONFIG_KVM=y
CONFIG_VHOST=y
CONFIG_VHOST_NET=y
```

## Adding a New Target

1. Create config seed:

   ```bash
   cat > configs/<target>-<subtarget> <<'EOF'
   CONFIG_TARGET_<target>=y
   CONFIG_TARGET_<target>_<subtarget>=y
   CONFIG_ALL_KMODS=y
   CONFIG_PACKAGE_kmod-vhost=y
   CONFIG_PACKAGE_kmod-vhost-net=y
   CONFIG_PACKAGE_qemu-firmware-edk2-aarch64=y
   # CONFIG_TARGET_ROOTFS_SQUASHFS is not set
   # CONFIG_TARGET_ROOTFS_EXT4FS is not set
   EOF
   ```

2. Create kernel config with KVM:

   ```bash
   mkdir -p patches/<target>/<subtarget>
   # Start from upstream, add KVM options
   ```

3. Add to Makefile `.PHONY` line:

   ```makefile
   .PHONY: <target> <target>-%
   ```

   And add rule:

   <!-- markdownlint-disable MD010 -->
   ```makefile
   <target> <target>-%:
   	./bootstrap.sh $@
   	$(MAKE) prepare
   	$(MAKE)
   ```
   <!-- markdownlint-enable MD010 -->

4. Build:

   ```bash
   make <target>
   ```

## Constraints

- **One target at a time**: Clean between target switches
- **vermagic**: Kmods tied to exact kernel config
- **No interactive prompts**: Run `make defconfig` to expand config

## Troubleshooting

| Problem | Solution |
| ------- | -------- |
| Config prompt during build | Run `make defconfig` first |
| `asort` function not defined | Use Docker (`x make`) or install gawk |
| defconfig loses target | awk issue - use Docker |
| Clock skew warnings | Ignore (NFS artefact) |
| Submodule dirty | Expected - configs are modified locally |
