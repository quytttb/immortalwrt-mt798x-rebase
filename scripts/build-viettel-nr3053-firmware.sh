#!/bin/sh
# Force rebuild NR3053 sysupgrade ITB (board.d network + LED).
set -e
OWRT="$(cd "$(dirname "$0")/.." && pwd)"
BDIR="$OWRT/build_dir/target-aarch64_cortex-a53_musl/linux-mediatek_filogic"
ROOT_ORIG="$OWRT/build_dir/target-aarch64_cortex-a53_musl/root.orig-mediatek"
BIN="$OWRT/bin/targets/mediatek/filogic/immortalwrt-mediatek-filogic-viettel_nr3053-squashfs-sysupgrade.itb"

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
grep -q "viettel,nr3053" "$ROOT_ORIG/etc/board.d/02_network" || \
	{ echo "MISSING viettel,nr3053 in 02_network"; exit 1; }
grep -q "viettel,nr3053" "$ROOT_ORIG/etc/board.d/01_leds" || \
	{ echo "MISSING viettel,nr3053 in 01_leds"; exit 1; }
for f in usr/sbin/led-nr3053 etc/init.d/nr3053-board etc/init.d/led-nr3053 \
	etc/uci-defaults/99-viettel-nr3053 etc/hotplug.d/iface/99-nr3053-led; do
	[ -e "$ROOT_ORIG/$f" ] && { echo "UNEXPECTED device script: $f"; exit 1; }
done

echo "[6/6] OK"
sha256sum "$BIN"
