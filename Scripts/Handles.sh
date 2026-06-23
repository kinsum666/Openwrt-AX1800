#!/bin/bash
# SPDX-License-Identifier: MIT
# Copyright (C) 2026 kinsum

OPENWRT_ROOT="$GITHUB_WORKSPACE/wrt"
cd "$OPENWRT_ROOT" || exit 1

# ========== 新增：代理软件 feeds ==========
if ! grep -q "openappfilter" feeds.conf.default; then
    echo "src-git openappfilter https://github.com/destan19/OpenAppFilter.git" >> feeds.conf.default
    echo "OAF feed added"
fi

if ! grep -q "src-git kenzok8" feeds.conf.default; then
    echo "src-git kenzok8 https://github.com/kenzok8/openwrt-packages.git" >> feeds.conf.default
fi
if ! grep -q "src-git small" feeds.conf.default; then
    echo "src-git small https://github.com/kenzok8/small.git" >> feeds.conf.default
fi
if ! grep -q "src-git openclash" feeds.conf.default; then
    echo "src-git openclash https://github.com/vernesong/OpenClash.git" >> feeds.conf.default
fi

if ! grep -q "src-git kiddin9" feeds.conf.default; then
    echo "src-git kiddin9 https://github.com/kiddin9/openwrt-packages.git" >> feeds.conf.default
    echo "kiddin9 feed added"
fi
echo "proxy feeds added"
# ==========================================

# 修改 openwrt_release 中的描述
RELEASE_FILE="package/base-files/files/etc/openwrt_release"
if [ -f "$RELEASE_FILE" ]; then
    sed -i "s/DISTRIB_DESCRIPTION='.*'/DISTRIB_DESCRIPTION='ImmortalWRT \/ LuCI Master \/Build by Kinsum @$(date +%y.%m.%d)'/" "$RELEASE_FILE"
else
    echo "⚠️  $RELEASE_FILE not found, skip DISTRIB_DESCRIPTION modification"
fi

# ========== 修改 banner 登录欢迎信息（防重复） ==========
BANNER_FILE="package/base-files/files/etc/banner"
if [ -f "$BANNER_FILE" ]; then
    if grep -q "Compiled by Kinsum" "$BANNER_FILE"; then
        echo "Banner already modified, skipping."
    else
        cat >> "$BANNER_FILE" << "EOF"
-----------------------------------------------
  Firmware: JDC
  Compiled by Kinsum @ $(TZ=UTC-8 date '+%Y-%m-%d %H:%M:%S')
-----------------------------------------------
EOF
    fi
else
    echo "⚠️  $BANNER_FILE not found, skip banner modification"
fi

# 自定义版本显示（ImmortalWrt 真实文件）
DEFAULT_SETTINGS="package/emortal/default-settings/files/99-default-settings"
if [ -f "$DEFAULT_SETTINGS" ]; then
    sed -i "s/OpenWrt /Chris Build $(TZ=UTC-8 date "+%Y.%m.%d") @ OpenWrt /g" "$DEFAULT_SETTINGS"
else
    echo "⚠️  $DEFAULT_SETTINGS not found, skip version modification"
fi

