# ImmortalWrt MT798x cho router Viettel

Firmware ImmortalWrt 25.12 cho **Viettel NR3053** và **Viettel 32X6**, dựa trên [chasey-dev/immortalwrt-mt798x-rebase](https://github.com/chasey-dev/immortalwrt-mt798x-rebase). Nhánh `main` là nhánh mặc định, dùng để build và phát hành firmware.

## Thiết bị hỗ trợ

| | Viettel NR3053 | Viettel 32X6 |
|---|---|---|
| SoC | MediaTek MT7981B | MediaTek MT7981B |
| RAM | 512 MB DDR3 | 128 MB DDR3 |
| Flash | 128 MB SPI-NAND (UBI) | 128 MB SPI-NAND (UBI) |
| Cổng mạng | 3 LAN + 1 WAN | 2 LAN + 1 WAN |
| IP LAN mặc định | `192.168.1.1` | `192.168.1.1` |
| Trạng thái | Đã test phần cứng | Đã test phần cứng |

## Dùng firmware có sẵn

Tải bản mới nhất tại [Releases](https://github.com/quytttb/immortalwrt-mt798x-rebase/releases), rồi chọn file **đúng model**.

| File | Mục đích |
|---|---|
| `*-squashfs-sysupgrade.itb` | Cài đặt hoặc nâng cấp vĩnh viễn |
| `*-initramfs-recovery.itb` | Boot qua TFTP để test hoặc recovery, không ghi NAND |
| `*-bl31-uboot.fip` | Nâng cấp U-Boot — tải từ [quytttb/bl-mt798x-dhcpd Releases](https://github.com/quytttb/bl-mt798x-dhcpd/releases) |
| `*-preloader.bin` | Nâng cấp BL2 — rủi ro cao, tải từ [quytttb/bl-mt798x-dhcpd Releases](https://github.com/quytttb/bl-mt798x-dhcpd/releases) |

> Không dùng file của NR3053 cho 32X6 hoặc ngược lại. Đọc [hướng dẫn nạp firmware](docs/huong-dan-nap-firmware.md) trước khi ghi NAND, FIP hoặc BL2.

## Điểm chính của bản fork

- LED WAN riêng cho từng board.
- Giao diện Aurora, TurboACC, UPnP, DDNS, WireGuard, Adblock và mặc định phù hợp Việt Nam.
- Band steering được hỗ trợ ở driver nhưng tắt mặc định (`BandSteering=0`) để không ép thiết bị khách đổi băng tần.
- NR3053 và 32X6 dùng toàn bộ UBI còn lại làm overlay. Không có volume `/mnt/storage` riêng; APK, cấu hình, log và file tải về đều ở overlay. Luôn chừa dung lượng trống cho hệ thống và nâng cấp.

## Build từ mã nguồn

Yêu cầu Ubuntu/Debian hoặc môi trường tương đương, đủ RAM và dung lượng đĩa cho OpenWrt.

```bash
git clone https://github.com/quytttb/immortalwrt-mt798x-rebase.git
cd immortalwrt-mt798x-rebase
bash scripts/install-deps.sh
bash scripts/build-viettel.sh
```

Build script chuẩn bị feeds, kiểm tra Aurora vendored, áp dụng bản dịch, defconfig hai thiết bị, tải source và build; artifact được chép vào `dist/`. Script kiểm tra đủ 8 file đặc thù hai board, xác minh `sha256sums` và sinh `dist/release-notes.md` từ artifact thực tế.

Để chỉ tạo image cho một thiết bị sau khi đã build package:

```bash
make target/linux/install V=s TARGET=mediatek SUBTARGET=filogic DEVICE=viettel_nr3053
# hoặc DEVICE=viettel_32x6
```

Kết quả gốc nằm trong `bin/targets/mediatek/filogic/`; luôn kiểm tra `sha256sums` trước khi nạp.

## Nạp và khôi phục

Hướng dẫn đầy đủ có TFTP, U-Boot bootmenu, UART, sysupgrade và recovery:

- [Nạp firmware](docs/huong-dan-nap-firmware.md)
- [Cấu hình WireGuard, DDNS và Adblock](docs/huong-dan-tinh-nang-mo-rong.md)
- [Nghiên cứu MediaTek EasyMesh cho NR3053](docs/trien-khai-mediatek-easymesh.md)

Quy trình an toàn: boot `initramfs-recovery.itb` qua TFTP để test trước, sau đó mới ghi `squashfs-sysupgrade.itb`. Chỉ nâng cấp FIP hoặc BL2 khi có lý do cụ thể và đã chuẩn bị đường recovery.

## Bootloader (U-Boot / BL2)

Source và release chính thức của file `*-bl31-uboot.fip` và `*-preloader.bin` nằm tại:

**[quytttb/bl-mt798x-dhcpd](https://github.com/quytttb/bl-mt798x-dhcpd)** — tải từ tab [Releases](https://github.com/quytttb/bl-mt798x-dhcpd/releases).

`scripts/build-viettel.sh` pin một commit của repo này, build FIP/BL2 một lần
sau firmware, rồi gom chúng vào `dist/`; source firmware không còn tự build
U-Boot/TF-A. BL2 RAM payload dùng cho `mtk_uartboot` cũng lấy từ repo đó.

## Đồng bộ upstream

Fork fetch trực tiếp từ [chasey-dev/25.12](https://github.com/chasey-dev/immortalwrt-mt798x-rebase/tree/25.12); không giữ nhánh mirror `25.12` riêng. Workflow **Sync Upstream** chạy mỗi thứ Hai lúc 10:17 giờ Việt Nam hoặc có thể chạy tay từ tab **Actions**.

Khi upstream có thay đổi, workflow merge vào nhánh PR riêng và tạo/cập nhật pull request, không tự merge vào `main`. DTS LED và README được bảo vệ bằng `merge=ours`; `DEVICE_PACKAGES` được tách ở file fork riêng. Vẫn cần review PR khi upstream đổi image layout, partition hoặc board files dùng chung. Nếu merge conflict, maintainer giải quyết bằng Git trên nhánh sync rồi mở PR.

## Đóng góp và ghi công

- Báo lỗi hoặc đề xuất tính năng: mở Issue trên fork.
- Patch chung cho upstream: tạo nhánh từ `chasey-dev/25.12`, mỗi PR chỉ cho một thiết bị.
- Tính năng riêng cho Viettel: phát triển trên `main`.

Nền tảng: [ImmortalWrt](https://immortalwrt.org/), MediaTek OpenWrt feeds và [chasey-dev/immortalwrt-mt798x-rebase](https://github.com/chasey-dev/immortalwrt-mt798x-rebase).
