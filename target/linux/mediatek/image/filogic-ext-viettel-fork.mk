# Fork-only: overrides Device/viettel_32x6 and Device/viettel_nr3053 to add
# fork-specific DEVICE_PACKAGES. This file is loaded after filogic-ext.mk
# (alphabetical order), so these definitions take precedence at eval time.
#
# When upstream modifies the upstream device blocks (partition layout, image
# format, artifacts), copy those changes here manually.

define Device/viettel_32x6
  DEVICE_VENDOR := Viettel
  DEVICE_MODEL := 32X6
  DEVICE_DTS := mt7981b-viettel-32x6
  DEVICE_DTS_DIR := ../dts-ext
  SUPPORTED_DEVICES := viettel,32x6
  UBINIZE_OPTS := -E 5
  BLOCKSIZE := 128k
  PAGESIZE := 2048
  IMAGE_SIZE := 114688k
  KERNEL_IN_UBI := 1
  UBOOTENV_IN_UBI := 1
  IMAGES := sysupgrade.itb
  KERNEL_INITRAMFS_SUFFIX := -recovery.itb
  KERNEL := kernel-bin | gzip
  KERNEL_INITRAMFS := kernel-bin | lzma | \
	fit lzma $$(KDIR)/image-$$(firstword $$(DEVICE_DTS)).dtb with-initrd | pad-to 64k
  IMAGE/sysupgrade.itb := append-kernel | \
	fit gzip $$(KDIR)/image-$$(firstword $$(DEVICE_DTS)).dtb external-static-with-rootfs | \
	append-metadata
  ARTIFACTS := preloader.bin bl31-uboot.fip
  ARTIFACT/preloader.bin := mt7981-bl2 spim-nand-ddr3
  ARTIFACT/bl31-uboot.fip := mt7981-bl31-uboot viettel_32x6
  DEVICE_PACKAGES := default-settings-vn luci-app-aurora-config bndstrg \
	-kmod-usb3 -kmod-usb-ledtrig-usbport -automount -autosamba
endef

define Device/viettel_nr3053
  DEVICE_VENDOR := Viettel
  DEVICE_MODEL := NR3053
  DEVICE_DTS := mt7981b-viettel-nr3053
  DEVICE_DTS_DIR := ../dts-ext
  SUPPORTED_DEVICES := viettel,nr3053
  UBINIZE_OPTS := -E 5
  BLOCKSIZE := 128k
  PAGESIZE := 2048
  IMAGE_SIZE := 229376k
  KERNEL_IN_UBI := 1
  UBOOTENV_IN_UBI := 1
  IMAGES := sysupgrade.itb
  KERNEL_INITRAMFS_SUFFIX := -recovery.itb
  KERNEL := kernel-bin | gzip
  KERNEL_INITRAMFS := kernel-bin | lzma | \
	fit lzma $$(KDIR)/image-$$(firstword $$(DEVICE_DTS)).dtb with-initrd | pad-to 64k
  IMAGE/sysupgrade.itb := append-kernel | \
	fit gzip $$(KDIR)/image-$$(firstword $$(DEVICE_DTS)).dtb external-static-with-rootfs | \
	append-metadata
  ARTIFACTS := preloader.bin bl31-uboot.fip
  ARTIFACT/preloader.bin := mt7981-bl2 spim-nand-ddr3
  ARTIFACT/bl31-uboot.fip := mt7981-bl31-uboot viettel_nr3053
  DEVICE_PACKAGES := default-settings-vn luci-app-aurora-config bndstrg \
	-kmod-usb3 -kmod-usb-ledtrig-usbport -automount -autosamba
endef
