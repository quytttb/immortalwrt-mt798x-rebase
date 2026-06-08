#!/bin/sh
# Force rebuild NR3053 sysupgrade ITB with filogic base-files (LED + LAN IP).
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

echo "[5/6] Verify root.orig + NR3053 squashfs..."
for f in usr/sbin/led-nr3053 etc/init.d/nr3053-board etc/init.d/led-nr3053 etc/uci-defaults/99-viettel-nr3053; do
	[ -e "$ROOT_ORIG/$f" ] || { echo "MISSING in root.orig: $f"; exit 1; }
done
[ -x "$ROOT_ORIG/etc/init.d/led-nr3053" ] || { echo "NOT EXECUTABLE: etc/init.d/led-nr3053"; exit 1; }

SQ=$(ls -1 "$BDIR"/root.squashfs+pkg=* 2>/dev/null | grep -v pagesync | head -1)
[ -n "$SQ" ] || SQ="$BDIR/root.squashfs"
for f in etc/init.d/nr3053-board etc/init.d/led-nr3053 usr/sbin/led-nr3053 etc/uci-defaults/99-viettel-nr3053; do
	unsquashfs -ll "$SQ" 2>/dev/null | grep -q "squashfs-root/$f" || \
		{ echo "MISSING in squashfs: $f"; exit 1; }
done

grep -q "nr3053" "$ROOT_ORIG/etc/board.d/01_leds" 2>/dev/null && \
	echo "WARN: stale 01_leds nr3053 entry still present" || true

echo "[6/6] OK"
sha256sum "$BIN"
