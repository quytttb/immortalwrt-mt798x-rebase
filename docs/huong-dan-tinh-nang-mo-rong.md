# Hướng dẫn cấu hình tính năng mở rộng

Firmware fork Viettel (NR3053 / 32X6) đã tích hợp sẵn các gói sau:

| Tính năng | Menu LuCI |
|-----------|-----------|
| Giám sát băng thông | **Services → Bandwidth Monitor** |
| Dynamic DNS | **Services → Dynamic DNS** |
| WireGuard VPN | **Network → Interfaces** |
| Chặn quảng cáo DNS | **Services → Adblock** |

> **Lưu ý:** WireGuard không có app LuCI riêng (`luci-app-wireguard`). Trên ImmortalWrt 25.12, cấu hình qua **luci-proto-wireguard** tại mục Interfaces.

---

## 1. WireGuard VPN — truy cập về nhà từ ngoài

### Mục tiêu

Tạo VPN server trên router để điện thoại/laptop kết nối từ internet và truy cập mạng LAN (`192.168.1.0/24`) như đang ở nhà.

### Điều kiện

- Router đã có internet qua WAN.
- Nên cấu hình **DDNS** (mục 2) nếu IP WAN là dynamic.
- Mở port **UDP 51820** trên modem (port forward → IP LAN của router).

### Bước 1: Tạo interface WireGuard trên router

1. Vào **Network → Interfaces → Add new interface**.
2. Tên: `wg0` (hoặc tên bạn muốn).
3. Protocol: **WireGuard VPN**.
4. Tab **General Setup**:
   - **Private Key**: bấm **Generate new key pair** (giữ private key trên router, copy public key để dùng sau).
   - **Listen Port**: `51820`.
   - **IP Addresses**: `10.10.10.1/24` (subnet VPN riêng, không trùng LAN).
5. Tab **Firewall Settings**:
   - Assign firewall zone: chọn **lan** (hoặc tạo zone `vpn` rồi forward sang `lan`).
6. **Save & Apply**.

### Bước 2: Thêm peer (client — điện thoại/laptop)

1. Mở interface `wg0` → tab **Peers → Add**.
2. **Public Key**: public key của client (tạo trên app WireGuard).
3. **Allowed IPs**: `10.10.10.2/32` (IP VPN của client này; mỗi client một IP khác nhau).
4. (Tuỳ chọn) **Persistent Keepalive**: `25` — giúp client sau NAT giữ kết nối.
5. **Save & Apply**.

### Bước 3: Cấu hình client (điện thoại)

Trên app **WireGuard** (iOS/Android/desktop), tạo tunnel mới:

```ini
[Interface]
PrivateKey = <private-key-cua-client>
Address = 10.10.10.2/32
DNS = 192.168.1.1

[Peer]
PublicKey = <public-key-cua-router>
Endpoint = <hostname-ddns-hoac-ip-wan>:51820
AllowedIPs = 10.10.10.0/24, 192.168.1.0/24
PersistentKeepalive = 25
```

- **Endpoint**: hostname DDNS hoặc IP WAN public của nhà bạn.
- **AllowedIPs**: thêm `192.168.1.0/24` nếu muốn truy cập thiết bị trong LAN.

### Bước 4: Firewall (nếu client không ping được LAN)

Vào **Network → Firewall**, kiểm tra zone chứa `wg0` được **forward** sang `lan` và **masquerading** bật trên zone `wan` nếu cần.

Hoặc qua SSH:

```bash
# Kiểm tra interface
wg show

# Kiểm tra firewall
uci show firewall | grep wg
```

### Kiểm tra

1. Bật VPN trên điện thoại (dùng 4G, không dùng WiFi nhà).
2. Ping router: `ping 10.10.10.1`
3. Ping thiết bị LAN: `ping 192.168.1.x`

---

## 2. Dynamic DNS (DDNS)

### Mục tiêu

Cập nhật hostname (ví dụ `nha.example.com`) khi IP WAN thay đổi — cần cho WireGuard Endpoint hoặc truy cập từ xa.

Firmware đã có provider: **Cloudflare**, **No-IP**, và các provider phổ biến trong `ddns-scripts-services`.

### Cấu hình Cloudflare

