# 更新日志 · Easy Swift

> 这里只记**已经做完**的事，按版本倒序。待办与需要拍板的事项见 [TODO.md](TODO.md)。
> 版本号唯一真相源是 `MARKETING_VERSION` / `CURRENT_PROJECT_VERSION`。

---

## 0.5.1 (10) · 2026-10-29

**首页标题进导航栏**

- `.navigationBarTitleDisplayMode(.inline)`：标题与右上角设置按钮同一行，不再用大标题占一整块；
  列表因此上移、多显示一行。仅 iOS 分支改动，macOS 走 `NavigationSplitView` 未动。

**文档拆分**

- 已完成的事按版本记进本文件，`TODO.md` 只留待办（370 → 159 行，53 条 `[x]` 全部迁走），
  随后又按「能不能动手」重排为 P0/P1/P2（159 → 126 行，19 条）；`AGENTS.md` 补一条文档分工约定

**小红书阶段文案真机确认**

- 连续截屏抓到两帧：「正在展开短链…」`xhslink.cn/o/9rha5mjvITI` → 「正在请求页面…」→ 结果「V社更新审核…」3 张图。
  第三段「正在校验原图…」只持续 0.3–0.6 秒，每秒一帧的设备截屏抓不到（同一处 `parseStageView` 渲染，前两段已证链路正常）

**链接解析：分享链接 → 分享者主页**

- 解析抖音/小红书分享链接时，额外解出**分享者**（转发这条链接的人，不是内容作者）并给主页入口
- 抖音：短链展开后的长链里解 `u_code`（base-23 → uid）/`share_user_id`/`sec_uid`/`activity_info`，
  再查一次 `live.douyin.com/webcast/user` 换昵称与 sec_uid → `douyin.com/user/{sec_uid}`；接口失败只少昵称
- 小红书：`shareRedId` → 32 位 Base64URL → 24 字节逐字节减偏移 → 24 位十六进制 uid →
  `xiaohongshu.com/user/profile/{uid}`，**纯离线**
- 结果区新增分享者卡片（昵称/ID + 平台），点「主页」用内置浏览器打开（新增 `WebBrowserView`）
- 链接里没有分享参数时不显示该卡片，不报错

验证：harness 20 条断言（小红书真 token `5e4bfdba…`、抖音 base23 三组往返、坏输入拒绝、activity_info 提取）；
三档构建通过（iOS 模拟器 / macOS）。

**已知不验证**

- 「解析撞登录墙 → 登录态降级为 expired」无法构造样本：只有私密/仅关注可见的笔记会撞墙，
  而这类笔记在 App 里复制不出分享链接。代码路径保留，等真实遇到再观察（TODO 附A 有记录）

## 0.5.0 (9) · 2026-10-29

**收件箱：从「点条目自动跳功能」改成「先问你要怎么处理」**

- 点一条 → 底部面板：顶部说明这是什么（「这是小红书链接，可以解析」/「这是普通网页链接，暂不支持解析」/
  「这是一段文本（N 字）」）+ 原文预览（长文本内部滚动，最多 180pt）+ 操作按钮；删除在右上角工具栏
- 操作集：链接给「复制 / [解析] / 二维码」，文本给「复制 / 二维码 / 搜索」；
  **「解析」只在解析器支持该域名时出现**；执行后自动标为已处理
- 链接解析新增查询接口：`LinkParserCapability` + `LinkParserRegistry.capability(for:)`（纯 host 判定、不发请求），
  收件箱不写死域名 —— 以后加 bilibili 只改注册表
- 「复制到剪贴板」= **应用内剪贴板**：新增 `ClipboardStore`（全 App 唯一写入入口 + 共享容器）；
  剪贴板页原来自己 `.modelContainer(for:)`，两处各建容器会争同一个 `default.store`，现改为共用
- `InboxClassifier` 拆两层：共享层只判类型（分享扩展也编译它），`InboxActions.swift`（App 专属）才决定操作集
- `LinkParserView` 新增 `autoParse`：选「解析链接」进去就直接开跑

验证：断言 23 条（操作集/头部文案/取材/边界）+ 剪贴板写入 8 条（判重/裁剪/新上下文读回）；
三档构建绿；模拟器写入 4 条测试数据（含旧版 `kind=keyword`、1 条已处理）→ 首页角标显示 3。

