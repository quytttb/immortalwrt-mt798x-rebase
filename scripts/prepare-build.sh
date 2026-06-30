#!/bin/bash
# Chuẩn bị build firmware Viettel NR3053 + 32X6.
# Dùng cả khi build local và trong GitHub Actions.
# Chạy từ thư mục gốc repo.
#
# Usage: ./scripts/prepare-build.sh [defconfig]
#   defconfig: đường dẫn tới defconfig, mặc định là defconfig/viettel-only.config

set -e

DEFCONFIG="${1:-defconfig/viettel-only.config}"
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

echo "=== Bước 1: Update và install feeds ==="
./scripts/feeds update -a
./scripts/feeds install -a

echo "=== Bước 2: Clone custom packages (Aurora theme) ==="
if [ ! -d "package/luci-theme-aurora" ]; then
    git clone --depth 1 https://github.com/eamonxg/luci-theme-aurora.git package/luci-theme-aurora
    rm -rf package/luci-theme-aurora/.git
else
    echo "  luci-theme-aurora đã có, bỏ qua."
fi

if [ ! -d "package/luci-app-aurora-config" ]; then
    git clone --depth 1 https://github.com/eamonxg/luci-app-aurora-config.git package/luci-app-aurora-config
    rm -rf package/luci-app-aurora-config/.git
else
    echo "  luci-app-aurora-config đã có, bỏ qua."
fi

echo "=== Bước 3: Áp dụng bản dịch và defaults tuỳ chỉnh ==="
# Bản dịch UPnP tiếng Việt
if [ -f "custom-files/vi-upnp.po" ] && [ -d "feeds/luci/applications/luci-app-upnp/po/vi" ]; then
    cp custom-files/vi-upnp.po feeds/luci/applications/luci-app-upnp/po/vi/upnp.po
    echo "  Đã copy vi-upnp.po"
fi

# UCI defaults tuỳ chỉnh Viettel (UPnP + BBR fallback)
mkdir -p package/base-files/files/etc/uci-defaults
cp custom-files/99-viettel-custom-defaults \
    package/base-files/files/etc/uci-defaults/99-viettel-custom-defaults
echo "  Đã copy 99-viettel-custom-defaults"

echo "=== Bước 4: Chuẩn bị .config từ $DEFCONFIG ==="
cp "$DEFCONFIG" .config
make defconfig

enabled=$(grep -c '^CONFIG_TARGET_DEVICE_mediatek_filogic_DEVICE_.*=y' .config)
if [ "$enabled" -ne 2 ]; then
    echo "ERROR: Expected 2 Viettel devices in .config, got $enabled" >&2
    grep '^CONFIG_TARGET_DEVICE_mediatek_filogic_DEVICE_.*=y' .config >&2 || true
    exit 1
fi
echo "  OK: $enabled devices selected"

echo ""
echo "Chuẩn bị hoàn tất. Tiếp theo:"
echo "  make download -j8"
echo "  make -j\$(nproc) V=s"
