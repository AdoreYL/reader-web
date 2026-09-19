#!/usr/bin/env bash
set -Eeuo pipefail
APP_DIR="${READER_WEB_DIR:-/opt/reader-web}"
cd "$APP_DIR"
echo '=== 系统 ==='; uname -a; cat /etc/debian_version 2>/dev/null || true
echo '=== Docker ==='; docker version --format '{{.Server.Version}}'; docker compose version
echo '=== 服务状态 ==='; docker compose ps
echo '=== 配置校验 ==='; docker compose config >/dev/null && echo 'Compose 配置：通过'
echo '=== 健康检查 ==='; docker inspect --format '{{.Name}} {{.State.Health.Status}}' $(docker compose ps -q reader) 2>/dev/null || true
echo '=== 最近日志（已由应用避免输出凭据） ==='; docker compose logs --tail=120 reader caddy
echo '=== 端口 ==='; ss -lntp | grep -E ':(80|443|6788)\b' || true
echo '=== 磁盘 ==='; df -h /opt "$APP_DIR"
