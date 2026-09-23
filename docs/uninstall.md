# 卸载

默认卸载停止 reader-web 容器并移除 Compose 网络，保留项目、`.env`、backups 和 Docker 数据卷。`--purge` 需要完整输入 `DELETE READER-WEB DATA`，只删除本项目固定数据卷和经过 Git 工作树校验的项目目录。
