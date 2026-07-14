# Viettel fork: throughWall WiFi calibration boost for NR3053.
# Ports the ROM stock /usr/sbin/throughWall.sh (MediaTek mt_wifi / iwpriv)
# to a persistent hotplug-driven implementation.
#
# Background:
#   Viettel NR3053 ships with WiFi calibration values (EEPROM offsets
#   0x81e-0x87e on rax0) intentionally lowered. The stock ROM contains a
#   hidden "throughWall" feature that writes 0xC4C4 to those offsets via
#   iwpriv to restore full TX power. We replicate this here using iwpriv
#   (available via kmod-mt_wifi) so it works on ImmortalWrt without needing
#   a ROM flash.
#
# UCI config (created by uci-defaults on first boot):
#   config throughwall 'throughwall'
#       option enable '1'
#
# Effect is applied in RAM via iwpriv each time rax0 comes up (hotplug).
# No flash write is performed — safe for NAND lifetime and read-only Factory.

# EEPROM offsets to override (5 GHz calibration, groups as in stock ROM)
_THROUGHWALL_OFFSETS="
81e 81f 820 821 822 823 824 825 826 827 828
82c 82d 82e 82f 830
835 836 837 838 839
83e 83f 840 841 842
848 849 84a 84b 84c
852 853 854 855 856
85c 85d 85e 85f 860
866 867 868 869 86a
870 871 872 873 874
87a 87b 87c 87d 87e
"

_THROUGHWALL_VALUE="c4c4"
_THROUGHWALL_IFACE="rax0"

viettel_throughwall_supported() {
	case "$(board_name)" in
	viettel,nr3053) return 0 ;;
	esac
	return 1
}

viettel_throughwall_enabled() {
	local val
	val=$(uci -q get throughwall.throughwall.enable)
	[ "$val" = "1" ]
}

viettel_throughwall_apply() {
	local off
	for off in $_THROUGHWALL_OFFSETS; do
		iwpriv "$_THROUGHWALL_IFACE" e2p "${off}=${_THROUGHWALL_VALUE}" 2>/dev/null
	done
	logger -t throughwall "Applied WiFi calibration boost on $_THROUGHWALL_IFACE (offsets 0x81e-0x87e -> 0x${_THROUGHWALL_VALUE})"
}

viettel_throughwall_update() {
	# Interface must be UP before iwpriv works
	ip link show dev "$_THROUGHWALL_IFACE" 2>/dev/null | grep -q 'state UP\|state UNKNOWN' || return 0

	if viettel_throughwall_enabled; then
		viettel_throughwall_apply
	fi
}
