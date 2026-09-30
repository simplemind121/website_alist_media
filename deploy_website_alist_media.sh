#!/bin/bash
# ============================================================
# website_alist_media 一键部署脚本 (v5.2 — 适配 19.0.4.3.0 显示区域工具；兼容 ≥19.0.4.1.1)
#
# 用法（本脚本和 website_alist_media.zip / .tar.gz 放在同一目录）：
#   sudo bash deploy_website_alist_media.sh                   # 部署到生产 (prod-odoo)
#   sudo bash deploy_website_alist_media.sh --target staging  # 部署到 staging-odoo
#   sudo bash deploy_website_alist_media.sh --rollback        # 回滚到最近一次部署前的备份
#
# 其他参数：
#   --container NAME   指定 Odoo 容器（覆盖 --target）
#   --db NAME          指定数据库（默认从 odoo.conf 的 dbfilter ^name$ 读取）
#   --package FILE     指定安装包（默认：脚本目录 → 当前目录 → 你的家目录，取最新）
#   --force            允许重装同版本以下的包（降级；默认拒绝）
#   --skip-tests       跳过离线单元测试（不推荐）
#   --no-backup        跳过部署前备份（不推荐）
#   -h | --help        显示帮助
#
# 流程：校验安装包(版本/关键文件/离线测试) → 输入一次数据库密码 → 兼容性检查
#      → 备份数据库与旧模块 → 自动 -i / -u → 核对版本 → 重启 → 健康检查 → 日志扫描
# 失败时：安装/升级报错会自动恢复旧模块文件；数据库可用 --rollback 回退。
# ============================================================
set -euo pipefail

MODULE="website_alist_media"
MIN_VERSION="19.0.4.1.1"   # 本脚本适配的最低包版本（19.0.4.1.1 = 无限滚动 + 默认 page_size 60）
TARGET="prod"
CONTAINER=""
DB_NAME=""
PKG=""
DO_BACKUP=1
DO_TESTS=1
FORCE=0
MODE="deploy"
BACKUP_ROOT="${WAM_BACKUP_ROOT:-/opt/prod-apps/backups/${MODULE}}"
BACKUP_KEEP=5
HEALTH_TIMEOUT=120
DB_USER="odoo"
DB_PORT="5432"

# 合并版必须存在的文件（缺任何一个 = 包不对，直接中止）
REQUIRED_FILES=(
  "__manifest__.py"
  "static/src/media_dialog/alist_selector.js"
  "static/src/media_dialog/alist_media_dialog_patch.js"
  "static/src/media_dialog/alist_tab_rules.js"
  "static/src/utils/bg_video_utils.js"
  "static/src/builder/background_video_dialog_patch.js"
  "static/src/interactions/background_video_direct_patch.js"
  "static/src/xml/background_video_direct.xml"
  "models/media_link.py"
  "data/ir_cron_data.xml"
)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SEARCH_DIRS=("$SCRIPT_DIR" "$(pwd)")
if [ -n "${SUDO_USER:-}" ]; then
  SUDO_HOME=$(getent passwd "$SUDO_USER" | cut -d: -f6 || true)
  [ -n "$SUDO_HOME" ] && SEARCH_DIRS+=("$SUDO_HOME")
fi
SEARCH_DIRS+=("$HOME")
# 去重（保持顺序）
_dedup=(); for d in "${SEARCH_DIRS[@]}"; do [[ " ${_dedup[*]} " == *" $d "* ]] || _dedup+=("$d"); done
SEARCH_DIRS=("${_dedup[@]}"); unset _dedup

log()  { echo -e "==> $*"; }
ok()   { echo -e "[OK] $*"; }
warn() { echo -e "[WARN] $*"; }
err()  { echo -e "[ERROR] $*" >&2; }
usage() { sed -n '2,24p' "$0" | sed 's/^# \{0,1\}//'; }

# 版本比较：ver_lt A B → A < B
ver_lt() { [ "$1" != "$2" ] && [ "$(printf '%s\n%s\n' "$1" "$2" | sort -V | head -n1)" = "$1" ]; }

