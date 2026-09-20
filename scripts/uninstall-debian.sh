#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
APP_DIR="${READER_WEB_DIR:-$SCRIPT_DIR}"
log(){ printf '[reader-web] %s\n' "$*"; }
die(){ log "错误：$*" >&2; exit 1; }
usage(){
  printf '用法：uninstall-debian.sh [--purge]\n默认只停止并移除 reader-web 容器和网络，保留项目、.env、备份和 Docker 数据卷。\n--purge 需要完整输入 DELETE READER-WEB DATA，才会删除本项目数据。\n'
}
PURGE=0
case "${1:-}" in
  "") ;;
  --purge) PURGE=1 ;;
  --help|-h) usage; exit 0 ;;
  *) usage >&2; die "不支持的参数：$1" ;;
esac
[[ $# -le 1 ]] || die '参数过多。'
[[ -d "$APP_DIR" ]] || die "找不到项目目录：$APP_DIR"
[[ -d "$APP_DIR/.git" ]] || die '目标目录不是 reader-web Git 工作树，已停止，未删除任何数据。'
cd "$APP_DIR"
command -v docker >/dev/null || die '系统缺少 Docker。'
if docker compose config >/dev/null 2>&1; then
  log '正在停止并移除 reader-web 容器和 Compose 网络；数据卷、项目目录和备份将保留。'
  docker compose down --remove-orphans
else
  log 'Compose 配置不可用，将仅按项目标签清理 reader-web 容器；项目文件和数据保留。'
  docker ps -aq --filter label=com.docker.compose.project=reader-web | xargs -r docker rm -f
fi
if (( PURGE == 0 )); then
  log '保留数据卸载完成：项目目录、.env、backups 和 Docker 数据卷均已保留。'
  exit 0
fi
printf '警告：--purge 将删除 Docker 数据卷、备份、.env 和整个项目目录。此操作不可恢复。\n请输入完整确认词 DELETE READER-WEB DATA：'
read -r CONFIRM
[[ "$CONFIRM" == 'DELETE READER-WEB DATA' ]] || die '确认词不匹配，未删除任何数据。'
for volume in reader-web-reader-data reader-web-reader-logs; do
  if docker volume inspect "$volume" >/dev/null 2>&1; then
    docker volume rm "$volume" || die "无法删除 Docker 数据卷：$volume"
  fi
done
[[ "$APP_DIR" != / ]] || die '拒绝删除根目录。'
cd /
rm -rf -- "$APP_DIR"
log "彻底卸载完成：已删除 $APP_DIR、backups、.env 及 reader-web 数据卷。"
