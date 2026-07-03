# Hướng dẫn nạp firmware ImmortalWrt — Viettel NR3053 & 32X6

**Branch build:** `main` — `mediatek/filogic` — kernel 6.12 — MTK mt_wifi  
**Firmware:** tải từ [GitHub Releases](https://github.com/quytttb/immortalwrt-mt798x-rebase/releases) hoặc build local (`bin/targets/mediatek/filogic/`).

> Tài liệu dành cho fork [quytttb/immortalwrt-mt798x-rebase](https://github.com/quytttb/immortalwrt-mt798x-rebase).

---

## Mục lục

- [Chuẩn bị chung](#chuẩn-bị-chung)
  - [Linux](#linux)
  - [Windows](#windows)
- [Viettel NR3053](#viettel-nr3053)
  - [Tuỳ chọn A — Boot RAM (test, không ghi NAND)](#nr3053-tuỳ-chọn-a--boot-ram-test-không-ghi-nand)
  - [Tuỳ chọn B — Cài đặt vĩnh viễn vào NAND](#nr3053-tuỳ-chọn-b--cài-đặt-vĩnh-viễn-vào-nand)
- [Viettel 32X6](#viettel-32x6)
  - [Tuỳ chọn A — Boot RAM (test, không ghi NAND)](#32x6-tuỳ-chọn-a--boot-ram-test-không-ghi-nand)
  - [Tuỳ chọn B — Cài đặt vĩnh viễn vào NAND](#32x6-tuỳ-chọn-b--cài-đặt-vĩnh-viễn-vào-nand)
- [Nạp firmware qua SSH từ ROM gốc](#nạp-firmware-qua-ssh-từ-rom-gốc-không-cần-tháo-vỏ)
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

### Địa chỉ IP

| Giai đoạn | Vai trò | Địa chỉ |
|---|---|---|
| Nạp TFTP / Web Failsafe (U-Boot) | Router | `192.168.1.1` |
| Nạp TFTP / Web Failsafe (U-Boot) | PC (TFTP server) | `192.168.1.254` |
| Sau boot ImmortalWrt (Linux) | Router LAN | `192.168.1.1` (cả NR3053 và 32X6) |

> ROM gốc Viettel cũng dùng `192.168.1.1` trên LAN. ImmortalWrt fork giữ **`192.168.1.1`** — không phải `192.168.2.1` hay `192.168.10.1`.

### Linux

#### TFTP server

```bash
# Ubuntu/Debian
sudo apt install tftpd-hpa
sudo mkdir -p /srv/tftp
# Sửa /etc/default/tftpd-hpa: TFTP_DIRECTORY="/srv/tftp"
sudo systemctl restart tftpd-hpa
```

Sao chép file `.itb` / `.fip` / `.bin` vào thư mục TFTP.

**Đặt IP tĩnh** (thay `eth0` bằng tên interface thật — `ip link`):

```bash
sudo ip addr flush dev eth0
sudo ip addr add 192.168.1.254/24 dev eth0
sudo ip link set eth0 up
```

Hoặc dùng NetworkManager: profile **TFTP** = `192.168.1.254/24`, không gateway, không DNS.

#### UART (picocom)

```bash
sudo apt install picocom
picocom -b 115200 /dev/ttyUSB0   # hoặc /dev/ttyACM0
```

- Cấp quyền serial (nếu cần): `sudo usermod -aG dialout $USER` rồi đăng xuất/đăng nhập lại.
- **Thoát picocom:** `Ctrl+A` rồi `Ctrl+X`.

### Windows

#### TFTP server — Tftpd64

1. Tải **Tftpd64** (64-bit): https://p.junod.nu/tftpd64/
2. Giải nén và chạy `tftpd64.exe` **bằng quyền Administrator**.
3. Tab **Tftp Server**:
   - **Current Directory**: thư mục chứa file firmware (ví dụ `C:\tftp\`)
   - **Server interfaces**: chọn card mạng LAN đã gán IP `192.168.1.254` (không chọn `127.0.0.1`)
4. Sao chép file firmware vào thư mục đó (tên file **đúng từng ký tự**, ví dụ `immortalwrt-mediatek-filogic-viettel_nr3053-squashfs-sysupgrade.itb`).
5. Khi router boot TFTP, cửa sổ Tftpd64 sẽ hiện dòng transfer — nếu không thấy gì → kiểm tra IP / firewall.

> **Không dùng** Windows built-in TFTP client (`tftp.exe`) làm server — chỉ là client. Cần Tftpd64 hoặc phần mềm TFTP server khác.

#### Đặt IP tĩnh trên Windows

**Cách 1 — GUI (Windows 10/11):**

1. **Settings → Network & Internet → Ethernet** (cáp LAN đã cắm router).
2. **IP assignment → Edit → Manual → IPv4 On**
3. IP address: `192.168.1.254`
4. Subnet mask: `255.255.255.0`
5. Gateway: **để trống**
6. DNS: **để trống**
7. Save — tắt VPN nếu đang bật.

**Cách 2 — CMD (Admin):**

```cmd
netsh interface ip set address name="Ethernet" static 192.168.1.254 255.255.255.0
```

Đổi `"Ethernet"` thành tên adapter thật (`ncpa.cpl` → xem tên).

Sau khi xong, mở CMD: `ping 192.168.1.1` (khi router đã bật).

#### Windows Firewall

Cho phép **Tftpd64** qua firewall (UDP **69**, và UDP ephemeral cho TFTP data). Khi Windows hỏi lần đầu chạy Tftpd64 → chọn **Allow**.

Nếu TFTP timeout: tạm tắt firewall để thử, hoặc thêm rule inbound UDP 69.

#### UART — PuTTY (Serial)

**Chuẩn bị session PuTTY một lần** (dùng lại sau mỗi lần `mtk_uartboot`):

1. Cắm USB-TTL, cài driver (CH340/CP2102…) nếu Windows chưa nhận.
2. **Device Manager → Ports (COM & LPT)** → ghi nhớ số COM (ví dụ `COM3`).
3. Mở **PuTTY** (chưa cần Open):
   - **Connection type:** Serial
   - **Serial line:** `COM3` (đúng cổng của bạn)
   - **Speed:** `115200`
4. Menu trái: **Connection → Serial** — kiểm tra **Data bits** 8, **Stop bits** 1, **Parity** None, **Flow control** None.
5. Quay lại **Session** → nhập tên (ví dụ `Viettel-UART`) → **Save**.

> Cáp TTL **3.3 V** — TX/RX **đảo** (TX adapter → RX board).  
> Sau này chỉ cần chọn session `Viettel-UART` → **Open** (xem mục [mtk_uartboot trên Windows](#mtk_uartboot-trên-windows) — mở PuTTY **sau** khi chạy xong `mtk_uartboot.exe`).

#### mtk_uartboot trên Windows

Dùng khi router **không vào U-Boot** (chỉ BootROM / im lặng). Tool tải từ:  
https://github.com/981213/mtk_uartboot/releases (file `mtk_uartboot-v*-x86_64-pc-windows-msvc.zip`).

**Chuẩn bị thư mục** (ví dụ `C:\viettel-uart\`):

```
C:\viettel-uart\
├── mtk_uartboot.exe
├── mt7981-ram-ddr3-bl2.bin          ← BL2 RAM (xem bảng công cụ UART bên dưới)
└── immortalwrt-mediatek-filogic-viettel_nr3053-bl31-uboot.fip   ← đúng model (NR3053 hoặc 32X6)
```

**Thứ tự thao tác** (quan trọng — COM port chỉ một chương trình dùng được):

| Bước | Việc cần làm |
|------|----------------|
| 1 | **Đóng PuTTY** nếu đang mở (serial phải trống). |
| 2 | **Rút nguồn** router (chưa cắm adapter). |
| 3 | Mở **CMD** hoặc **PowerShell**, chạy `mtk_uartboot.exe` (xem lệnh bên dưới). |
| 4 | Khi thấy `Handshake...` → **cắm nguồn** router (hoặc nhấn nút Reset). |
| 5 | Đợi dòng **`FIP received`** (hoặc tool báo hoàn tất). |
| 6 | **`Ctrl+C`** đóng `mtk_uartboot` **ngay** (trong ~2–3 giây). |
| 7 | Mở **PuTTY** → chọn session **`Viettel-UART`** đã lưu → **Open**. |
| 8 | Thấy log U-Boot → nhấn **phím bất kỳ** khi `Hit any key to stop autoboot` → gõ `bootmenu`. |

**Lệnh CMD** (NR3053 — đổi tên file FIP cho 32X6):

```cmd
cd C:\viettel-uart
mtk_uartboot.exe -s COM3 --payload mt7981-ram-ddr3-bl2.bin --aarch64 --fip immortalwrt-mediatek-filogic-viettel_nr3053-bl31-uboot.fip
```

Thay `COM3` bằng COM thật trong Device Manager.

**32X6** — chỉ đổi file FIP:

```cmd
mtk_uartboot.exe -s COM3 --payload mt7981-ram-ddr3-bl2.bin --aarch64 --fip immortalwrt-mediatek-filogic-viettel_32x6-bl31-uboot.fip
```

> `mtk_uartboot` chỉ nạp U-Boot **vào RAM**, không ghi NAND. Rút điện → router boot lại firmware cũ trên flash.  
> Nếu bỏ lỡ bước 6–7 (không kịp mở PuTTY), router có thể treo hoặc boot tiếp — **rút nguồn** và chạy lại từ bước 1.

**WSL/Linux thay thế:** nếu không dùng `mtk_uartboot.exe`, có thể dùng bản Linux trong WSL2 (cần passthrough USB serial) — quy trình giống mục A2 bên dưới (`--serial /dev/ttyUSB0`).

#### Copy file qua SCP (mục SSH unlock)

Windows 10/11 có sẵn OpenSSH Client. Trong **PowerShell** hoặc **CMD**:

```powershell
scp immortalwrt-mediatek-filogic-viettel_nr3053-bl31-uboot.fip root@192.168.1.1:/tmp/fip.bin
```

Mật khẩu sau unlock: `admin`. Lần đầu chấp nhận host key (`yes`).

Nếu lỗi protocol, thử **WinSCP** (giao diện đồ họa) hoặc thêm `-O` (legacy SCP):

```powershell
scp -O immortalwrt-mediatek-filogic-viettel_nr3053-bl31-uboot.fip root@192.168.1.1:/tmp/fip.bin
```

#### Web Failsafe (trình duyệt)

Sau khi ghi FIP và reboot, đặt IP PC `192.168.1.254` như trên, mở trình duyệt:

```
http://192.168.1.1/
```

Upload file `*-squashfs-sysupgrade.itb`. Dùng Chrome/Edge/Firefox — không cần cài thêm phần mềm.

> ⚠️ **Lưu ý chung (Linux & Windows):** Phải **đóng picocom/PuTTY** trước khi chạy `mtk_uartboot` — cổng serial chỉ một phần mềm dùng được. Sau `FIP received` → **đóng mtk_uartboot** → **rồi mới** mở PuTTY/picocom.

- Đọc log boot: nhấn **phím bất kỳ** khi thấy dòng `Hit any key to stop autoboot`.
- Gõ lệnh U-Boot trực tiếp trong terminal (ví dụ `bootmenu`, `printenv`).

### Vào U-Boot bootmenu

1. Trong picocom/PuTTY, nhấn **phím bất kỳ** khi thấy `Hit any key to stop autoboot`.
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

| File | Nguồn cung cấp / Vị trí |
|---|---|
| `mtk_uart/mtk_uartboot` | Tool Linux (`../mtk_uart/`) hoặc [mtk_uartboot.exe](https://github.com/981213/mtk_uartboot/releases) (Windows) |
| `mt7981-ram-ddr3-bl2.bin` | BL2 RAM payload — `build_dir/.../mt7981/release/bl2.bin` sau build, hoặc `mtk_uart/bl2_ram.bin` (đổi tên khi copy) |
| `bin/targets/mediatek/filogic/immortalwrt-mediatek-filogic-viettel_nr3053-bl31-uboot.fip` | NR3053 FIP (Lấy từ kết quả build) |
| `bin/targets/mediatek/filogic/immortalwrt-mediatek-filogic-viettel_32x6-bl31-uboot.fip` | 32X6 FIP (Lấy từ kết quả build) |

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

Tải từ [GitHub Releases](https://github.com/quytttb/immortalwrt-mt798x-rebase/releases) (mỗi thiết bị 4 file + `sha256sums`):

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

Mở picocom (hoặc PuTTY) để theo dõi log và gửi lệnh:

```bash
# Lệnh cho picocom
picocom -b 115200 /dev/ttyUSB0
```

**A1 — U-Boot chạy bình thường**

1. Bật nguồn router (cáp LAN đã cắm).
2. Trong picocom/PuTTY, nhấn **phím bất kỳ** khi thấy `Hit any key to stop autoboot`.
3. Gõ `bootmenu` hoặc các lệnh U-Boot ở bước 2.

**A2 — Brick / không vào U-Boot (mtk_uartboot)**

Dùng khi chỉ thấy log BootROM hoặc im lặng — không có dòng autoboot.

**Linux:**

1. **Đóng picocom** (cổng serial cần trống).
2. **Rút nguồn** router.
3. Chạy tại **thư mục gốc repo** (hoặc thư mục có file FIP + BL2):

```bash
chmod +x ../mtk_uart/mtk_uartboot

sudo ../mtk_uart/mtk_uartboot --serial /dev/ttyUSB0 \
  --payload build_dir/target-aarch64_cortex-a53_musl/arm-trusted-firmware-mediatek-mt7981-ram-ddr3/arm-trusted-firmware-mediatek-*/build/mt7981/release/bl2.bin \
  --fip bin/targets/mediatek/filogic/immortalwrt-mediatek-filogic-viettel_nr3053-bl31-uboot.fip \
  --aarch64
```

4. Khi thấy `Handshake...` → **cắm nguồn** (hoặc nhấn reset).
5. Đợi **`FIP received`** → **`Ctrl+C`** đóng `mtk_uartboot`.
6. Mở lại **picocom** (`picocom -b 115200 /dev/ttyUSB0`) — đợi prompt U-Boot.

**Windows:** xem [mtk_uartboot trên Windows](#mtk_uartboot-trên-windows) — dùng `mtk_uartboot.exe`, sau `FIP received` mở session PuTTY **`Viettel-UART`** đã lưu.

> `mtk_uartboot` chỉ boot U-Boot **trong RAM**, không ghi NAND. Rút điện → router boot lại từ NAND cũ.

#### Bước 2 — Boot initramfs từ TFTP

**Đặt file TFTP:**
```
immortalwrt-mediatek-filogic-viettel_nr3053-initramfs-recovery.itb
```

**Cách 1 — Qua bootmenu (khuyến nghị)**

Trong picocom/PuTTY, gõ `bootmenu`, dùng **↑/↓** chọn mục **[2] Boot system via TFTP**, nhấn **Enter**.

U-Boot tự tải `initramfs-recovery.itb` từ TFTP rồi boot — không ghi gì vào NAND.

**Cách 2 — Lệnh thủ công trong U-Boot**

Gõ trực tiếp trong picocom/PuTTY:

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

1. Trong picocom/PuTTY, gõ `bootmenu`, chọn mục **[5] Load production system via TFTP then write to NAND**.
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

## Viettel 32X6

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

Tải từ [GitHub Releases](https://github.com/quytttb/immortalwrt-mt798x-rebase/releases):

| File | Dùng cho |
|---|---|
| `immortalwrt-mediatek-filogic-viettel_32x6-initramfs-recovery.itb` | Boot RAM / recovery |
| `immortalwrt-mediatek-filogic-viettel_32x6-squashfs-sysupgrade.itb` | Cài đặt vĩnh viễn |
| `immortalwrt-mediatek-filogic-viettel_32x6-bl31-uboot.fip` | Nâng cấp U-Boot |
| `immortalwrt-mediatek-filogic-viettel_32x6-preloader.bin` | Nâng cấp BL2 (rủi ro cao) |

---

### 32X6 Tuỳ chọn A — Boot RAM (test, không ghi NAND)

Chạy firmware **hoàn toàn trong RAM**, không động đến NAND.

#### Bước 1 — Vào U-Boot

Mở picocom (hoặc PuTTY) để theo dõi log và gửi lệnh:

```bash
# Lệnh cho picocom
picocom -b 115200 /dev/ttyUSB0
```

**A1 — U-Boot chạy bình thường**

1. Bật nguồn router (cáp LAN đã cắm).
2. Trong picocom/PuTTY, nhấn **phím bất kỳ** khi thấy `Hit any key to stop autoboot`.
3. Gõ `bootmenu` hoặc các lệnh U-Boot ở bước 2.

**A2 — Brick / không vào U-Boot (mtk_uartboot)**

Dùng khi chỉ thấy log BootROM hoặc im lặng — không có dòng autoboot.

**Linux:**

1. **Đóng picocom** — **rút nguồn** router.
2. Chạy tại thư mục gốc repo:

```bash
chmod +x ../mtk_uart/mtk_uartboot

sudo ../mtk_uart/mtk_uartboot --serial /dev/ttyUSB0 \
  --payload build_dir/target-aarch64_cortex-a53_musl/arm-trusted-firmware-mediatek-mt7981-ram-ddr3/arm-trusted-firmware-mediatek-*/build/mt7981/release/bl2.bin \
  --fip bin/targets/mediatek/filogic/immortalwrt-mediatek-filogic-viettel_32x6-bl31-uboot.fip \
  --aarch64
```

3. `Handshake...` → cắm nguồn → `FIP received` → **Ctrl+C** → mở lại **picocom**.

**Windows:** [mtk_uartboot trên Windows](#mtk_uartboot-trên-windows) — file FIP `viettel_32x6-bl31-uboot.fip`, sau đó mở PuTTY session đã lưu.

> `mtk_uartboot` chỉ boot U-Boot **trong RAM**, không ghi NAND. **Không dùng** FIP của NR3053 cho 32X6.

#### Bước 2 — Boot initramfs từ TFTP

**Đặt file TFTP:**
```
immortalwrt-mediatek-filogic-viettel_32x6-initramfs-recovery.itb
```

**Cách 1 — Qua bootmenu (khuyến nghị)**

Trong picocom/PuTTY, gõ `bootmenu`, chọn mục **[2] Boot system via TFTP**, nhấn **Enter**.

**Cách 2 — Lệnh thủ công trong U-Boot**

Gõ trực tiếp trong picocom/PuTTY:

```
setenv serverip 192.168.1.254
setenv ipaddr   192.168.1.1
tftpboot 0x46000000 immortalwrt-mediatek-filogic-viettel_32x6-initramfs-recovery.itb
bootm 0x46000000#config-1
```

**Kết quả:**  
ImmortalWrt boot từ RAM. LED WPS bật khi boot. Tắt nguồn → thiết bị trở về ban đầu.

---

### 32X6 Tuỳ chọn B — Cài đặt vĩnh viễn vào NAND

**Đặt file TFTP:**
```
immortalwrt-mediatek-filogic-viettel_32x6-squashfs-sysupgrade.itb
```

**Cách 1 — Qua bootmenu (khuyến nghị)**

1. Trong bootmenu, chọn mục **[5] Load production system via TFTP then write to NAND**.

**Cách 2 — Lệnh thủ công**

```
setenv serverip 192.168.1.254
setenv ipaddr   192.168.1.1

tftpboot 0x46000000 immortalwrt-mediatek-filogic-viettel_32x6-squashfs-sysupgrade.itb

ubi part ubi
ubi check fit && ubi remove fit
ubi create fit $filesize dynamic
ubi write 0x46000000 fit $filesize

ubi read 0x46000000 fit && bootm 0x46000000#config-1
```

**Cài đặt recovery (tuỳ chọn):**

Bootmenu **[6] Load recovery system via TFTP then write to NAND**, hoặc lệnh thủ công:

```
tftpboot 0x46000000 immortalwrt-mediatek-filogic-viettel_32x6-initramfs-recovery.itb

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
3. Chạy script mở khoá SSH (trong thư mục clone repo):

   **Linux:**
   ```bash
   pip3 install requests
   python3 scripts/unlock/unlock_viettel.py --password SERIAL_NUMBER_CUA_BAN
   ```

   **Windows (PowerShell):**
   ```powershell
   py -m pip install requests
   py scripts\unlock\unlock_viettel.py --password SERIAL_NUMBER_CUA_BAN
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
# Chạy trên PC (Linux/macOS/Git Bash) — KHÔNG chạy trong SSH router
# NR3053:
scp immortalwrt-mediatek-filogic-viettel_nr3053-bl31-uboot.fip root@192.168.1.1:/tmp/fip.bin

# 32X6:
scp immortalwrt-mediatek-filogic-viettel_32x6-bl31-uboot.fip root@192.168.1.1:/tmp/fip.bin
```

**Windows (PowerShell):** cùng lệnh `scp` — xem [Copy file qua SCP](#copy-file-qua-scp-mục-ssh-unlock).

> Nếu `scp` báo lỗi option `-O`, bỏ cờ đó (Linux OpenSSH mới) hoặc thêm `-O` (Windows khi server chỉ hỗ trợ legacy SCP).

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

1. Đặt IP tĩnh cho card mạng PC: **`192.168.1.254/24`** (xem [Linux](#linux) hoặc [Windows](#windows)).

   ```bash
   # Linux — thay eth0 bằng tên interface thật
   sudo ip addr flush dev eth0
   sudo ip addr add 192.168.1.254/24 dev eth0
   sudo ip link set eth0 up
   ```

   Windows (CMD Admin): `netsh interface ip set address name="Ethernet" static 192.168.1.254 255.255.255.0`

2. Mở trình duyệt, vào **`http://192.168.1.1/`** — giao diện **"FIRMWARE UPDATE"** sẽ hiện ra.

3. Chọn file `*-squashfs-sysupgrade.itb` đúng thiết bị:
   - NR3053: `immortalwrt-mediatek-filogic-viettel_nr3053-squashfs-sysupgrade.itb`
   - 32X6: `immortalwrt-mediatek-filogic-viettel_32x6-squashfs-sysupgrade.itb`

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

# 32X6
tftpboot 0x46000000 immortalwrt-mediatek-filogic-viettel_32x6-bl31-uboot.fip
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
- Thử cổng khác: Linux `/dev/ttyUSB0`, `/dev/ttyUSB1`; Windows `COM3`, `COM4` (Device Manager).
- Chạy `mtk_uartboot` **trước**, rồi mới cắm nguồn hoặc nhấn reset.
- **Đóng PuTTY/picocom** trước khi chạy `mtk_uartboot` (cổng serial chỉ một process).
- NR3053 và 32X6 dùng chung BL2 RAM DDR3 (`mt7981-ram-ddr3-bl2.bin` hoặc `bl2.bin` từ build).

**Sau `FIP received` không thấy log U-Boot (Windows):**

1. **`Ctrl+C`** đóng `mtk_uartboot.exe` ngay (trong vài giây).
2. Mở **PuTTY** session `Viettel-UART` đã cấu hình sẵn — **không** để mtk_uartboot chiếm COM port.
3. Nếu PuTTY trống: rút nguồn, lặp lại từ đầu.
4. `mtk_uartboot` và PuTTY **không mở cùng lúc** trên cùng `COMx`.

### TFTP timeout / không tải được file

- TFTP server đang chạy và lắng nghe **UDP 69**.
- IP máy tính **`192.168.1.254`**, subnet `/24`, **không gateway**, tắt VPN.
- Tên file trong thư mục TFTP **khớp chính xác** (phân biệt hoa/thường trên Linux TFTP).
- Trong U-Boot: `printenv serverip ipaddr` → phải là `192.168.1.254` và `192.168.1.1`.

**Windows thêm:**
- Tftpd64 chạy **Administrator**, tab Tftp Server, **Server interfaces** = card `192.168.1.254` (không phải `127.0.0.1`).
- **Current Directory** trùng thư mục chứa file `.itb`.
- Cho phép Tftpd64 qua Windows Firewall (UDP 69).
- Cửa sổ Tftpd64 phải hiện dòng `Read request` khi router tải — không thấy = router chưa kết nối tới PC.
- Không dùng Wi-Fi — chỉ **cáp Ethernet** trực tiếp PC ↔ cổng LAN router.

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

*Firmware: [GitHub Releases](https://github.com/quytttb/immortalwrt-mt798x-rebase/releases) hoặc `bin/targets/mediatek/filogic/` sau build*  
*Cập nhật: 2026-07-03*