while [ $# -gt 0 ]; do
  case "$1" in
    --target) TARGET="${2:-}"; shift 2 ;;
    --container) CONTAINER="${2:-}"; shift 2 ;;
    --db) DB_NAME="${2:-}"; shift 2 ;;
    --package) PKG="${2:-}"; shift 2 ;;
    --force) FORCE=1; shift ;;
    --skip-tests) DO_TESTS=0; shift ;;
    --no-backup) DO_BACKUP=0; shift ;;
    --rollback) MODE="rollback"; shift ;;
    -h|--help) usage; exit 0 ;;
    *) err "未知参数：$1"; usage; exit 1 ;;
  esac
done

if [ "$(id -u)" -ne 0 ]; then
  err "请用 sudo 或 root 运行本脚本：sudo bash $0"
  exit 1
fi

TARGET_FLAG=""
[ "$TARGET" != "prod" ] && TARGET_FLAG=" --target $TARGET"
[ -n "$CONTAINER" ] && TARGET_FLAG="$TARGET_FLAG --container $CONTAINER"

TMP_EXTRACT=""
DB_PASSWORD=""
cleanup() { unset DB_PASSWORD; [ -n "$TMP_EXTRACT" ] && rm -rf "$TMP_EXTRACT"; rm -f /tmp/wam_deploy_err /tmp/wam_restore_err; return 0; }
trap cleanup EXIT

# ============================================================ 0. 安装包预检（不需要密码，失败不改任何东西）
if [ "$MODE" = "deploy" ]; then
  log "查找 ${MODULE} 安装包"
  if [ -n "$PKG" ]; then
    [ -f "$PKG" ] || { err "指定的安装包不存在：$PKG"; exit 1; }
  else
    for d in "${SEARCH_DIRS[@]}"; do
      [ -d "$d" ] || continue
      found=$(find "$d" -maxdepth 1 -type f \
                \( -iname "${MODULE}*.zip" -o -iname "${MODULE}*.tar.gz" -o -iname "${MODULE}*.tgz" \) \
                ! -iname "*deploy_bundle*" -printf '%T@ %p\n' 2>/dev/null \
              | sort -nr | head -n1 | cut -d' ' -f2- || true)
      if [ -n "$found" ]; then PKG="$found"; break; fi
    done
  fi
  if [ -z "$PKG" ]; then
    err "在 ${SEARCH_DIRS[*]} 里没找到 ${MODULE}*.zip 或 ${MODULE}*.tar.gz（可用 --package 指定）"
    exit 1
  fi
  ok "安装包：$PKG（$(date -r "$PKG" '+%F %T')）"

  TMP_EXTRACT=$(mktemp -d)
  case "$PKG" in
    *.zip) command -v unzip >/dev/null || { err "缺少 unzip：apt-get install -y unzip"; exit 1; }
           unzip -q -o "$PKG" -d "$TMP_EXTRACT" ;;
    *.tar.gz|*.tgz) tar -xzf "$PKG" -C "$TMP_EXTRACT" ;;
    *) err "不认识的包格式：$PKG"; exit 1 ;;
  esac
  MANIFEST_PATH=$(find "$TMP_EXTRACT" -maxdepth 4 -type f -name "__manifest__.py" | head -n1 || true)
  if [ -z "$MANIFEST_PATH" ]; then
    err "解压后没找到 __manifest__.py（可能传错文件），解压内容："
    find "$TMP_EXTRACT" -maxdepth 2 | sed 's/^/  /'
    exit 1
  fi
  MODULE_SRC_DIR=$(dirname "$MANIFEST_PATH")
  PKG_VERSION=$(grep -oE "'version'[[:space:]]*:[[:space:]]*'[^']+'" "$MANIFEST_PATH" | grep -oE "[0-9]+(\.[0-9]+)+" | head -n1 || true)
  if [ -z "$PKG_VERSION" ]; then
    err "读不到 __manifest__.py 里的版本号，中止"
    exit 1
  fi
  ok "安装包版本：$PKG_VERSION"
  if ver_lt "$PKG_VERSION" "$MIN_VERSION"; then
    err "本脚本适配 ${MIN_VERSION} 及以上；该包是 ${PKG_VERSION}，缺少合并版功能，中止"
    exit 1
  fi

  MISSING=0
  for f in "${REQUIRED_FILES[@]}"; do
    if [ ! -f "$MODULE_SRC_DIR/$f" ]; then err "  包内缺少：$f"; MISSING=1; fi
  done
  [ "$MISSING" = "0" ] || { err "安装包不完整，中止"; exit 1; }
  ok "关键文件齐全（${#REQUIRED_FILES[@]} 项）"

  if [ "$DO_TESTS" = "1" ]; then
    log "离线单元测试（不连数据库、不联网）"
    if command -v python3 >/dev/null && [ -d "$MODULE_SRC_DIR/tests" ]; then
      PY_TESTS=()
      for t in test_small test_cdn_utils test_bg_video_utils test_merge_4_1; do
        [ -f "$MODULE_SRC_DIR/tests/$t.py" ] && PY_TESTS+=("tests.$t")
      done
      if [ ${#PY_TESTS[@]} -gt 0 ]; then
        if ! (cd "$MODULE_SRC_DIR" && PYTHONDONTWRITEBYTECODE=1 python3 -m unittest -q "${PY_TESTS[@]}" >/tmp/wam_deploy_err 2>&1); then
          err "Python 单元测试失败，中止（尚未改动任何东西）："
          tail -n 30 /tmp/wam_deploy_err >&2
          exit 1
        fi
        ok "  Python：$(grep -oE 'Ran [0-9]+ tests' /tmp/wam_deploy_err || echo '通过')"
      fi
    else
      warn "  宿主机没有 python3，跳过 Python 测试"
    fi
    NODE_MAJOR=$(node -v 2>/dev/null | sed -E 's/^v([0-9]+).*/\1/' || true)
    if [ -n "$NODE_MAJOR" ] && [ "$NODE_MAJOR" -ge 18 ] 2>/dev/null && [ -f "$MODULE_SRC_DIR/tests/js/run.sh" ]; then
      if ! bash "$MODULE_SRC_DIR/tests/js/run.sh" >/tmp/wam_deploy_err 2>&1; then
        err "JS 单元测试失败，中止（尚未改动任何东西）："
        tail -n 30 /tmp/wam_deploy_err >&2
        exit 1
      fi
      ok "  JS：通过"
    else
      warn "  宿主机没有 Node ≥ 18，跳过 JS 测试（不影响部署）"
    fi
  else
    warn "已跳过离线单元测试（--skip-tests）"
  fi
  # 测试不应留下任何文件在包里
  find "$MODULE_SRC_DIR" -name '__pycache__' -type d -prune -exec rm -rf {} + 2>/dev/null || true
fi

# ---------- 目标容器 ----------
if [ -z "$CONTAINER" ]; then
  case "$TARGET" in
    prod) CONTAINER="prod-odoo" ;;
    staging) CONTAINER="staging-odoo" ;;
    *) err "--target 只能是 prod 或 staging"; exit 1 ;;
  esac
