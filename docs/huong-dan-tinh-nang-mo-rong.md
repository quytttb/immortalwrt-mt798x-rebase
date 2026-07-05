# Hướng dẫn cấu hình tính năng mở rộng

Firmware fork Viettel (NR3053 / 32X6) đã tích hợp sẵn các gói sau:

| Tính năng | Menu LuCI |
|-----------|-----------|
| Dynamic DNS | **Services → Dynamic DNS** |
| WireGuard VPN | **Network → Interfaces** |
| Chặn quảng cáo DNS | **Services → Adblock** |

> **Lưu ý:** WireGuard không có app LuCI riêng (`luci-app-wireguard`). Trên ImmortalWrt 25.12, cấu hình qua **luci-proto-wireguard** tại mục Interfaces.

> **NAT kép:** Nếu router nằm sau modem chủ nhà (WAN `192.168.1.x`), WireGuard + DDNS **cần modem mở port forward UDP 51820** mới vào được từ ngoài. Không mở được port trên modem thì cần giải pháp VPN mesh khác (cài riêng, không có trong firmware fork).

---

## 1. Adblock — chặn quảng cáo (quốc tế + Việt Nam)

### Mục tiêu

Chặn domain quảng cáo/tracker ở tầng DNS cho toàn mạng LAN.

### Feeds khuyến nghị (firmware mới)

| Feed | Mô tả |
|------|--------|
| `adguard` | Chặn quảng cáo chung (AdGuard DNS filter) |
| `adguard_tracking` | Chặn tracker |
| `adguard_mobile` | [AdGuard Mobile Ads](https://kb.adguard.com/general/adguard-ad-filters#mobile-ads-filter) — mạng QC trên mobile |
| `reg_vn` | **[hostsVN](https://bigdargon.github.io/hostsVN)** — domain quảng cáo/malware VN |
| `abpvn` | **[ABPVN](https://abpvn.com/)** — filter list cho người Việt (chỉ rule `||domain^` áp dụng được ở tầng DNS) |

Firmware fork tự thêm `reg_vn`, `adguard_mobile`, `abpvn` vào `/etc/adblock/adblock.feeds` lúc first-boot (script `patch-reg_vn.sh`).

> **Lưu ý ABPVN:** List gốc dùng cho uBlock/ABP (có rule CSS, exception `@@`). Router chỉ trích domain từ rule `||...^`. Rule chặn element (`.admicro`) không hoạt động ở DNS — cần uBlock trên trình duyệt cho phần đó.

**Quan trọng (Adblock 4.5.6):** Không đặt nội dung trong `/etc/adblock/adblock.custom.feeds` trừ khi bạn copy **toàn bộ** catalog — file này **thay thế** `adblock.feeds` nếu có nội dung.

### Cấu hình thủ công (nếu cần)

```bash
# Đảm bảo custom feeds rỗng
: > /etc/adblock/adblock.custom.feeds
/etc/adblock/patch-reg_vn.sh

uci del_list adblock.global.adb_feed='certpl'
uci add_list adblock.global.adb_feed='adguard'
uci add_list adblock.global.adb_feed='adguard_tracking'
uci add_list adblock.global.adb_feed='reg_vn'
uci add_list adblock.global.adb_feed='adguard_mobile'
uci add_list adblock.global.adb_feed='abpvn'
uci set adblock.global.adb_trigger='daily'
uci commit adblock
/etc/init.d/adblock restart
```

### Kiểm tra

```bash
/etc/init.d/adblock status
nslookup doubleclick.net 192.168.2.1
# Kết quả mong đợi: NXDOMAIN hoặc 0.0.0.0
```

Thiết bị LAN lấy DNS từ router (`192.168.2.1`). Tắt **Secure DNS** trên trình duyệt nếu quảng cáo vẫn lọt.

---

## 2. WireGuard VPN

### Điều kiện (truy cập từ ngoài)

- Port forward **UDP 51820** trên modem → IP WAN router (ví dụ `192.168.1.11`).
- Nên có **DDNS** (mục 3) nếu IP public thay đổi.

### Thông số đề xuất

| Mục | Giá trị |
|-----|---------|
| Interface | `wg0` |
| Subnet VPN | `10.66.66.1/24` |
| Listen port | `51820` |
| Firewall zone | `vpn` ↔ `lan` |

### Client mẫu

```ini
[Interface]
PrivateKey = <client-private-key>
Address = 10.66.66.2/32
DNS = 192.168.2.1

[Peer]
PublicKey = <router-public-key>
Endpoint = <hostname-ddns>:51820
AllowedIPs = 10.66.66.0/24, 192.168.2.0/24
PersistentKeepalive = 25
```

Cấu hình qua LuCI **Network → Interfaces → Add → WireGuard**, hoặc UCI/`wg` trên shell.

---

## 3. Dynamic DNS (No-IP)

### Lưu ý WAN kép

Nếu WAN router là IP private (`192.168.1.x`), đặt **IP source = web** (không dùng `network`):

```bash
/root/setup-ddns-noip.sh HOSTNAME.ddns.net EMAIL PASSWORD
```

Hoặc LuCI **Services → Dynamic DNS** với `ip_source=web`, `ip_url=https://api.ipify.org`.

DDNS chỉ cập nhật hostname — **không thay port forward**. WireGuard từ ngoài vẫn cần modem mở UDP 51820.

### Kiểm tra

```bash
logread | grep -i ddns
/etc/init.d/ddns status
```

---

## Xử lý sự cố nhanh

| Vấn đề | Gợi ý |
|--------|-------|
| Không vào được từ ngoài (NAT kép) | Mở port forward UDP 51820 trên modem; hoặc dùng VPN mesh cài riêng |
| WireGuard không kết nối | Port forward UDP 51820, DDNS, kiểm tra public key |
| Adblock = 0 domain | Xóa nội dung `adblock.custom.feeds`; chạy `patch-reg_vn.sh` |
| DDNS không cập nhật | `ip_source=web`, kiểm tra credentials No-IP |
| Adblock chặn nhầm | **Services → Adblock → Allowlist** |

---

## Tài liệu liên quan

- [Hướng dẫn nạp firmware](huong-dan-nap-firmware.md)
- [README](../README.md)
