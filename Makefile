# OpenWrt KVM ARM64
OPENWRT := openwrt
OPENWRT_PACKAGEINFO := $(OPENWRT)/tmp/.packageinfo

.PHONY: all prepare packages index sync clean distclean
.PHONY: rockchip rockchip-%

all: packages index

prepare: $(OPENWRT)/.config $(OPENWRT_PACKAGEINFO)
	$(MAKE) -C $(OPENWRT) package/system/apk/host/compile V=s

$(OPENWRT_PACKAGEINFO): feeds.conf
	ln -snf ../feeds.conf $(OPENWRT)/feeds.conf
	$(OPENWRT)/scripts/feeds update -a
	$(OPENWRT)/scripts/feeds install -a

$(OPENWRT)/.config:
	@echo "No .config - run 'make <target>' first" >&2; false

packages: $(OPENWRT_PACKAGEINFO)
	$(MAKE) -C $(OPENWRT) package/compile V=s

index: $(OPENWRT_PACKAGEINFO)
	$(MAKE) -C $(OPENWRT) package/index

sync:
	./sync.sh

clean:
	rm -f $(OPENWRT)/.config

distclean: clean
	$(MAKE) -C $(OPENWRT) dirclean

# Targets: rockchip (default subtarget), rockchip-armv8, etc.
rockchip: rockchip-armv8

rockchip-%:
	./bootstrap.sh $@
