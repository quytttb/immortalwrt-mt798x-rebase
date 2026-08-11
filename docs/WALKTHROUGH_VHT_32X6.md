# Walkthrough — Viettel VHT-32X6V1 (ImmortalWrt 25.12)

Tài liệu ghi lại toàn bộ quá trình unlock, nạp firmware và các phát hiện phần cứng thực tế trên **Viettel VHT-32X6V1** (MT7981B, MT7531, 128 MB NAND, 256 MB RAM).

**Build tree:** `IMMORTALWRT/immortalwrt-mt798x-rebase/`  
**Board compatible:** `viettel,vht-32x6`  
**Hướng dẫn nạp nhanh:** [flash-guide.md](flash-guide.md)

---

## 1. Phân vùng NAND (U-Boot / OpenWrt)

| Phân vùng | Offset | Kích thước | Ghi chú |
|-----------|--------|----------|---------|
| BL2 | `0x000000` | 1 MB | Preloader |
| u-boot-env | `0x100000` | 512 KB | Env (raw, trước UBI) |
| **Factory** | `0x180000` | 2 MB | EEPROM WiFi, MAC Ethernet |
| FIP | `0x380000` | 2 MB | ATF BL31 + U-Boot |
| **ubi** | `0x580000` | ~122 MB | `fit`, `ubootenv`, `rootfs_data`, … |

Trên Linux đang chạy ImmortalWrt: Factory = `/dev/mtd2`.

---

## 2. Factory — MAC và EEPROM

### Offset đúng (VHT-32X6)

| Offset | Nội dung | Ví dụ |
|--------|----------|-------|
| `0x00` | EEPROM magic | `81 79` (MT7981) |
| `0x04` | WiFi MAC | `24:0B:2A:DA:10:6A` |
| `0x24` | LAN MAC (switch) | `24:0B:2A:DA:10:6A` |
| `0x2a` | WAN MAC | `24:0B:2A:DA:10:69` (= label − 1) |

### Sai lầm patch cộng đồng (`32x6.patch.txt`)

Patch gốc dùng offset **`0x1fef20` / `0x1fef26`** — copy từ **Netis NX32U**, không áp dụng cho 32X6. Nếu dùng mù quáng sẽ mất MAC Ethernet.

Trong tree ImmortalWrt, DTS dùng `macaddr@24` và `macaddr@2a` — đã verify trên phần cứng.

### Khôi phục Factory khi partition hỏng

1. Lấy backup EEPROM từ router cùng model (hoặc backup gốc `mtd3_Factory.bin`).
2. Patch MAC theo nhãn dưới đáy (WAN = label − 1, LAN/WiFi = label).
3. Nạp qua **U-Boot** (Linux không ghi được Factory do `read-only` trong DTS):

```
setenv ipaddr 192.168.1.1
setenv serverip 192.168.1.254
tftpboot 0x46000000 factory_backup.bin
mtd erase Factory
mtd write Factory 0x46000000
```

Backup sau cài đặt thành công (khuyến nghị giữ):

```bash
ssh root@192.168.1.1 "dd if=/dev/mtd2 bs=128k" > VIETTEL_32X6/backup_firmware/mtd2_Factory_YYYYMMDD.bin
```

File patched tạm (`mtd3_Factory_patched.bin`) đã xóa sau khi nạp NAND — thay bằng backup `mtd2_Factory_*.bin` từ router đang chạy.

---

## 3. GPIO — LED và nút bấm (đã verify SSH)

Patch cộng đồng (VOZ) ghi RGB GPIO **5, 7, 8**. Trên **VHT-32X6V1 thực tế**:

| Chức năng | GPIO | Ghi chú |
|-----------|------|---------|
| Mesh | 0 | `button-mesh` |
| Reset | 1 | `button-reset` |
| Power / WPS | 5 | `led_wps` (đỏ) |
| Internet / WAN | **9** | `led_internet` — **không phải GPIO 8** |
| WiFi 2.4G | 34 | `led_wifi2g` |
| WiFi 5G | 35 | `led_wifi5g` |

Thiết bị **không có cổng USB** — kernel tắt `usb_phy` / `xhci` (giống NR3053).

GPIO 7 và 8 tồn tại trên chip nhưng **không** được DTS kernel/U-Boot sử dụng cho LED chính.

DTS: `target/linux/mediatek/dts/mt7981b-viettel-vht-32x6.dts`

---

## 4. Chuỗi nạp firmware (đã thực hiện)

