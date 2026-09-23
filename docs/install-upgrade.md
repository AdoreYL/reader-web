# 安装与升级

默认 Compose 只启动 reader，宿主机 `0.0.0.0:6788` 映射到容器 `6788`。安装器支持 `/opt/reader-web` 和 `--install-dir "$PWD"`。

更新脚本在更新前备份数据卷，快进失败或构建失败时不强制 reset 用户修改。
