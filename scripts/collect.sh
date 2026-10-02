#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
TARGET=openwrt/bin/targets/mediatek/filogic
mkdir -p firmware
shopt -s nullglob
sysupgrade=("$TARGET"/*tenda_be12-pro*sysupgrade.bin)
initramfs=("$TARGET"/*tenda_be12-pro*initramfs-kernel.bin)
test "${#sysupgrade[@]}" -eq 1
test "${#initramfs[@]}" -eq 1
cp "${sysupgrade[@]}" "${initramfs[@]}" firmware/
manifest=("$TARGET"/*tenda_be12-pro*.manifest)
test "${#manifest[@]}" -gt 0
cp "${manifest[@]}" firmware/
for package in luci-app-openclash luci-app-nikki nikki mihomo-meta firewall4 dnsmasq-full; do
  grep -Eq "^${package} " "${manifest[0]}"
done
cp "$TARGET/profiles.json" firmware/
cp build-info/full.config build-info/diffconfig build-info/source-versions.txt firmware/
cp README.md firmware/README.md
(cd firmware && sha256sum *.bin > sha256sums)
{
  echo '### BE12 Pro 固件已生成'
  echo '下载本次运行的 immortalwrt-tenda-be12-pro artifact。'
  echo 'OpenClash 与 Nikki 已预装，默认关闭；每次只启用一个。'
  echo 'WAN 允许私有局域网入站；默认 LAN 地址为 192.168.10.1。'
  echo '```'
  cat firmware/sha256sums
  echo '```'
} >> "${GITHUB_STEP_SUMMARY:-/dev/null}"
