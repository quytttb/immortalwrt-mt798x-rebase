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
# Bước 3 injects translations into the luci feed checkout on every run. Reset those
# paths first so 'feeds update' never fails on a dirty-tree merge (they are
# re-applied deterministically in Bước 3).
if [[ -d feeds/luci/.git ]]; then
    git -C feeds/luci checkout -- \
        modules/luci-base/po/vi/base.po \
        applications/luci-app-upnp/po/vi/upnp.po 2>/dev/null || true
fi
./scripts/feeds update -a
./scripts/feeds install -a

echo "=== Bước 2: Sync Aurora packages (rolling) ==="
# Aurora theme + config app track upstream eamonxg HEAD so each build picks up the
# latest release. These are single-package repos (Makefile at repo root), which the
# buildroot feed indexer cannot handle as src-git feeds, so sync them straight into
# package/ instead (local package/ shadows feeds/ by design).
sync_aurora_repo() {
    local dest="$1" url="$2" branch sha ver
    branch="$(git ls-remote --symref "$url" HEAD | awk '/^ref:/ { sub("refs/heads/", "", $2); print $2; exit }')"
    [[ -n "$branch" ]] || { echo "ERROR: cannot resolve HEAD branch for $url" >&2; exit 1; }
    if [[ -d "$dest/.git" ]]; then
        git -C "$dest" fetch --quiet --depth 1 origin "$branch"
        git -C "$dest" reset --quiet --hard FETCH_HEAD
    else
        rm -rf "$dest"
        git clone --quiet --depth 1 --branch "$branch" "$url" "$dest"
    fi
    sha="$(git -C "$dest" rev-parse --short HEAD)"
    ver="$(awk -F':= *' '/^PKG_VERSION/ { print $2; exit }' "$dest/Makefile")"
    echo "  $(basename "$dest"): $ver @ $sha ($branch)"
}
sync_aurora_repo package/luci-theme-aurora https://github.com/eamonxg/luci-theme-aurora.git
sync_aurora_repo package/luci-app-aurora-config https://github.com/eamonxg/luci-app-aurora-config.git

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