## 0.4.1 (8) · 2026-10-29

**撤掉小红书作者主页解析**（该功能从未提交，整体回退）

- 需求本是「粘贴作者主页链接 → 列笔记 → 选一条解析」，试了两轮跑不通：
  - SSR 的 `profile.noteData[].id` 与 SPA 会话里的笔记 id **不是同一套**（`d9e4bc26…` vs `6a8be922…`）
  - 主页 SSR 与渲染后的 DOM 卡片链接**都不带 `xsecToken`**；从 `__INITIAL_STATE__` 扫到的 token 属于推荐流
  - 无 token 的笔记页一律 `/website-login/error?error_code=300011`，WKWebView 打开也一样（`title: 安全限制`）
- 保留的改进：命中 `300011` 时不再错报「登录已过期」，改为「分享链接不完整（缺少访问参数），请重新复制分享链接」
  （10 条断言覆盖：300011 三种形态、300031/正常页不误判、真登录页仍走「登录过期」分支）
- 分享扩展嵌入加 `platformFilter = ios`：否则 macOS 构建直接失败
  （「This target is built for macOS but contains embedded content built for iOS」）

验证：三档构建绿、版本回读一致；真实解析回归 —— 小红书图文笔记 7 图（3 张动图）、标题正确。

## 0.4.0 (7) · 2026-10-28

**分享扩展**：系统分享面板里出现「Easy Swift」，其他 App 分享的文本/链接直接进收件箱

- 新增 target `ShareExtension`：进入即取文本/链接 → 写 App Group 的 `inbox.json` → 显示「已收进收件箱（类型）」→ 1.5 秒自动关
- 激活规则只收 text / webURL / webPage，不抢图片视频；取内容优先 URL 其次正文
- 与主 App 共用 `InboxShared`（文件格式 + App Group 写探针）与 `InboxClassifier`（分类规则），判定只允许一份
- 扩展 entitlements 带 `com.apple.security.application-groups`；分享面板显示名从 `ShareExtension` 改成 **Easy Swift**
- 主 App 现在能接受不带 `text` 的 `easyswift://inbox`（只把 App 拉到前台）

已知限制：分享扩展**无法**主动打开主 App（`extensionContext.open` 回调 false；responder 链 `openURL:` 被系统忽略），
所以面板只留「完成」，不放点了没反应的按钮。

签名坑：扩展是新 App ID，`xcodebuild -allowProvisioningUpdates` 拿不到 GUI 账号（`No Accounts`）——
必须先在 Xcode GUI 构建一次生成 profile，之后命令行就能复用。

验证：真机分享一次 → `[收件箱] 读取 2 条` → `读取 3 条`（App Group 写读打通）。

## 0.3.0 (6) · 2026-10-28

**收件箱（B 段）**：其他 App 的文本/链接有了统一落点，并打通 App Group

- `InboxClassifier`：纯逻辑分类（小红书/抖音/普通链接/短文本/长文本）+ 附件 `LinkExtractor` 从分享文案里抠链接
- `InboxStore` + `InboxShared`：JSON 存储（不用 SwiftData —— 分享扩展要能写同一个文件）；10 秒内同一条去重、
  上限 200 条、原子写、坏文件改名留证
- `InboxView`：列表 + 未处理角标 + 左右滑（删除/标记）+ 「从剪贴板收件」+ 全标/清空
- URL scheme：`easyswift://inbox?text=<percent-encoded>`，`CFBundleURLTypes` 写在 `Easy-Swift-Info.plist`
  （这个键没有对应的 `INFOPLIST_KEY_*` 构建设置）
- App Groups：entitlements 加 `group.me.zzhhoo.easyswift`

踩坑：**没有 App Group entitlement 时 `containerURL(...)` 仍然返回路径**，写入报「没有权限保存到文件夹」——
表现是内存有、磁盘无、重启就丢。现用「写探针」判定，写不进去自动退回 AppSupport 并打日志。

验证：harness 41 条断言；macOS 端到端 `open "easyswift://inbox?text=…"` → 杀进程重开仍能读回；
模拟器与真机日志均显示 `存储位置=AppGroup`。

## 0.2.3 (5) · 2026-10-27

