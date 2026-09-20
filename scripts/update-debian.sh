#!/usr/bin/env bash
set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
APP_DIR="${READER_WEB_DIR:-$SCRIPT_DIR}"
log(){ printf '[reader-web] %s\n' "$*"; }
BACKUP_DIR="$APP_DIR/backups"
die(){ log "错误：$*" >&2; exit 1; }
[[ $EUID -eq 0 ]] || die '请使用 root 或 sudo 运行。'
[[ -d "$APP_DIR/.git" ]] || die "找不到 Git 安装：$APP_DIR"
cd "$APP_DIR"
mkdir -p "$BACKUP_DIR"
STAMP=$(date +%Y%m%d-%H%M%S)
BACKUP="$BACKUP_DIR/$STAMP"
mkdir -p "$BACKUP"
docker run --rm -v reader-web-reader-data:/data -v "$BACKUP:/backup" alpine:3.20 tar czf /backup/reader-data.tgz -C /data .
cp .env "$BACKUP/.env"
CURRENT_COMMIT=$(git rev-parse HEAD)
[[ -z "$(git status --porcelain)" ]] || die '工作树存在未提交修改，未自动覆盖。'
git fetch --prune origin
git checkout main
git merge --ff-only origin/main || die "本地版本不是可快进更新，未 reset；备份位于 $BACKUP"
if ! docker compose up -d --build; then
  log "更新失败，正在恢复旧代码：$CURRENT_COMMIT"
  git reset --hard "$CURRENT_COMMIT"
  docker compose up -d --build || true
  die "更新失败；数据备份位于 $BACKUP"
fi
docker compose ps
printf '更新完成，备份：%s\n' "$BACKUP"
