# Tenda BE12 Pro · ImmortalWrt 云编译

基于 **ImmortalWrt 官方 master**，目标 `mediatek/filogic`，设备 `tenda_be12-pro`。采用主线 mt76 开源无线驱动，保留官方设备定义自带的 MT7992、MT7987 和 Airoha EN8811H 驱动/固件。

## 已集成

- LuCI 网页管理、HTTPS、简体中文。
- OpenClash（ImmortalWrt 官方 LuCI feed）与 Nikki（作者官方 feed）。
- 稳定版 `mihomo-meta`：在云端从源代码编译 ARM64 内核，Nikki 使用 `/usr/bin/mihomo`，OpenClash 的 `/etc/openclash/core/clash_meta` 链接到同一内核。无需首次启动时另行下载内核。
- firewall4 / nftables、dnsmasq-full、TUN、TPROXY 及插件依赖。
- 上级局域网经 WAN 访问路由器的规则。

**两个代理插件默认关闭，每次只启用一个。** 使用前在 LuCI 导入自己的订阅或配置；仓库不包含订阅、账号或密码。OpenClash 使用 Meta 内核，插件需要的 GeoIP/GeoSite 数据可在界面中更新。关闭一个插件并停止其服务后，再开启另一个，避免 DNS、端口、路由及 nftables 规则冲突。流量软/硬件卸载默认关闭。

## 云编译和下载

1. 打开仓库 **Actions → Build Tenda BE12 Pro → Run workflow**。
2. 修改配置、文件或脚本并推送到 `main` 也会自动编译。没有自动定时任务。
3. 等待全部步骤成功。单次编译最长允许 6 小时，实际时间取决于 GitHub runner 和下载情况。
4. 在该次运行页面的 **Artifacts** 下载 `immortalwrt-tenda-be12-pro-运行编号`，解压后核对 `sha256sums`。

固件 artifact 保留 30 天；日志 artifact 保留 14 天。不会自动发布 Release。固件包包含：

| 文件 | 用途 |
| --- | --- |
| `*tenda_be12-pro-squashfs-sysupgrade.bin` | 已运行兼容 OpenWrt/ImmortalWrt 的设备升级用 |
| `*tenda_be12-pro-initramfs-kernel.bin` | 临时内存启动/安装流程使用，不是通用原厂升级包 |
| `*.manifest` | 实际固件内的包及版本，工作流验证两个插件和内核都已包含 |
| `sha256sums` | 固件完整性校验 |
| `full.config`、`diffconfig`、`source-versions.txt` | 最终配置与源码/feed 版本 |

编译成功仅代表生成了固件，未经过实机刷写和网络测试。不要把 sysupgrade 或 initramfs 文件直接提交到腾达原厂升级页面。首次安装应按设备官方页面和与现有 Bootloader/分区布局匹配的方法操作；本项目不修改 Bootloader，也不生成通用 factory.bin。

## 首次访问

- LAN 地址：**192.168.10.1/24**，用网线连接 LAN 后打开 `http://192.168.10.1` 或 `https://192.168.10.1`。HTTPS 使用设备自签名证书。
- WAN 使用官方默认 DHCP。上级路由器 LAN 口接 BE12 Pro 的 WAN 口，在上级路由器客户端列表找到分配的 WAN IP；同一个上级局域网内的设备访问 `http://WAN-IP` / `https://WAN-IP`。
- LAN 和上级局域网不能使用同一网段。如果上级也是 `192.168.10.0/24`，先从 LAN 修改 BE12 Pro 的 LAN 网段。
- 用户名 `root`；未预设共享密码。首次从 LAN 登录后立即设置管理密码，再投入日常使用。SSH 密码登录需要先设置密码。

## WAN 放行范围

首次启动脚本添加 WAN **入站至本机** ACCEPT 规则，允许 IPv4 来源 `10.0.0.0/8`、`172.16.0.0/12`、`192.168.0.0/16`，以及 IPv6 ULA `fc00::/7` 和链路本地 `fe80::/10`。该范围内可访问管理界面、SSH 及已监听 WAN 的其他服务；没有端口限制。

WAN zone 的默认入站策略和 WAN→LAN 转发策略保持官方默认，防火墙继续运行。公网 IPv4 和 IPv6 全局地址不被这些规则放行。上级局域网若使用其他网段，需要在 LuCI 的防火墙规则中明确添加对应来源。插件启动后的自有防火墙规则可能影响代理端口访问，应在实机中检查。WAN 管理访问不等于旁路由部署已完成：若要给其他设备透明代理，还需按实际拓扑设置它们的网关/DNS。

使用 sysupgrade 保留旧配置时，旧配置可能覆盖首次启动设置；如需本仓库默认配置，请在备份后选择不保留配置升级。

## 固定源码与配置

`config/source.env` 固定 ImmortalWrt 主源码 commit；`config/feeds.conf` 使用官方支持的 `^commit` 语法固定全部 feeds。初始版本于 2026-10-02 核实。修改固定版本即可更新；若更新上游造成设备或插件选项失效，工作流会在编译前失败，不会默默生成缺少插件的固件。

`config/be12-pro.config` 为最小增量配置，`make defconfig` 展开官方默认依赖。使用单设备模式的 `CONFIG_TARGET_mediatek_filogic_DEVICE_tenda_be12-pro=y`；不引入本固件用不到且存在配置依赖循环的视频 feed。不要删掉官方设备默认驱动，也不要通过盲目扩大 rootfs 配置改变物理 NAND 分区。编译日志会显示空间超限等问题。

## 上游资料

- [OpenWrt BE12 Pro 硬件条目](https://openwrt.org/toh/hwdata/tenda/tenda_be12_pro)：官方支持状态为 snapshot。
- [OpenWrt 设备页面](https://openwrt.org/toh/tenda/be12_pro)
- [ImmortalWrt 官方设备定义](https://github.com/immortalwrt/immortalwrt/blob/0359f868e8f52897ff7b32eaa0b8ccdc4ec91cc7/target/linux/mediatek/image/filogic.mk)
- [OpenClash](https://github.com/vernesong/OpenClash)
- [Nikki](https://github.com/nikkinikki-org/OpenWrt-nikki)

固件及各插件遵守各自上游许可证；本仓库提供构建配置与自动化脚本。