fi
if ! docker inspect "$CONTAINER" >/dev/null 2>&1; then
  err "找不到容器 $CONTAINER（用 docker ps 查看实际名字，再用 --container 指定）"
  exit 1
fi
DB_CONTAINER="${CONTAINER}-db"
docker inspect "$DB_CONTAINER" >/dev/null 2>&1 || DB_CONTAINER=""

# ---------- 从容器挂载自动识别 addons 目录与配置文件 ----------
mount_source() {  # $1 = container path
  docker inspect "$CONTAINER" --format '{{range .Mounts}}{{.Destination}}|{{.Source}}{{"\n"}}{{end}}' \
    | awk -F'|' -v d="$1" '$1==d {print $2}' | head -n1
}
ADDONS_DIR=$(mount_source /mnt/extra-addons)
CONFIG_DIR=$(mount_source /etc/odoo)
if [ -z "$ADDONS_DIR" ] || [ ! -d "$ADDONS_DIR" ]; then
  err "无法从 $CONTAINER 的挂载中找到 /mnt/extra-addons 对应的宿主机目录"
  exit 1
fi
CONFIG_FILE=""
if [ -n "$CONFIG_DIR" ] && [ -f "$CONFIG_DIR/odoo.conf" ]; then
  CONFIG_FILE="$CONFIG_DIR/odoo.conf"
fi

conf_get() {  # $1 = key; prints value or nothing
  [ -n "$CONFIG_FILE" ] || return 0
  grep -E "^[[:space:]]*$1[[:space:]]*=" "$CONFIG_FILE" | tail -n1 \
    | sed -E "s/^[[:space:]]*$1[[:space:]]*=[[:space:]]*//" | tr -d '\r' | xargs || true
}
container_env() { docker exec "$CONTAINER" printenv "$1" 2>/dev/null || true; }

