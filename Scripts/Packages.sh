#!/bin/bash

# [核心加固] 配置 Git 安全目录，防止 GitHub Actions 报错
git config --global --add safe.directory "$GITHUB_WORKSPACE"

UPDATE_PACKAGE() {
	local PKG_NAME=$1
	local PKG_REPO=$2
	local PKG_BRANCH=$3
	local PKG_SPECIAL=$4
	local PKG_LIST=("$PKG_NAME" $5)
	local REPO_NAME=${PKG_REPO#*/}

	# 1. 清理旧的插件目录，防止重复冲突
	for NAME in "${PKG_LIST[@]}"; do
		[ -z "$NAME" ] && continue
		# 查找 feeds 目录下所有同名插件并强制删除
		find ../feeds/luci/ ../feeds/packages/ -maxdepth 3 -type d -iname "*$NAME*" 2>/dev/null | xargs -r rm -rf
	done

	# 2. 克隆新仓库 (增加清理逻辑)
	rm -rf "./$REPO_NAME"
	git clone --depth=1 --single-branch --branch "$PKG_BRANCH" "https://github.com/$PKG_REPO.git"
	if [ $? -ne 0 ]; then 
		echo "Failed to clone $PKG_REPO"
		return 1 
	fi

	# 3. 处理特殊的包结构
	if [[ "$PKG_SPECIAL" == "pkg" ]]; then
		# 提取子文件夹中的特定插件
		find "./$REPO_NAME/" -maxdepth 3 -type d -iname "*$PKG_NAME*" -not -path "./$REPO_NAME/" -prune -exec cp -rf {} ./ \;
		rm -rf "./$REPO_NAME/"
	elif [[ "$PKG_SPECIAL" == "name" ]]; then
		# 重命名插件目录
		mv -f "$REPO_NAME" "$PKG_NAME"
	fi
}

# --- 插件更新列表 ---
UPDATE_PACKAGE "argon" "jerrykuku/luci-theme-argon" "master"
UPDATE_PACKAGE "OpenClash" "vernesong/OpenClash" "master" "pkg"
UPDATE_PACKAGE "diskman" "lisaac/luci-app-diskman" "master"

# 自动版本更新逻辑
UPDATE_VERSION() {
	local PKG_NAME=$1
	local PKG_MARK=${2:-false}
	local PKG_FILES=$(find ./ ../feeds/packages/ -maxdepth 3 -type f -wholename "*/$PKG_NAME/Makefile")
	[ -z "$PKG_FILES" ] && return
	for PKG_FILE in $PKG_FILES; do
		local PKG_REPO=$(grep -Po "PKG_SOURCE_URL:=https://.*github.com/\K[^/]+/[^/]+(?=.*)" "$PKG_FILE")
		# [重要修正] 添加 Token 鉴权，解决 GitHub API 速率限制问题
		local RELEASE_DATA=$(curl -sL -H "Authorization: token $GITHUB_TOKEN" "https://api.github.com/repos/$PKG_REPO/releases")
		local PKG_TAG=$(echo "$RELEASE_DATA" | jq -r "map(select(.prerelease == $PKG_MARK)) | first | .tag_name")
		[ "$PKG_TAG" == "null" ] && PKG_TAG=$(echo "$RELEASE_DATA" | jq -r "first | .tag_name")
		if [ -n "$PKG_TAG" ] && [ "$PKG_TAG" != "null" ]; then
			sed -i "s/PKG_VERSION:=.*/PKG_VERSION:=${PKG_TAG#v}/g" "$PKG_FILE"
			echo "$PKG_NAME version updated to $PKG_TAG"
		fi
	done
}

# 需要自动更新版本的插件
UPDATE_VERSION "sing-box"