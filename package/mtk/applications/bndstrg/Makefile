#
# MTK band steering daemon (Keenetic bndstrg v1.1-4) + OpenWrt ioctl shim.
#

include $(TOPDIR)/rules.mk

PKG_NAME:=bndstrg
PKG_VERSION:=1.1
PKG_RELEASE:=6

PKG_BUILD_DIR:=$(BUILD_DIR)/$(PKG_NAME)-$(PKG_VERSION)
PKG_FLAGS:=nonshared

include $(INCLUDE_DIR)/package.mk

define Package/bndstrg
  SECTION:=MTK Properties
  CATEGORY:=MTK Properties
  SUBMENU:=Applications
  TITLE:=MTK band steering daemon
  DEPENDS:=+kmod-mt_wifi +wireless-tools
endef

define Package/bndstrg/description
  Userspace band steering for mt_wifi (802.11v BTM). Requires BandSteering=1
  in the wifi profile and CONFIG_MTK_BAND_STEERING in the driver.
endef

define Build/Prepare
	$(CP) ./src/bndstrg-ioctl-shim.c $(PKG_BUILD_DIR)/
endef

define Build/Compile
	$(TARGET_CC) $(TARGET_CFLAGS) $(TARGET_LDFLAGS) -shared -fPIC \
		-o $(PKG_BUILD_DIR)/bndstrg-ioctl-shim.so \
		$(PKG_BUILD_DIR)/bndstrg-ioctl-shim.c -ldl
endef

define Package/bndstrg/install
	$(INSTALL_DIR) $(1)/usr/sbin $(1)/usr/lib $(1)/etc $(1)/etc/init.d $(1)/etc/uci-defaults
	$(INSTALL_BIN) ./files/bndstrg $(1)/usr/sbin/bndstrg
	$(INSTALL_BIN) ./files/libssp.so.0 $(1)/usr/lib/libssp.so.0
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/bndstrg-ioctl-shim.so $(1)/usr/lib/bndstrg-ioctl-shim.so
	$(INSTALL_CONF) ./files/bndstrg.conf $(1)/etc/bndstrg.conf
	$(INSTALL_BIN) ./files/bndstrg.init $(1)/etc/init.d/bndstrg
	$(INSTALL_BIN) ./files/99-bndstrg-wifi $(1)/etc/uci-defaults/99-bndstrg-wifi
endef

$(eval $(call BuildPackage,bndstrg))
