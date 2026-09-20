#!/usr/bin/env bash
set -Eeuo pipefail
APP_DIR="${READER_WEB_DIR:-/opt/reader-web}"
cd "$APP_DIR"
echo '=== 系统 ==='; uname -a; cat /etc/debian_version 2>/dev/null || true
echo '=== Docker ==='; docker version --format '{{.Server.Version}}'; docker compose version
echo '=== 服务状态 ==='; docker compose ps
echo '=== 配置校验 ==='; docker compose config >/dev/null && echo 'Compose 配置：通过'
echo '=== 健康检查 ==='; docker inspect --format '{{.Name}} {{.State.Health.Status}}' "$(docker compose ps -q reader)" 2>/dev/null || true
echo '=== 本机 HTTP 健康检查 ==='; curl -fsS http://127.0.0.1:"${READER_HOST_PORT:-6788}"/health || true; echo
echo '=== 最近日志（应用已避免输出凭据） ==='; docker compose logs --tail=120 reader
echo '=== 端口 ==='; ss -lntp | grep -E ':6788\b' || true
echo '=== 磁盘 ==='; df -h /opt "$APP_DIR"