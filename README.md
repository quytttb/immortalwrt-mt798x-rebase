# ImmortalWrt - MT798x

```
This repository is worked on ImmortalWrt with MTK OpenWrt Feeds patches imported.
```

## Commit Cutoff Revisions

### ImmortalWrt: [62bd6b3](https://github.com/immortalwrt/immortalwrt/commit/62bd6b3625b47308343252e7875107a8bd665765) - OpenWrt 25.12 SNAPSHOT

```
Merge Official Source

Signed-off-by: Tianling Shen <cnsztl@immortalwrt.org>
```

### MTK OpenWrt Feeds: [2459584](https://git01.mediatek.com/plugins/gitiles/openwrt/feeds/mtk-openwrt-feeds/+/24595844f63aebb6ccb9bcd28d9690dbfc541a46)

```
[][MAC80211][kernel-6.12][wed][Refactor wed msdu page ring init for next generation wifi chip compatible]

[Description]
Refactor wed msdu page ring init for next generation wifi chip compatible
and add mt76 patch for mp4.3 build pass

[Root Cause]
N/A

[Solution]
N/A

[How to Verify]
N/A

[Info to Customer]
N/A

Change-Id: I65784a91c8657b65e0b7ab4961c3a7da8a7cab50
Reviewed-on: https://gerrit.mediatek.inc/c/openwrt/feeds/mtk_openwrt_feeds/+/11890197
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