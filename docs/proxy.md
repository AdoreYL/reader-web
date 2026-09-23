# 反向代理

上游协议 HTTP，主机为服务器内网 IP，端口 6788。默认不占用 80/443，不启动 Caddy；域名和 HTTPS 由 1Panel、Nginx Proxy Manager 或其他反向代理管理。后端使用 SSE，反代应保留长连接且不要缓存 SSE。
