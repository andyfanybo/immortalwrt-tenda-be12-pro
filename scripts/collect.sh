#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
FLAVOR=${1:-open-source}
case "$FLAVOR" in
  open-source|closed-source) ;;
  *) echo "Unknown flavor: $FLAVOR" >&2; exit 1;;
esac
TARGET=openwrt/bin/targets/mediatek/filogic
mkdir -p firmware
shopt -s nullglob
sysupgrade=("$TARGET"/*tenda_be12-pro*sysupgrade.bin)
initramfs=("$TARGET"/*tenda_be12-pro*initramfs-kernel.bin)
test "${#sysupgrade[@]}" -eq 1
test "${#initramfs[@]}" -eq 1
for image in "${sysupgrade[@]}" "${initramfs[@]}"; do
  cp "$image" "firmware/${FLAVOR}-$(basename "$image")"
done
manifest=("$TARGET"/*tenda_be12-pro*.manifest)
test "${#manifest[@]}" -gt 0
cp "${manifest[@]}" firmware/
for package in luci-app-openclash mihomo-meta firewall4 dnsmasq-full; do
  grep -Eq "^${package} " "${manifest[0]}"
done
if [ "$FLAVOR" = closed-source ]; then
  for package in luci-app-nikki nikki kmod-mt_wifi7 kmod-mt_hwifi kmod-mt7992 wifi-profile luci-app-mtwifi-cfg; do
    grep -Eq "^${package} " "${manifest[0]}"
  done
else
  if grep -Eq '^(nikki|luci-app-nikki|luci-i18n-nikki-[^ ]+) ' "${manifest[0]}"; then
    echo 'Open-source firmware must not include Nikki' >&2
    exit 1
  fi
fi
cp "$TARGET/profiles.json" firmware/
cp build-info/full.config build-info/diffconfig build-info/source-versions.txt firmware/
cp README.md firmware/README.md
printf '%s\n' "$FLAVOR" > firmware/build-flavor.txt
(cd firmware && sha256sum "${FLAVOR}"-*.bin > sha256sums)
{
  echo '### BE12 Pro 固件已生成'
  echo "固件类型：${FLAVOR}。下载对应 Release 或本次运行的 ${FLAVOR} artifact。"
  if [ "$FLAVOR" = open-source ]; then
    echo 'OpenClash 和 Mihomo 已预装，OpenClash 默认关闭；LAN 地址 192.168.1.1。'
  else
    echo 'OpenClash 与 Nikki 已预装，默认关闭；LAN 地址 192.168.10.1。'
  fi
  echo 'WAN 允许私有局域网入站访问本机。'
  echo '```'
  cat firmware/sha256sums
  echo '```'
} >> "${GITHUB_STEP_SUMMARY:-/dev/null}"
