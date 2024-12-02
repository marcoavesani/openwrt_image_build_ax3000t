#!/bin/sh

# Variables
REPO_URL="https://api.github.com/repos/marcoavesani/openwrt_image_build_ax3000t/releases/latest"
TEMP_DIR="/tmp"
FIRMWARE_FILE="openwrt-ramips-mt7621-xiaomi_mi-router-ax3000t0-squashfs-sysupgrade.bin"
SHA256SUMS_FILE="sha256sums"

# Download the latest firmware URL
echo "Fetching firmware URL..."
FIRMWARE_URL=$(curl -s "$REPO_URL" \
  | grep -o '"browser_download_url": *"[^"]*' \
  | cut -d '"' -f 4 \
  | grep openwrt-ramips-mt7621-xiaomi_mi-router-ax3000t0-squashfs-sysupgrade.bin)

if [ -z "$FIRMWARE_URL" ]; then
  echo "Error: Unable to fetch firmware URL. Exiting."
  exit 1
fi
echo "Firmware URL fetched: $FIRMWARE_URL"

# Download the firmware
echo "Downloading firmware..."
wget -q -O "$TEMP_DIR/$FIRMWARE_FILE" "$FIRMWARE_URL"
if [ $? -ne 0 ]; then
  echo "Error: Firmware download failed. Exiting."
  exit 1
fi
echo "Firmware downloaded to $TEMP_DIR/$FIRMWARE_FILE."

# Download the sha256sums file
echo "Downloading sha256sums file..."
SHA256SUMS_URL=$(echo "$FIRMWARE_URL" | sed 's/\(.*\)\/[^\/]*$/\1\/sha256sums/')
wget -q -O "$TEMP_DIR/$SHA256SUMS_FILE" "$SHA256SUMS_URL"
if [ $? -ne 0 ]; then
  echo "Error: sha256sums download failed. Exiting."
  exit 1
fi
echo "sha256sums file downloaded to $TEMP_DIR/$SHA256SUMS_FILE."

mv /tmp/openwrt-ramips-mt7621-xiaomi_mi-router-ax3000t0-squashfs-sysupgrade.bin /tmp/openwrt-mediatek-filogic-xiaomi_mi-router-ax3000t-squashfs-sysupgrade.bin

FIRMWARE_FILE="openwrt-mediatek-filogic-xiaomi_mi-router-ax3000t-squashfs-sysupgrade.bin"
# Verify the firmware file's hash
echo "Verifying firmware hash..."
EXPECTED_HASH=$(grep "$FIRMWARE_FILE" "$TEMP_DIR/$SHA256SUMS_FILE" | cut -d ' ' -f 1)
if [ -z "$EXPECTED_HASH" ]; then
  echo "Error: Expected hash not found in sha256sums file. Exiting."
  exit 1
fi

ACTUAL_HASH=$(sha256sum "$TEMP_DIR/$FIRMWARE_FILE" | cut -d ' ' -f 1)

if [ "$EXPECTED_HASH" != "$ACTUAL_HASH" ]; then
  echo "Error: Hash mismatch. Expected: $EXPECTED_HASH, but got: $ACTUAL_HASH. Exiting."
  exit 1
fi

echo "Firmware hash verified successfully."

# Upgrade the firmware
echo "Starting firmware upgrade..."
sysupgrade "$TEMP_DIR/$FIRMWARE_FILE"
if [ $? -ne 0 ]; then
  echo "Error: Firmware upgrade failed. Exiting."
  exit 1
fi

echo "Firmware upgrade completed successfully!"
