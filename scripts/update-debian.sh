#!/usr/bin/env bash
set -Eeuo pipefail
APP_DIR="${READER_WEB_DIR:-/opt/reader-web}"
BACKUP_DIR="$APP_DIR/backups"
[[ $EUID -eq 0 ]] || { echo '请使用 root 或 sudo 运行。' >&2; exit 1; }
cd "$APP_DIR"
mkdir -p "$BACKUP_DIR"
STAMP=$(date +%Y%m%d-%H%M%S)
BACKUP="$BACKUP_DIR/$STAMP"
mkdir -p "$BACKUP"
docker run --rm -v reader-web_reader-data:/data -v "$BACKUP:/backup" alpine:3.20 tar czf /backup/reader-data.tgz -C /data .
cp .env "$BACKUP/.env"
CURRENT_COMMIT=$(git rev-parse HEAD)
git fetch --prune origin
git checkout main
git reset --hard origin/main
if ! docker compose up -d --build; then
  echo "更新失败，正在回滚代码；数据备份位于 $BACKUP" >&2
  git reset --hard "$CURRENT_COMMIT"
  docker compose up -d --build || true
  exit 1
fi
docker compose ps
printf '更新完成，备份：%s\n' "$BACKUP"