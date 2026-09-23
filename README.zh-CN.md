# reader-web

`reader-web` 是基于 AdoreYL/reader 的浏览器阅读服务。本项目仓库为 <https://github.com/AdoreYL/reader-web>，保留原项目 GPLv3 许可证、版权声明和来源说明，详见 [LICENSE](LICENSE)。

## 默认部署

- 默认 Compose 只启动 `reader`，容器监听 `6788`，宿主机默认发布 `0.0.0.0:6788`。
- 默认不管理域名、HTTPS、证书、Caddy、Nginx，也不占用 `80/443`。这些由 1Panel、Nginx Proxy Manager、同机/局域网反向代理或 Docker 反代管理。
- 默认访问：`http://服务器内网IP:6788`。反向代理上游协议为 `http`，主机为服务器内网 IP，端口为 `6788`。
- 后端使用 HTTP 和 SSE；当前前端没有启用 WebSocket 客户端，反代无需开启 WebSocket，但应保留 SSE 长连接且不要缓存 SSE。
- 不建议把 6788 暴露到公网，应仅允许局域网或反向代理网络访问。

## Debian 安装

安装器不询问域名、ACME 邮箱或代理配置，也不会修改防火墙。默认安装到 `/opt/reader-web`：

```bash
curl -fsSL https://raw.githubusercontent.com/AdoreYL/reader-web/main/scripts/install-debian.sh | bash
```

安装到执行命令时的当前目录：

```bash
curl -fsSL https://raw.githubusercontent.com/AdoreYL/reader-web/main/scripts/install-debian.sh | bash -s -- --install-dir "$PWD"
```

当前目录为空时会安装；已有本项目 Git 工作树会快进更新并保留 `.env`、`backups` 和 Docker 数据卷；非空且不是本项目 Git 工作树时会停止并提示，不会改名、移动、覆盖或删除目录。

## 运维和卸载

脚本默认使用自身所在项目目录，也可通过 `READER_WEB_DIR=/path/to/reader-web` 指定目录。更新失败不会自动 reset 用户数据，更新前会备份数据卷：

```bash
sudo /opt/reader-web/scripts/update-debian.sh
sudo /opt/reader-web/scripts/diagnose-debian.sh
sudo /opt/reader-web/scripts/rollback-debian.sh
```

保留项目、`.env`、备份和 Docker 数据卷的卸载：

```bash
sudo /opt/reader-web/scripts/uninstall-debian.sh
```

彻底卸载需要完整输入确认词 `DELETE READER-WEB DATA`，才会删除本项目目录、备份、`.env` 以及固定名称的两个 Docker 数据卷；不会删除 Docker、本机其他 Compose 项目、其他容器或其他数据卷：

```bash
sudo /opt/reader-web/scripts/uninstall-debian.sh --purge
```

当前目录安装时，将上述 `/opt/reader-web` 替换为实际目录。

## 网络安全

可按实际网段选择性限制 6788，安装器不会强制改防火墙：

```bash
sudo ufw allow from 192.168.1.0/24 to any port 6788 proto tcp
sudo ufw deny 6788/tcp
```

## 架构支持

- `linux/amd64`、`linux/arm64`：GitHub Actions 会分别执行 Compose 配置、Docker build、启动容器、容器内 `/health` 和宿主机 `127.0.0.1:6788/health` 验证。
- `linux/arm/v7` 等 32 位 ARM：未验证，不默认承诺支持。
- Dockerfile 使用的 Node、Gradle/JDK 8、Amazon Corretto 8 Alpine 基础镜像由 CI 在目标架构实际验证；若 ARM64 构建或健康检查失败，不能宣称兼容。

## 可选高级模式

`deploy/docker-compose.caddy.yml` 仅供自行管理域名和证书的高级部署，会占用 `80/443`，不要与 1Panel、Nginx Proxy Manager 或同机其他反向代理同时使用。默认安装和默认 Compose 不使用它。

## 项目文档

- [安装与升级](docs/install-upgrade.md)
- [反向代理](docs/proxy.md)
- [备份与恢复](docs/backup-restore.md)
- [卸载](docs/uninstall.md)
- [安全说明](docs/security.md)
- [API 与兼容性](docs/api-compatibility.md)
- [架构与开发](docs/architecture.md)
- [前端现代化](docs/frontend-modernization.md)

## 远程仓库

- `origin`：<https://github.com/AdoreYL/reader-web.git>，唯一允许推送的仓库。
- `upstream`：<https://github.com/AdoreYL/reader.git>，仅作原始项目参考。
- `legado-upstream`：<https://github.com/LegadoTeam/legado.git>，仅作社区版本参考。
