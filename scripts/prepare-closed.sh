#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
cd "$ROOT"
mkdir -p build-info
source config/closed-source/source.env
git init openwrt
git -C openwrt remote add origin "$SOURCE_URL"
git -C openwrt fetch --depth=1 origin "$SOURCE_COMMIT"
git -C openwrt checkout --detach FETCH_HEAD
test "$(git -C openwrt rev-parse HEAD)" = "$SOURCE_COMMIT"
grep -q '^define Device/tenda_be12-pro$' openwrt/target/linux/mediatek/image/filogic-ext.mk
test -f "openwrt/$BASE_CONFIG"
cp "openwrt/$BASE_CONFIG" build-info/upstream-base.config
cp config/closed-source/feeds.conf openwrt/feeds.conf.default
# Preserve the full vendor Wi-Fi 7 stack. Overlay only device/app choices.
# Last assignment wins, including explicit '# CONFIG_... is not set' entries.
python3 - "openwrt/$BASE_CONFIG" config/closed-source/be12-pro.config build-info/requested.config <<'PY'
import re
import sys
from pathlib import Path
symbols = {}
for path in sys.argv[1:3]:
    for line in Path(path).read_text().splitlines():
        if 'routerich_be7200' in line:
            continue
        match = re.match(r'^(CONFIG_\w+)=(.*)$|^# (CONFIG_\w+) is not set$', line)
        if match:
            symbols[match.group(1) or match.group(3)] = line
        elif re.match(r'^(CONFIG_[^= ]+)=', line):
            # Device and package names can include hyphens.
            symbols[line.split('=', 1)[0]] = line
        elif re.match(r'^# CONFIG_[^ ]+ is not set$', line):
            symbols[line.split()[1]] = line
Path(sys.argv[3]).write_text('\n'.join(symbols.values()) + '\n')
PY
cp -a files openwrt/
chmod 0755 openwrt/files/etc/uci-defaults/zzz-be12-pro-custom
cd openwrt
./scripts/feeds update -a
./scripts/feeds install -a
# The 25.12 Kconfig generator recurses on the two mutually conflicting Mihomo
# providers. We build only the stable provider; leave alpha out of package scans.
rm -f package/feeds/nikki/mihomo-alpha
# Feed installation can normalize .config before all packages are available.
# Apply the complete desired configuration only after installing the feeds.
cp "$ROOT/build-info/requested.config" .config
mkdir -p files/etc/openclash/core
ln -s /usr/bin/mihomo files/etc/openclash/core/clash_meta
{
  printf 'Flavor closed-source\nSource %s\nBranch %s\nCommit %s\n' "$SOURCE_URL" "$SOURCE_BRANCH" "$(git rev-parse HEAD)"
  for feed in packages luci routing telephony nikki; do
    printf '%s %s\n' "$feed" "$(git -C "feeds/$feed" rev-parse HEAD)"
  done
} > "$ROOT/build-info/source-versions.txt"
cp feeds.conf.default "$ROOT/build-info/feeds.conf"
cp "$ROOT/config/closed-source/source.env" "$ROOT/build-info/source.env"
