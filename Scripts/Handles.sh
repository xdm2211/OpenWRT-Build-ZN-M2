#!/bin/bash

# =========================================================
# 路径定义 (适配 GitHub Actions 环境)
# =========================================================
PKG_PATH="$GITHUB_WORKSPACE/wrt/package"
FEED_PATH="$GITHUB_WORKSPACE/wrt/feeds"

# 1. NSS 相关组件启动顺序优化 (有线加速稳定性的关键)
# ---------------------------------------------------------
# 将启动顺序从默认调整为 85，确保网络栈完全就绪后再加载 NSS 驱动
NSS_DRV_FILE=$(find "$FEED_PATH" -type f -name "qca-nss-drv.init" | head -n 1)
if [ -f "$NSS_DRV_FILE" ]; then
    sed -i 's/START=.*/START=85/g' "$NSS_DRV_FILE"
fi

# 2. 彻底抹除无线残留 (驱动定义与初始化脚本)
# ---------------------------------------------------------
# 物理删除 mac80211 的初始化定义，从根源切断无线配置生成
find "$PKG_PATH" -type f -name "mac80211.sh" -delete
rm -f "$PKG_PATH/base-files/files/etc/config/wireless"

# 3. 清理 LuCI 应用中可能残留的无线插件目录
# ---------------------------------------------------------
# 彻底删除 MTK 专用无线界面和无线定时插件，防止它们出现在编译菜单中
find "$FEED_PATH/luci/" -type d -name "*luci-app-mtwifi*" | xargs rm -rf
find "$FEED_PATH/luci/" -type d -name "*luci-app-wifi-schedule*" | xargs rm -rf

# 4. 提升有线并发性能 (内核参数调优)
# ---------------------------------------------------------
# [优化] 增大 nf_conntrack_max 到 131072，适配 512M/1G 内存设备的高并发需求
if ! grep -q "nf_conntrack_max" "$PKG_PATH/base-files/files/etc/sysctl.conf"; then
    echo "net.netfilter.nf_conntrack_max=131072" >> "$PKG_PATH/base-files/files/etc/sysctl.conf"
fi

# 5. 修复 Rust 编译环境 (解决编译插件如 OpenClash 时的报错)
# ---------------------------------------------------------
# [优化] 扩大搜索范围到整个 feeds 目录，防止 rust 包路径变更导致查找失败
RUST_FILE=$(find "$FEED_PATH" -maxdepth 4 -type f -wholename "*/rust/Makefile" | head -n 1)
if [ -n "$RUST_FILE" ] && [ -f "$RUST_FILE" ]; then
    sed -i 's/ci-llvm=true/ci-llvm=false/g' "$RUST_FILE"
fi