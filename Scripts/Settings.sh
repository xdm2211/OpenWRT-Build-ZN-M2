#!/bin/bash

# 1. 基础系统设置 (IP地址与主机名)
CFG_FILE="./package/base-files/files/bin/config_generate"

# [修正] 精确修改 LAN IP
# 使用正则匹配默认 IP (例如 192.168.1.1)，即使上游源码变动也能生效
if [ -n "$WRT_IP" ]; then
    sed -i "s/lan) ipad=\${2:-[0-9]*\.[0-9]*\.[0-9]*\.[0-9]*}/lan) ipad=\${2:-$WRT_IP}/" "$CFG_FILE"
fi

# [修正] 修改默认主机名
if [ -n "$WRT_NAME" ]; then
    sed -i "s/hostname='.*'/hostname='$WRT_NAME'/g" "$CFG_FILE"
fi

# 2. 彻底禁用无线初始化 
rm -f ./package/base-files/files/etc/config/wireless

# 3. 核心组件冲突解决 
sed -i 's/CONFIG_PACKAGE_dnsmasq=y/# CONFIG_PACKAGE_dnsmasq is not set/g' .config
echo "CONFIG_PACKAGE_dnsmasq-full=y" >> .config
echo "CONFIG_PACKAGE_luci=y" >> .config
echo "CONFIG_LUCI_LANG_zh_Hans=y" >> .config

# 4. 高通 Qualcommax 平台稳定性加固 
if [[ "${WRT_TARGET^^}" == *"QUALCOMMAX"* ]]; then 
    echo "CONFIG_FEED_sqm_scripts_nss=n" >> .config 
    if [[ "${WRT_CONFIG,,}" == *"ipq50"* ]]; then 
        echo "CONFIG_PACKAGE_nss-firmware-ipq5018=y" >> .config
    else
        echo "CONFIG_PACKAGE_nss-firmware-ipq6018=y" >> .config
    fi
    echo "CONFIG_PACKAGE_kmod-qca-nss-drv=y" >> .config
    echo "CONFIG_PACKAGE_kmod-qca-nss-ecm=y" >> .config
fi

if [ -n "$WRT_PACKAGE" ]; then
    echo "$WRT_PACKAGE" >> .config
fi

exit 0