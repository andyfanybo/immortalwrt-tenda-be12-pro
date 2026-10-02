#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
TARGET="$PWD/openwrt/bin/targets/mediatek/filogic"
shopt -s nullglob
images=("$TARGET"/*tenda_be12-pro*sysupgrade.bin)
if [ "${#images[@]}" -ne 1 ]; then
  echo "Expected one BE12 Pro sysupgrade image; found ${#images[@]}" >&2
  ls -lah "$TARGET" >&2
  exit 1
fi
UNSQUASHFS=${UNSQUASHFS:-"$PWD/openwrt/staging_dir/host/bin/unsquashfs4"}
test -x "$UNSQUASHFS"
VERIFY="$PWD/openwrt/tmp/closed-image-verification"
mkdir -p "$VERIFY"
# Generic root.orig manifests may omit modules in the per-device rootfs.
# Inspect the actual BE12 Pro image and generate its installed package list.
tar -xOf "${images[0]}" sysupgrade-tenda_be12-pro/root > "$VERIFY/root.squashfs"
# Only extract the package database. Full extraction tries to create /dev/console
# and fails for an unprivileged runner even though the firmware itself is valid.
"$UNSQUASHFS" -no-progress -d "$VERIFY/rootfs" "$VERIFY/root.squashfs" lib/apk/db/installed
MANIFEST="$TARGET/immortalwrt-mediatek-filogic-tenda_be12-pro.manifest"
python3 scripts/read-apk-installed.py "$VERIFY/rootfs/lib/apk/db/installed" > "$MANIFEST"
test -s "$MANIFEST"
for package in kmod-mt798x-2p5g-phy mt798x-2p5g-phy-firmware-internal \
  kmod-phy-airoha-en8811h airoha-en8811h-firmware; do
  if ! grep -Eq "^${package} " "$MANIFEST"; then
    echo "Missing installed PHY package: $package" >&2
    exit 1
  fi
done
cp "$MANIFEST" build-info/verified-device.manifest
bash scripts/collect.sh closed-source
