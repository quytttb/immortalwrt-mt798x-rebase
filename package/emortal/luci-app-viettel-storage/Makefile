include $(TOPDIR)/rules.mk

PKG_NAME:=luci-app-viettel-storage
PKG_RELEASE:=1

PKG_LICENSE:=GPL-2.0-only
PKG_MAINTAINER:=Viettel ImmortalWrt maintainers

include $(INCLUDE_DIR)/package.mk

define Package/luci-app-viettel-storage
  SECTION:=luci
  CATEGORY:=LuCI
  TITLE:=LuCI support for Viettel NR3053 internal storage
  DEPENDS:=+luci-base +ubi-utils +ubifs-utils +uboot-envtools
  PKGARCH:=all
endef

define Build/Compile
endef

define Package/luci-app-viettel-storage/install
	$(INSTALL_DIR) $(1)/etc/init.d $(1)/etc/uci-defaults
	$(INSTALL_BIN) ./root/etc/init.d/viettel-storage $(1)/etc/init.d/
	$(INSTALL_BIN) ./root/etc/uci-defaults/99-viettel-storage $(1)/etc/uci-defaults/
	$(INSTALL_DIR) $(1)/usr/sbin
	$(INSTALL_BIN) ./root/usr/sbin/viettel-storage $(1)/usr/sbin/
	$(INSTALL_DIR) $(1)/usr/share/luci/menu.d $(1)/usr/share/rpcd/acl.d
	$(INSTALL_DATA) ./root/usr/share/luci/menu.d/luci-app-viettel-storage.json $(1)/usr/share/luci/menu.d/
	$(INSTALL_DATA) ./root/usr/share/rpcd/acl.d/luci-app-viettel-storage.json $(1)/usr/share/rpcd/acl.d/
	$(INSTALL_DIR) $(1)/www/luci-static/resources/view/system
	$(INSTALL_DATA) ./htdocs/luci-static/resources/view/system/viettel-storage.js $(1)/www/luci-static/resources/view/system/
endef

$(eval $(call BuildPackage,luci-app-viettel-storage))