1. Tạo **API Token** trên Cloudflare (quyền Edit DNS cho zone của bạn).
2. Vào **Services → Dynamic DNS → Add**.
3. Điền:
   - **Lookup Hostname**: `nha.example.com`
   - **Domain**: `example.com`
   - **Username**: `Bearer` (hoặc để trống tuỳ phiên bản script)
   - **Password / Token**: API token Cloudflare
   - **IP address source**: `network` → interface `wan`
   - **Check Interval**: `10` phút
4. Bật **Enabled** → **Save & Apply**.

### Cấu hình No-IP

1. Đăng ký hostname miễn phí tại [noip.com](https://www.noip.com/).
2. Vào **Services → Dynamic DNS → Add**.
3. Điền:
   - **Lookup Hostname**: hostname No-IP của bạn
   - **Username**: email đăng ký No-IP
   - **Password**: mật khẩu No-IP
   - **IP address source**: `network` → `wan`
4. Bật **Enabled** → **Save & Apply**.

### Kiểm tra qua SSH

```bash
logread | grep ddns
# hoặc
/etc/init.d/ddns status
```

---

## 3. Adblock — chặn quảng cáo qua DNS

### Mục tiêu

Chặn domain quảng cáo/tracker ở tầng DNS cho toàn mạng LAN (mọi thiết bị dùng router làm DNS).

### Bước 1: Bật Adblock

1. Vào **Services → Adblock**.
2. Tab **General**:
   - **Enable Adblock**: bật.
   - **DNS Backend**: `dnsmasq` (mặc định trên router).
3. Tab **Feed Sources**:
   - Chọn vài list phù hợp, ví dụ:
     - `adaway` — cân bằng tốt
     - `adguard` — bổ sung thêm
     - `winspy` — chặn tracker Windows (tuỳ chọn)
4. **Save & Apply** → chờ tải list lần đầu (có thể vài phút).

### Bước 2: Đảm bảo client dùng DNS router

Thiết bị LAN phải lấy DNS từ router (`192.168.1.1`). Kiểm tra **Network → DHCP and DNS**:

- **DNS forwardings**: có thể thêm upstream như `1.1.1.1`, `8.8.8.8` (Adblock sẽ lọc trước khi forward).

### Whitelist / Blacklist

- **Whitelist**: domain bị chặn nhầm → thêm vào whitelist.
- **Blacklist**: chặn thêm domain thủ công.

### Kiểm tra

```bash
/etc/init.d/adblock status
nslookup doubleclick.net 192.168.1.1
# Kết quả mong đợi: 0.0.0.0 hoặc NXDOMAIN
```

### Lưu ý

- Adblock tốn **RAM** khi load nhiều list — trên **32X6 (128 MB)** nên chọn 1–2 list nhẹ.
- Một số app dùng DNS-over-HTTPS riêng sẽ **không** bị chặn (YouTube app, Chrome Secure DNS…).

---

## 4. Bandwidth Monitor (nlbwmon)

Không cần cấu hình phức tạp — vào **Services → Bandwidth Monitor** để xem traffic theo từng thiết bị MAC/IP.

Lần đầu có thể mất vài phút để bắt đầu thu thập số liệu.

---

## Xử lý sự cố nhanh

| Vấn đề | Gợi ý |
|--------|-------|
| WireGuard không kết nối | Kiểm tra port forward UDP 51820, DDNS, public key đúng |
| VPN vào được nhưng không thấy LAN | Kiểm tra AllowedIPs client, firewall forward zone |
| DDNS không cập nhật | Xem `logread \| grep ddns`, kiểm tra token/credentials |
| Adblock chặn nhầm | Thêm domain vào whitelist |
| Router chậm sau bật Adblock | Giảm số feed trên 32X6 |
| `apk update` lỗi wget / vsean | Firmware mới tự sửa mirror → `downloads.immortalwrt.org`; kiểm tra: `cat /etc/apk/repositories.d/distfeeds.list` |

---

## Cài thêm gói qua `apk` (sau khi flash firmware mới)

Firmware fork dùng mirror chính thức ImmortalWrt. Sau flash, chạy:

```bash
apk update
apk list | grep <tên-gói>
apk add <tên-gói>
```

Gói đã có sẵn trong firmware (nlbwmon, WireGuard, Adblock, …) **không cần** `apk add` lại.

---

## Tài liệu liên quan

- [Hướng dẫn nạp firmware](huong-dan-nap-firmware.md)
- [README](../README.md)
