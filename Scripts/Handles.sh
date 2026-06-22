#!/bin/bash
# SPDX-License-Identifier: MIT
# Copyright (C) 2026 kinsum

OPENWRT_ROOT="$GITHUB_WORKSPACE/wrt"
PKG_PATH="$OPENWRT_ROOT/package/"

cd "$OPENWRT_ROOT" || exit 1

# ========== 新增：代理软件 feeds ==========
# 添加 OAF 源到 feeds.conf.default
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

# ========== 新增 kiddin9 源 ==========
if ! grep -q "src-git kiddin9" feeds.conf.default; then
    echo "src-git kiddin9 https://github.com/kiddin9/openwrt-packages.git" >> feeds.conf.default
    echo "kiddin9 feed added"
fi
echo "proxy feeds added"
# ==========================================


# 自定义版本显示
sed -i "s/OpenWrt /Chris Build $(TZ=UTC-8 date "+%Y.%m.%d") @ OpenWrt /g" package/lean/default-settings/files/zzz-default-settings


# 预置 HomeProxy 数据（需要用子 shell 隔离）
if ls -d *homeproxy* >/dev/null 2>&1; then
    (
        HP_RULE="surge"
        HP_PATH="homeproxy/root/etc/homeproxy"
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
if [ -d *"luci-theme-argon"* ]; then
    (
        cd ./luci-theme-argon/ || exit
        sed -i "s/primary '.*'/primary '#31a1a1'/; s/'0.2'/'0.5'/; s/'none'/'bing'/; s/'600'/'normal'/" ./luci-app-argon-config/root/etc/config/argon
    )
    echo "theme-argon has been fixed!"
fi

# 修改 aurora 菜单样式（类似处理，注意路径）
if [ -d *"luci-app-aurora-config"* ]; then
    (
        cd ./luci-app-aurora-config/ || exit
        sed -i "s/nav_submenu_type '.*'/nav_submenu_type 'boxed-dropdown'/g" $(find ./root/usr/share/aurora/ -type f -name "*.template")
    )
    echo "theme-aurora has been fixed!"
fi

# 修改 mini-diskmanager 菜单位置
if [ -d *"luci-app-mini-diskmanager"* ]; then
    (
        cd ./luci-app-mini-diskmanager/ || exit
        sed -i "s/services/system/g" ./luci-app-mini-diskmanager/root/usr/share/luci/menu.d/luci-app-mini-diskmanager.json
    )
    echo "mini-diskmanager has been fixed!"
fi

# 修改 qca-nss-drv 启动顺序（注意路径是相对 feeds 的）
NSS_DRV="../feeds/nss_packages/qca-nss-drv/files/qca-nss-drv.init"
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


# 创建 crontab 文件，设置定时开关灯
mkdir -p ./files/etc/crontabs
cat > ./files/etc/crontabs/root << "EOF"
# 每天 23:00 关闭 LED
0 23 * * * uci set athena_led.config.enable='0' && uci commit athena_led && /etc/init.d/athena_led reload
# 每天 07:00 开启 LED
0 7 * * * uci set athena_led.config.enable='1' && uci commit athena_led && /etc/init.d/athena_led reload
EOF

# ======================== LED 按键控制 ========================
# 创建 LED 切换脚本
mkdir -p ./files/etc
cat > ./files/etc/led_toggle.sh << "EOF"
#!/bin/sh

LED_STATE_FILE="/tmp/led_state"   # 记录当前 LED 状态（0=关，1=开）

# 关闭所有 LED
led_off() {
    for led in /sys/class/leds/*; do
        [ -e "$led/brightness" ] && echo 0 > "$led/brightness"
        [ -e "$led/trigger" ] && echo none > "$led/trigger"
    done
}

# 开启所有 LED（恢复默认 trigger）
led_on() {
    for led in /sys/class/leds/*; do
        [ -e "$led/trigger" ] && echo default-on > "$led/trigger"
    done
}

# 读取当前状态，取反
if [ -f "$LED_STATE_FILE" ]; then
    STATE=$(cat "$LED_STATE_FILE")
else
    STATE="1"   # 默认开机为开启
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

# 创建按键监听脚本（hotplug）
mkdir -p ./files/etc/hotplug.d/button
cat > ./files/etc/hotplug.d/button/01-mesh-led << "EOF"
#!/bin/sh
# 监听 mesh 按键（亚瑟/雅典娜的物理按键）
# 当按键被按下时，执行 LED 切换

case "$ACTION" in
    pressed)
        # 检查是否是该设备对应的按键事件
        case "$BUTTON" in
            BTN_MESH|mesh|wps)   # 不同固件可能名称不同，包含常见名称
                /etc/led_toggle.sh &
                ;;
        esac
        ;;
esac
EOF

chmod +x ./files/etc/hotplug.d/button/01-mesh-led
