#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
cd "$ROOT"
mkdir -p build-info
source config/source.env
git init openwrt
git -C openwrt remote add origin "$SOURCE_URL"
git -C openwrt fetch --depth=1 origin "$SOURCE_COMMIT"
git -C openwrt checkout --detach FETCH_HEAD
test "$(git -C openwrt rev-parse HEAD)" = "$SOURCE_COMMIT"
grep -q '^define Device/tenda_be12-pro$' openwrt/target/linux/mediatek/image/filogic.mk
cp config/feeds.conf openwrt/feeds.conf.default
cp -a files openwrt/
cp -a files-open-source/. openwrt/files/
chmod 0755 openwrt/files/etc/uci-defaults/zzz-be12-pro-custom
chmod 0755 openwrt/files/etc/uci-defaults/zzzz-open-source-defaults
chmod 0755 openwrt/files/etc/uci-defaults/zzzzz-open-source-network
cd openwrt
./scripts/feeds update -a
./scripts/feeds install -a
# Only build the stable Mihomo provider. Keep the final app/language choices
# until after feed installation, when all of their Kconfig symbols exist.
rm -f package/feeds/nikki/mihomo-alpha
cp "$ROOT/config/be12-pro.config" .config
# Both frontends use the stable Mihomo binary compiled by the Nikki feed.
# A symlink avoids including a second large ARM64 core in 128 MB NAND.
mkdir -p files/etc/openclash/core
ln -s /usr/bin/mihomo files/etc/openclash/core/clash_meta
{
  printf 'ImmortalWrt %s\n' "$(git rev-parse HEAD)"
  for feed in packages luci routing telephony nikki; do
    printf '%s %s\n' "$feed" "$(git -C "feeds/$feed" rev-parse HEAD)"
  done
} > "$ROOT/build-info/source-versions.txt"
cp feeds.conf.default "$ROOT/build-info/feeds.conf"
cp "$ROOT/config/source.env" "$ROOT/build-info/source.env"
