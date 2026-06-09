#!/bin/sh
# Force rebuild VHT-32X6 sysupgrade ITB (board.d network + LED).
set -e
OWRT="$(cd "$(dirname "$0")/.." && pwd)"
BDIR="$OWRT/build_dir/target-aarch64_cortex-a53_musl/linux-mediatek_filogic"
ROOT_ORIG="$OWRT/build_dir/target-aarch64_cortex-a53_musl/root.orig-mediatek"
BIN="$OWRT/bin/targets/mediatek/filogic/immortalwrt-mediatek-filogic-vht_32x6-squashfs-sysupgrade.itb"

cd "$OWRT"

echo "[1/6] Rebuild base-files..."
make package/base-files/clean
make package/base-files/compile -j"$(nproc)"

echo "[2/6] Refresh APK index (packages.adb)..."
make package/index

echo "[3/6] Reinstall rootfs (root.orig-mediatek)..."
rm -rf "$ROOT_ORIG" "$BDIR/target-dir-"*
rm -f "$BDIR/root.squashfs" "$BDIR/root.squashfs+pkg="*
make package/install -j"$(nproc)"

echo "[4/6] Build target images..."
make target/linux/install V=s -j"$(nproc)"

echo "[5/6] Verify board.d + no device scripts..."
grep -q "viettel,vht-32x6" "$ROOT_ORIG/etc/board.d/02_network" || \
	{ echo "MISSING viettel,vht-32x6 in 02_network"; exit 1; }
grep -q "viettel,vht-32x6" "$ROOT_ORIG/etc/board.d/01_leds" || \
	{ echo "MISSING viettel,vht-32x6 in 01_leds"; exit 1; }
for f in usr/sbin/led-vht32x6 etc/init.d/led-vht32x6 \
	etc/uci-defaults/99-vht32x6-network etc/uci-defaults/99-vht32x6-rgb-led; do
	[ -e "$ROOT_ORIG/$f" ] && { echo "UNEXPECTED device script: $f"; exit 1; }
done

echo "[6/6] OK"
sha256sum "$BIN"
