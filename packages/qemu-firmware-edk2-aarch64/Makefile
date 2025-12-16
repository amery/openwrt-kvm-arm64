# SPDX-License-Identifier: GPL-2.0-only

include $(TOPDIR)/rules.mk

PKG_NAME:=qemu-firmware-edk2-aarch64
PKG_VERSION:=16.02
PKG_RELEASE:=1

# Linaro EDK2 UEFI firmware for QEMU ARM64
PKG_SOURCE:=QEMU_EFI.fd
PKG_SOURCE_URL:=https://releases.linaro.org/components/kernel/uefi-linaro/$(PKG_VERSION)/release/qemu64/
PKG_HASH:=42f915c44de6858f69ae6f1ffc9eaa3884d1b2ca97a7537d81312fb0dfd712cd

PKG_LICENSE:=BSD-2-Clause-Patent
PKG_MAINTAINER:=Alejandro Mery <amery@apptly.co>

# Raw binary file, not an archive - skip extraction
PKG_UNPACK:=:

include $(INCLUDE_DIR)/package.mk

define Package/qemu-firmware-edk2-aarch64
  SECTION:=utils
  CATEGORY:=Utilities
  SUBMENU:=Virtualization
  TITLE:=EDK2 UEFI firmware for QEMU ARM64
  URL:=https://releases.linaro.org/components/kernel/uefi-linaro/
  PKGARCH:=all
endef

define Package/qemu-firmware-edk2-aarch64/description
  EDK2 UEFI firmware (QEMU_EFI.fd) for running ARM64 virtual machines
  with UEFI boot support. Required for Home Assistant OS and other
  UEFI-based aarch64 guest operating systems.
endef

define Build/Compile
endef

define Package/qemu-firmware-edk2-aarch64/install
	$(INSTALL_DIR) $(1)/usr/share/qemu/firmware
	$(INSTALL_DATA) $(DL_DIR)/$(PKG_SOURCE) $(1)/usr/share/qemu/firmware/QEMU_EFI.fd
endef

$(eval $(call BuildPackage,qemu-firmware-edk2-aarch64))
