#!/bin/bash
# SPDX-License-Identifier: MIT
# Copyright (C) 2026 VIKINGYFY

#移除luci-app-attendedsysupgrade
sed -i "/attendedsysupgrade/d" $(find ./feeds/luci/collections/ -type f -name "Makefile")
#修改默认主题
sed -i "s/luci-theme-bootstrap/luci-theme-$WRT_THEME/g" $(find ./feeds/luci/collections/ -type f -name "Makefile")
#修改immortalwrt.lan关联IP
sed -i "s/192\.168\.[0-9]*\.[0-9]*/$WRT_IP/g" $(find ./feeds/luci/modules/luci-mod-system/ -type f -name "flash.js")
#添加编译日期标识
sed -i "s/(\(luciversion || ''\))/(\1) + (' \/Build by Kinsum @$(TZ=UTC-8 date "+%y.%m.%d")')/g" $(find ./feeds/luci/modules/luci-mod-status/ -type f -name "10_system.js")

# ⚠️ 原两行 sed 现在先判断文件是否存在，避免因找不到文件而脚本中断
DEFAULT_SETTINGS="package/lean/default-settings/files/zzz-default-settings"
if [ -f "$DEFAULT_SETTINGS" ]; then
    sed -i "s/OpenWrt /Chris Build $(TZ=UTC-8 date "+%Y.%m.%d") @ OpenWrt /g" "$DEFAULT_SETTINGS"
    sed -i "s/DISTRIB_DESCRIPTION='.*'/DISTRIB_DESCRIPTION='ImmortalWRT SNAPSHOT \/ LuCI Master \/Build by Chris @$(TZ=UTC-8 date "+%y.%m.%d")'/g" "$DEFAULT_SETTINGS"
else
    echo "⚠️  $DEFAULT_SETTINGS not found, skip version modification"
fi

WIFI_SH=$(find ./target/linux/{mediatek/filogic,qualcommax}/base-files/etc/uci-defaults/ -type f -name "*set-wireless.sh" 2>/dev/null)
WIFI_UC="./package/network/config/wifi-scripts/files/lib/wifi/mac80211.uc"
if [ -f "$WIFI_SH" ]; then
	#修改WIFI名称
	sed -i "s/BASE_SSID='.*'/BASE_SSID='$WRT_SSID'/g" $WIFI_SH
	#修改WIFI密码
	sed -i "s/BASE_WORD='.*'/BASE_WORD='$WRT_WORD'/g" $WIFI_SH
elif [ -f "$WIFI_UC" ]; then
	#修改WIFI名称
	sed -i "s/ssid='.*'/ssid='$WRT_SSID'/g" $WIFI_UC
	#修改WIFI密码
	sed -i "s/key='.*'/key='$WRT_WORD'/g" $WIFI_UC
	#修改WIFI地区
	sed -i "s/country='.*'/country='CN'/g" $WIFI_UC
	#修改WIFI加密
	sed -i "s/encryption='.*'/encryption='psk2+ccmp'/g" $WIFI_UC
fi

CFG_FILE="./package/base-files/files/bin/config_generate"
#修改默认IP地址
sed -i "s/192\.168\.[0-9]*\.[0-9]*/$WRT_IP/g" $CFG_FILE
#修改默认主机名
sed -i "s/hostname='.*'/hostname='$WRT_NAME'/g" $CFG_FILE

#配置文件修改
echo "CONFIG_PACKAGE_luci=y" >> ./.config
echo "CONFIG_LUCI_LANG_zh_Hans=y" >> ./.config
echo "CONFIG_PACKAGE_luci-theme-$WRT_THEME=y" >> ./.config
echo "CONFIG_PACKAGE_luci-app-$WRT_THEME-config=y" >> ./.config

#引入私有扩展配置
if [ -f "$GITHUB_WORKSPACE/Config/PRIVATE.txt" ]; then
	echo "Applying private configurations from PRIVATE.txt..."
	cat $GITHUB_WORKSPACE/Config/PRIVATE.txt >> ./.config
fi

#手动调整的插件
if [ -n "$WRT_PACKAGE" ]; then
	echo -e "$WRT_PACKAGE" >> ./.config
fi

#无WIFI配置标志
if [[ "${WRT_CONFIG,,}" == *"wifi"* && "${WRT_CONFIG,,}" == *"no"* ]]; then
	echo "WRT_WIFI=wifi-no" >> $GITHUB_ENV
fi

