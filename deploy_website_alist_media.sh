#!/bin/bash
# ============================================================
# website_alist_media 一键部署脚本 (v3.0 — 适配 19.0.3.0.1)
# 用法：把本脚本和 website_alist_media.zip（或 .tar.gz）放在同一个
#       目录（比如家目录），然后：
#         chmod +x deploy_website_alist_media.sh
#         sudo ./deploy_website_alist_media.sh
#       脚本会自动找包、自动解压（不管包内部目录结构差几层）、
#       自动判断装/升级、自动重启、自动做安全检查。
#       运行中会提示你输入一次数据库密码（不回显、不落盘、不进历史记录）。
#
# 19.0.3.0.1 要点：
#   - 正文 AList 视频插入 <video controls playsinline>
#   - 区块背景视频：MediaDialog AList + 直链 <video autoplay muted loop>
#   - onlyImages 补丁保留；升级后务必 Ctrl+Shift+R 强刷资产
# ============================================================
set -euo pipefail

# ---------- 按你的实际环境改这几行（一般不用改） ----------
ADDONS_DIR="/opt/prod-apps/odoo/addons"
CONFIG_FILE="/opt/prod-apps/odoo/config/odoo.conf"
CONTAINER="prod-odoo"
DB_CONTAINER="odoo-db"
DB_HOST="odoo-db"
DB_PORT="5432"
DB_USER="odoo"
DB_NAME="letaoge"
MODULE="website_alist_media"
EXPECTED_VERSION="19.0.3.0.1"
SEARCH_DIRS=("$HOME" "$(pwd)" "$(cd "$(dirname "$0")" && pwd)")
# ----------------------------------------------------------

log()  { echo -e "==> $*"; }
ok()   { echo -e "[OK] $*"; }
warn() { echo -e "[WARN] $*"; }
err()  { echo -e "[ERROR] $*" >&2; }

if [ "$(id -u)" -ne 0 ]; then
  err "请用 sudo 或 root 运行本脚本：sudo $0"
  exit 1
fi

# ---------- 1. 自动找包（zip 或 tar.gz，按修改时间取最新一个）----------
log "查找 ${MODULE} 安装包"
PKG=""
for d in "${SEARCH_DIRS[@]}"; do
  [ -d "$d" ] || continue
  found=$(find "$d" -maxdepth 1 -type f \( -iname "${MODULE}*.zip" -o -iname "${MODULE}*.tar.gz" -o -iname "${MODULE}*.tgz" \) 2>/dev/null | xargs -r ls -t 2>/dev/null | head -n1 || true)
  if [ -n "$found" ]; then
    PKG="$found"
    break
  fi
done

if [ -z "$PKG" ]; then
  err "在 ${SEARCH_DIRS[*]} 里没找到 ${MODULE}*.zip 或 ${MODULE}*.tar.gz"
  err "先把安装包传到家目录（或与本脚本同目录），再重新运行本脚本"
  exit 1
fi
ok "找到安装包：$PKG"

# ---------- 2. 解压到临时目录，自动定位 __manifest__.py 所在层级 ----------
log "解压安装包"
TMP_EXTRACT=$(mktemp -d)
case "$PKG" in
  *.zip)
    command -v unzip >/dev/null || { err "缺少 unzip，先执行: apt-get install -y unzip"; exit 1; }
    unzip -q -o "$PKG" -d "$TMP_EXTRACT"
    ;;
  *.tar.gz|*.tgz)
    tar -xzf "$PKG" -C "$TMP_EXTRACT"
    ;;
  *)
    err "不认识的包格式：$PKG"
    exit 1
    ;;
esac

MANIFEST_PATH=$(find "$TMP_EXTRACT" -maxdepth 4 -type f -name "__manifest__.py" | head -n1 || true)

if [ -z "$MANIFEST_PATH" ]; then
  err "解压后在任何层级都没找到 __manifest__.py，包内容不对（可能传错文件了），中止"
  err "解压出来的顶层内容："
  find "$TMP_EXTRACT" -maxdepth 2 | sed 's/^/  /'
  rm -rf "$TMP_EXTRACT"
  exit 1
fi

MODULE_SRC_DIR=$(dirname "$MANIFEST_PATH")
ok "定位到模块目录：$MODULE_SRC_DIR（相对包内路径：${MODULE_SRC_DIR#$TMP_EXTRACT/}）"

PKG_VERSION=$(python3 -c "import re,pathlib; t=pathlib.Path(r'''$MANIFEST_PATH''').read_text(); m=re.search(r\"'version'\\s*:\\s*'([^']+)'\", t); print(m.group(1) if m else '')" 2>/dev/null || true)
if [ -n "$PKG_VERSION" ]; then
  ok "包内版本：$PKG_VERSION"
  if [ "$PKG_VERSION" != "$EXPECTED_VERSION" ]; then
    warn "期望版本为 $EXPECTED_VERSION，当前包是 $PKG_VERSION（仍继续部署）"
  fi
fi

# 关键文件检查（19.0.3.0.0 BG video + onlyImages）
if [ ! -f "$MODULE_SRC_DIR/static/src/media_dialog/media_dialog_only_images_patch.js" ]; then
  err "包内缺少 media_dialog_only_images_patch.js，不像 19.0.2.1.0+，中止"
  rm -rf "$TMP_EXTRACT"
  exit 1
