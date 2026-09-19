我想使用AI开发一个项目。

我用AdoreYL/reader个项目搭建了一个 阅读 的服务器版，这是我Fork的https://github.com/hectorqin/legado 这个项目的功能是可以使阅读这个安卓项目，可以部署在服务器上面，在网页上面使用，但是这个项目的原版项目已经删库停更了。

阅读的原项目https://github.com/gedoor/legado也已经删库，我想通过https://github.com/LegadoTeam/legado这个社区接手版结合我Fork的AdoreYL/reader项目结合起来重新开发一个自用服务器版，通过浏览器网页使用 阅读。


一、我想要实现目标：
  1.在GitHub新建仓库AdoreYL/reader-web，不影响原仓库。
  2.书源导入、预览、去重、批量管理、校验。
  3.书架筛选、批量管理、分组与换源。
  4.传统 Legado 规则回归测试集。
  5.公网安全、SSRF 防护、限流。
  6.前后端模块化和后续路由化。
  7.再考虑新规则特性与前端框架升级。
  8.独立 Docker 基线 + 数据备份/回滚。
  9.用户体系与数据隔离：
  10.内部映射端口使用6788
  11.原项目使用了很多老旧的模块，对新系统的安装兼容不够。
     例如：Gradle Wrapper 6.1.1，Spring Boot 2.1.6.RELEASE，Spring Framework Boot 2.1，Kotlin Gradle 插件 1.5.21 / Spring 插件 1.3.61。
          Java 编译目标  Java 8，系统 JDK JDK 11。
     我们知道这些模块不是单独的，而是作为项目的一部分，需要在项目中联动使用。我们需要对这些与之相关的模块升级，以确保新系统的兼容性。

二、项目定位与边界
  基于 AdoreYL/reader 的完整服务端源码，创建一个独立的新 GitHub 仓库持续开发：

  不直接修改 AdoreYL/reader；
  新项目保留完整 Git 历史，并将原仓库配置为 upstream 参考源；
  服务形态是 Docker 部署后的 Web 阅读服务；
  主设备为 PC 浏览器 + 手机浏览器；
  以 LegadoTeam/legado 作为传统小说书源规则兼容参考；
  不做 Android / 桌面客户端。

首期规则兼容范围

保证以下传统书源能力稳定：

搜索；
书籍详情；
目录；
正文；
XPath / JSONPath / Jsoup(CSS Selector) / 正则；
内嵌 JavaScript 规则。

三、代码仓库与分支策略
新仓库原则
推荐 AdoreYL/reader-web，简洁且定位明确。