#高通平台调整
DTS_PATH="./target/linux/qualcommax/dts/"
if [[ "${WRT_TARGET^^}" == *"QUALCOMMAX"* ]]; then
	#取消nss相关feed
	echo "CONFIG_FEED_nss_packages=n" >> ./.config
	echo "CONFIG_FEED_sqm_scripts_nss=n" >> ./.config
	#设置NSS版本
	echo "CONFIG_NSS_FIRMWARE_VERSION_12_5=y" >> ./.config
	#其他调整
	echo "CONFIG_PACKAGE_kmod-usb-serial-qualcomm=y" >> ./.config

	#无WIFI配置调整Q6大小
	if [[ "${WRT_CONFIG,,}" == *"wifi"* && "${WRT_CONFIG,,}" == *"no"* ]]; then
		find $DTS_PATH -type f ! -iname '*nowifi*' -exec sed -i 's/ipq\(6018\|8074\).dtsi/ipq\1-nowifi.dtsi/g' {} +
		echo "qualcommax set up nowifi successfully!"
	fi
fi

# ===== 新增内容开始 =====
# 1. 设置 root 密码为 erlang
ROOT_PWD_HASH=$(openssl passwd -1 'erlang')
mkdir -p ./files/etc
echo "root:${ROOT_PWD_HASH}:0:0:99999:7:::" > ./files/etc/shadow

# 2. 启用 zram-swap 解决编译错误
echo "CONFIG_PACKAGE_zram-swap=y" >> ./.config
# ===== 新增内容结束 =====

# ============================================
# 🐳 强制追加 Docker 配置（如果不存在）
# ============================================
if ! grep -q "CONFIG_PACKAGE_docker=y" .config; then
    cat >> .config << 'EOF'
CONFIG_PACKAGE_docker=y
CONFIG_PACKAGE_dockerd=y
CONFIG_PACKAGE_docker-compose=y
CONFIG_PACKAGE_containerd=y
CONFIG_PACKAGE_runc=y
CONFIG_PACKAGE_luci-app-dockerman=y
CONFIG_PACKAGE_luci-i18n-dockerman-zh-cn=y
CONFIG_PACKAGE_luci-lib-docker=y
CONFIG_PACKAGE_kmod-veth=y
CONFIG_PACKAGE_kmod-tun=y
CONFIG_PACKAGE_kmod-ipt-nat=y
CONFIG_PACKAGE_kmod-nf-ipvs=y
CONFIG_PACKAGE_kmod-nf-nat=y
CONFIG_PACKAGE_kmod-nf-conntrack=y
CONFIG_PACKAGE_kmod-br-netfilter=y
CONFIG_PACKAGE_kmod-fs-ext4=y
CONFIG_PACKAGE_kmod-fs-vfat=y
CONFIG_PACKAGE_e2fsprogs=y
CONFIG_PACKAGE_ip-full=y
CONFIG_PACKAGE_bridge-utils=y
CONFIG_PACKAGE_iptables=y
CONFIG_PACKAGE_kmod-ipt-nat6=y
CONFIG_PACKAGE_ttyd=y
CONFIG_PACKAGE_htop=y
EOF
    echo "✅ Docker config appended (was missing)"
else
    echo "✅ Docker config already exists, skipping"
fi

# ============================================
# 🎛️ 修改 athena_led 默认配置
# ============================================
ATHENA_CFG="./files/etc/config/athena_led"

if [ -f "$ATHENA_CFG" ]; then
    sed -i "s/option value '.*'/option value 'Chris love you.'/" "$ATHENA_CFG"
    sed -i "s/option lightLevel '.*'/option lightLevel '3'/" "$ATHENA_CFG"
    echo "✅ athena_led 配置已修改：文本='Chris love you.'，亮度=3"
else
    echo "⚠️ 未找到 athena_led 配置文件，路径：$ATHENA_CFG"
fi

# ============================================
# 🔧 修复递归依赖导致 defconfig 失败
# ============================================
# 移除已知的冲突选项（mihomo / kmod-oaf）
# 注意：这会使这些包不被编译，如需使用请等待上游修复 Kconfig
sed -i '/CONFIG_PACKAGE_mihomo/d' .config
sed -i '/CONFIG_PACKAGE_kmod-oaf/d' .config
echo "# CONFIG_PACKAGE_mihomo-alpha is not set" >> .config
echo "# CONFIG_PACKAGE_mihomo-meta is not set" >> .config
echo "# CONFIG_PACKAGE_kmod-oaf is not set" >> .config
echo "🔧 Recursive dependency items cleared"
