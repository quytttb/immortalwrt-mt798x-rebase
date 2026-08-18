#!/bin/bash
# Validate the fork-owned configuration after OpenWrt resolves it with defconfig.
set -euo pipefail

CONFIG_FILE="${1:-.config}"

[[ -f "$CONFIG_FILE" ]] || {
    echo "Missing resolved config: $CONFIG_FILE" >&2
    exit 1
}

require_enabled() {
    local symbol="$1"
    if ! grep -qx "${symbol}=y" "$CONFIG_FILE"; then
        echo "Required config symbol is not enabled: $symbol" >&2
        exit 1
    fi
}

require_enabled CONFIG_TARGET_mediatek
require_enabled CONFIG_TARGET_mediatek_filogic
require_enabled CONFIG_TARGET_MULTI_PROFILE
require_enabled CONFIG_TARGET_PER_DEVICE_ROOTFS
require_enabled CONFIG_TARGET_DEVICE_mediatek_filogic_DEVICE_viettel_nr3053
require_enabled CONFIG_TARGET_DEVICE_mediatek_filogic_DEVICE_viettel_32x6

for symbol in \
    CONFIG_PACKAGE_luci-theme-aurora \
    CONFIG_PACKAGE_luci-app-aurora-config \
    CONFIG_PACKAGE_luci-app-turboacc-mtk \
    CONFIG_PACKAGE_luci-app-upnp \
    CONFIG_PACKAGE_luci-app-ddns \
    CONFIG_PACKAGE_luci-app-adblock \
    CONFIG_PACKAGE_strongswan-charon \
    CONFIG_PACKAGE_strongswan-swanctl \
    CONFIG_PACKAGE_luci-app-strongswan-swanctl \
    CONFIG_PACKAGE_luci-proto-wireguard; do
    require_enabled "$symbol"
done

selected_devices=$(grep -c '^CONFIG_TARGET_DEVICE_mediatek_filogic_DEVICE_.*=y$' "$CONFIG_FILE")
if [[ "$selected_devices" -ne 2 ]]; then
    echo "Expected exactly 2 selected Filogic devices, got $selected_devices" >&2
    exit 1
fi

echo "Viettel firmware config OK (NR3053 + 32X6 and required packages)."
