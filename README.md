[![Build Status](https://circleci.com/gh/marcoavesani/openwrt_image_build_ax3000t/tree/master.svg?style=svg)](https://circleci.com/gh/marcoavesani/openwrt_image_build_ax3000t/tree/master)
[Latest build](https://github.com/marcoavesani/openwrt_image_build_ax3000t/releases/latest)

# OpenWrt images for the Xiaomi Mi Router AX3000T

Weekly OpenWrt images for the Xiaomi Mi Router AX3000T, built with the
official [ImageBuilder](https://openwrt.org/docs/guide-user/additional-software/imagebuilder)
and a custom package list.

## How it works

- `modules.txt` lists the packages to add (or, with a leading `-`, remove).
  Comments after `#` are allowed.
- `files/` is copied into the image as-is (upgrade script, first-boot defaults, sysctl).
- `build_ax3000t.sh` downloads the ImageBuilder, checks it against OpenWrt's
  `sha256sums`, builds the image and, when `GITHUB_TOKEN` is set, publishes a
  release whose notes list the package changes since the previous one.
- [CircleCI](https://app.circleci.com/pipelines/github/marcoavesani/openwrt_image_build_ax3000t)
  runs the script on every push and every Friday at 23:00 UTC. Only master
  builds are released; other branches keep their images as CircleCI artifacts.

### Settings (CircleCI project environment variables)

| Variable | Default | Meaning |
|---|---|---|
| `GITHUB_TOKEN` | — | Token allowed to create releases (required to publish) |
| `OPENWRT_VERSION` | `snapshot` | `snapshot`, or a release such as `25.12.5` |
| `KEEP_RELEASES` | `0` | Keep only the newest N releases; `0` keeps them all |

Note: `mesh11sd` is only available in snapshot, so remove it from
`modules.txt` before switching to a stable release.

### Building locally

```sh
./build_ax3000t.sh            # images end up in /tmp/openwrt
```

Needs the usual [ImageBuilder prerequisites](https://openwrt.org/docs/guide-user/additional-software/imagebuilder#prerequisites)
and `zstd`.

## Upgrading the router

The image includes `/usr/bin/auto_upgrade_openwrt`. It reads the installed
build from `/etc/custom_release`, downloads the latest release, verifies its
checksum, tests it with `sysupgrade -T` and flashes it, keeping settings.

```sh
auto_upgrade_openwrt -n   # dry run: download and verify only
auto_upgrade_openwrt      # upgrade if a newer build exists
auto_upgrade_openwrt -f   # reflash even if already on the latest build
```

The checksum guards against a corrupted download, not against a compromised
GitHub account.

Routers still running an older build have the old `/auto_upgrade_openwrt.sh`,
which looks for the previous (mislabelled `ramips-mt7621`) asset names and
won't find the new ones. Upgrade those once with the new script:

```sh
wget -O /tmp/auto_upgrade_openwrt https://raw.githubusercontent.com/marcoavesani/openwrt_image_build_ax3000t/master/files/usr/bin/auto_upgrade_openwrt
sh /tmp/auto_upgrade_openwrt
```

## First-boot defaults

- irqbalance is enabled (`files/etc/uci-defaults/99-custom-defaults`).
- BBR is the default TCP congestion control (`files/etc/sysctl.d/12-tcp-bbr.conf`).
- SQM is installed but not configured: set your line speed in LuCI under
  Network → SQM QoS. Don't enable flow offloading at the same time, because
  offloaded traffic bypasses SQM.

## Acknowledgement

Originally based on [trinhpham/xiaomi-r3g-openwrt-builder](https://github.com/trinhpham/xiaomi-r3g-openwrt-builder).