```mermaid
flowchart LR
  A[mtk_uartboot RAM] --> B[TFTP initramfs test]
  B --> C[mtd write Factory]
  C --> D[Menu 7 FIP]
  D --> E[Menu 5 sysupgrade]
  E --> F[Cold boot NAND OK]
```

### Bước 1 — Boot U-Boot RAM (nếu NAND là Keenetic)

```bash
cd IMMORTALWRT/mtk_uart
sudo ./mtk_uartboot --serial /dev/ttyUSB0 \
  --payload bl2-mt7981-bga-ddr3-ram.bin \
  --fip fip/immortalwrt-mediatek-filogic-vht_32x6-bl31-uboot.fip \
  --aarch64
```

### Bước 2 — Nạp Factory (U-Boot prompt)

Xem mục 2. Không dùng UBI/`mtdblock` — Factory là raw NAND.

### Bước 3 — Test initramfs RAM

Bootmenu **2** hoặc:

```
tftpboot 0x46000000 immortalwrt-mediatek-filogic-vht_32x6-initramfs-recovery.itb
bootm 0x46000000#config-1
```

Kiểm tra:

```bash
hexdump -C -n 16 /dev/mtd2    # 81 79 ... MAC đúng
dmesg | grep -i eeprom        # không có "EEPROM in Flash is wrong"
```

### Bước 4 — Nạp FIP (menu **7**)

Ghi ImmortalWrt U-Boot vào phân vùng FIP. Sau bước này cold boot không cần `mtk_uartboot`.

### Bước 5 — Nạp sysupgrade (menu **5**)

```
immortalwrt-mediatek-filogic-vht_32x6-squashfs-sysupgrade.itb
```

Ghi volume `fit` trên UBI, thay firmware Keenetic cũ.

### Bước 6 — Cold boot

Rút nguồn → cắm lại. Kỳ vọng: boot ImmortalWrt từ NAND, không lặp TFTP.

---

## 5. Kiểm tra PASS (sau cài đặt)

```bash
cat /tmp/sysinfo/board_name          # viettel,vht-32x6
ubinfo -a | grep -E 'Name:|State:'   # fit, rootfs_data OK
hexdump -C -n 48 /dev/mtd2
ip link | grep -A1 'eth0\|wan\|ra0'
```

Kỳ vọng Factory:

```
00000000  81 79 00 00 24 0b 2a da  10 6a ...
00000020  ... 24 0b 2a da  10 6a 24 0b 2a da 10 69
```

---

## 6. Gỡ lỗi thường gặp

| Triệu chứng | Nguyên nhân | Xử lý |
|-------------|-------------|--------|
| TFTP `File not found` lặp vô hạn | `boot_tftp_forever`, thiếu initramfs trên TFTP | Đặt lại file recovery.itb hoặc nhấn phím dừng autoboot |
| `reboot` vào Keenetic | Chưa nạp FIP/sysupgrade | Nạp menu 7 + 5 |
| Linux không ghi Factory | DTS `read-only` | Chỉ ghi qua U-Boot `mtd write` |
| MAC random `22:41:97:...` | Factory hỏng / offset sai | Nạp lại Factory đúng offset |
| `ethaddr=6d:73:29:...` trong uboot env | Đọc text rác từ Factory corrupt | Nạp Factory + `fw_setenv ethaddr` |

---

## 7. Backup & file trong repo

| File | Mô tả |
|------|--------|
| `VIETTEL_32X6/backup_firmware/mtd3_Factory.bin` | Backup gốc router cũ |
| `VIETTEL_32X6/backup_firmware/mtd2_Factory_YYYYMMDD.bin` | Backup Factory sau cài đặt (MAC đúng) |
| `IMMORTALWRT/.../505-add-vht-32x6.patch` | Patch U-Boot mã nguồn (giữ) |
| `Downloads/32x6.patch.txt` | Patch cộng đồng tham khảo (có lỗi MAC/GPIO) |

---

## 8. Build firmware

```bash
cd IMMORTALWRT/immortalwrt-mt798x-rebase
./scripts/prepare-vht-32x6-config.sh
make -j$(nproc)
```

Artifact: `bin/targets/mediatek/filogic/immortalwrt-mediatek-filogic-vht_32x6-*`

Nâng cấp từ router đang chạy: `sysupgrade -n immortalwrt-...-sysupgrade.itb`  
Nếu đổi U-Boot env: nạp lại FIP (bootmenu 7) trước.
