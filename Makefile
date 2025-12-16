# OpenWrt KVM ARM64
OPENWRT := openwrt

.PHONY: all prepare packages index sync clean distclean
.PHONY: rockchip rockchip-%

all: packages index

prepare: $(OPENWRT)/.config
	$(MAKE) -C $(OPENWRT) defconfig
	$(MAKE) -C $(OPENWRT) package/system/apk/host/compile V=s

$(OPENWRT)/.config:
	@echo "No .config - run 'make <target>' first" >&2
	@false

packages:
	$(MAKE) -C $(OPENWRT) package/compile V=s

index:
	$(MAKE) -C $(OPENWRT) package/index

sync:
	./sync.sh

clean:
	rm -f $(OPENWRT)/.config

distclean: clean
	$(MAKE) -C $(OPENWRT) dirclean

# Targets: rockchip, rockchip-armv8, etc.
rockchip rockchip-%:
	./bootstrap.sh $@
	$(MAKE) prepare
	$(MAKE)
