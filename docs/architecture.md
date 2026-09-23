# 架构与开发说明

## 当前稳定基线
- 后端：Spring Boot 2.1.6、Vert.x 3.8.1、Kotlin 1.5.21、Java 8 编译目标。
- 构建：Gradle 6.9.4 JDK 8 builder；前端 Vue 2 + Vue CLI + Element UI。
- 运行：Docker 多阶段构建，应用容器端口 6788，数据卷 `reader-web-reader-data` 和 `reader-web-reader-logs`。
- 已验证：GitHub Actions 分别验证 linux/amd64 与 linux/arm64 的构建、Compose、启动和 `/health`。ARMv7 未验证。

## 升级路线
Java/Spring/Gradle/Kotlin 升级不与稳定部署混合：先固定测试基线，再逐层升级 JDK/Gradle、Kotlin 插件、Spring Boot 2.x，最后评估 `javax` 到 `jakarta` 迁移和 Spring Boot 3。每一层必须独立构建、启动、健康检查并可回滚。
