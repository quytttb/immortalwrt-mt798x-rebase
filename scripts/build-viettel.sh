#!/bin/bash
# Build firmware Viettel NR3053 + 32X6 — đầy đủ từ đầu đến cuối.
# Dùng cả khi build local và trong GitHub Actions.
# Chạy từ thư mục gốc repo.
#
# Usage: ./scripts/build-viettel.sh [defconfig]
#   defconfig: đường dẫn tới defconfig, mặc định là defconfig/viettel-only.config

set -e

DEFCONFIG="${1:-defconfig/viettel-only.config}"
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

# Bước 1–4: chuẩn bị (feeds, Aurora, bản dịch, defconfig)
bash scripts/prepare-build.sh "$DEFCONFIG"

echo ""
echo "=== Bước 5: Download sources ==="
make download -j8 || make download -j1 V=s

echo ""
echo "=== Bước 6: Build firmware ==="
make -j"$(nproc)" V=s || {
    echo "Parallel build failed, retrying single-thread..."
    make -j1 V=s
}

echo ""
echo "=== Bước 7: Collect artifacts ==="
mkdir -p dist
shopt -s nullglob
cp bin/targets/mediatek/filogic/*viettel_nr3053* dist/ 2>/dev/null || true
cp bin/targets/mediatek/filogic/*viettel_32x6*   dist/ 2>/dev/null || true
cp bin/targets/mediatek/filogic/sha256sums       dist/ 2>/dev/null || true

echo ""
echo "Artifacts:"
ls -lh dist/
echo ""
echo "Build hoàn tất. Firmware trong thư mục dist/"
