#!/bin/bash
# Build Viettel firmware, then build matching BL2/FIP once from the dedicated
# bootloader repository. Used locally and by GitHub Actions.
#
# Usage: ./scripts/build-viettel.sh [defconfig]
# Optional: BOOTLOADER_DIR=/path/to/bl-mt798x-dhcpd ./scripts/build-viettel.sh

set -euo pipefail

DEFCONFIG="${1:-defconfig/viettel-only.config}"
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BOOTLOADER_REPO_URL="https://github.com/quytttb/bl-mt798x-dhcpd.git"
BOOTLOADER_REVISION="7b27cb0e2b91d7ecfaba12f6380c5a1fea4ab44c"
BOOTLOADER_VERSION="SP2"
cd "$REPO_ROOT"

build_bootloaders() {
    local bootloader_dir
    local board fip bl2

    bootloader_dir="${BOOTLOADER_DIR:-$REPO_ROOT/tmp/bl-mt798x-dhcpd}"
    if [[ -n "${BOOTLOADER_DIR:-}" ]]; then
        [[ -d "$bootloader_dir/.git" ]] || {
            echo "BOOTLOADER_DIR is not a git checkout: $bootloader_dir" >&2
            exit 1
        }
    else
        rm -rf "$bootloader_dir"
        git clone --quiet "$BOOTLOADER_REPO_URL" "$bootloader_dir"
    fi

    git -C "$bootloader_dir" fetch --quiet origin "$BOOTLOADER_REVISION"
    git -C "$bootloader_dir" checkout --quiet --detach "$BOOTLOADER_REVISION"

    echo ""
    echo "=== Bước 7: Build bootloader external ($BOOTLOADER_REVISION) ==="
    mkdir -p "$bootloader_dir/output"
    for board in viettel_32x6 viettel_nr3053; do
        rm -f "$bootloader_dir"/output/*"$board"*"$BOOTLOADER_VERSION"*
        make -C "$bootloader_dir" \
            BOARD="$board" VERSION="$BOOTLOADER_VERSION" VARIANT=default BUILD_LOG=y

        shopt -s nullglob
        local fips=("$bootloader_dir"/output/fip-mt7981-"$board"-"$BOOTLOADER_VERSION"*.bin)
        local bl2s=("$bootloader_dir"/output/bl2-mt7981_"$board"_"$BOOTLOADER_VERSION"*.img)
        shopt -u nullglob
        (( ${#fips[@]} == 1 )) || { echo "Expected one FIP for $board, got ${#fips[@]}" >&2; exit 1; }
        (( ${#bl2s[@]} == 1 )) || { echo "Expected one BL2 for $board, got ${#bl2s[@]}" >&2; exit 1; }

        fip="${fips[0]}"
        bl2="${bl2s[0]}"
        cp "$fip" "dist/immortalwrt-mediatek-filogic-${board}-bl31-uboot.fip"
        cp "$bl2" "dist/immortalwrt-mediatek-filogic-${board}-preloader.bin"
    done
}

# Steps 1-4: feeds, Aurora, translations, and the requested defconfig.
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
echo "=== Bước 7: Collect firmware artifacts ==="
rm -rf dist
mkdir -p dist
shopt -s nullglob
for image in bin/targets/mediatek/filogic/*viettel_nr3053*.itb \
             bin/targets/mediatek/filogic/*viettel_32x6*.itb; do
    cp "$image" dist/
done
cp bin/targets/mediatek/filogic/sha256sums dist/ 2>/dev/null || true
shopt -u nullglob

build_bootloaders

# Regenerate checksums after adding the externally-built FIP and BL2 artifacts.
(
    cd dist
    rm -f sha256sums
    sha256sum -- * > sha256sums
)

echo ""
echo "Artifacts:"
ls -lh dist/
echo ""
echo "Build hoàn tất. Firmware và bootloader trong thư mục dist/"
