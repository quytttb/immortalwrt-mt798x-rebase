#!/bin/sh
# Tạo .config cho Viettel NR3053 trên mediatek/filogic (ImmortalWrt 25.12).
set -e
OWRT="$(cd "$(dirname "$0")/.." && pwd)"
BASE="$OWRT/defconfig/mt7981-ax3000.config"
FRAG="$OWRT/defconfig/viettel_nr3053.config"
CFG="$OWRT/.config"
TARGET=CONFIG_TARGET_mediatek_filogic_DEVICE_viettel_nr3053

[ -f "$BASE" ] || { echo "Thiếu $BASE"; exit 1; }
[ -f "$FRAG" ] || { echo "Thiếu $FRAG"; exit 1; }

cp -f "$BASE" "$CFG"
make -C "$OWRT" defconfig

sed -i 's/^CONFIG_TARGET_MULTI_PROFILE=y$/# CONFIG_TARGET_MULTI_PROFILE is not set/' "$CFG"
sed -i '/^CONFIG_TARGET_mediatek_filogic_DEVICE_/s/^CONFIG_TARGET_mediatek_filogic_DEVICE_\(.*\)=y$/# CONFIG_TARGET_mediatek_filogic_DEVICE_\1 is not set/' "$CFG"
sed -i "s/^# ${TARGET} is not set$/${TARGET}=y/" "$CFG"

make -C "$OWRT" defconfig

cat "$FRAG" >> "$CFG"
make -C "$OWRT" defconfig

echo "[+] .config sẵn sàng: TARGET=viettel_nr3053 (filogic)"
grep -E "^(CONFIG_TARGET_PROFILE|${TARGET}|CONFIG_PACKAGE_kmod-mt7915e)=" "$CFG" | head -5
