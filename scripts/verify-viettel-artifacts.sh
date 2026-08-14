#!/bin/bash
# Ensure a release contains every flashable artifact for both supported boards.
set -euo pipefail

DIST_DIR="${1:-dist}"

[[ -d "$DIST_DIR" ]] || {
    echo "Artifact directory does not exist: $DIST_DIR" >&2
    exit 1
}

expected=()
for board in viettel_nr3053 viettel_32x6; do
    expected+=(
        "immortalwrt-mediatek-filogic-${board}-squashfs-sysupgrade.itb"
        "immortalwrt-mediatek-filogic-${board}-initramfs-recovery.itb"
        "immortalwrt-mediatek-filogic-${board}-bl31-uboot.fip"
        "immortalwrt-mediatek-filogic-${board}-preloader.bin"
    )
done

for artifact in "${expected[@]}"; do
    [[ -s "$DIST_DIR/$artifact" ]] || {
        echo "Missing or empty required artifact: $DIST_DIR/$artifact" >&2
        exit 1
    }
done

checksum_file="$DIST_DIR/sha256sums"
[[ -s "$checksum_file" ]] || {
    echo "Missing checksum manifest: $checksum_file" >&2
    exit 1
}

(
    cd "$DIST_DIR"
    sha256sum --check --strict sha256sums
)

echo "Viettel release artifacts OK (8 board-specific files and checksums)."
