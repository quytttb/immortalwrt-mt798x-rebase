# ImmortalWrt MT798x — Fork hỗ trợ router Viettel

Fork từ [chasey-dev/immortalwrt-mt798x-rebase](https://github.com/chasey-dev/immortalwrt-mt798x-rebase) (branch `25.12`), bổ sung hỗ trợ **hai router WiFi 6 Viettel** chạy ImmortalWrt trên nền MediaTek MT7981.

---

## Router được hỗ trợ

| | **Viettel NR3053** | **Viettel VHT-32X6V1** |
|---|---|---|
| SoC | MediaTek MT7981B | MediaTek MT7981B |
| RAM | 512 MB DDR3 | 128 MB DDR3 |
| Flash | 128 MB SPI-NAND (UBI) | 128 MB SPI-NAND (UBI) |
| Cổng LAN | 3 × LAN + 1 × WAN | 3 × LAN + 1 × WAN |
| USB | Không | Không |
| LED | Đỏ / xanh (WAN + Internet) | RGB (đỏ / xanh / xanh dương) |
| IP LAN mặc định | `192.168.10.1` | `192.168.2.1` |
| Trạng thái test | Đã test trên phần cứng | Đã test trên phần cứng |

---

## Build firmware

Yêu cầu: Linux, đủ RAM/disk cho OpenWrt build, đã `make menuconfig` / feeds theo hướng dẫn upstream.

### NR3053

```bash
git checkout 25.12
./scripts/prepare-viettel-nr3053-config.sh
make -j$(nproc)
# hoặc: ./scripts/build-viettel-nr3053-firmware.sh
```

### VHT-32X6

```bash
git checkout 25.12
./scripts/prepare-vht-32x6-config.sh
make -j$(nproc)
# hoặc: ./scripts/build-vht32x6-firmware.sh
```

**Artifact** (cả hai máy):

```
bin/targets/mediatek/filogic/
  immortalwrt-mediatek-filogic-<device>-preloader.bin
  immortalwrt-mediatek-filogic-<device>-bl31-uboot.fip
  immortalwrt-mediatek-filogic-<device>-squashfs-sysupgrade.itb
  immortalwrt-mediatek-filogic-<device>-initramfs-recovery.itb
```

---

## Nạp firmware

Hướng dẫn chi tiết (TFTP, U-Boot bootmenu, UART, sysupgrade NAND):

**[docs/huong-dan-nap-firmware.md](docs/huong-dan-nap-firmware.md)**

Tóm tắt nhanh:

1. Cắm PC vào cổng **LAN**, cấu hình TFTP server `192.168.1.254/24`.
2. **Test không ghi NAND:** boot initramfs qua TFTP (bootmenu mục **[2]**).
3. **Cài vĩnh viễn:** ghi `sysupgrade.itb` qua TFTP (bootmenu mục **[5]**) hoặc `sysupgrade` từ Linux.
4. UART 115200 8N1 nếu cần debug / recovery.

---

## Branch

Hỗ trợ NR3053 và VHT-32X6 nằm trên branch **`25.12`** (branch này).

---

## Upstream & ghi công

- Repo gốc: [chasey-dev/immortalwrt-mt798x-rebase](https://github.com/chasey-dev/immortalwrt-mt798x-rebase)
- Nền: [ImmortalWrt](https://immortalwrt.org/) + MTK OpenWrt feeds
- Tham khảo thêm mục **About External Devices HNAT** và commit cutoff trong lịch sử README upstream

---

## Đóng góp

- Bug / góp ý: mở Issue trên fork hoặc comment PR upstream (#50 / #51).
- Patch device nên gửi qua PR vào `chasey-dev:25.12`, giữ diff tách theo từng thiết bị.