DB_HOST=$(conf_get db_host); [ -n "$DB_HOST" ] || DB_HOST=$(container_env HOST); DB_HOST=${DB_HOST:-odoo-db}
V=$(conf_get db_port); DB_PORT=${V:-$DB_PORT}
V=$(conf_get db_user); [ -n "$V" ] || V=$(container_env USER); DB_USER=${V:-$DB_USER}
V=$(conf_get http_port); HTTP_PORT=${V:-8069}
if [ -z "$DB_NAME" ]; then
  DBF=$(conf_get dbfilter)
  if [[ "$DBF" =~ ^\^([A-Za-z0-9_.-]+)\$$ ]]; then
    DB_NAME="${BASH_REMATCH[1]}"
  else
    err "无法从 dbfilter（${DBF:-未设置}）推断数据库名，请用 --db 指定"
    exit 1
  fi
fi
BACKUP_DIR_BASE="$BACKUP_ROOT/${CONTAINER}_${DB_NAME}"

echo
log "目标：容器=$CONTAINER  数据库=$DB_NAME  addons=$ADDONS_DIR"
log "      配置=${CONFIG_FILE:-未找到}  DB=$DB_USER@$DB_HOST:$DB_PORT  DB容器=${DB_CONTAINER:-无}"
echo

read -rsp "请输入 Odoo 数据库密码（$DB_USER@$DB_NAME，不会显示、不会保存）: " DB_PASSWORD
echo
if [ -z "$DB_PASSWORD" ]; then
  err "密码不能为空"
  exit 1
fi

db_query() {
  docker exec -e PGPASSWORD="$DB_PASSWORD" "$CONTAINER" \
    psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -tAc "$1"
}
# pg_dump / pg_restore: prefer the DB container (client version == server version)
pg_tool() {  # $1 = pg_dump|pg_restore, rest = args
  local tool="$1"; shift
  if [ -n "$DB_CONTAINER" ]; then
    docker exec -i -e PGPASSWORD="$DB_PASSWORD" "$DB_CONTAINER" "$tool" -h 127.0.0.1 -p 5432 -U "$DB_USER" "$@"
  else
    docker exec -i -e PGPASSWORD="$DB_PASSWORD" "$CONTAINER" "$tool" -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" "$@"
  fi
}

log "测试数据库连接"
if ! db_query "SELECT 1" >/dev/null 2>/tmp/wam_deploy_err; then
  err "无法连接数据库（密码错误或连接失败），中止："
  cat /tmp/wam_deploy_err >&2
  exit 1
fi
ok "数据库连接正常"

