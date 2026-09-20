# reader-web

`reader-web` 是基于 AdoreYL/reader 的浏览器阅读服务。本项目仓库为 <https://github.com/AdoreYL/reader-web>，保留原项目 GPLv3 许可证、版权声明和来源说明。

## 默认部署与安装

- 默认 Compose 只启动 `reader`，容器监听 `6788`，宿主机默认发布 `0.0.0.0:6788`。
- 默认不管理域名、HTTPS、证书、Caddy、Nginx，也不占用 `80/443`；适用于 1Panel、Nginx Proxy Manager、局域网或 Docker 反向代理。
- 默认访问：`http://服务器内网IP:6788`。反向代理上游协议为 `http`，主机为服务器内网 IP，端口为 `6788`。
- 后端使用 HTTP 和 SSE；当前前端没有启用 WebSocket 客户端，反代无需开启 WebSocket，但应保留 SSE 长连接且不要缓存 SSE。

默认安装到 `/opt/reader-web`：

```bash
curl -fsSL https://raw.githubusercontent.com/AdoreYL/reader-web/main/scripts/install-debian.sh | bash
```

安装到当前目录：

```bash
curl -fsSL https://raw.githubusercontent.com/AdoreYL/reader-web/main/scripts/install-debian.sh | bash -s -- --install-dir "$PWD"
```

当前目录为空时会安装；已有本项目 Git 工作树会安全快进更新；非空且不是本项目 Git 工作树时会停止，不改名、不移动、不覆盖、不删除。

保留数据卸载：

```bash
sudo /opt/reader-web/scripts/uninstall-debian.sh
```

彻底卸载（必须输入 `DELETE READER-WEB DATA`，只删除本项目目录、备份、`.env` 和固定数据卷）：

```bash
sudo /opt/reader-web/scripts/uninstall-debian.sh --purge
```

当前目录安装时将上述路径替换为实际安装目录。AMD64/x86_64 与 ARM64/aarch64 由 GitHub Actions 分别实际验证；ARMv7/32 位 ARM 未验证，不默认承诺支持。

---
# reader-web

`reader-web` is a browser reading service based on AdoreYL/reader. It retains the upstream GPLv3 license and copyright notices.

## Default deployment

The default `docker-compose.yml` starts only `reader` and publishes HTTP on `0.0.0.0:6788`. It does not manage domains, HTTPS, certificates, Caddy, Nginx, or ports 80/443. This is intended for 1Panel, Nginx Proxy Manager, another local/LAN reverse proxy, and Docker reverse proxies.

- Default URL: `http://server-private-ip:6788`
- Reverse-proxy upstream: protocol `http`, host `server private IP`, port `6788`
- The application uses HTTP and Server-Sent Events. The current frontend has no active WebSocket client, so WebSocket proxy support is not required.
- Do not expose port 6788 directly to the Internet; it bypasses reverse-proxy HTTPS and access controls. Restrict it to the LAN or proxy network.

For Chinese Debian installation, operations, UFW examples, and the optional Caddy advanced mode, see [README.zh-CN.md](README.zh-CN.md).