# 预置 HomeProxy 数据
if ls -d ./package/*homeproxy* >/dev/null 2>&1; then
    (
        HP_DIR=$(ls -d ./package/*homeproxy* | head -1)
        HP_RULE="surge"
        HP_PATH="$HP_DIR/root/etc/homeproxy"
        rm -rf "./$HP_PATH/resources/*"
        git clone -q --depth=1 --single-branch --branch "release" "https://github.com/Loyalsoldier/surge-rules.git" "./$HP_RULE/"
        cd "./$HP_RULE/" || exit
        RES_VER=$(git log -1 --pretty=format:'%s' | grep -o "[0-9]*")
        echo "$RES_VER" | tee china_ip4.ver china_ip6.ver china_list.ver gfw_list.ver
        awk -F, '/^IP-CIDR,/{print $2 > "china_ip4.txt"} /^IP-CIDR6,/{print $2 > "china_ip6.txt"}' cncidr.txt
        sed 's/^\.//g' direct.txt > china_list.txt
        sed 's/^\.//g' gfw.txt > gfw_list.txt
        mv -f ./{china_*,gfw_list}.{ver,txt} "../$HP_PATH/resources/"
        cd ../..
        rm -rf "./$HP_RULE/"
    )
    echo "homeproxy date has been updated!"
fi

# 修改 argon 主题
if ls -d ./package/*luci-theme-argon* >/dev/null 2>&1; then
    ARGON_DIR=$(ls -d ./package/*luci-theme-argon* | head -1)
    (
        cd "$ARGON_DIR" || exit
        sed -i "s/primary '.*'/primary '#31a1a1'/; s/'0.2'/'0.5'/; s/'none'/'bing'/; s/'600'/'normal'/" ./luci-app-argon-config/root/etc/config/argon
    )
    echo "theme-argon has been fixed!"
fi

# 修改 aurora 菜单样式
if ls -d ./package/*luci-app-aurora-config* >/dev/null 2>&1; then
    AURORA_DIR=$(ls -d ./package/*luci-app-aurora-config* | head -1)
    (
        cd "$AURORA_DIR" || exit
        sed -i "s/nav_submenu_type '.*'/nav_submenu_type 'boxed-dropdown'/g" $(find ./root/usr/share/aurora/ -type f -name "*.template")
    )
    echo "theme-aurora has been fixed!"
fi

# 修改 mini-diskmanager 菜单位置
if ls -d ./package/*luci-app-mini-diskmanager* >/dev/null 2>&1; then
    DISKMAN_DIR=$(ls -d ./package/*luci-app-mini-diskmanager* | head -1)
    (
        cd "$DISKMAN_DIR" || exit
        sed -i "s/services/system/g" ./luci-app-mini-diskmanager/root/usr/share/luci/menu.d/luci-app-mini-diskmanager.json
    )
    echo "mini-diskmanager has been fixed!"
fi

# 修改 qca-nss-drv 启动顺序
NSS_DRV="./feeds/nss_packages/qca-nss-drv/files/qca-nss-drv.init"
if [ -f "$NSS_DRV" ]; then
    sed -i 's/START=.*/START=85/g' "$NSS_DRV"
    echo "qca-nss-drv has been fixed!"
fi

# 修改 qca-nss-pbuf 启动顺序
NSS_PBUF="./kernel/mac80211/files/qca-nss-pbuf.init"
if [ -f "$NSS_PBUF" ]; then
    sed -i 's/START=.*/START=86/g' "$NSS_PBUF"
    echo "qca-nss-pbuf has been fixed!"
fi

# 修复 TailScale 配置文件冲突
TS_FILE=$(find ../feeds/packages/ -maxdepth 3 -type f -wholename "*/tailscale/Makefile" 2>/dev/null)
if [ -f "$TS_FILE" ]; then
    sed -i '/\/files/d' "$TS_FILE"
    echo "tailscale has been fixed!"
fi

# 修复 Rust 编译失败
RUST_FILE=$(find ../feeds/packages/ -maxdepth 3 -type f -wholename "*/rust/Makefile" 2>/dev/null)
if [ -f "$RUST_FILE" ]; then
    sed -i 's/ci-llvm=true/ci-llvm=false/g' "$RUST_FILE"
    echo "rust has been fixed!"
fi

# ======================== 定时开关灯 ========================
mkdir -p ./files/etc/crontabs
cat > ./files/etc/crontabs/root << "EOF"
# 每天 23:00 关闭 LED
0 23 * * * uci set athena_led.config.enable='0' && uci commit athena_led && /etc/init.d/athena_led reload
# 每天 07:00 开启 LED
0 7 * * * uci set athena_led.config.enable='1' && uci commit athena_led && /etc/init.d/athena_led reload
EOF

# ======================== LED 按键控制（增强版） ========================
mkdir -p ./files/etc
cat > ./files/etc/led_toggle.sh << "EOF"
#!/bin/sh
LED_STATE_FILE="/tmp/led_state"

