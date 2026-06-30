# ImmortalWrt MT798x — Fork hỗ trợ router Viettel

Fork từ [chasey-dev/immortalwrt-mt798x-rebase](https://github.com/chasey-dev/immortalwrt-mt798x-rebase) (branch `25.12`), bổ sung hỗ trợ **hai router WiFi 6 Viettel** chạy ImmortalWrt trên nền MediaTek MT7981.

---

## Router được hỗ trợ

| | **Viettel NR3053** | **Viettel 32X6** |
|---|---|---|
| SoC | MediaTek MT7981B | MediaTek MT7981B |
| RAM | 512 MB DDR3 | 128 MB DDR3 |
| Flash | 128 MB SPI-NAND (UBI) | 128 MB SPI-NAND (UBI) |
| Cổng LAN | 3 × LAN + 1 × WAN | 2 × LAN + 1 × WAN |
| USB | Không | Không |
| LED | Đỏ không có WAN carrier / xanh có carrier (một màu) | Giống NR3053 (không ping, không TX) |
| IP LAN mặc định | `192.168.1.1` | `192.168.1.1` |
| Trạng thái test | Đã test trên phần cứng | Đã test trên phần cứng |

---

## Cấu trúc nhánh

| Nhánh | Mục đích |
|-------|----------|
| **`main`** | Fork đầy đủ: cả hai router, band steering (`bndstrg`), README/docs tiếng Việt — **dùng để build flash** |
| **`25.12`** | Mirror [chasey-dev/immortalwrt-mt798x-rebase](https://github.com/chasey-dev/immortalwrt-mt798x-rebase) (`25.12`), không patch Viettel |

NR3053 và 32X6 đã merge vào upstream (`chasey-dev:25.12`). Các nhánh PR cũ (`viettel-nr3053`, `viettel-32x6`) đã xóa — không còn cần thiết.

---

## Đồng bộ upstream

Fork `main` định kỳ merge từ [chasey-dev/25.12](https://github.com/chasey-dev/immortalwrt-mt798x-rebase/tree/25.12). Một số file fork **cố ý khác upstream** (LED DTS, `DEVICE_PACKAGES`, README) nên đã được tách riêng để tránh conflict mỗi lần sync.

**Cách sync (khuyến nghị):**

```bash
git checkout main
./scripts/sync-upstream.sh          # mặc định: remote origin, branch 25.12
# hoặc chỉ định remote/branch khác:
./scripts/sync-upstream.sh origin 25.12
git push quytttb main
```

Script sẽ đăng ký merge driver `merge=ours`, fetch upstream, merge, và báo lỗi nếu còn conflict chưa giải quyết.

**File fork-only cần biết:**

| File | Vai trò |
|------|---------|
| `target/linux/mediatek/dts-ext/mt7981b-viettel-32x6.dts` | LED layout fork (tích hợp `viettel-wan-led.sh`) |
| `target/linux/mediatek/dts-ext/mt7981b-viettel-nr3053.dts` | LED layout fork (`nr3053:green` / `nr3053:red`) |
| `target/linux/mediatek/image/filogic-ext-viettel-fork.mk` | `DEVICE_PACKAGES` riêng cho NR3053 và 32X6 |
| `.gitattributes` | `merge=ours` cho 2 DTS + README — **không phải** `.gitignore`; file vẫn track và CI build bình thường |

`filogic-ext.mk` giữ định nghĩa device theo upstream (không `DEVICE_PACKAGES`). File `filogic-ext-viettel-fork.mk` load sau (thứ tự alphabet) và override khi build.

**Lưu ý khi upstream sửa Viettel:** nếu upstream đổi partition layout, image format, hoặc artifact của NR3053/32X6, cần cập nhật thủ công `filogic-ext-viettel-fork.mk`. Nếu upstream fix bug trong DTS (MAC, partition, EEPROM), kiểm tra diff upstream và cherry-pick hunk cần thiết — `.gitattributes` sẽ giữ bản fork khi merge.

---

## Tải bản đã build (Release)

Nếu bạn không muốn tự build, có thể tải firmware được build tự động (có sẵn giao diện hiện đại như Aurora) tại trang **[Releases](../../releases)** của repository.
Mỗi bản release sẽ có đầy đủ các file `.itb` cần thiết để cài đặt.

---

## Build firmware

Build firmware đầy đủ tính năng từ branch **`main`**.

Yêu cầu: Linux, đủ RAM/disk cho OpenWrt build; lần đầu cần cập nhật feeds theo hướng dẫn upstream.

```bash
git clone https://github.com/quytttb/immortalwrt-mt798x-rebase.git
cd immortalwrt-mt798x-rebase
git checkout main
./scripts/feeds update -a && ./scripts/feeds install -a   # lần đầu
```

Chọn target và device trong menuconfig, rồi build:

```bash
# Khuyến nghị: chỉ build NR3053 + 32X6 (dùng trong CI)
cp defconfig/viettel-only.config .config
make defconfig
make -j$(nproc)
```

Hoặc dùng defconfig đầy đủ nhiều thiết bị (build lâu hơn):

```bash
cp defconfig/mt7981-ax3000.config .config
make defconfig
make menuconfig
# Target System → MediaTek ARM
# Subtarget → Filogic
# Target Profile → Viettel NR3053 hoặc Viettel 32X6
make -j$(nproc)
```

Chỉ chạy bước tạo file image (nhanh hơn lệnh `make` ở trên vì bỏ qua việc biên dịch lại package). Lưu ý lệnh này sẽ đóng gói file cho **tất cả** các device đang được chọn trong `.config`:

```bash
make target/linux/install V=s TARGET=mediatek SUBTARGET=filogic DEVICE=viettel_nr3053
# hoặc DEVICE=viettel_32x6
```

**Artifact** (`bin/targets/mediatek/filogic/`):

| Router | `<device>` trong tên file |
|--------|---------------------------|
| NR3053 | `viettel_nr3053` |
| 32X6 | `viettel_32x6` |

```
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

## Upstream & ghi công

- Repo gốc: [chasey-dev/immortalwrt-mt798x-rebase](https://github.com/chasey-dev/immortalwrt-mt798x-rebase)
- Nền: [ImmortalWrt](https://immortalwrt.org/) + MTK OpenWrt feeds
- Tham khảo thêm mục **About External Devices HNAT** và commit cutoff trong lịch sử README upstream

---

## Đóng góp

- Bug / góp ý: mở Issue trên fork hoặc comment PR upstream (#50 / #51).
- Patch upstream: tạo nhánh mới từ `origin/25.12` → PR vào `chasey-dev:25.12`, mỗi PR một thiết bị.
- Tính năng fork (bndstrg, v.v.): chỉ trên `main`.

