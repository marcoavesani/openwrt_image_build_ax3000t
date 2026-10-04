#!/usr/bin/env bash
# Build an OpenWrt image for the Xiaomi Mi Router AX3000T with the OpenWrt
# ImageBuilder and, if GITHUB_TOKEN is set, publish it as a GitHub release.
#
# Environment (all optional):
#   OPENWRT_VERSION  "snapshot" (default) or a release such as "25.12.5"
#   GITHUB_TOKEN     token allowed to create releases; no token = no upload
#   GITHUB_REPO      owner/name of the repo to release to
#   KEEP_RELEASES    keep only the newest N releases; 0 (default) keeps all
#   OUT_DIR          where the images are copied (default /tmp/openwrt)
set -euo pipefail

OPENWRT_VERSION="${OPENWRT_VERSION:-snapshot}"
GITHUB_REPO="${GITHUB_REPO:-marcoavesani/openwrt_image_build_ax3000t}"
KEEP_RELEASES="${KEEP_RELEASES:-0}"
OUT_DIR="${OUT_DIR:-/tmp/openwrt}"

PROFILE="xiaomi_mi-router-ax3000t"
TARGET="mediatek/filogic"
RELEASE_TAG="$(date -u +%Y%m%d_%H%M%S)"

ROOT="$(cd "$(dirname "$0")" && pwd)"
WORK="$ROOT/work"

if [ "$OPENWRT_VERSION" = "snapshot" ]; then
	BASE_URL="https://downloads.openwrt.org/snapshots/targets/$TARGET"
	IB_NAME="openwrt-imagebuilder-${TARGET/\//-}.Linux-x86_64"
else
	BASE_URL="https://downloads.openwrt.org/releases/$OPENWRT_VERSION/targets/$TARGET"
	IB_NAME="openwrt-imagebuilder-$OPENWRT_VERSION-${TARGET/\//-}.Linux-x86_64"
fi

# modules.txt: strip comments and join everything into one line.
PACKAGES="$(sed -e 's/#.*//' "$ROOT/modules.txt" | xargs)"

echo "Building $RELEASE_TAG ($OPENWRT_VERSION) with: $PACKAGES"

rm -rf "$WORK"
mkdir -p "$WORK"
cd "$WORK"

# Download the ImageBuilder and check it against OpenWrt's own checksums.
wget -q "$BASE_URL/sha256sums" -O sha256sums.upstream
wget -q "$BASE_URL/$IB_NAME.tar.zst"
awk -v f="$IB_NAME.tar.zst" '$2 == f || $2 == "*" f' sha256sums.upstream | sha256sum -c -
tar --use-compress-program=unzstd -xf "$IB_NAME.tar.zst"

# Overlay files: the repo's files/ plus a stamp the upgrade script reads.
cp -a "$ROOT/files" "$WORK/files"
mkdir -p "$WORK/files/etc"
cat > "$WORK/files/etc/custom_release" <<EOF
RELEASE_TAG=$RELEASE_TAG
OPENWRT_VERSION=$OPENWRT_VERSION
GITHUB_REPO=$GITHUB_REPO
EOF

make -C "$IB_NAME" image \
	PROFILE="$PROFILE" \
	PACKAGES="$PACKAGES" \
	FILES="$WORK/files"

BIN="$WORK/$IB_NAME/bin/targets/$TARGET"
ls -la "$BIN"
mkdir -p "$OUT_DIR"
cp "$BIN"/*"$PROFILE"* "$BIN/sha256sums" "$OUT_DIR"/
ls -la "$OUT_DIR"

if [ -z "${GITHUB_TOKEN:-}" ]; then
	echo "GITHUB_TOKEN not set, skipping the GitHub release"
	exit 0
fi
export GH_REPO="$GITHUB_REPO"

# Release notes: what changed in the package manifest since the last release.
NOTES="$WORK/notes.md"
{
	echo "OpenWrt $OPENWRT_VERSION build for the Xiaomi AX3000T."
	echo
	echo "Requested packages: \`$PACKAGES\`"
	echo
	if gh release download --pattern '*.manifest' --dir "$WORK/prev" 2>/dev/null; then
		echo "### Package changes since $(gh release view --json tagName --jq .tagName)"
		echo
		CHANGES="$(diff -U0 "$WORK"/prev/*.manifest "$OUT_DIR"/*.manifest | grep -E '^[+-][^+-]' || true)"
		echo '```diff'
		echo "${CHANGES:-(no changes)}"
		echo '```'
	fi
} > "$NOTES"

gh release create "$RELEASE_TAG" \
	--title "$RELEASE_TAG ($OPENWRT_VERSION)" \
	--notes-file "$NOTES" \
	"$OUT_DIR"/*

# Optionally delete old releases (and their tags), keeping the newest N.
if [ "$KEEP_RELEASES" -gt 0 ]; then
	gh release list --limit 1000 --json tagName,createdAt \
		--jq "sort_by(.createdAt) | reverse | .[$KEEP_RELEASES:] | .[].tagName" |
	while read -r tag; do
		echo "Deleting old release $tag"
		gh release delete "$tag" --cleanup-tag --yes
	done
fi