fi
if [ ! -f "$MODULE_SRC_DIR/static/src/builder/background_video_dialog_patch.js" ]; then
  err "包内缺少 background_video_dialog_patch.js，不像 19.0.3.0.0+，中止"
  rm -rf "$TMP_EXTRACT"
  exit 1
fi
if [ ! -f "$MODULE_SRC_DIR/static/src/interactions/background_video_direct_patch.js" ]; then
  err "包内缺少 background_video_direct_patch.js，不像 19.0.3.0.0+，中止"
  rm -rf "$TMP_EXTRACT"
  exit 1
fi
ok "已检测到 onlyImages + 背景视频补丁文件"

log "部署到 addons 目录：$ADDONS_DIR/$MODULE"
mkdir -p "$ADDONS_DIR"
rm -rf "${ADDONS_DIR:?}/${MODULE}"
mv "$MODULE_SRC_DIR" "$ADDONS_DIR/${MODULE}"
rm -rf "$TMP_EXTRACT"
ok "部署完成：$ADDONS_DIR/${MODULE}"

# ---------- 3. 输入数据库密码（交互式，不回显，不落盘）----------
echo
read -rsp "请输入 Odoo 数据库密码（$DB_USER@$DB_NAME，不会显示、不会保存）: " DB_PASSWORD
echo
if [ -z "$DB_PASSWORD" ]; then
  err "密码不能为空"
  exit 1
fi

# ---------- 4. 判断已安装 / 未安装，决定 -i 还是 -u ----------
log "检测 ${MODULE} 当前安装状态"
STATE=$(docker exec "$DB_CONTAINER" psql -U "$DB_USER" -d "$DB_NAME" -t -c \
  "SELECT state FROM ir_module_module WHERE name='${MODULE}';" 2>/dev/null | xargs || true)

if [ "$STATE" = "installed" ]; then
  ACTION="-u"
  ok "检测到已安装（升级模式 -u）"
else
  ACTION="-i"
  ok "未安装或首次部署（安装模式 -i）"
fi

# ---------- 5. 执行安装/升级 ----------
log "在库 $DB_NAME 上执行 odoo $ACTION $MODULE"
if ! docker exec "$CONTAINER" odoo "$ACTION" "$MODULE" -d "$DB_NAME" \
  --db_host="$DB_HOST" --db_port="$DB_PORT" --db_user="$DB_USER" \
  --db_password="$DB_PASSWORD" \
  --no-http --stop-after-init; then
  err "安装/升级失败，看上面的日志定位具体报错，不要继续重启容器"
  unset DB_PASSWORD
  exit 1
fi
unset DB_PASSWORD
ok "安装/升级命令执行完毕，无异常退出"

# 核对库内版本
DB_VER=$(docker exec "$DB_CONTAINER" psql -U "$DB_USER" -d "$DB_NAME" -t -c \
  "SELECT latest_version FROM ir_module_module WHERE name='${MODULE}';" 2>/dev/null | xargs || true)
if [ -n "$DB_VER" ]; then
  ok "数据库模块版本：$DB_VER"
  if [ -n "$PKG_VERSION" ] && [ "$DB_VER" != "$PKG_VERSION" ]; then
    warn "库内版本 ($DB_VER) 与包内版本 ($PKG_VERSION) 不一致，请检查升级日志"
  fi
fi

# ---------- 6. 重启容器 ----------
log "重启容器 $CONTAINER"
docker restart "$CONTAINER" >/dev/null
ok "已重启"

# ---------- 7. 安全检查：dbfilter / list_db ----------
log "检查 dbfilter / list_db 配置（防止数据库选择页暴露在公网）"
if [ -f "$CONFIG_FILE" ]; then
  if grep -qE "^\s*dbfilter\s*=" "$CONFIG_FILE" && grep -qE "^\s*list_db\s*=\s*[Ff]alse" "$CONFIG_FILE"; then
    ok "dbfilter / list_db 配置正常"
  else
    warn "没检测到安全的 dbfilter / list_db 配置！"
    warn "建议在 $CONFIG_FILE 里确认包含："
    warn "  dbfilter = ^${DB_NAME}\$"
    warn "  list_db = False"
    warn "改完记得: docker restart $CONTAINER"
  fi
else
  warn "没找到配置文件 $CONFIG_FILE，跳过这项检查，请自行确认"
fi

echo
ok "全部完成"
echo "接下来手动确认："
echo "  1. 后台「应用」去掉筛选后搜 ${MODULE}，确认版本约为 ${EXPECTED_VERSION}（或包内版本）"
echo "  2. 浏览器对后台/网站编辑器做 Ctrl+Shift+R 强刷（很重要，否则会仍像旧版）"
echo "  3. 网站 → 配置 → AList Media → Media Sources，Test Connection"
echo "  4. 网站编辑器：图库「添加图片」弹窗应出现 AList；选图后 src 为 CDN"
echo "  5. 正文插入媒体 → AList 选视频 → <video controls playsinline src=CDN>"
echo "  6. 区块背景视频 → MediaDialog 有 Videos+AList；直链前台为 <video autoplay muted loop>"
echo "  7. 再抽测：正文插图、YT/Vimeo 背景视频仍可用"