led_off() {
    for led in /sys/class/leds/*; do
        [ -e "$led/brightness" ] && echo 0 > "$led/brightness" 2>/dev/null
        [ -e "$led/trigger" ] && echo none > "$led/trigger" 2>/dev/null
    done
}

led_on() {
    for led in /sys/class/leds/*; do
        [ -e "$led/trigger" ] && echo default-on > "$led/trigger" 2>/dev/null
    done
}

if [ -f "$LED_STATE_FILE" ]; then
    STATE=$(cat "$LED_STATE_FILE")
else
    STATE="1"
fi

if [ "$STATE" = "1" ]; then
    led_off
    echo "0" > "$LED_STATE_FILE"
else
    led_on
    echo "1" > "$LED_STATE_FILE"
fi
EOF
chmod +x ./files/etc/led_toggle.sh

mkdir -p ./files/etc/hotplug.d/button
cat > ./files/etc/hotplug.d/button/01-mesh-led << "EOF"
#!/bin/sh
# 按键 LED 开关（防抖，适配所有常见键值）

case "$ACTION" in
    pressed)
        LAST=$(cat /tmp/button_last_time 2>/dev/null)
        NOW=$(cut -d '.' -f 1 /proc/uptime)
        if [ -n "$LAST" ] && [ $((NOW - LAST)) -lt 1 ]; then
            exit 0
        fi
        echo "$NOW" > /tmp/button_last_time

        case "$BUTTON" in
            BTN_*|mesh|wps|reset)
                /etc/led_toggle.sh &
                ;;
        esac
        ;;
esac
EOF
chmod +x ./files/etc/hotplug.d/button/01-mesh-led

# ========== 彻底移除导致 Kconfig 递归依赖的包 ==========
rm -rf ./package/feeds/kenzok8/mihomo-alpha ./package/feeds/kenzok8/mihomo-meta 2>/dev/null
rm -rf ./package/feeds/small/mihomo-alpha ./package/feeds/small/mihomo-meta 2>/dev/null
rm -rf ./package/feeds/openappfilter/kmod-oaf 2>/dev/null
rm -rf ./feeds/openappfilter/kmod-oaf 2>/dev/null
echo "Recursive dependency source packages removed"

# ========== Docker nftables 兼容修复（带日志捕获） ==========
DOCKER_FIX="$GITHUB_WORKSPACE/Scripts/docker_nftables_fix.sh"
if [ -x "$DOCKER_FIX" ]; then
    echo "Applying Docker nftables compat fixes..."
    "$DOCKER_FIX" "$OPENWRT_ROOT" > /tmp/docker_fix.log 2>&1 || {
        echo "⚠️ Docker nftables fix failed! Last 50 lines of log:"
        tail -n 50 /tmp/docker_fix.log
    }
else
    echo "⚠️ Docker nftables fix script not found or not executable, skipping."
fi

# ========== 京东云 eMMC p27 首次格式化 + 自动挂载 ==========
mkdir -p ./files/etc/init.d
cat > ./files/etc/init.d/format_p27 << 'EOF'
#!/bin/sh /etc/rc.common
START=95
STOP=10

PARTITION="/dev/mmcblk0p27"
MOUNT_POINT="/opt"
FS_TYPE="ext4"
STAMP="/etc/.p27_formatted"

start() {
    if [ ! -b "$PARTITION" ]; then
        logger -t "format_p27" "Partition $PARTITION not found, exit."
        return 1
    fi

    if mount | grep -q "$PARTITION"; then
        logger -t "format_p27" "$PARTITION already mounted, nothing to do."
        return 0
    fi

    if [ ! -f "$STAMP" ]; then
        logger -t "format_p27" "First boot detected, formatting $PARTITION to $FS_TYPE..."
        echo "y" | mkfs.ext4 "$PARTITION" || {
            logger -t "format_p27" "Format failed!"
            return 1
        }
        touch "$STAMP"
        logger -t "format_p27" "Format complete, stamp created."
    else
        logger -t "format_p27" "Already formatted, mounting..."
    fi

    mkdir -p "$MOUNT_POINT"
    mount -t "$FS_TYPE" "$PARTITION" "$MOUNT_POINT" || {
        logger -t "format_p27" "Mount failed!"
        return 1
    }
    logger -t "format_p27" "Mounted $PARTITION to $MOUNT_POINT"

    if ! grep -q "$PARTITION" /etc/fstab; then
        echo "$PARTITION $MOUNT_POINT $FS_TYPE defaults 0 0" >> /etc/fstab
    fi
}
EOF
chmod +x ./files/etc/init.d/format_p27

# 启用开机自启
ln -sf /etc/init.d/format_p27 ./files/etc/rc.d/S95format_p27 2>/dev/null || true


# 强制清除 Kconfig 缓存，让下次 defconfig 重新扫描包依赖
rm -f ./tmp/.config-package.in
echo "Kconfig cache cleared"
