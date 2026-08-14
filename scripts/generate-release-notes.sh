#!/bin/bash
# Generate the release body from the artifacts that were actually built.
set -euo pipefail

DIST_DIR="${1:-dist}"
VERSION="${2:-dev}"
BOOTLOADER_REVISION="${3:-unknown}"

[[ -d "$DIST_DIR" ]] || {
    echo "Artifact directory does not exist: $DIST_DIR" >&2
    exit 1
}

size_of() {
    stat --printf='%s bytes' "$DIST_DIR/$1"
}

cat <<EOF_BODY
## ImmortalWrt ${VERSION}

ImmortalWrt 25.12 (filogic / MT7981) cho Viettel NR3053 va 32X6.

> **Luu y USB:** Chuc nang USB trong release nay chi danh cho Viettel **NR3053 da mod phan cung USB**. Khong dung ban nay de kich hoat USB tren 32X6 hoac NR3053 chua mod USB.

Moi thiet bi co 4 file + \`sha256sums\`. Kich thuoc ben duoi duoc lay truc tiep tu artifact da build.

### Viettel NR3053

| File | Thanh phan | Kich thuoc | Cach dung |
|------|------------|------------|-----------|
| \`immortalwrt-mediatek-filogic-viettel_nr3053-squashfs-sysupgrade.itb\` | Firmware | $(size_of immortalwrt-mediatek-filogic-viettel_nr3053-squashfs-sysupgrade.itb) | sysupgrade / TFTP (bootmenu [5]) |
| \`immortalwrt-mediatek-filogic-viettel_nr3053-initramfs-recovery.itb\` | Recovery RAM | $(size_of immortalwrt-mediatek-filogic-viettel_nr3053-initramfs-recovery.itb) | UART / TFTP test (bootmenu [2]) |
| \`immortalwrt-mediatek-filogic-viettel_nr3053-bl31-uboot.fip\` | BL31 + U-Boot | $(size_of immortalwrt-mediatek-filogic-viettel_nr3053-bl31-uboot.fip) | Nang cap U-Boot (bootmenu [7]) |
| \`immortalwrt-mediatek-filogic-viettel_nr3053-preloader.bin\` | BL2 preloader | $(size_of immortalwrt-mediatek-filogic-viettel_nr3053-preloader.bin) | Nang cap BL2 (bootmenu [8], **rui ro cao**) |

### Viettel 32X6

| File | Thanh phan | Kich thuoc | Cach dung |
|------|------------|------------|-----------|
| \`immortalwrt-mediatek-filogic-viettel_32x6-squashfs-sysupgrade.itb\` | Firmware | $(size_of immortalwrt-mediatek-filogic-viettel_32x6-squashfs-sysupgrade.itb) | sysupgrade / TFTP (bootmenu [5]) |
| \`immortalwrt-mediatek-filogic-viettel_32x6-initramfs-recovery.itb\` | Recovery RAM | $(size_of immortalwrt-mediatek-filogic-viettel_32x6-initramfs-recovery.itb) | UART / TFTP test (bootmenu [2]) |
| \`immortalwrt-mediatek-filogic-viettel_32x6-bl31-uboot.fip\` | BL31 + U-Boot | $(size_of immortalwrt-mediatek-filogic-viettel_32x6-bl31-uboot.fip) | Nang cap U-Boot (bootmenu [7]) |
| \`immortalwrt-mediatek-filogic-viettel_32x6-preloader.bin\` | BL2 preloader | $(size_of immortalwrt-mediatek-filogic-viettel_32x6-preloader.bin) | Nang cap BL2 (bootmenu [8], **rui ro cao**) |

- Bootloader source: [quytttb/bl-mt798x-dhcpd](https://github.com/quytttb/bl-mt798x-dhcpd), pinned revision \`${BOOTLOADER_REVISION}\`.
- Huong dan nap firmware: [docs/huong-dan-nap-firmware.md](https://github.com/quytttb/immortalwrt-mt798x-rebase/blob/main/docs/huong-dan-nap-firmware.md)
- Kiem tra file truoc khi nap: \`sha256sum -c sha256sums\`.
EOF_BODY
