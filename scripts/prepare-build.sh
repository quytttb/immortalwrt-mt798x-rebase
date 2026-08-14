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

echo "=== Bước 2: Verify custom packages (Aurora) ==="
# Aurora sources are vendored in this fork, so their revision is pinned by the
# top-level firmware commit. Do not replace them with an unpinned clone at build time.
for package_dir in package/luci-theme-aurora package/luci-app-aurora-config; do
    if [[ ! -f "$package_dir/Makefile" ]]; then
        echo "ERROR: Missing vendored Aurora package: $package_dir" >&2
        exit 1
    fi
done
echo "  Aurora packages are pinned by this firmware revision."

echo "=== Bước 3: Áp dụng bản dịch và defaults tuỳ chỉnh ==="
inject_po() {
    local src="$1" dest_dir="$2" dest_name="$3"
    if [ -f "$src" ]; then
        mkdir -p "$dest_dir"
        cp "$src" "$dest_dir/$dest_name"
        echo "  Đã copy $(basename "$src") -> $dest_dir/$dest_name"
    fi
}

# Bản dịch tiếng Việt cho từng app (chỗ nào upstream chưa có vi)
inject_po custom-files/vi-upnp.po \
    feeds/luci/applications/luci-app-upnp/po/vi upnp.po
inject_po custom-files/vi-turboacc.po \
    package/mtk/applications/luci-app-turboacc-mtk/po/vi turboacc.po
inject_po custom-files/vi-mtwifi-cfg.po \
    package/mtk/applications/luci-app-mtwifi-cfg/po/vi mtwifi-cfg.po

# Bổ sung bản dịch LuCI base từ fork cũ (default.vi.po, more.vi.po)
BASE_PO="feeds/luci/modules/luci-base/po/vi/base.po"
if [ -f "$BASE_PO" ] && command -v msgcat >/dev/null 2>&1; then
    EXTRAS=()
    [ -f custom-files/more.vi.po ] && EXTRAS+=("custom-files/more.vi.po")
    [ -f custom-files/default.vi.po ] && EXTRAS+=("custom-files/default.vi.po")
    if [ "${#EXTRAS[@]}" -gt 0 ]; then
        MERGE_TMP=()
        for f in "${EXTRAS[@]}"; do
            if [ "$(basename "$f")" = "more.vi.po" ]; then
                msguniq "$f" -o "${f}.uniq"
                MERGE_TMP+=("${f}.uniq")
            else
                MERGE_TMP+=("$f")
            fi
        done
        # Custom trước, base sau: bản dịch fork bổ sung chỗ upstream thiếu
        msgcat --use-first --no-wrap -o "${BASE_PO}.tmp" "${MERGE_TMP[@]}" "$BASE_PO"
        rm -f custom-files/more.vi.po.uniq
        mv "${BASE_PO}.tmp" "$BASE_PO"
        echo "  Đã merge default.vi.po + more.vi.po vào luci-base vi"
    fi
elif [ -f custom-files/default.vi.po ] || [ -f custom-files/more.vi.po ]; then
    echo "  CẢNH BÁO: thiếu msgcat (gettext), bỏ qua merge default/more.vi.po" >&2
fi

# UCI defaults tuỳ chỉnh Viettel (UPnP + BBR fallback)
mkdir -p package/base-files/files/etc/uci-defaults
cp custom-files/99-viettel-custom-defaults \
    package/base-files/files/etc/uci-defaults/99-viettel-custom-defaults
echo "  Đã copy 99-viettel-custom-defaults"

# Services defaults: Adblock VN feed, DDNS cleanup
if [ -f custom-files/99-viettel-services-defaults ]; then
    cp custom-files/99-viettel-services-defaults \
        package/base-files/files/etc/uci-defaults/99-viettel-services-defaults
    echo "  Đã copy 99-viettel-services-defaults"
fi

# Adblock hostsVN patch script (first boot)
if [ -f custom-files/etc/adblock/patch-reg_vn.sh ]; then
    mkdir -p package/base-files/files/etc/adblock
    cp custom-files/etc/adblock/patch-reg_vn.sh \
        package/base-files/files/etc/adblock/patch-reg_vn.sh
    chmod +x package/base-files/files/etc/adblock/patch-reg_vn.sh
    echo "  Đã copy etc/adblock/patch-reg_vn.sh"
fi

echo "=== Bước 4: Chuẩn bị .config từ $DEFCONFIG ==="
cp "$DEFCONFIG" .config
make defconfig

bash scripts/verify-viettel-config.sh .config

echo ""
echo "Chuẩn bị hoàn tất. Tiếp theo:"
echo "  make download -j8"
echo "  make -j\$(nproc) V=s"
