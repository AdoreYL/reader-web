#!/usr/bin/env bash
set -Eeuo pipefail

APP_DIR="${READER_WEB_DIR:-/opt/reader-web}"
REPO_URL="https://github.com/AdoreYL/reader-web.git"
BRANCH="main"
ENV_FILE="$APP_DIR/.env"

log(){ printf '[reader-web] %s\n' "$*"; }
die(){ log "错误：$*" >&2; log "未删除或覆盖现有数据。如需诊断，请运行：$APP_DIR/scripts/diagnose-debian.sh" >&2; exit 1; }
err_report(){ local code=$?; trap - ERR; die "安装过程在第 $1 行失败（退出码 $code），请把以上全部输出发回。"; }
trap 'err_report $LINENO' ERR

[[ $EUID -eq 0 ]] || die '请使用 root 或 sudo 运行。'
[[ -f /etc/debian_version ]] || die '此安装器只支持 Debian 11/12。'
command -v apt-get >/dev/null || die '找不到 apt-get。'

log '安装启动依赖（curl、git、openssl、证书组件）……'
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y ca-certificates curl git openssl

if ! command -v docker >/dev/null || ! docker compose version >/dev/null 2>&1; then
  log '未检测到可用 Docker Compose，安装 Docker Engine 和 Compose 插件……'
  install -d -m 0755 /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc
  chmod a+r /etc/apt/keyrings/docker.asc
  . /etc/os-release
  [[ "$ID" == debian ]] || die "当前系统不是 Debian：$ID"
  : "${VERSION_CODENAME:?无法确定 Debian 版本代号}"
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/debian $VERSION_CODENAME stable" > /etc/apt/sources.list.d/docker.list
  apt-get update
  apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
  systemctl enable --now docker
fi
command -v docker >/dev/null || die 'Docker 安装后仍不可用。'
docker compose version >/dev/null 2>&1 || die 'Docker Compose 插件安装后仍不可用。'

mkdir -p "$(dirname "$APP_DIR")"
if [[ -e "$APP_DIR" && ! -d "$APP_DIR" ]]; then
  die "安装路径已存在但不是目录：$APP_DIR"
fi

if [[ -d "$APP_DIR/.git" ]]; then
  log '检测到已有 Git 安装，保留 .env、Docker 数据卷和 backups。'
  [[ -z "$(git -C "$APP_DIR" status --porcelain)" ]] || die '已有安装存在未提交修改，未自动覆盖；请先保留现场后再处理。'
  git -C "$APP_DIR" fetch --prune origin || die '拉取 origin 失败，请检查网络或把完整输出发回。'
  git -C "$APP_DIR" checkout "$BRANCH" || die '切换 main 分支失败。'
  git -C "$APP_DIR" merge --ff-only "origin/$BRANCH" || die '已有安装不是可快进状态，未 reset 或删除数据。'
elif [[ -d "$APP_DIR" ]] && [[ -n "$(find "$APP_DIR" -mindepth 1 -maxdepth 1 -print -quit)" ]]; then
  die "安装路径已存在且不是 reader-web Git 工作树，为避免覆盖文件而停止：$APP_DIR"
else
  [[ ! -d "$APP_DIR" || -z "$(find "$APP_DIR" -mindepth 1 -maxdepth 1 -print -quit)" ]] || die '安装目录不是空目录。'
  [[ -d "$APP_DIR" ]] && rmdir "$APP_DIR"
  log "首次安装：克隆 $REPO_URL 到 $APP_DIR……"
  git clone --branch "$BRANCH" --depth 1 "$REPO_URL" "$APP_DIR" || die '源码下载失败，未覆盖已有文件。'
fi

if [[ ! -f "$ENV_FILE" ]]; then
  read -r -p '请输入绑定域名（例如 reader.example.com）：' DOMAIN
  read -r -p '请输入 ACME 邮箱：' ACME_EMAIL
  [[ "$DOMAIN" =~ ^[A-Za-z0-9.-]+$ ]] || die '域名格式不正确。'
  [[ "$ACME_EMAIL" == *@*.* ]] || die '邮箱格式不正确。'
  ADMIN_PASSWORD=$(openssl rand -base64 48 | tr -dc 'A-Za-z0-9@#%+=' | head -c 32 || true)
  [[ ${#ADMIN_PASSWORD} -ge 20 ]] || die '无法生成足够强度的管理员密码。'
  umask 077
  printf 'DOMAIN=%s\nACME_EMAIL=%s\nREADER_ADMIN_PASSWORD=%s\nREADER_INVITE_CODE=\nTZ=Asia/Shanghai\n' "$DOMAIN" "$ACME_EMAIL" "$ADMIN_PASSWORD" > "$ENV_FILE"
  log "初始管理员密码（仅显示一次）：$ADMIN_PASSWORD"
else
  log '检测到已有 .env，保留现有密码、域名和注册配置。'
fi
chmod 600 "$ENV_FILE"
cd "$APP_DIR"
log '校验 Compose 配置……'
docker compose config >/dev/null || die 'Compose 配置校验失败。'
log '构建并启动服务……'
docker compose up -d --build || die '服务启动失败。'
log '等待应用健康检查……'
status=''
for attempt in $(seq 1 30); do
  status=$(docker inspect --format '{{.State.Health.Status}}' "$(docker compose ps -q reader)" 2>/dev/null || true)
  [[ "$status" == healthy || "$status" == unhealthy ]] && break
  sleep 2
done
if [[ "$status" != healthy ]]; then
  docker compose ps >&2 || true
  docker compose logs --tail=120 reader caddy >&2 || true
  die '应用未通过 /health 健康检查。'
fi
if ! docker compose ps --status running --services | grep -qx caddy; then
  docker compose ps >&2 || true
  docker compose logs --tail=120 reader caddy >&2 || true
  die 'Caddy 未进入运行状态。'
fi

docker compose ps
log "安装完成。访问地址：https://$(grep '^DOMAIN=' "$ENV_FILE" | cut -d= -f2-)"
log "更新：$APP_DIR/scripts/update-debian.sh"
log "诊断：$APP_DIR/scripts/diagnose-debian.sh"
log '数据和备份均保留在服务器安装目录与 Docker volumes 中。'
