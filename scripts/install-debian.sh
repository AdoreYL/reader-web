#!/usr/bin/env bash
set -Eeuo pipefail
APP_DIR="${READER_WEB_DIR:-/opt/reader-web}"
ENV_FILE="$APP_DIR/.env"
log(){ printf '[reader-web] %s\n' "$*"; }
die(){ log "错误：$*" >&2; exit 1; }
[[ $EUID -eq 0 ]] || die '请使用 root 或 sudo 运行。'
[[ -f /etc/debian_version ]] || die '此安装器只支持 Debian。'
command -v curl >/dev/null || die '系统缺少 curl。'
command -v git >/dev/null || die '系统缺少 git。'
if ! command -v docker >/dev/null; then
  apt-get update
  apt-get install -y ca-certificates curl git
  install -d -m 0755 /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc
  chmod a+r /etc/apt/keyrings/docker.asc
  . /etc/os-release
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/debian $VERSION_CODENAME stable" > /etc/apt/sources.list.d/docker.list
  apt-get update
  apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
fi
docker compose version >/dev/null || die 'Docker Compose 插件不可用。'
mkdir -p "$APP_DIR"
if [[ -d "$APP_DIR/.git" ]]; then
  git -C "$APP_DIR" fetch --prune origin
  git -C "$APP_DIR" checkout main
  git -C "$APP_DIR" reset --hard origin/main
else
  git clone --branch main --depth 1 https://github.com/AdoreYL/reader-web.git "$APP_DIR"
fi
if [[ ! -f "$ENV_FILE" ]]; then
  read -r -p '请输入绑定域名（例如 reader.example.com）：' DOMAIN
  read -r -p '请输入 ACME 邮箱：' ACME_EMAIL
  [[ "$DOMAIN" =~ ^[A-Za-z0-9.-]+$ ]] || die '域名格式不正确。'
  [[ "$ACME_EMAIL" == *@*.* ]] || die '邮箱格式不正确。'
  ADMIN_PASSWORD=$(openssl rand -base64 30 2>/dev/null | tr -dc 'A-Za-z0-9@#%+=' | head -c 24 || true)
  [[ ${#ADMIN_PASSWORD} -ge 16 ]] || ADMIN_PASSWORD=$(date +%s%N | sha256sum | cut -c1-24)
  umask 077
  printf 'DOMAIN=%s\nACME_EMAIL=%s\nREADER_ADMIN_PASSWORD=%s\nREADER_INVITE_CODE=\nTZ=Asia/Shanghai\n' "$DOMAIN" "$ACME_EMAIL" "$ADMIN_PASSWORD" > "$ENV_FILE"
  log "初始管理员密码（仅显示一次）：$ADMIN_PASSWORD"
else
  log "检测到已有配置，保留现有密码和数据。"
fi
chmod 600 "$ENV_FILE"
cd "$APP_DIR"
docker compose config >/dev/null
docker compose up -d --build
docker compose ps
log "安装完成。访问地址：https://$(grep '^DOMAIN=' "$ENV_FILE" | cut -d= -f2-)"
log "更新：$APP_DIR/scripts/update-debian.sh"
log "诊断：$APP_DIR/scripts/diagnose-debian.sh"
log "数据：Docker volume reader-web_reader-data；日志：reader-web_reader-logs"
