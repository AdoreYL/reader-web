# reader-web

`reader-web` is a browser reading service based on AdoreYL/reader. It retains the upstream GPLv3 license and copyright notices.

## Default deployment

The default `docker-compose.yml` starts only `reader` and publishes HTTP on `0.0.0.0:6788`. It does not manage domains, HTTPS, certificates, Caddy, Nginx, or ports 80/443. This is intended for 1Panel, Nginx Proxy Manager, another local/LAN reverse proxy, and Docker reverse proxies.

- Default URL: `http://server-private-ip:6788`
- Reverse-proxy upstream: protocol `http`, host `server private IP`, port `6788`
- The application uses HTTP and Server-Sent Events. The current frontend has no active WebSocket client, so WebSocket proxy support is not required.
- Do not expose port 6788 directly to the Internet; it bypasses reverse-proxy HTTPS and access controls. Restrict it to the LAN or proxy network.

For Chinese Debian installation, operations, UFW examples, and the optional Caddy advanced mode, see [README.zh-CN.md](README.zh-CN.md).