#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
FLAVOR=${1:?Usage: publish-release.sh open-source|closed-source}
ARTIFACT_DIR=$(cd "${2:-firmware}" && pwd)
case "$FLAVOR" in
  open-source) LABEL='开源驱动 mt76';;
  closed-source) LABEL='闭源驱动 MTK Wi-Fi 7 · chasey-dev';;
  *) echo "Unknown flavor: $FLAVOR" >&2; exit 1;;
esac
test "$(cat "$ARTIFACT_DIR/build-flavor.txt")" = "$FLAVOR"
(cd "$ARTIFACT_DIR" && sha256sum -c sha256sums)
TAG="${RELEASE_TAG:-${FLAVOR}-$(date +%Y%m%d)-${GITHUB_RUN_ID:?}-${GITHUB_RUN_ATTEMPT:?}}"
mkdir -p build-info
{
  printf '# Tenda BE12 Pro · %s\n\n' "$LABEL"
  printf '固件类型：**%s**。仅包含该驱动版本的固件，请勿与另一类型混淆。\n\n' "$FLAVOR"
  printf '编译记录：[GitHub Actions](%s/%s/actions/runs/%s)。\n\n' "$GITHUB_SERVER_URL" "$GITHUB_REPOSITORY" "$GITHUB_RUN_ID"
  echo '预装 OpenClash、Nikki 和稳定版 Mihomo，两个插件默认关闭，每次只启用一个。'
  echo 'LAN 地址 192.168.10.1；WAN 允许上级私有局域网访问本机。'
  if [ -f "$ARTIFACT_DIR/default-settings.txt" ]; then
    echo
    cat "$ARTIFACT_DIR/default-settings.txt"
  else
    echo '首次登录后设置 root 密码。'
  fi
  echo
  echo 'sysupgrade 用于兼容系统升级；initramfs 用于临时启动/设备安装流程，不是原厂网页升级包。'
  echo '请核对当前 Bootloader/分区布局。跨驱动版本升级请备份配置后不保留旧配置。未经过实机测试。'
  echo
  echo '## 固定源码版本'
  echo '```text'
  cat "$ARTIFACT_DIR/source-versions.txt"
  echo '```'
  echo
  echo '## SHA256'
  echo '```text'
  cat "$ARTIFACT_DIR/sha256sums"
  echo '```'
} > build-info/release-notes.md
# Upload to a draft first. A failed upload never leaves a published partial release.
gh release create "$TAG" "$ARTIFACT_DIR"/* --repo "$GITHUB_REPOSITORY" \
  --target "$GITHUB_SHA" --draft --title "BE12 Pro · ${LABEL} · $(date +%Y-%m-%d) · ${GITHUB_RUN_ID}" \
  --notes-file build-info/release-notes.md
gh release edit "$TAG" --repo "$GITHUB_REPOSITORY" --draft=false --latest=false
printf '\nRelease: %s/%s/releases/tag/%s\n' "$GITHUB_SERVER_URL" "$GITHUB_REPOSITORY" "$TAG" >> "${GITHUB_STEP_SUMMARY:-/dev/null}"
