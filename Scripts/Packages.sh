#!/bin/bash
# SPDX-License-Identifier: MIT
# Copyright (C) 2026 VIKINGYFY

# ========== 添加 iStore 及 Docker 相关 feeds 源（不切换目录） ==========
echo "正在添加 iStore 源..."

if ! grep -q "istore" ../feeds.conf.default; then
    echo 'src-git istore https://github.com/linkease/istore.git;main' >> ../feeds.conf.default
    echo 'src-git nas https://github.com/linkease/nas-packages.git;master' >> ../feeds.conf.default
    echo 'src-git nas_luci https://github.com/linkease/nas-packages-luci.git;main' >> ../feeds.conf.default
    echo "iStore 源已添加"
else
    echo "iStore 源已存在，跳过添加"
fi

../scripts/feeds update istore nas nas_luci
../scripts/feeds install -a -p istore
../scripts/feeds install -a -p nas
../scripts/feeds install -a -p nas_luci

echo "iStore feeds 安装完成"

# ========== 原有函数（确保括号成对） ==========
UPDATE_PACKAGE() {
    local PKG_NAME=$1
    local PKG_REPO=$2
    local PKG_BRANCH=$3
    local PKG_SPECIAL=$4
    local PKG_LIST=("$PKG_NAME" $5)
    local REPO_NAME=${PKG_REPO#*/}

    echo " "

    for NAME in "${PKG_LIST[@]}"; do
        echo "Search directory: $NAME"
        local FOUND_DIRS=$(find ../feeds/luci/ ../feeds/packages/ -maxdepth 3 -type d -iname "*$NAME*" 2>/dev/null)
        if [ -n "$FOUND_DIRS" ]; then
            while read -r DIR; do
                rm -rf "$DIR"
                echo "Delete directory: $DIR"
            done <<< "$FOUND_DIRS"
        else
            echo "Not fonud directory: $NAME"
        fi
    done

    git clone --depth=1 --single-branch --branch $PKG_BRANCH "https://github.com/$PKG_REPO.git"

    if [[ "$PKG_SPECIAL" == "pkg" ]]; then
        find ./$REPO_NAME/*/ -maxdepth 3 -type d -iname "*$PKG_NAME*" -prune -exec cp -rf {} ./ \;
        rm -rf ./$REPO_NAME/
    elif [[ "$PKG_SPECIAL" == "name" ]]; then
        mv -f $REPO_NAME $PKG_NAME
    fi
}

# 以下所有 UPDATE_PACKAGE 调用...
UPDATE_PACKAGE "argon" "sbwml/luci-theme-argon" "openwrt-25.12"
UPDATE_PACKAGE "shadcn" "eamonxg/luci-theme-shadcn" "main"
# ...（其余调用不变） ...

UPDATE_VERSION() {
    # ...（您的原有代码） ...
}
UPDATE_VERSION "sing-box"

if [ -f "$GITHUB_WORKSPACE/Scripts/PRIVATE.sh" ]; then
    source "$GITHUB_WORKSPACE/Scripts/PRIVATE.sh"
fi