Git 关系
AdoreYL/reader              ← 原始完整源码 Fork，仅保留/参考
        │
        └── AdoreYL/reader-web   ← 新仓库，实际开发主仓库
                 │
                 ├── main        ← 稳定可运行版本
                 ├── develop     ← 日常集成分支
                 └── feature/*   ← 独立功能开发分支

新仓库保留原始提交历史，但不需要维持 GitHub 的 Fork 关联。后续可以：

origin 指向新仓库；
upstream 指向 AdoreYL/reader；
必要时额外配置 legado-upstream 指向 LegadoTeam/legado，仅用于规则代码对照，不直接合并 Android UI 代码。

四、用户体系与数据隔离
账户模型
系统保留管理员和注册用户两类角色：
角色	    能力
管理员	     管理注册开关、用户、全局配置、书源模板、系统状态与审计信息
普通用户	 仅管理自己的书架、书源、阅读进度、本地书籍、分组与阅读设置

注册开关
管理员后台需要提供一个全局开关：
允许新用户注册：开启 / 关闭

推荐扩展为三个模式：

关闭注册：仅管理员可创建用户；
开放注册：任何人可以注册；
邀请码注册：必须提供邀请码才可注册。
默认建议：邀请码注册或关闭注册。公网部署时不要默认开放注册。

用户数据隔离
每个用户的数据必须保存在独立用户目录，不能与其他用户混合：

必须保证：

书源、书架、分组、阅读进度、书签、用户设置均按用户隔离；
后端只能根据已认证用户身份读取对应目录；
管理员查看或管理其他用户资料必须有明确后台入口；
禁止普通请求通过 userNS、用户名等参数越权指定其他用户目录；
用户名需做字符白名单校验，防止路径穿越；
批量操作只能作用于当前登录用户的数据域。


五、Web 管理台改造范围

1. 管理台入口
保持原有阅读页路径可用，新增清晰的管理入口：
首页
├── 我的书架
├── 搜书
├── 书源管理
├── 书架管理
├── 分组管理
├── 用户设置
└── 管理后台（管理员可见）
PC 端使用侧栏或顶部导航；移动端使用底部导航、抽屉菜单和响应式表格/卡片。

2. 书源管理
核心能力
本地文件导入；
远程 URL 导入；
粘贴 JSON 导入；
导入预览；
URL 去重；
冲突策略：覆盖 / 跳过；
导入成功、失败、覆盖、跳过汇总；
名称、URL、备注搜索；
按书源分组、类型、启停、发现状态、异常状态筛选；
批量启用、停用；
批量设置发现开关；
批量移动分组；
批量权重设置；
批量导出、删除；
单源测试、SSE 调试；
批量校验，显示超时、无结果、解析异常、访问受限等结果；
失败书源可一键移入“待处理/隔离”分组。

3. 书架与书籍管理
核心能力
按书名、作者、来源搜索；
按分组、类型、追更状态、缓存状态、阅读状态筛选；
支持网络小说、本地书、音频、漫画的明确标识；
批量加入/移出分组；
批量刷新追更；
批量缓存、清理缓存；
批量导出；
批量删除；
单书详情、换源、封面、阅读进度、缓存状态；
标记来源失效与一键换源；
按最近阅读、最近更新、加入时间、标题、作者排序；
删除时明确区分：
仅移出书架；
移出书架并清理服务端缓存。
4. 分组管理
保留原有位掩码模型，即：

一本书允许同时属于多个分组。

UI 上使用多选分组，不将其伪装成只能放一个目录的文件夹系统。

支持：

新建、编辑、隐藏、排序；
显示组内书籍数量；
删除空分组；
从分组直接跳转到已筛选书架。

六、管理员后台
管理员后台首期建议包含：

用户管理
注册开关；
邀请码配置；
用户列表；
用户启用/禁用；
重置用户密码；
查看用户书架、书源数量、存储用量；
清理长期不活跃账户（默认关闭，需显式启用）；
用户数据导出与删除前确认。
系统与安全配置
管理员密码修改；
允许注册模式；
单用户书籍数和书源数限制；
上传文件大小限制；
批量书源校验并发数与超时；
远程导入 URL 安全策略；
系统运行状态、版本号、日志下载；
数据备份状态。

七、反向代理与公网访问
公网访问采用反向代理，推荐 Caddy 或 Nginx：

Internet
   │ HTTPS
   ▼
Caddy / Nginx
   │ 反向代理
   ▼
Reader Web 服务（仅监听内网 / Docker 网络）

强制安全要求
HTTPS；
管理后台强密码；
生产环境默认关闭公开注册；
禁止管理密码、Token 长期出现在 URL 参数中；
远程书源导入防 SSRF：
拦截 localhost、127.0.0.1、私有 IP、Docker 内网地址；
限制重定向次数；
限制下载大小、响应时间；
限制协议为 HTTP/HTTPS；
登录、注册、导入、批量校验加入限流；
日志中脱敏 Cookie、Token、管理密码和书源敏感请求头；
管理后台建议支持 IP 白名单或额外访问认证。


八、首期新增后端 API
建议保持 /reader3/* 前缀，并保留旧 API 兼容。

九、Legado（开源阅读 3.0 官方仓库 LegadoTeam/legado）在仓库内部确实自带了一套完整的 Web 端（位于 modules/web 目录，基于 Vue 3 + Vite + Element Plus + Pinia），并且其官方 Android App 在本地通过 NanoHTTPD 内嵌了 Web 服务。AdoreYL/reader-web 与 Legado 官方自带的 modules/web 有着深刻的渊源与差异。以下为你拆解两者的关系、演进脉络，以及我们参考与应当吸纳的核心设计：

上游前端的血缘演进：

早期 Legado（2020~2022 年前）只有简单的书架与源编辑页面（即 celetor/web-yuedu3 和嵌入式的简易 Web 页面，Vue 2 + Element UI）。
AdoreYL/reader（即当前项目的上游 Fork 源）就是在那个时期把 Legado 的解析核心移植到 PC/Server 端，并集成了当时这套 Vue 2 前端。
而 Legado 官方随后对内置 Web 端进行了彻底重构：创建了独立的 modules/web 模块，全面升级为 Vue 3 + Vite + TypeScript + Element Plus + Pinia + UnoCSS/Tailwind，并包含了完备的书架、移动端/桌面端自适应阅读器、书源/订阅源调试编辑器、全局配置。

架构定位的根本差异：

维度	          Legado 官方自带 modules/web	                                                                 当前 AdoreYL/reader-web
宿主环境	      运行在 Android 手机上（通过手机内嵌 NanoHTTPD / Netty 启动在 127.0.0.1:1122 或局域网 Wi-Fi）  	   运行在 Linux / Docker / 云服务器 / NAS 上（作为长期守护进程的 Headless Server）
通信与服务框架  	Android Service + NanoHTTPD (轻量嵌入式)	                                                   Eclipse Vert.x 3.8.1 (高性能反应式微服务) + Spring Boot
用户与多租户	   纯单用户（手机持有者本人，无需隔离，仅用于局域网传书、电脑端传源）	                                    多租户隔离架构（多用户注册登录、独立 /storage/data/{userId}/ 目录、管理员权限、WebDAV 隔离）
持久化引擎	     Android Room (SQLite) 数据库	纯服务端物理文件                                                  JSON 存储 + 原子落盘（后续规划演进至 SQLite）
前端技术栈	     Vue 3 + Vite + Element Plus（现代、模块化）                                                  	Vue 2 + Webpack + Element UI（历史遗留代码，维护成本高）

Legado 官方 modules/web 有哪些值得我们深度参考的地方？
官方 modules/web 代表了阅读 3.0 协议和功能在 Web 端的正统、最新标准。我们必须重点参考其以下几个维度的实现：

1. 官方标准化 API 规范（api.md 对齐）
官方 api.md 明确定义了阅读 3.0 的标准接口规范：
/getBookshelf、/saveBook、/deleteBook
/getChapterList、/getBookContent、/saveBookProgress
/getBookSources、/saveBookSource、/deleteBookSources
/cover（封面防盗链代理）
/bookSourceDebug（基于 WebSocket / SSE 的源调试）
官方支持配置访问令牌（Token / Bearer Protection）。我们在上一轮安全加固中将凭据标准化到 Header（Authorization: Bearer / X-Access-Token），正是与官方的接口防护演进方向完全一致。
2. 阅读排版与翻页体验的演进（Reader 体验）
章节预加载与图片防盗链代理：官方 Web 端在渲染章节中的正文配图时，对加载失败的图片、防盗链 Referer 以及 Base64 Data URL 做了专门的回退处理（如官方 commit: fix(web/ChapterContent.vue): replace img src when origin src load error）。
字体与样式自定义：官方已支持独立设置正文字体、行高、首行缩进、章节标题字体大小以及双页翻页模式。
正文净化规则（ReplaceRules）在前端与服务端的双重生效：官方 Web 端在拿到正文后能无缝应用用户配置的正文替换净化。
3. 书源编辑与在线调试器（Source Debugger）
官方 modules/web 内部实现了一个极度强大的“可视化书源编辑器”，集成了：
JSON 规则实时高亮与格式化；
规则各字段（bookName、author、catalog、content）一键语法测试；
实时抓取日志与元素提取树显示；
这比当前 reader-web 简易的表格调试要先进得多。
三、 我们下一步的演进路线规划（Roadmap）
结合官方自带 Web 端的现状，我们可以将 reader-web 的架构路线演化得更加纯粹清晰：

协议与 API 层 100% 兼容官方：
保持服务端的接口契约（Endpoint、入参、出参）完全遵循 Legado 官方 api.md 标准，使得任何第三方客户端或官方配套 Web 前端可以直接接入。
多用户与服务端能力保持自主增强：
保持我们独有的多租户隔离、三档注册管理模式、两阶段 WebDAV 备份容灾、SSRF 与路径沙箱防护，这是官方纯手机端 NanoHTTPD 所不具备的企业级/服务端特质。
前端现代化（重大升级目标）​：
将当前的 Vue 2 老旧前端彻底迁移或对齐到官方 modules/web（Vue 3 + Vite + Element Plus）​。
这样既能继承官方最新维护的精美排版与源调试器，又能无缝享受 Vite 带来的毫秒级打包与更小体积，彻底摆脱 Vue 2 即将停更的生态包袱。



