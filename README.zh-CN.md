# reader-web 部署说明

`reader-web` 是基于 AdoreYL/reader 的浏览器阅读服务，保留原项目 GPLv3 许可证、版权信息和传统 Legado 书源能力。默认部署为一个仅提供 HTTP 的 Docker 服务，适用于 1Panel、Nginx Proxy Manager、同机或局域网其他反向代理，以及 Docker 反向代理。

## 默认部署

- reader 容器内部固定监听 `6788`，默认发布为 `0.0.0.0:6788 -> 6788`。
- 默认 Compose 只启动 `reader`，不会启动 Caddy，不会占用 `80` 或 `443`。
- 默认访问方式：`http://服务器内网IP:6788`。
- 数据和日志使用独立 Docker volumes；容器自动重启，并保留健康检查、备份、更新、诊断和回滚脚本。
- 生产默认开启登录鉴权。安装器生成管理密码和随机邀请码；随机邀请码使公开注册默认关闭。首次用户在浏览器中自行设置用户名和登录密码。

项目默认不负责域名、HTTPS 或证书。`80/443` 应继续由你已有的反向代理管理。

## Debian 一键安装

在 Debian 11/12 使用 root 或具备 sudo 权限的账号执行：

```bash
curl -fsSL https://raw.githubusercontent.com/AdoreYL/reader-web/main/scripts/install-debian.sh | sudo bash
```

该命令不需要交互输入域名、邮箱或 ACME 信息。安装器会自动安装启动依赖、构建并启动容器，首次成功后仅显示一次初始管理员密码，并打印局域网访问和反向代理上游地址。

## 1Panel / Nginx Proxy Manager

在已有反向代理中新建代理主机时使用：

| 配置项 | 值 |
| --- | --- |
| 上游协议 | `http` |
| 上游主机 | 服务器内网 IP |
| 上游端口 | `6788` |

项目后端使用普通 HTTP 和 SSE（Server-Sent Events）流式接口；当前前端没有启用 WebSocket 连接，因此反向代理不需要开启 WebSocket 支持。请保留长连接响应，不要缓存 SSE 响应。

## 网络安全

端口 `6788` 直接暴露到公网会绕过现有反向代理的 HTTPS、访问控制和安全策略。建议只允许局域网或反向代理所在网络访问。安装器不会修改防火墙。可选 Debian UFW 示例：

```bash
sudo ufw allow from 192.168.1.0/24 to any port 6788 proto tcp
sudo ufw deny 6788/tcp
```

先按你的实际局域网网段调整第一条规则，再执行第二条规则。

## 运维入口

安装目录默认为 `/opt/reader-web`。重复执行安装器会保留现有 `.env`、Docker 数据卷和 `backups`：

- 更新：`sudo /opt/reader-web/scripts/update-debian.sh`
- 诊断：`sudo /opt/reader-web/scripts/diagnose-debian.sh`
- 回滚：`sudo /opt/reader-web/scripts/rollback-debian.sh`

更新会先把 `reader-data` volume 备份到 `backups/时间戳/`。项目脚本不会自动删除 Docker volumes。

## 可选 Caddy 高级模式

`deploy/docker-compose.caddy.yml` 仅供自行管理域名和证书的高级部署使用。它会占用 `80/443`，不要与 1Panel、Nginx Proxy Manager 或同机其他反向代理同时使用。

## 构建与远程仓库

唯一默认 Compose 入口是 `docker-compose.yml`。应用构建采用 Docker 多阶段流程：Node 构建现有 Vue 前端，Gradle/JDK 8 构建 Kotlin/Java 服务，运行阶段只保留 JRE。GitHub Actions 会实际执行 Shell 语法检查、Compose 配置验证、Docker 构建、默认 Compose 启动，以及容器内和宿主机映射端口的 `/health` 检查。

- `origin`：<https://github.com/AdoreYL/reader-web.git>，唯一允许推送的仓库。
- `upstream`：<https://github.com/AdoreYL/reader.git>，仅作原始项目参考。
- `legado-upstream`：<https://github.com/LegadoTeam/legado.git>，仅作社区规则参考。

本项目遵循 GPLv3，详见 [LICENSE](LICENSE)。