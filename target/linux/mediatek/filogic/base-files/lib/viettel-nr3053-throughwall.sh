# Viettel fork: throughWall WiFi calibration boost for NR3053.
# Ports stock /usr/sbin/throughWall.sh (MediaTek mt_wifi / iwpriv).
#
# Always on for viettel,nr3053 (no LuCI). Does NOT write Factory NAND —
# only the driver's in-RAM EEPROM via iwpriv e2p. Re-applied on boot /
# when rax0 appears.

# MediaTek iwpriv e2p writes a 16-bit word at an *even* offset.
_THROUGHWALL_OFFSETS="
81e 820 822 824 826 828
82c 82e 830
836 838
83e 840 842
848 84a 84c
852 854 856
85c 85e 860
866 868 86a
870 872 874
87a 87c 87e
"

_THROUGHWALL_VALUE="c4c4"
_THROUGHWALL_IFACE="rax0"
_THROUGHWALL_VERIFY_OFF="81e"

viettel_throughwall_supported() {
	case "$(board_name 2>/dev/null)" in
	viettel,nr3053) return 0 ;;
	esac
	return 1
}

viettel_throughwall_iwpriv() {
	if command -v iwpriv >/dev/null 2>&1; then
		command -v iwpriv
		return 0
	fi
	[ -x /usr/sbin/iwpriv ] && { echo /usr/sbin/iwpriv; return 0; }
	[ -x /sbin/iwpriv ] && { echo /sbin/iwpriv; return 0; }
	return 1
}

viettel_throughwall_iface_ready() {
	local iw
	iw=$(viettel_throughwall_iwpriv) || return 1
	[ -e "/sys/class/net/$_THROUGHWALL_IFACE" ] || return 1
	"$iw" "$_THROUGHWALL_IFACE" e2p "$_THROUGHWALL_VERIFY_OFF" >/dev/null 2>&1
}

viettel_throughwall_read_word() {
	local iw off out
	iw=$(viettel_throughwall_iwpriv) || return 1
	off=${1:-$_THROUGHWALL_VERIFY_OFF}
	out=$("$iw" "$_THROUGHWALL_IFACE" e2p "$off" 2>/dev/null) || return 1
	echo "$out" | tr 'A-F' 'a-f' | sed -n 's/.*\[0x[0-9a-f]*\]:0x\([0-9a-f][0-9a-f]*\).*/\1/p' | head -n1
}

viettel_throughwall_apply() {
	local iw off ok fail word
	iw=$(viettel_throughwall_iwpriv) || {
		logger -t throughwall "iwpriv not found (need kmod-mt_wifi) — cannot apply"
		return 1
	}

	ok=0
	fail=0
	for off in $_THROUGHWALL_OFFSETS; do
		if "$iw" "$_THROUGHWALL_IFACE" e2p "${off}=${_THROUGHWALL_VALUE}" >/dev/null 2>&1; then
			ok=$((ok + 1))
		else
			fail=$((fail + 1))
		fi
	done

	word=$(viettel_throughwall_read_word "$_THROUGHWALL_VERIFY_OFF")
	case "$word" in
	c4c4|C4C4)
		logger -t throughwall \
			"OK RAM e2p on ${_THROUGHWALL_IFACE}: verify[0x${_THROUGHWALL_VERIFY_OFF}]=0x${word} (wrote ${ok} words, fail=${fail}; Factory NAND untouched)"
		return 0
		;;
	esac

	logger -t throughwall \
		"FAIL apply on ${_THROUGHWALL_IFACE}: verify[0x${_THROUGHWALL_VERIFY_OFF}]=${word:-empty} ok=${ok} fail=${fail}"
	return 1
}

# Returns 0 when applied (or not this board), 1 when should retry later.
viettel_throughwall_update() {
	viettel_throughwall_supported || return 0
	viettel_throughwall_iface_ready || return 1
	viettel_throughwall_apply
}

viettel_throughwall_apply_with_retry() {
	local n max sleep_s
	max=${1:-30}
	sleep_s=${2:-2}
	n=0
	while [ "$n" -lt "$max" ]; do
		if viettel_throughwall_update; then
			return 0
		fi
		n=$((n + 1))
		sleep "$sleep_s"
	done
	logger -t throughwall "gave up after ${max} attempts — ${_THROUGHWALL_IFACE} never ready for iwpriv e2p"
	return 1
}
