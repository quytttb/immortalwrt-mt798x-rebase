#!/bin/sh
# Append extra DNS blocklist feeds to /etc/adblock/adblock.feeds on first boot.
# Do NOT use adblock.custom.feeds (Adblock 4.5.6 replaces the whole catalog).

FEEDS=/etc/adblock/adblock.feeds

[ -f "$FEEDS" ] || exit 0

add_feed() {
	name="$1"
	body="$2"
	grep -q "\"$name\"" "$FEEDS" && return 0
	TMP=/tmp/adblock.feeds.$$
	head -n -1 "$FEEDS" >"$TMP" || return 1
	printf ',\n%s\n}\n' "$body" >>"$TMP"
	mv "$TMP" "$FEEDS"
}

add_feed reg_vn '	"reg_vn": {
		"url": "https://raw.githubusercontent.com/bigdargon/hostsVN/master/hosts",
		"rule": "feed 0.0.0.0 2",
		"size": "S",
		"descr": "reg_vietnam"
	}'

add_feed adguard_mobile '	"adguard_mobile": {
		"url": "https://filters.adtidy.org/extension/chromium/filters/11.txt",
		"rule": "feed || 3 [|^]",
		"size": "S",
		"descr": "adguard_mobile_ads"
	}'

add_feed abpvn '	"abpvn": {
		"url": "https://raw.githubusercontent.com/abpvn/abpvn/master/filter/abpvn.txt",
		"rule": "feed || 3 [|^]",
		"size": "S",
		"descr": "abpvn_vietnam"
	}'

exit 0