- 手动填写 Cookie 页可预填现有 Cookie 并一键复制
- 修 sheet 缺导航容器：`XhsCookieEditView`、`XhsLoginView` 各自套 `NavigationStack`，
  标题与「复制」按钮才显示（原先被顶到状态栏下面、按钮看不见）

## 0.2.2 · 2026-10-27

**小红书扫码登录（原生二维码）—— 走「隐藏 WebView 抠图」路线**

- 为什么不调登录接口：`create` / `qr/userinfo` / `qr/status` 全要 `x-s` / `x-s-common` / `x-t`，
  算法在第三方 Python 库（xhshow）里，Swift 复刻成本高；无签名请求实测 `HTTP 406 {"code":-1}`
- 实现：`XhsQRLoginService`（269 行）+ `XhsQRLoginView`（165 行）。隐藏 WKWebView（`.nonPersistent()` +
  桌面 UA + 0.01 透明度）打开 `/login`，页面自己的 JS 调签名接口并渲染二维码；我们只做三件事：
  从 `img.qrcode-img` 的 `src` 抠 `data:image/png;base64,…`、轮询状态、轮询 cookie
- 登录判据：cookie 出现 `web_session` **且前缀 04**（03 是游客态）→ 再做一次行为探测才落库；超时 180 秒
- 平台入口：macOS 以扫码为主；iOS 主入口仍是网页登录，扫码放「用另一台设备扫」
- 踩坑：`loadCookies()` 一开始读 `WKWebsiteDataStore.default()`，而隐藏 WebView 用的是 `.nonPersistent()`
  —— 两者不是同一个存储，页面登录成功了这里也永远是空的；改为读 `webView.configuration.websiteDataStore`
- 真机闭环（2026-10-27）：40 秒内完成，日志 `出现 web_session，前缀=04` → 行为探测 `status=200 … 登录墙=false`
  → `keychain.update` 成功；顺带验了「退出登录 → 重新扫码」19 秒循环

## 0.2.0 (2) · 2026-10-24

**崩溃记录抽成 CrashKit 远端依赖**

- 先在仓库内做独立模块（16 个测试全绿），再挪到 `../CrashKit` 独立仓库，最后推到
  https://github.com/zhihaofans/CrashKit（tag `0.1.0`），工程用 `XCRemoteSwiftPackageReference`
- 能力：ObjC 异常 + `SIGABRT/SIGSEGV/SIGBUS/SIGILL/SIGFPE/SIGTRAP`；只做 async-signal-safe 的 `write`
- 端到端：模拟器 `kill -ABRT` → `pending-signal.bin` 16 字节（`CK01` + 信号 + 时间戳）→ 重启弹「上次闪退」→ 读完 `ftruncate` 清空
- 从这次起，每批改动都动 `MARKETING_VERSION` / `CURRENT_PROJECT_VERSION`

## 0.1.x 及更早 · 2026-10-22 ~ 10-24

### 链接解析重写（抖音 + 小红书）

- `VideoHTTP`：UA 分档 / finalURL / HEAD 探测 / 短链展开 / Cookie 注入；`LinkParseResult` 加 `notice`、`motions`；
  `LinkParseError` 扩到 7 类且各有用户文案
- 小红书纯 HTTP：登录墙与风控只看 `finalURL`；`__INITIAL_STATE__` 先清洗 `undefined`；去水印 `fileId` + 并发 HEAD
  （只认 404/410）；视频流 `h265→h264→av1→h266`
- 抖音：1×1 隐藏 WebView + document-start 注入 + XHR/fetch 钩子 + `RENDER_DATA → 钩子 → DOM` 三级取数；
  HTTP 与 WebView 按作品类型**分流竞速**
- UI：按错误类型给不同出路、展示 `notice`、动图角标与播放；输入框回车解析、滑动收起键盘
- 真机验证（2026-10-22，iPhone 15 Pro）：抖音视频 1 条 mp4（HEAD 206）；抖音图文 7 图 + 7 动图；
  被限流的两条改竞速后 1 秒出结果（原先 40 秒转圈）；小红书图文/视频各一条带登录态解析成功
- 过程中修掉：验证码误判（隐藏 iframe）、`RENDER_DATA` 存在≠有数据、XHR 钩子 URL 白名单漏接口、
  图文配乐被当成视频、假 cookie 被探测请求的 500 骗过、`NSApp` 隐式解包在非 GUI 进程直接 trap

