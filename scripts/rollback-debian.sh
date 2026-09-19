#!/usr/bin/env bash
set -Eeuo pipefail
APP_DIR="${READER_WEB_DIR:-/opt/reader-web}"
BACKUP_DIR="$APP_DIR/backups"
[[ $EUID -eq 0 ]] || { echo '请使用 root 或 sudo 运行。' >&2; exit 1; }
cd "$APP_DIR"
LATEST=$(find "$BACKUP_DIR" -mindepth 1 -maxdepth 1 -type d | sort | tail -1)
[[ -n "$LATEST" && -f "$LATEST/reader-data.tgz" ]] || { echo '没有可恢复的备份。' >&2; exit 1; }
read -r -p "将恢复 $LATEST，现有数据会先停止服务。继续？输入 YES：" CONFIRM
[[ "$CONFIRM" == YES ]] || exit 1
docker compose down
cat "$LATEST/.env" > .env
docker run --rm -v reader-web-reader-data:/data -v "$LATEST:/backup" alpine:3.20 sh -c 'rm -rf /data/* /data/.[!.]* /data/..?* 2>/dev/null || true; tar xzf /backup/reader-data.tgz -C /data'
docker compose up -d
