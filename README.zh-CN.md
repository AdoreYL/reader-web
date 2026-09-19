# reader-web 部署说明

`reader-web` 是基于 AdoreYL/reader 的浏览器阅读服务，保留原项目 GPLv3 许可证、版权信息和传统 Legado 书源能力。项目面向 Debian、Docker 和 NAS 部署，不提供 Android 或桌面客户端。

## 当前可部署基线

- 应用容器内部固定监听 `6788`，不直接发布宿主机应用端口。
- Caddy 独立提供 HTTP/HTTPS 入口，自动申请和续期证书。
- 数据、日志和 Caddy 证书使用独立 Docker volumes。
- 生产默认启用登录鉴权，注册默认关闭；管理员密码只在首次安装时生成并显示一次。
- 安装前自动检查 Debian、Docker Compose、域名和邮箱；更新前生成数据备份。
- 提供 `/health` 健康检查，并通过 GitHub Actions 验证 Compose 配置和 Docker 构建。

## Debian 一键安装

在干净的 Debian 11/12 服务器上，以 root 或具备 sudo 权限的账号执行：

```bash
curl -fsSL https://raw.githubusercontent.com/AdoreYL/reader-web/main/scripts/install-debian.sh | sudo bash
```

安装器会询问域名和 ACME 邮箱。域名必须已经解析到服务器，且云防火墙允许 TCP 80/443。安装成功后会显示访问地址、一次性管理员密码、更新和诊断入口。不要把 `.env` 或密码提交到 Git。

## 运维入口

安装目录默认为 `/opt/reader-web`。重复执行安装器会保留现有 `.env` 和 Docker 数据：

- 更新：`sudo /opt/reader-web/scripts/update-debian.sh`
- 诊断：`sudo /opt/reader-web/scripts/diagnose-debian.sh`
- 回滚：`sudo /opt/reader-web/scripts/rollback-debian.sh`

更新会先把 `reader-data` volume 备份到 `backups/时间戳/`。项目脚本不会自动删除 Docker volumes。

## 构建与远程仓库

唯一 Compose 入口是 `docker-compose.yml`。应用构建采用 Docker 多阶段流程：Node 构建现有 Vue 前端，Gradle/JDK 8 构建 Kotlin/Java 服务，运行阶段只保留 JRE。独立 CI 会执行 Compose 配置校验、Shell 语法检查和 Docker 构建。

- `origin`：<https://github.com/AdoreYL/reader-web.git>，唯一允许推送的仓库。
- `upstream`：<https://github.com/AdoreYL/reader.git>，仅作原始项目参考。
- `legado-upstream`：<https://github.com/LegadoTeam/legado.git>，仅作社区规则参考。

本项目遵循 GPLv3，详见 [LICENSE](LICENSE)。