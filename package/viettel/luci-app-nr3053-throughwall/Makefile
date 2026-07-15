include $(TOPDIR)/rules.mk

LUCI_TITLE:=ThroughWall WiFi Boost (NR3053)
LUCI_DEPENDS:=+luci-base

PKG_LICENSE:=MIT
PKG_MAINTAINER:=Viettel Fork

include $(TOPDIR)/feeds/luci/luci.mk

define Package/luci-app-nr3053-throughwall/install
	$(call LuciInstall/Default,$(1))
	$(INSTALL_DIR) $(1)/usr/bin
	$(INSTALL_BIN) ./root/usr/bin/throughwall-eeprom-read $(1)/usr/bin/throughwall-eeprom-read
endef

# call BuildPackage - OpenWrt buildroot signature
$(eval $(call BuildPackage,luci-app-nr3053-throughwall))
