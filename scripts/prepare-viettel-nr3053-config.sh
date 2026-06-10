#!/bin/sh
# Tạo .config cho Viettel NR3053 (mt7981-ax3000 template, mediatek/filogic).
set -e
OWRT="$(cd "$(dirname "$0")/.." && pwd)"
BASE="$OWRT/defconfig/mt7981-ax3000.config"
CFG="$OWRT/.config"
TARGET=CONFIG_TARGET_mediatek_filogic_DEVICE_viettel_nr3053

[ -f "$BASE" ] || { echo "Thiếu $BASE"; exit 1; }

cp -f "$BASE" "$CFG"
make -C "$OWRT" defconfig

sed -i 's/^CONFIG_TARGET_MULTI_PROFILE=y$/# CONFIG_TARGET_MULTI_PROFILE is not set/' "$CFG"
sed -i '/^CONFIG_TARGET_mediatek_filogic_DEVICE_/s/^CONFIG_TARGET_mediatek_filogic_DEVICE_\(.*\)=y$/# CONFIG_TARGET_mediatek_filogic_DEVICE_\1 is not set/' "$CFG"
sed -i "s/^# ${TARGET} is not set$/${TARGET}=y/" "$CFG"

make -C "$OWRT" defconfig

# Single-profile build: DEVICE_PACKAGES are not merged without TARGET_PER_DEVICE_ROOTFS.
sed -i 's/^CONFIG_PACKAGE_bndstrg=.*$/CONFIG_PACKAGE_bndstrg=y/' "$CFG"
grep -q '^CONFIG_PACKAGE_bndstrg=y' "$CFG" || echo 'CONFIG_PACKAGE_bndstrg=y' >> "$CFG"

echo "[+] .config sẵn sàng: TARGET=viettel_nr3053 (filogic)"
grep -E "^(CONFIG_TARGET_PROFILE|${TARGET})=" "$CFG" | head -3