### 抖音动图链路（2026-10-23 真机逐张核对）

- 动图能播但「点开是 jpeg」：改为 **Content-Type → 文件头魔数 → URL 扩展名** 三层判定
- 隐藏 WebView 被限流：`.nonPersistent()` 每次新会话 + 超时后 5 分钟走 HTTP 的失败冷却
- 超时日志打印 `hook/render/work/captcha/login` 快照；配乐（`ies-music` mp3）按 URL 特征过滤
- 核对结果：18 图作品解析出 9 个动图（`[1,3,5,7,13,14,15,16,17]`），逐个下载均为 `video/mp4`、1.6–2.8 秒

### 动图导出为 Live Photo 存相册（0.2.0 前，`2127ca6`）

- `PhotoLibrarySaver`：静态图写 `MakerApple[17]`、视频导 `.mov` 写 `quicktime.content.identifier`，两侧同一 UUID
  → `PHAssetCreationRequest` 的 `.photo` + `.pairedVideo`
- 写完**回读两侧标识再比对**，不一致就抛错（避免静默存成「一张照片 + 一段孤儿视频」）
- 真机验证（2026-10-24）：`v.douyin.com/JK1uPOwMU5w` 7 图 7 动图 → 保存后 **7/7 全部为实况照片**，
  7 个不同配对标识，整批 6 秒；相册里长按确认会动

### 解析状态提示（2026-10-23）

- `LinkParseStage` + `LinkParseProgress`：解析器在**真实发生**的节点上报，界面显示阶段 + 「已等 N 秒」
- 约定：文案只能描述还活着的那条线（两条竞速，死掉的那条不能出现在提示里）
- 踩坑：`TimelineView(.periodic(from:))` 的秒数永远落后（视图晚建、schedule 从解析开始时刻起发），
  改成 `.task(id:)` 里每秒 `Date().timeIntervalSince(start)` 重算

### macOS 钥匙串弹窗（SwiftUtils 0.0.27）

- 现象：频繁弹「想要使用您储存在钥匙串中的机密信息」，点不允许后登录态「莫名丢失」
- 证据：安全日志里两次 `SecItemCopyMatching` 后各跟一条 `CSSMERR_CSP_USER_CANCELED` —— 是**读**的时候弹
- 根因：老文件钥匙串每条记录绑 ACL（记的是「哪个签名的 App 能读」），重签后读取就要授权
- 修复（库侧）：四个查询统一 `kSecUseDataProtectionKeychain` + 同一 `kSecAttrService`；老记录静默试读、
  能读就迁移；宿主缺 entitlement（-34018）时回退旧钥匙串并打 error
- 工程侧：entitlements 加 `keychain-access-groups = $(AppIdentifierPrefix)me.zzhhoo.easyswift`

### 其它

- 部署目标 iOS 26 / macOS 26 → **27**，删掉不再需要的 `#available` 兜底
- SwiftUtils `0.0.22 → 0.0.26`（`HttpUtil` 迁到纯 Foundation，不再依赖 Alamofire）→ `0.0.27`（钥匙串）→
  `0.0.28`（`PermissionUtil`，相册权限判断收敛）
- `debugPrint` 每行 `fflush(stdout)`：真机 stdout 按块缓冲，日志会攒到 4KB 才吐
- 闪退捕获与记录（后抽成 CrashKit）：`loadUnaligned` 修未对齐 trap；读完 `ftruncate` 不 `unlink`；启动不开 `O_TRUNC`
- 二维码生成移出 `body`（`.task(id:)` + 150ms 防抖）；二维码内容统一为原文（不再 `urlDecode`）
- 剪贴板去掉 `clipList` / `ClipItemView.path` 死状态，`clipContentList` 改由 `@Query` 派生
- GitHub Token 从 UserDefaults 迁钥匙串（含旧明文迁移、写失败提示）；起始日期改 UTC；
  搜索关键词改用 `EncodeUtil().urlEncode`
- 修 `project.pbxproj` 里 `INFOPLIST_KEY_UISupportedInterfaceOrientations_iPad` 的笔误
- 新增 `AGENTS.md`（开发约束）与 `TODO.md`（待办清单）、`README.md`
