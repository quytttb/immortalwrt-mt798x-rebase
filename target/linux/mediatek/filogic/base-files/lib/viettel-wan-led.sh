# Viettel fork: one WAN color at a time (carrier only). Blue status is reserved for sysupgrade via diag.sh.

viettel_wan_led_supported() {
	case "$(board_name)" in
	viettel,nr3053|viettel,32x6) return 0 ;;
	esac
	return 1
}

viettel_wan_led_suspended() {
	[ -f /tmp/sysupgrade ] || [ -f /tmp/viettel-wan-led.suspend ]
}

_viettel_wan_led_names() {
	GREEN=green:status
	RED=red:status
	BLUE=

	case "$(board_name)" in
	viettel,32x6)
		BLUE=blue:status
		;;
	esac
}

viettel_wan_led_set() {
	local state="$1"

	_viettel_wan_led_names
	. /lib/functions/leds.sh

	led_off "$GREEN"
	led_off "$RED"
	[ -n "$BLUE" ] && led_off "$BLUE"

	case "$state" in
	up) led_on "$GREEN" ;;
	down) led_on "$RED" ;;
	esac
}

viettel_wan_led_update() {
	viettel_wan_led_suspended && return 0

	if [ "$1" = down ] || ! ip link show dev wan 2>/dev/null | grep -q 'LOWER_UP'; then
		viettel_wan_led_set down
	else
		viettel_wan_led_set up
	fi
}

viettel_wan_led_suspend() {
	touch /tmp/viettel-wan-led.suspend
}
