# OpenWrt KVM ARM64
OPENWRT := openwrt
OPENWRT_PACKAGEINFO := $(OPENWRT)/tmp/.packageinfo
REPO_ROOT_FROM_OPENWRT := ..

.PHONY: all prepare packages index clean distclean
.PHONY: rockchip rockchip-%

all: packages index

prepare: $(OPENWRT)/.config $(OPENWRT_PACKAGEINFO)

$(OPENWRT_PACKAGEINFO): feeds.conf | $(OPENWRT)/.config
	ln -snf $(REPO_ROOT_FROM_OPENWRT)/feeds.conf $(OPENWRT)/feeds.conf
	$(OPENWRT)/scripts/feeds update -a
	$(OPENWRT)/scripts/feeds install -a

$(OPENWRT)/.config:
	@echo "No .config - run 'make <target>' first" >&2; false

packages: $(OPENWRT)/.config $(OPENWRT_PACKAGEINFO)
	$(MAKE) -C $(OPENWRT) tools/install V=s
	$(MAKE) -C $(OPENWRT) toolchain/install V=s
	$(MAKE) -C $(OPENWRT) target/compile V=s
	$(MAKE) -C $(OPENWRT) package/compile V=s

index: $(OPENWRT_PACKAGEINFO)
	$(MAKE) -C $(OPENWRT) package/index

clean:
	rm -rf $(OPENWRT)/tmp
	rm -f $(OPENWRT)/.config

distclean:
	+@if [ -f $(OPENWRT)/.config ]; then $(MAKE) -C $(OPENWRT) dirclean; fi
	$(MAKE) clean

# Targets: rockchip (default subtarget), rockchip-armv8, etc.
rockchip: rockchip-armv8

rockchip-%:
	+./bootstrap.sh $@
