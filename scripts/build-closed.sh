#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
mkdir -p "$ROOT/build-info"
cd "$ROOT/openwrt"
export NO_COLOR=1
echo "开始并行编译（$(nproc) 线程）。页面显示包级进度，详细命令保存在 build.log。"
if make -j"$(nproc)" V=s 2>&1 | tee "$ROOT/build-info/build.log" \
  | python3 "$ROOT/scripts/build-output.py"; then
  echo '固件编译成功。'
  exit 0
else
  status=$?
  echo "并行编译失败（退出码 $status），开始单线程详细重试。"
fi
if make -j1 V=s 2>&1 | tee "$ROOT/build-info/build-retry.log" \
  | python3 "$ROOT/scripts/build-output.py"; then
  echo '单线程重试成功，继续校验和发布固件。'
  exit 0
else
  status=$?
  echo '::error::闭源固件编译失败。下方为错误摘要，完整日志见 build-info 附件。'
  python3 "$ROOT/scripts/build-output.py" --summary \
    "$ROOT/build-info/build-retry.log" "$ROOT/build-info/build.log" || true
  exit "$status"
fi
