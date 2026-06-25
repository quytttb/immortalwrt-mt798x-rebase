# Hướng dẫn nạp firmware ImmortalWrt — Viettel NR3053 & VHT-32X6

**Branch:** `25.12` — `mediatek/filogic` — kernel 6.12 — MTK mt_wifi  
**Build tree:** thư mục gốc repo (sau khi `git clone` fork này)

> Tài liệu dành cho fork [quytttb/immortalwrt-mt798x-rebase](https://github.com/quytttb/immortalwrt-mt798x-rebase).  
> Firmware build nằm tại `bin/targets/mediatek/filogic/`.

---

## Mục lục

- [Chuẩn bị chung](#chuẩn-bị-chung)
- [Viettel NR3053](#viettel-nr3053)
  - [Tuỳ chọn A — Boot RAM (test, không ghi NAND)](#nr3053-tuỳ-chọn-a--boot-ram-test-không-ghi-nand)
  - [Tuỳ chọn B — Cài đặt vĩnh viễn vào NAND](#nr3053-tuỳ-chọn-b--cài-đặt-vĩnh-viễn-vào-nand)
- [Viettel VHT-32X6V1](#viettel-vht-32x6v1)
  - [Tuỳ chọn A — Boot RAM (test, không ghi NAND)](#32x6-tuỳ-chọn-a--boot-ram-test-không-ghi-nand)
  - [Tuỳ chọn B — Cài đặt vĩnh viễn vào NAND](#32x6-tuỳ-chọn-b--cài-đặt-vĩnh-viễn-vào-nand)
- [Cập nhật U-Boot (nâng cấp từ ROM khác)](#cập-nhật-u-boot-nâng-cấp-từ-rom-khác)
- [Gỡ lỗi](#gỡ-lỗi)

---

## Chuẩn bị chung

### Phần cứng

| Thiết bị | Cáp |
|---|---|
| Máy tính | Ethernet (LAN) + cáp UART 3.3 V (TTL) nếu cần debug |
| Router | Cáp mạng cắm vào **cổng LAN bất kỳ** |

> **Không cắm WAN** trong khi nạp firmware qua TFTP.

### Phần mềm — TFTP server

Cài `tftpd-hpa` (Linux) hoặc `Tftpd64` (Windows).

```bash
# Ubuntu/Debian
sudo apt install tftpd-hpa
# Đặt thư mục phục vụ, thường /srv/tftp hoặc /var/lib/tftpboot
```

Sao chép các file firmware cần dùng vào thư mục TFTP.

### Địa chỉ IP mặc định của U-Boot

| Vai trò | Địa chỉ |
|---|---|
| Router U-Boot (ipaddr) | `192.168.1.1` (cả VHT-32X6 và NR3053 khi nạp TFTP) |
| TFTP server (serverip) | `192.168.1.254` |
| LAN sau boot (Linux) | `192.168.2.1` (VHT-32X6) / `192.168.10.1` (NR3053) |

Trên laptop dùng NetworkManager: profile **TFTP** = `192.168.1.254/24` (cố định, bật khi nạp firmware); profile **wired** = DHCP (dùng hàng ngày). Chuyển profile trong GUI hoặc `nmcli connection up TFTP` / `nmcli connection up wired`.

### UART — đọc log và gửi lệnh

Cài `picocom` (Linux) hoặc dùng PuTTY/Tera Term (Windows), baud **115200 8N1**, cáp TTL **3.3 V**:

```bash
# Ubuntu/Debian
sudo apt install picocom

# Mở cổng serial (thường /dev/ttyUSB0 hoặc /dev/ttyACM0)
picocom -b 115200 /dev/ttyUSB0
```

- Đọc log boot, nhấn **phím bất kỳ** khi thấy `Hit any key to stop autoboot`.
- Gõ lệnh U-Boot trực tiếp trong cửa sổ picocom (ví dụ `bootmenu`, `printenv`).
- **Thoát picocom:** `Ctrl+A` rồi `Ctrl+X`.
- **Đóng picocom** trước khi chạy `mtk_uartboot` — cổng serial chỉ dùng được bởi một process.

Cấp quyền serial (nếu cần): `sudo usermod -aG dialout $USER` rồi đăng xuất/đăng nhập lại.

### Vào U-Boot bootmenu

1. Trong picocom, nhấn **phím bất kỳ** khi thấy `Hit any key to stop autoboot`.
2. Gõ `bootmenu` và Enter — menu hiện ra với banner ImmortalWrt, ví dụ:  
   `U-Boot 2025.10-ImmortalWrt-r38075-58bfd4af73 (Jun 06 2026 - ...)`
3. Điều hướng: **↑/↓** chọn mục, **Enter** xác nhận, **Esc** thoát.

**Bảng bootmenu** (số hiển thị trên màn hình — dùng đúng số này khi chọn):

| # | Mục menu | Dùng khi |
|---|---|---|
| **1** | Run default boot command | Boot theo cấu hình mặc định |
| **2** | Boot system via TFTP | **Tuỳ chọn A** — test initramfs, không ghi NAND |
| **3** | Boot production system from NAND | Boot firmware đã cài |
| **4** | Boot recovery system from NAND | Khôi phục từ volume recovery |
| **5** | Load production system via TFTP then write to NAND | **Tuỳ chọn B** — cài firmware chính |
| **6** | Load recovery system via TFTP then write to NAND | Ghi recovery vào NAND (tuỳ chọn) |
| **7** | Load BL31+U-Boot FIP via TFTP then write to NAND | Nâng cấp FIP — **rủi ro** (chữ đỏ) |
| **8** | Load BL2 preloader via TFTP then write to NAND | Nâng cấp BL2 — **rủi ro cao** (chữ đỏ) |
| **9** | Reboot | Khởi động lại |
| **a** | Reset all settings to factory defaults | Xoá cấu hình U-Boot |
| **0** | Exit | Thoát menu, về prompt U-Boot |

> **Lần đầu** sau khi ghi firmware mới, mục **[1]** có thể là `Initialize environment` (chạy `_firstboot` — đọc MAC Factory, tạo env). Sau khi hoàn tất, mục **[1]** đổi thành `Run default boot command` như bảng trên.

### Bộ công cụ UART — `mtk_uart/` (ngoài repo)

Dùng trong **Tuỳ chọn A** khi không vào được U-Boot (treo BROM, không có prompt autoboot).  
Công cụ `mtk_uartboot` thường đặt ở thư mục riêng cạnh repo clone (ví dụ `../mtk_uart/`).

| File | Board |
|---|---|
| `mtk_uart/mtk_uartboot` | Host tool |
| `mtk_uart/bl2_ram.bin` | NR3053 — BL2 RAM payload |
| `mtk_uart/bl2-mt7981-bga-ddr3-ram.bin` | VHT-32X6 — BL2 RAM payload |
| `mtk_uart/fip/immortalwrt-mediatek-filogic-viettel_nr3053-bl31-uboot.fip` | NR3053 FIP |
| `mtk_uart/fip/immortalwrt-mediatek-filogic-vht_32x6-bl31-uboot.fip` | 32X6 FIP |

---

## Viettel NR3053

### Thông tin phân vùng (U-Boot, NAND 256 MB)

| Phân vùng | Offset | Kích thước | Ghi chú |
|---|---|---|---|
| BL2 | `0x000000` | 1 MB | Preloader SPL |
| u-boot-env | `0x100000` | 1 MB | Biến môi trường U-Boot |
| Factory | `0x200000` | 2 MB | Calibration data, MAC |
| FIP | `0x400000` | 2 MB | ATF BL31 + U-Boot |
| **ubi** | `0x600000` | ~234 MB | Toàn bộ rootfs/kernel |

### File firmware

| File | Dùng cho |
|---|---|
| `immortalwrt-mediatek-filogic-viettel_nr3053-initramfs-recovery.itb` | Boot RAM / recovery |
| `immortalwrt-mediatek-filogic-viettel_nr3053-squashfs-sysupgrade.itb` | Cài đặt vĩnh viễn |
| `immortalwrt-mediatek-filogic-viettel_nr3053-bl31-uboot.fip` | Nâng cấp U-Boot |
| `immortalwrt-mediatek-filogic-viettel_nr3053-preloader.bin` | Nâng cấp BL2 (rủi ro cao) |

---

### NR3053 Tuỳ chọn A — Boot RAM (test, không ghi NAND)

Chạy firmware **hoàn toàn trong RAM**, không động đến NAND.  
Phù hợp để kiểm thử trước khi cài chính thức.

#### Bước 1 — Vào U-Boot

Mở picocom để theo dõi log và gửi lệnh:

```bash
picocom -b 115200 /dev/ttyUSB0
```

**A1 — U-Boot chạy bình thường**

1. Bật nguồn router (cáp LAN đã cắm).
2. Trong picocom, nhấn **phím bất kỳ** khi thấy `Hit any key to stop autoboot`.
3. Gõ `bootmenu` hoặc các lệnh U-Boot ở bước 2.

**A2 — Brick / không vào U-Boot (mtk_uartboot)**

Dùng khi chỉ thấy log BootROM hoặc im lặng — không có dòng autoboot.

1. **Đóng picocom** (cổng serial cần trống).
2. Chạy:

```bash
cd ../mtk_uart
chmod +x mtk_uartboot

# Rút nguồn router, giữ terminal sẵn sàng
sudo ./mtk_uartboot --serial /dev/ttyUSB0 \
  --payload bl2_ram.bin \
  --fip fip/immortalwrt-mediatek-filogic-viettel_nr3053-bl31-uboot.fip \
  --aarch64
```

3. Khi tool báo handshake, **cắm nguồn** (hoặc nhấn reset).
4. Mở lại picocom: `picocom -b 115200 /dev/ttyUSB0` — đợi prompt U-Boot.

> `mtk_uartboot` chỉ boot U-Boot **trong RAM**, không ghi NAND. Rút điện → router boot lại từ NAND cũ.

#### Bước 2 — Boot initramfs từ TFTP

**Đặt file TFTP:**
```
immortalwrt-mediatek-filogic-viettel_nr3053-initramfs-recovery.itb
```

**Cách 1 — Qua bootmenu (khuyến nghị)**

Trong picocom, gõ `bootmenu`, dùng **↑/↓** chọn mục **[2] Boot system via TFTP**, nhấn **Enter**.

U-Boot tự tải `initramfs-recovery.itb` từ TFTP rồi boot — không ghi gì vào NAND.

**Cách 2 — Lệnh thủ công trong U-Boot**

Gõ trực tiếp trong picocom:

```
setenv serverip 192.168.1.254
setenv ipaddr   192.168.1.1
tftpboot 0x46000000 immortalwrt-mediatek-filogic-viettel_nr3053-initramfs-recovery.itb
bootm 0x46000000#config-1
```

**Kết quả:**  
Hệ thống khởi động vào ImmortalWrt từ RAM. Tắt nguồn → thiết bị trở về trạng thái ban đầu.

---

### NR3053 Tuỳ chọn B — Cài đặt vĩnh viễn vào NAND

> ⚠️ **Lưu ý quan trọng — Native UBI vs NMBM:**  
> NR3053 V2 dùng **Native UBI** (không có lớp NMBM).  
> Nếu thiết bị hiện đang chạy firmware có NMBM (V1 stock), phân vùng UBI cũ sẽ bị xoá và tạo lại — dữ liệu cũ mất hết. Đây là hành động **không thể hoàn tác**.

**Đặt file TFTP:**
```
immortalwrt-mediatek-filogic-viettel_nr3053-squashfs-sysupgrade.itb
```

**Cách 1 — Qua bootmenu (khuyến nghị)**

1. Trong picocom, gõ `bootmenu`, chọn mục **[5] Load production system via TFTP then write to NAND**.
2. U-Boot tải `bootfile_upg` (`squashfs-sysupgrade.itb`) từ TFTP, ghi vào UBI volume `fit`, rồi tự boot.

**Cách 2 — Lệnh thủ công trong U-Boot**

```
setenv serverip 192.168.1.254
setenv ipaddr   192.168.1.1

# Tải sysupgrade
tftpboot 0x46000000 immortalwrt-mediatek-filogic-viettel_nr3053-squashfs-sysupgrade.itb

# Gắn phân vùng UBI
ubi part ubi

# Xoá volume cũ (nếu có) và ghi
ubi check fit && ubi remove fit
ubi create fit $filesize dynamic
ubi write 0x46000000 fit $filesize

# Khởi động
ubi read 0x46000000 fit && bootm 0x46000000#config-1
```

**Cài đặt recovery (tuỳ chọn — cho phép khôi phục từ NAND sau này):**

Đặt file `initramfs-recovery.itb` vào TFTP, trong bootmenu chọn **[6] Load recovery system via TFTP then write to NAND**.

Hoặc lệnh thủ công:

```
tftpboot 0x46000000 immortalwrt-mediatek-filogic-viettel_nr3053-initramfs-recovery.itb

ubi check recovery && ubi remove recovery
ubi create recovery $filesize dynamic
ubi write 0x46000000 recovery $filesize
```

**Khởi động lần đầu sau cài đặt:**  
Lần đầu U-Boot chạy `_firstboot`: đọc MAC từ Factory (`offset 0x4`), khởi tạo env. Trong bootmenu chọn **[1] Initialize environment**, hoặc để tự boot. Lần sau mục **[1]** sẽ là `Run default boot command`.

---

## Viettel VHT-32X6V1

> **GPIO LED thực tế (đã verify):** Power/WPS GPIO 5, Internet GPIO **9** (không phải 8), WiFi 2.4G/5G GPIO 34/35. Không có cổng USB (giống NR3053).

### Thông tin phân vùng (U-Boot, NAND 128 MB)

| Phân vùng | Offset | Kích thước | Ghi chú |
|---|---|---|---|
| BL2 | `0x000000` | 1 MB | Preloader SPL |
| u-boot-env | `0x100000` | 512 KB | Biến môi trường U-Boot |
| Factory | `0x180000` | 2 MB | Calibration data, MAC (`0x24`/`0x2a`) |
| FIP | `0x380000` | 2 MB | ATF BL31 + U-Boot |
| **ubi** | `0x580000` | ~122 MB | Toàn bộ rootfs/kernel |

### File firmware

| File | Dùng cho |
|---|---|
| `immortalwrt-mediatek-filogic-vht_32x6-initramfs-recovery.itb` | Boot RAM / recovery |
| `immortalwrt-mediatek-filogic-vht_32x6-squashfs-sysupgrade.itb` | Cài đặt vĩnh viễn |
| `immortalwrt-mediatek-filogic-vht_32x6-bl31-uboot.fip` | Nâng cấp U-Boot |
| `immortalwrt-mediatek-filogic-vht_32x6-preloader.bin` | Nâng cấp BL2 (rủi ro cao) |

---

### 32X6 Tuỳ chọn A — Boot RAM (test, không ghi NAND)

Chạy firmware **hoàn toàn trong RAM**, không động đến NAND.

#### Bước 1 — Vào U-Boot

Mở picocom để theo dõi log và gửi lệnh:

```bash
picocom -b 115200 /dev/ttyUSB0
```

**A1 — U-Boot chạy bình thường**

1. Bật nguồn router (cáp LAN đã cắm).
2. Trong picocom, nhấn **phím bất kỳ** khi thấy `Hit any key to stop autoboot`.
3. Gõ `bootmenu` hoặc các lệnh U-Boot ở bước 2.

**A2 — Brick / không vào U-Boot (mtk_uartboot)**

Dùng khi chỉ thấy log BootROM hoặc im lặng — không có dòng autoboot.

1. **Đóng picocom** (cổng serial cần trống).
2. Chạy:

```bash
cd ../mtk_uart
chmod +x mtk_uartboot

sudo ./mtk_uartboot --serial /dev/ttyUSB0 \
  --payload bl2-mt7981-bga-ddr3-ram.bin \
  --fip fip/immortalwrt-mediatek-filogic-vht_32x6-bl31-uboot.fip \
  --aarch64
```

3. Khi tool báo handshake, **cắm nguồn** (hoặc nhấn reset).
4. Mở lại picocom: `picocom -b 115200 /dev/ttyUSB0` — đợi prompt U-Boot.

> `mtk_uartboot` chỉ boot U-Boot **trong RAM**, không ghi NAND. **Không dùng** payload/FIP của NR3053.

#### Bước 2 — Boot initramfs từ TFTP

**Đặt file TFTP:**
```
immortalwrt-mediatek-filogic-vht_32x6-initramfs-recovery.itb
```

**Cách 1 — Qua bootmenu (khuyến nghị)**

Trong picocom, gõ `bootmenu`, chọn mục **[2] Boot system via TFTP**, nhấn **Enter**.

**Cách 2 — Lệnh thủ công trong U-Boot**

Gõ trực tiếp trong picocom:

```
setenv serverip 192.168.1.254
setenv ipaddr   192.168.1.1
tftpboot 0x46000000 immortalwrt-mediatek-filogic-vht_32x6-initramfs-recovery.itb
bootm 0x46000000#config-1
```

**Kết quả:**  
ImmortalWrt boot từ RAM. LED WPS bật khi boot. Tắt nguồn → thiết bị trở về ban đầu.

---

### 32X6 Tuỳ chọn B — Cài đặt vĩnh viễn vào NAND

**Đặt file TFTP:**
```
immortalwrt-mediatek-filogic-vht_32x6-squashfs-sysupgrade.itb
```

**Cách 1 — Qua bootmenu (khuyến nghị)**

1. Trong bootmenu, chọn mục **[5] Load production system via TFTP then write to NAND**.

**Cách 2 — Lệnh thủ công**

```
setenv serverip 192.168.1.254
setenv ipaddr   192.168.1.1

tftpboot 0x46000000 immortalwrt-mediatek-filogic-vht_32x6-squashfs-sysupgrade.itb

ubi part ubi
ubi check fit && ubi remove fit
ubi create fit $filesize dynamic
ubi write 0x46000000 fit $filesize

ubi read 0x46000000 fit && bootm 0x46000000#config-1
```

**Cài đặt recovery (tuỳ chọn):**

Bootmenu **[6] Load recovery system via TFTP then write to NAND**, hoặc lệnh thủ công:

```
tftpboot 0x46000000 immortalwrt-mediatek-filogic-vht_32x6-initramfs-recovery.itb

ubi check recovery && ubi remove recovery
ubi create recovery $filesize dynamic
ubi write 0x46000000 recovery $filesize
```

**Khởi động lần đầu:**  
U-Boot đọc MAC từ Factory (`offset 0x24` cho eth0 WAN, `0x2a` cho LAN), khởi tạo env UBI, bật LED WPS.

---

## Nạp firmware qua SSH từ ROM gốc (Không cần tháo vỏ)

Nếu thiết bị của bạn đang chạy firmware gốc của Viettel và bạn không muốn tháo vỏ để hàn UART, bạn có thể áp dụng phương pháp mở khoá SSH bằng phần mềm để nạp firmware.

### Bước 1 — Mở khoá SSH

1. Kết nối PC vào cổng LAN của router.
2. **Factory reset** router (nhấn giữ nút Reset >10 giây cho đến khi đèn tắt rồi sáng lại). Mật khẩu admin trang web lúc này sẽ là Serial Number (S/N) in dưới đáy router.
3. Chạy script mở khoá SSH (nằm trong thư mục `scripts/unlock/` của repo):
   ```bash
   pip3 install requests
   python3 scripts/unlock/unlock_viettel.py --password SERIAL_NUMBER_CUA_BAN
   ```
4. Đợi script chạy xong và router khởi động lại, bạn sẽ có quyền truy cập SSH:
   ```bash
   ssh root@192.168.1.1
   # Mật khẩu: admin
   ```

### Bước 2 — Hiểu sự khác biệt partition layout (quan trọng!)

> ⚠️ **Cực kỳ quan trọng:** Layout phân vùng của ROM gốc Viettel **khác hoàn toàn** với ImmortalWrt ở phần OS/firmware. Không thể dùng `sysupgrade` trực tiếp vì ROM gốc dùng `firmware`/`firmware2` kiểu flat, còn ImmortalWrt dùng UBI volumes.

ROM gốc Viettel và ImmortalWrt dùng **cùng địa chỉ vật lý** cho BL2/FIP (bootloader), nhưng tổ chức phần OS hoàn toàn khác:

| Offset NAND | ROM gốc Viettel (NR3053) | ImmortalWrt |
|---|---|---|
| `0x000000` – `0x100000` | `BL2` (mtd1) | `BL2` (mtd0) |
| `0x100000` – `0x200000` | `u-boot-env` (mtd2) | `u-boot-env` (mtd1) |
| `0x200000` – `0x400000` | `Factory` (mtd3) ← **KHÔNG GHI** | `Factory` (mtd2) ← **KHÔNG GHI** |
| `0x400000` – `0x600000` | `FIP` (mtd4) ← cùng offset vật lý | `FIP` (mtd3) ← cùng offset vật lý |
| `0x600000` → hết NAND | `firmware` (32MB) + `firmware2` (32MB) + các vùng khác | `ubi` (~234MB) — toàn bộ hệ điều hành |

**Chiến lược:** Ghi FIP mới (U-Boot ImmortalWrt) vào đúng offset `0x400000` từ SSH của ROM gốc → reboot → U-Boot mới chạy → vào Web Failsafe → flash `sysupgrade.itb` qua HTTP (U-Boot sẽ tự định dạng lại vùng UBI).

Xác nhận layout từ SSH vào ROM gốc:

```bash
cat /proc/mtd
```

Kết quả điển hình ROM gốc NR3053:
```
dev:    size   erasesize  name
mtd0: 10000000 00020000 "spi0.0"     ← Raw toàn bộ NAND 256MB
mtd1: 00100000 00020000 "BL2"
mtd2: 00100000 00020000 "u-boot-env"
mtd3: 00200000 00020000 "Factory"    ← TUYỆT ĐỐI KHÔNG GHI
mtd4: 00200000 00020000 "FIP"        ← Ghi FIP mới vào đây
mtd5: 02000000 00020000 "firmware"
mtd6: 02000000 00020000 "firmware2"
mtd7: 08e00000 00020000 "rootfs_data"
...
```

### Bước 3 — Ghi U-Boot ImmortalWrt vào NAND

Copy file FIP đúng thiết bị từ PC sang router:

```bash
# Chạy lệnh này trên PC (không phải trong SSH của router)
# NR3053:
scp -O immortalwrt-mediatek-filogic-viettel_nr3053-bl31-uboot.fip root@192.168.1.1:/tmp/fip.bin

# VHT-32X6:
scp -O immortalwrt-mediatek-filogic-vht_32x6-bl31-uboot.fip root@192.168.1.1:/tmp/fip.bin
```

> Nếu `scp` báo lỗi option `-O`, bỏ cờ đó đi.

Từ **SSH vào router**, ghi FIP. Vì ROM gốc NR3053 có MTD tên `FIP` — có thể dùng trực tiếp:

```bash
# Xác nhận mtd4 là FIP (kích thước 0x200000 = 2097152 bytes)
cat /proc/mtd | grep FIP

# Ghi FIP ImmortalWrt vào phân vùng FIP
mtd write /tmp/fip.bin FIP
```

Kết quả thành công:
```
Unlocking FIP ...
Writing from /tmp/fip.bin to FIP ...     [w]
```

> **Nếu ROM gốc của thiết bị không có MTD tên `FIP`** (kiểm tra `cat /proc/mtd`), dùng lệnh `dd` ghi theo offset vật lý. Offset FIP = `0x400000`, erase block = `0x20000` (128KB) → `seek = 0x400000 / 0x20000 = 32`:
> ```bash
> # Ghi raw vào NAND tại offset 0x400000 (bỏ qua BL2 + env + Factory)
> dd if=/tmp/fip.bin of=/dev/mtd0 bs=131072 seek=32 conv=sync
> ```

Sau khi ghi xong, reboot:

```bash
sync && reboot
```

### Bước 4 — Cài firmware ImmortalWrt qua Web Failsafe

Sau khi reboot, router chạy **U-Boot ImmortalWrt**. Do vùng NAND chưa có hệ điều hành hợp lệ theo định dạng UBI của ImmortalWrt, U-Boot sẽ tự động vào chế độ **Web Failsafe**.

> ⚠️ **Địa chỉ IP TFTP server:** U-Boot ImmortalWrt mặc định dùng `serverip = 192.168.1.254` (khác với `192.168.1.2` mà một số hướng dẫn khác dùng). Đặt IP PC là `192.168.1.254`.

1. Đặt IP tĩnh cho card mạng PC: **`192.168.1.254/24`**

   ```bash
   # Linux
   sudo ip addr add 192.168.1.254/24 dev eth0
   sudo ip link set eth0 up
   ```

2. Mở trình duyệt, vào **`http://192.168.1.1/`** — giao diện **"FIRMWARE UPDATE"** sẽ hiện ra.

3. Chọn file `*-squashfs-sysupgrade.itb` đúng thiết bị:
   - NR3053: `immortalwrt-mediatek-filogic-viettel_nr3053-squashfs-sysupgrade.itb`
   - VHT-32X6: `immortalwrt-mediatek-filogic-vht_32x6-squashfs-sysupgrade.itb`

4. Bấm **Upload → Update**. Đợi ~3 phút. Router tự reboot vào ImmortalWrt.

> **Nếu không vào được Web Failsafe:** Ping thử `ping 192.168.1.1`. Nếu không ping được nghĩa là FIP ghi sai (sai thiết bị hoặc file bị lỗi). Cần UART để debug, hoặc thử lại từ Bước 3 với cách ghi `dd` raw.

---


## Cập nhật U-Boot (nâng cấp từ ROM khác)

> ⚠️ Rủi ro cao — brick thiết bị nếu file sai. Chỉ làm khi chắc chắn U-Boot cũ không tương thích.

### Nâng cấp FIP (ATF BL31 + U-Boot) — an toàn hơn

```
# NR3053
tftpboot 0x46000000 immortalwrt-mediatek-filogic-viettel_nr3053-bl31-uboot.fip
mtd erase FIP
mtd write FIP 0x46000000

# VHT-32X6
tftpboot 0x46000000 immortalwrt-mediatek-filogic-vht_32x6-bl31-uboot.fip
mtd erase FIP
mtd write FIP 0x46000000
```

Hoặc trong bootmenu chọn **[7] Load BL31+U-Boot FIP via TFTP then write to NAND** (mục chữ đỏ).

### Nâng cấp BL2 Preloader — rất rủi ro

```
# NR3053
tftpboot 0x46000000 immortalwrt-mediatek-filogic-viettel_nr3053-preloader.bin
mtd erase BL2
mtd write BL2 0x46000000
```

Hoặc trong bootmenu chọn **[8] Load BL2 preloader via TFTP then write to NAND** (mục chữ đỏ).

---

## Gỡ lỗi

### mtk_uartboot — handshake timeout / không kết nối

- Kiểm tra TX/RX **đã đảo** (TX adapter ↔ RX board).
- Đúng mức **3.3 V**, không dùng 5 V.
- Thử cổng khác: `/dev/ttyUSB0`, `/dev/ttyUSB1`, `/dev/ttyACM0`.
- Chạy `mtk_uartboot` **trước**, rồi mới cắm nguồn hoặc nhấn reset.
- Đóng `picocom` / `minicom` trước khi chạy `mtk_uartboot` (cổng serial chỉ một process).
- NR3053 dùng `bl2_ram.bin`; 32X6 dùng `bl2-mt7981-bga-ddr3-ram.bin` — không đổi chéo.

### TFTP timeout / không tải được file

- Kiểm tra TFTP server đang chạy và lắng nghe UDP 69.
- Đặt IP máy tính `192.168.1.254`, không dùng máy tính khác cùng subnet.
- Xác nhận tên file trong thư mục TFTP **khớp chính xác** với tên trong bảng trên.
- Trong U-Boot kiểm tra: `printenv serverip ipaddr`.

### Sau cài đặt, thiết bị không khởi động được

1. Vào bootmenu, chọn **[4] Boot recovery system from NAND** — nếu đã cài recovery.
2. Nếu recovery chưa có, dùng Tuỳ chọn A để boot initramfs từ TFTP.
3. Trong initramfs, chạy `firstboot` hoặc xoá partition từ CLI.

### Reset về mặc định

Từ U-Boot bootmenu, chọn **[a] Reset all settings to factory defaults**.

Hoặc lệnh thủ công:
```
run reset_factory
reset
```

### NR3053 — cảnh báo NMBM cũ

Nếu thiết bị trước đây dùng firmware có NMBM, khi lần đầu boot initramfs V2, chạy:
```sh
# Trong ImmortalWrt initramfs shell
ubirmvol /dev/ubi0 -N rootfs_data 2>/dev/null
ubirename /dev/ubi0 fit fit
```
Nếu UBI không nhận do bảng NMBM cũ, cần xoá toàn bộ phân vùng `ubi` từ U-Boot:
```
ubi part ubi
run ubi_format
# Thiết bị sẽ reset, sau đó chạy lại cài đặt từ bước đầu
```

---

*Firmware sau build: `bin/targets/mediatek/filogic/`*  
*Cập nhật: 2026-06-08*
