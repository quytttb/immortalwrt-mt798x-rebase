# ImmortalWrt - MT798x

```
This repository is worked on ImmortalWrt with MTK OpenWrt Feeds patches imported.
```

## Commit Cutoff Revisions

### ImmortalWrt: [2fee31c](https://github.com/immortalwrt/immortalwrt/commit/2fee31cb47dc2e2078cc7d962bcd21b49b6227db)

```
Merge Official Source

Signed-off-by: Tianling Shen <cnsztl@immortalwrt.org>
```

### MTK OpenWrt Feeds: [0a3ac21](https://git01.mediatek.com/plugins/gitiles/openwrt/feeds/mtk-openwrt-feeds/+/0a3ac21dccc74e12d2b1263a636085c9fd532dd5)

```
[][HIGH][kernel/kernel-6.12][mt7988/87][eth][Fix incorrect HW LRO auto-learn refresh timer register]

[Description]
Fix incorrect HW LRO auto-learn refresh timer register.

The original auto-learn refresh timer register is only applicable to
LROv1. MT7988 uses LROv2, and the register is not shared between the
two versions. As a result, the intended configuration value was never
written to the correct register, causing offloaded flows to take at
least 30 seconds to age out.

Without this patch, candidate flows must wait at least 30 seconds
before they have a chance to be offloaded, instead of the expected
1 second.

[Release-log]
N/A


Change-Id: I8da166f9b8a70809279493f3fc91975a86e53f84
Reviewed-on: https://gerrit.mediatek.inc/c/openwrt/feeds/mtk_openwrt_feeds/+/12273616
```

### l1parser: [081bb31](https://github.com/chasey-dev/l1parser/commit/081bb31211efc74594d25bfd1bb5811f3408a205)

```
feat(ucode): add get all device map support
```
## About External Devices HNAT
> [!WARNING]
> Current HNAT support for external devices is basic and lack of complete test for various types. Please use with caution.

> [!IMPORTANT]
> Please keep interface `rxppd` in your bridge device (e.g. `br-lan`) while using external device HNAT.

### Support Matrix:
|               |  Ext as WAN   | Ext as LAN                |
|   :----:      |   :----:      | :----:                    |
|  **Ethernet** |      ✔️       |   ❌                     |
| **AP/ApCli**  |      ✔️       |   ⚠️(**Untested**)       |

## Acknowledgements
HNAT support for external devices is adapted from [Padavanonly's repo](https://github.com/padavanonly/immortalwrt-mt798x-6.6). 