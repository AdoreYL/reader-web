#!/usr/bin/env bash
set -Eeuo pipefail

APP_DIR="${READER_WEB_DIR:-/opt/reader-web}"

usage() {
  printf '用法：install-debian.sh [--install-dir 目录]\n未指定 --install-dir 时默认安装到 /opt/reader-web。\n'
}

while (($#)); do
  case "$1" in
    --install-dir)
      [[ $# -ge 2 && -n "$2" ]] || { usage >&2; exit 2; }
      APP_DIR="$2"
      shift 2
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      usage >&2
      printf '[reader-web] 错误：不支持的参数：%s\n' "$1" >&2
      exit 2
      ;;
  esac
done

if [[ "$APP_DIR" != /* ]]; then
  mkdir -p "$APP_DIR"
  APP_DIR="$(cd "$APP_DIR" && pwd -P)"
fi
REPO_URL="https://github.com/AdoreYL/reader-web.git"
BRANCH="main"
ENV_FILE="$APP_DIR/.env"
FIRST_INSTALL=0
ADMIN_PASSWORD=""
INVITE_CODE=""
GENERATED_ADMIN_PASSWORD=0
GENERATED_INVITE_CODE=0

log(){ printf '[reader-web] %s\n' "$*"; }
die(){ log "错误：$*" >&2; log "未删除或覆盖现有数据。如需诊断，请运行：$APP_DIR/scripts/diagnose-debian.sh" >&2; exit 1; }
err_report(){ local code=$?; trap - ERR; die "安装过程在第 $1 行失败（退出码 $code），请把以上全部输出发回。"; }
trap 'err_report $LINENO' ERR

git_with_retry() {
  local attempt=1 max_attempts=5 exit_code=0
  while (( attempt <= max_attempts )); do
    if GIT_TERMINAL_PROMPT=0 git -c http.version=HTTP/1.1 -c http.lowSpeedLimit=1 -c http.lowSpeedTime=60 "$@"; then
      return 0
    fi
    exit_code=$?
    (( attempt == max_attempts )) && return "$exit_code"
    log "GitHub 连接中断，${attempt}/${max_attempts} 次下载失败；10 秒后自动重试……"
    sleep 10
    ((attempt++))
  done
}

random_secret() {
  openssl rand -base64 48 | tr -dc 'A-Za-z0-9@#%+=' | head -c 32 || true
}

lan_ipv4() {
  local candidate
  while read -r candidate; do
    case "$candidate" in
      10.*|192.168.*|172.1[6-9].*|172.2[0-9].*|172.3[0-1].*) printf '%s' "$candidate"; return 0 ;;
    esac
  done < <(hostname -I 2>/dev/null | tr ' ' '\n')
  return 1
}

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
  git_with_retry -C "$APP_DIR" fetch --prune origin || die '拉取 origin 连续失败，请检查服务器到 github.com 的网络后把完整输出发回。'
  git -C "$APP_DIR" checkout "$BRANCH" || die '切换 main 分支失败。'
  git -C "$APP_DIR" merge --ff-only "origin/$BRANCH" || die '已有安装不是可快进状态，未 reset 或删除数据。'
elif [[ -d "$APP_DIR" ]] && [[ -n "$(find "$APP_DIR" -mindepth 1 -maxdepth 1 -print -quit)" ]]; then
  die "安装路径已存在且不是 reader-web Git 工作树，为避免覆盖文件而停止：$APP_DIR；请改用空目录。"
else
  [[ ! -d "$APP_DIR" || -z "$(find "$APP_DIR" -mindepth 1 -maxdepth 1 -print -quit)" ]] || die '安装目录不是空目录。'
  log "首次安装：克隆 $REPO_URL 到 $APP_DIR……"
  CLONE_DIR=$(mktemp -d "$(dirname "$APP_DIR")/.reader-web.clone.XXXXXX")
  if ! git_with_retry clone --branch "$BRANCH" --depth 1 "$REPO_URL" "$CLONE_DIR/repository"; then
    rm -rf "$CLONE_DIR"
    die '源码连续下载失败，未覆盖已有文件。'
  fi
  mkdir -p "$APP_DIR"
  cp -a "$CLONE_DIR/repository/." "$APP_DIR/"
  rm -rf "$CLONE_DIR"
fi

if [[ ! -f "$ENV_FILE" ]]; then
  FIRST_INSTALL=1
  ADMIN_PASSWORD=$(random_secret)
  INVITE_CODE=$(random_secret)
  GENERATED_ADMIN_PASSWORD=1
  GENERATED_INVITE_CODE=1
  [[ ${#ADMIN_PASSWORD} -ge 20 && ${#INVITE_CODE} -ge 20 ]] || die '无法生成足够强度的管理员凭据。'
  umask 077
  printf 'READER_HOST_BIND=0.0.0.0\nREADER_HOST_PORT=6788\nTZ=Asia/Shanghai\nREADER_ADMIN_PASSWORD=%s\nREADER_INVITE_CODE=%s\n' "$ADMIN_PASSWORD" "$INVITE_CODE" > "$ENV_FILE"
else
  log '检测到已有 .env，保留现有密码、端口和注册配置。'
  if ! grep -q '^READER_HOST_BIND=' "$ENV_FILE"; then printf 'READER_HOST_BIND=0.0.0.0\n' >> "$ENV_FILE"; fi
  if ! grep -q '^READER_HOST_PORT=' "$ENV_FILE"; then printf 'READER_HOST_PORT=6788\n' >> "$ENV_FILE"; fi
  if ! grep -q '^TZ=' "$ENV_FILE"; then printf 'TZ=Asia/Shanghai\n' >> "$ENV_FILE"; fi
  if ! grep -q '^READER_ADMIN_PASSWORD=.' "$ENV_FILE"; then
    ADMIN_PASSWORD=$(random_secret)
    [[ ${#ADMIN_PASSWORD} -ge 20 ]] || die '无法生成足够强度的管理员密码。'
    printf 'READER_ADMIN_PASSWORD=%s\n' "$ADMIN_PASSWORD" >> "$ENV_FILE"
    FIRST_INSTALL=1
    GENERATED_ADMIN_PASSWORD=1
  fi
  if ! grep -q '^READER_INVITE_CODE=.' "$ENV_FILE"; then
    INVITE_CODE=$(random_secret)
    [[ ${#INVITE_CODE} -ge 20 ]] || die '无法生成足够强度的邀请码。'
    printf 'READER_INVITE_CODE=%s\n' "$INVITE_CODE" >> "$ENV_FILE"
    GENERATED_INVITE_CODE=1
  fi
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
  docker compose logs --tail=120 reader >&2 || true
  die '应用未通过 /health 健康检查。'
fi

ADDRESS=$(lan_ipv4 || true)
[[ -n "$ADDRESS" ]] || ADDRESS='服务器IP'
docker compose ps
log '安装完成'
log "局域网访问地址：http://${ADDRESS}:6788"
log '管理员用户名：首次注册时自行设置（至少 5 位，仅限字母和数字）'
if (( GENERATED_ADMIN_PASSWORD )); then
  log "初始管理员密码：$ADMIN_PASSWORD"
fi
if (( GENERATED_INVITE_CODE )); then
  log "首次注册邀请码：$INVITE_CODE"
fi
if (( GENERATED_ADMIN_PASSWORD || GENERATED_INVITE_CODE )); then
  log '初始管理员密码用于管理功能；随机邀请码用于关闭公开注册。'
fi
log "反向代理上游地址：http://${ADDRESS}:6788"
log "更新命令：$APP_DIR/scripts/update-debian.sh"
log "诊断命令：$APP_DIR/scripts/diagnose-debian.sh"
log "数据和备份路径：Docker volume reader-web-reader-data；$APP_DIR/backups"