# ============================================================ ROLLBACK
if [ "$MODE" = "rollback" ]; then
  LATEST=$(ls -1d "$BACKUP_DIR_BASE"/*/ 2>/dev/null | sort | tail -n1 || true)
  LATEST=${LATEST%/}
  if [ -z "$LATEST" ] || [ ! -s "$LATEST/db.dump" ]; then
    err "没有找到可用备份：$BACKUP_DIR_BASE"
    exit 1
  fi
  echo
  warn "即将回滚到备份：$LATEST"
  [ -f "$LATEST/meta.txt" ] && sed 's/^/        /' "$LATEST/meta.txt"
  warn "数据库 $DB_NAME 会被备份覆盖：备份之后产生的所有数据（订单、内容修改等）都会丢失！"
  read -rp "确认请输入数据库名 $DB_NAME ：" CONFIRM
  if [ "$CONFIRM" != "$DB_NAME" ]; then
    err "输入不一致，已取消，未做任何改动"
    exit 1
  fi
  log "停止 $CONTAINER（避免回滚期间写入）"
  docker stop "$CONTAINER" >/dev/null
  trap 'docker start "$CONTAINER" >/dev/null 2>&1 || true; cleanup' EXIT
  log "恢复模块目录"
  rm -rf "${ADDONS_DIR:?}/${MODULE}"
  if [ -d "$LATEST/module/${MODULE}" ]; then
    cp -a "$LATEST/module/${MODULE}" "$ADDONS_DIR/${MODULE}"
    ok "模块目录已恢复"
  else
    ok "备份时模块尚未部署，已移除模块目录"
  fi
  log "恢复数据库（pg_restore --clean --if-exists）"
  RESTORE_RC=0
  pg_tool pg_restore --clean --if-exists --no-owner -d "$DB_NAME" < "$LATEST/db.dump" 2>/tmp/wam_restore_err || RESTORE_RC=$?
  if [ "$RESTORE_RC" != "0" ]; then
    NERR=$(grep -c "error:" /tmp/wam_restore_err || true)
    warn "pg_restore 返回码 $RESTORE_RC，报告 $NERR 条错误（前 10 条如下）。"
    warn "扩展/注释/权限类错误通常可忽略；其他错误请保留该输出并检查网站。"
    head -n 10 /tmp/wam_restore_err | sed 's/^/        /'
  fi
  docker start "$CONTAINER" >/dev/null
  trap cleanup EXIT
  ok "回滚完成，$CONTAINER 已启动。浏览器请强制刷新（Ctrl+Shift+R）。"
  exit 0
fi

# ============================================================ DEPLOY
# ---------- 1. 兼容性检查（本模块依赖的 Odoo 内部代码是否仍在）----------
log "检查 Odoo 内部代码兼容性"
ODOO_ADDONS=$(docker exec "$CONTAINER" python3 -c "import odoo.addons, os; print([p for p in odoo.addons.__path__ if os.path.isdir(os.path.join(p,'html_editor'))][0])" 2>/dev/null || true)
ODOO_ADDONS=${ODOO_ADDONS:-/usr/lib/python3/dist-packages/odoo/addons}
COMPAT_WARN=0
anchor() {  # $1 file or dir (relative to addons), $2 fixed string, $3 description
  if docker exec "$CONTAINER" grep -rqF -- "$2" "$ODOO_ADDONS/$1" 2>/dev/null; then
    ok "  兼容：$3"
  else
    warn "  变化：$3 —— 相关入口可能不显示 AList（不影响网站其他功能）"
    COMPAT_WARN=1
  fi
}
anchor html_editor/static/src/main/media/media_dialog/media_dialog.js "this.props.extraTabs.forEach" "MediaDialog 额外标签机制"
anchor html_editor/static/src/main/media/media_dialog/media_dialog.js "if (onlyImages) {" "仅图片模式提前返回（补丁针对点）"
anchor html_editor/static/src/main/media/media_dialog/media_dialog.js "renderMedia" "renderMedia（正文视频类清理）"
anchor html_editor/static/src/main/media/icon_plugin.js "openIconDialog()" "图标对话框入口"
anchor html_editor/static/src/main/media/icon_plugin.js "onSaveIcon(icon, prevIcon)" "图标保存逻辑"
anchor html_editor/static/src/main/media/media_plugin.js "media_dialog_extra_tabs" "extra tabs 资源名"
anchor website/static/src "loadReplaceBackgroundVideo" "背景视频对话框（AList 背景视频入口）"
anchor website/static/src "websiteBackgroundVideoPlugin" "背景视频插件注册名"
anchor website/static/src/interactions/video/background_video.js "appendBgVideo" "前台背景视频渲染（直链 <video> 播放）"
anchor html_builder/static/src/core/utils.js "export class BaseOptionComponent" "侧栏选项组件基类（显示区域工具）"
anchor html_builder/static/src/core/utils.js "export function useDomState" "侧栏选项状态钩子（显示区域工具）"
anchor html_builder/static/src/utils/option_sequence.js "export function after" "选项排序 after()（显示区域工具）"
anchor html_builder/static/src/utils/option_sequence.js "IMAGE_TOOL" "图片工具选项序号（显示区域工具）"
anchor html_editor/static/src/main/media/media_dialog/media_dialog.js "element.classList.add(...this.props.media.classList)" "替换时类名继承（显示区域工具保留依赖此行为）"
if [ "$COMPAT_WARN" = "1" ]; then
  warn "Odoo 内部代码与适配版本不同，建议先部署到 staging 验证（--target staging）。"
fi

# ---------- 2. 当前状态 + 降级保护 ----------
STATE=$(db_query "SELECT COALESCE((SELECT state FROM ir_module_module WHERE name='${MODULE}'), 'absent');" | xargs)
OLD_VERSION=$(db_query "SELECT COALESCE((SELECT latest_version FROM ir_module_module WHERE name='${MODULE}'), '');" | xargs || true)
case "$STATE" in
  installed|"to upgrade") ACTION="-u"; ok "已安装（${OLD_VERSION:-?}）→ 升级 -u → $PKG_VERSION" ;;
  *)                      ACTION="-i"; ok "状态：$STATE → 安装 -i → $PKG_VERSION" ;;
esac
if [ "$ACTION" = "-u" ] && [ -n "$OLD_VERSION" ]; then
  if ver_lt "$PKG_VERSION" "$OLD_VERSION"; then
    if [ "$FORCE" = "1" ]; then
      warn "降级：$OLD_VERSION → $PKG_VERSION（--force 已允许）"
    else
      err "安装包 $PKG_VERSION 比数据库里的 $OLD_VERSION 旧，拒绝降级（可能拿错了包）。确需降级请加 --force"
      exit 1
    fi
  elif [ "$PKG_VERSION" = "$OLD_VERSION" ]; then
    warn "同版本重装（$PKG_VERSION），会重新加载代码与视图"
  fi
fi

# ---------- 3. 备份（数据库 + 旧模块目录）----------
BK=""
if [ "$DO_BACKUP" = "1" ]; then
  TS=$(date +%Y%m%d_%H%M%S)
  BK="$BACKUP_DIR_BASE/$TS"
  mkdir -p "$BK"
  chmod 700 "$BACKUP_ROOT" "$BACKUP_DIR_BASE" "$BK" 2>/dev/null || true
  log "备份数据库 $DB_NAME → $BK/db.dump"
  if ! pg_tool pg_dump -Fc -d "$DB_NAME" > "$BK/db.dump" 2>"$BK/pg_dump.err" || [ ! -s "$BK/db.dump" ]; then
    err "数据库备份失败，已中止部署（尚未改动任何东西）："
    cat "$BK/pg_dump.err" >&2
    rm -rf "$BK"
    err "如确需跳过备份，可加 --no-backup（不推荐）"
    exit 1
  fi
  rm -f "$BK/pg_dump.err"
  if [ -d "$ADDONS_DIR/$MODULE" ]; then
    mkdir -p "$BK/module" && cp -a "$ADDONS_DIR/$MODULE" "$BK/module/"
  fi
  printf "time=%s\ncontainer=%s\ndb=%s\nmodule_state=%s\nmodule_version=%s\nupgrading_to=%s\npackage=%s\n" \
    "$TS" "$CONTAINER" "$DB_NAME" "$STATE" "${OLD_VERSION:-}" "${PKG_VERSION:-}" "$PKG" > "$BK/meta.txt"
  chmod 600 "$BK/db.dump"
  ok "备份完成（$(du -sh "$BK" | cut -f1)）。回滚命令：sudo bash $0 --rollback$TARGET_FLAG"
  ls -1d "$BACKUP_DIR_BASE"/*/ 2>/dev/null | sort | head -n -"$BACKUP_KEEP" | xargs -r rm -rf
else
  warn "已跳过备份（--no-backup），此次部署无法用 --rollback 回退"
fi

# 安装/升级失败时：把模块文件恢复成部署前的样子（数据库事务已由 Odoo 回滚）
restore_module_files() {
  rm -rf "${ADDONS_DIR:?}/${MODULE}"
  if [ -n "$BK" ] && [ -d "$BK/module/${MODULE}" ]; then
    cp -a "$BK/module/${MODULE}" "$ADDONS_DIR/${MODULE}"
    warn "已自动恢复部署前的模块文件（$OLD_VERSION）"
  elif [ -z "$BK" ]; then
    warn "无备份（--no-backup），模块目录已移除；请手动放回旧版本"
  else
    warn "部署前没有该模块，已移除模块目录"
  fi
}

# ---------- 4. 部署文件（权限与 addons 目录一致，避免容器内读不到）----------
rm -rf "${ADDONS_DIR:?}/${MODULE}"
cp -a "$MODULE_SRC_DIR" "$ADDONS_DIR/${MODULE}"
chown -R "$(stat -c '%u:%g' "$ADDONS_DIR")" "$ADDONS_DIR/${MODULE}"
chmod -R u=rwX,go=rX "$ADDONS_DIR/${MODULE}"
ok "文件已部署：$ADDONS_DIR/${MODULE}"

# ---------- 5. 安装/升级 ----------
log "在 $DB_NAME 上执行 odoo $ACTION $MODULE"
if ! docker exec "$CONTAINER" odoo "$ACTION" "$MODULE" -d "$DB_NAME" \
     --db_host="$DB_HOST" --db_port="$DB_PORT" --db_user="$DB_USER" \
     --db_password="$DB_PASSWORD" --no-http --stop-after-init; then
  err "安装/升级失败（容器未重启，线上仍在跑旧代码）。"
  restore_module_files
  err "看上面的 Odoo 报错定位问题；若数据库状态异常，可回滚：sudo bash $0 --rollback$TARGET_FLAG"
  exit 1
fi
NEW_STATE=$(db_query "SELECT state FROM ir_module_module WHERE name='${MODULE}';" | xargs || true)
NEW_VERSION=$(db_query "SELECT COALESCE(latest_version,'') FROM ir_module_module WHERE name='${MODULE}';" | xargs || true)
if [ "$NEW_STATE" != "installed" ]; then
  err "执行后模块状态为「${NEW_STATE:-未知}」，不是 installed。容器未重启。回滚：sudo bash $0 --rollback$TARGET_FLAG"
  exit 1
fi
if [ "$NEW_VERSION" != "$PKG_VERSION" ]; then
  err "数据库版本 ${NEW_VERSION:-未知} ≠ 安装包版本 $PKG_VERSION —— 新代码未生效。容器未重启。回滚：sudo bash $0 --rollback$TARGET_FLAG"
  exit 1
fi
ok "数据库确认：${MODULE} 已安装，版本 $NEW_VERSION"

# ---------- 6. 重启 + 健康检查 ----------
RESTART_AT=$(date -u +%Y-%m-%dT%H:%M:%SZ)
docker restart "$CONTAINER" >/dev/null
ok "已重启 $CONTAINER，等待服务就绪（最多 ${HEALTH_TIMEOUT}s）"
HEALTHY=0
for _ in $(seq 1 $((HEALTH_TIMEOUT / 3))); do
  if docker exec "$CONTAINER" python3 -c \
      "import urllib.request; urllib.request.urlopen('http://127.0.0.1:${HTTP_PORT}/web/health', timeout=3)" \
      >/dev/null 2>&1; then
    HEALTHY=1; break
  fi
  sleep 3
done
if [ "$HEALTHY" = "1" ]; then
  ok "健康检查通过（/web/health）"
else
  warn "${HEALTH_TIMEOUT}s 内健康检查未通过，请看：docker logs --since $RESTART_AT $CONTAINER"
  warn "如网站打不开，回滚：sudo bash $0 --rollback$TARGET_FLAG"
fi

# ---------- 7. 启动日志扫描 ----------
LOG_ERR=$(docker logs --since "$RESTART_AT" "$CONTAINER" 2>&1 | grep -E " (ERROR|CRITICAL) |Traceback" | head -n 15 || true)
if [ -n "$LOG_ERR" ]; then
  warn "重启后日志中有错误（前 15 行）："
  echo "$LOG_ERR" | sed 's/^/        /'
  echo "$LOG_ERR" | grep -q "$MODULE" && warn "其中涉及 ${MODULE}，请重点检查"
else
  ok "重启后日志无 ERROR"
fi

# ---------- 8. 安全检查 ----------
if [ -n "$CONFIG_FILE" ]; then
  if grep -qE "^[[:space:]]*dbfilter[[:space:]]*=" "$CONFIG_FILE" && grep -qE "^[[:space:]]*list_db[[:space:]]*=[[:space:]]*[Ff]alse" "$CONFIG_FILE"; then
    ok "dbfilter / list_db 配置安全"
  else
    warn "$CONFIG_FILE 缺少安全配置：dbfilter = ^${DB_NAME}\$ 与 list_db = False"
  fi
fi
DB_SECRETS=$(db_query "SELECT count(*) FROM website_alist_media_source WHERE active AND (COALESCE(token,'')<>'' OR COALESCE(s3_secret_key,'')<>'');" 2>/dev/null | xargs || true)
if [ -n "$DB_SECRETS" ] && [ "$DB_SECRETS" != "0" ]; then
  warn "有 $DB_SECRETS 个媒体源把密钥存在数据库里；建议改用环境变量（源表单的 Secret Reference）"
fi

echo
ok "全部完成（$CONTAINER / $DB_NAME / $NEW_VERSION）"
echo "接下来："
echo "  1. 浏览器强制刷新（Ctrl+Shift+R）；控制台输入 __websiteAlistMedia，确认 version 为 $NEW_VERSION"
echo "  2. 按包内 TEST_PLAN.md 第 0 节验收（正文视频、背景视频、替换矩阵抽测）"
echo "  3. 如需回退：sudo bash $0 --rollback$TARGET_FLAG"
