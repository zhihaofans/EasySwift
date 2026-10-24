# TODO · Easy Swift

> 本文件是**待办清单**，不是设计文档。硬约束与验证方式见 [AGENTS.md](AGENTS.md)，架构见源码。
>
> 用法：做完就把 `[ ]` 改 `[x]`；新增条目要写清「改哪里 + 怎么算做完」。**不要**在这里记录本机绝对路径、账号、Token。

最后更新：2026-10-23

---

## 一、收尾（链接解析重写已完成，剩三件小事）

- [x] **删掉 `HTMLFetcher` 兼容层**（2026-10-23）：连同 `OGMetaExtractor` 一起删除，全项目零引用，`LinkParser.swift` 196 → 143 行
- [x] **抖音图文动图真机复测**（2026-10-23 通过）：日志 `HTTP 先拿到 7 张图（无动图），继续等 WebView 补动图` → `解析成功(hook) 图=7 动图=7 视频=0`
      —— 期间发现的真因：隐藏 WebView 用了持久化存储，同一个匿名 `ttwid` 被平台标记后连续 `hook/render/work 全 0`；改成每次 `.nonPersistent()` 新会话 + 失败冷却 5 分钟后恢复
- [x] **小红书登录过期路径**（2026-10-23）：新增三态 `unknown / valid / expired` + 解析撞墙时自动降级；新增「手动填写 Cookie」入口（保存前强制探测）
      - 过程中修掉两个判据问题：`/explore` 游客态也返回 200（不能当登录判据，改用 `/notification`）；5xx 不能判过期（平台限流时会误杀登录态）
- [x] **在真机上确认三态文案**：设置页在真实登录态下应显示「已登录」；把钥匙串里的 cookie 改坏后解析，应显示「登录已过期」而不是「需要登录」
      - 2026-10-24 真机（iPhone 15 Pro / iOS 27.2）：**未登录态已确认**——`keychain.get: 未找到记录, id: xhs_web_session_cookies`，设置页显示「未登录」，没有 -34018、没有回退旧钥匙串（说明 0.0.27 的数据保护钥匙串在真机上生效）
      - 「已登录」态已确认（2026-10-24）：网页登录后 `登录态探测: status=200 final=…/notification 登录墙=false` → 钥匙串写入成功 → 设置页「已登录」
      - 「已过期」态已确认（2026-10-24）：用「只在本进程返回假 cookie」的临时开关（不写钥匙串，重启即恢复）→ 探测得到 `status=200 final=https://www.xiaohongshu.com/login?redirectPath=… 登录墙=true` → 状态置 expired → 设置页「登录已过期」
        - 这个样本顺带证明了**不能按状态码判**：HTTP 200，但最终地址是 `/login`
      - **仍未验**：解析撞到登录墙 → `noteLoginWall()` 把 valid 降级成 expired 这条路径。公开笔记不登录也能解析，手上没有需要登录的笔记链接，只能等真实遇到私密/风控笔记时再看

---

## 二、适配：后续新功能统一要求（iPhone Duo）

> 从这条开始，**新增页面 / 改布局默认要过 iPhone Duo**，不再只测常规 iPhone。

- [ ] 建立机型基线：常规 iPhone（SE / 标准 / Pro Max）+ **iPhone Duo**（机型 `iPhone19,4`，最低运行时 iOS 27.1；模拟器设备类型已存在）
- [ ] 布局不用固定宽度/写死高度：容器走 `maxWidth: .infinity`、网格走 `LazyVGrid(columns: [GridItem(.adaptive(minimum:))])`，预览尺寸按可用宽度算
- [ ] 折叠/展开：可用尺寸变化时重排（`GeometryReader` + `.onChange(of:)`，或 `horizontalSizeClass`），不缓存首帧尺寸
- [ ] 状态不随屏幕形态切换丢失：`@State` / SwiftData 都不该因为窗口变化被重建
- [ ] 安全区不要写死 padding，走 `safeAreaInset` / `ignoresSafeArea` 的显式组合
- [ ] 横竖屏 + 分屏下：列表、网格、工具栏不裁切，按钮不被遮挡
- [ ] 每次改动至少跑一次 Duo 模拟器并截图留证

**模拟器状态（2026-10-23 已修复）**：

- `iPhone Duo`（UDID `134E3268-…`）现在可以正常启动，`Data Migration Failed` 是首次迁移失败、重试后自愈；App 已装上并能运行
- 设备规格：`iOS 27.2 (iPhone19,4)`，主屏 **1398×2034 px**（竖屏，比常规 iPhone 更方）
- **截图必须带 `--display=1`**：这是多屏设备，`xcrun simctl io <udid> screenshot` 不带参数会报 `Invalid argument`

**适配现状（已发现的问题）**：App 在 Duo 上是**以手机宽度的窗口运行**，内容挤在左侧、右侧大片留白，工具栏也被压在中间 —— 说明还没声明支持这个尺寸。下一步要确认是 Info.plist / Scene 声明的问题，还是需要 `UIRequiresFullScreen` / 可缩放 scene 的配置。

---

## 三、待办（体检遗留）

- [x] **iPad 方向配置笔误**（2026-10-23 修）：`project.pbxproj` 的 `INFOPLIST_KEY_UISupportedInterfaceOrientations_iPad` 末尾多了 `Easy Swift`（两处配置都有），已删；合法值只剩四个 `UIInterfaceOrientation*`
- [x] **二维码内容与「复制文字」不一致**（2026-10-23 修）：[QrcodeView.swift](<Easy Swift/Views/QrcodeView.swift>) 取消生成前的 `EncodeUtil().urlDecode`，统一为**原文**——输入框、二维码、复制三处同一个字符串
      —— 原来那样还有一个更隐蔽的后果：扫进来的链接本身带 `%XX`，再生成会被二次解码，扫回去已经不是同一个码
      - 真机验证（2026-10-24）：输入 `https://example.com/a%20b?q=%E4%B8%AD` → 设备截屏后用 Vision 解二维码，得到**原样**字符串（`%20`、`%E4%B8%AD` 都没被解掉）；另用纯数字 `280920138209502000` 验过「二维码 = 输入框文本 = 复制文字」三者一致
- [ ] **隐私清单** `PrivacyInfo.xcprivacy`：用了 UserDefaults（CA92.1）等 Required Reason API，上架前必须补（当前不打算上架，优先级最低）
- [ ] **测试 target**：目前只能靠仓库外 `swiftc` harness 验；若要长期维护，考虑加 unit test target，先覆盖链接解析纯函数、日期换算、参数编码
- [ ] **删除文件需要动 pbxproj**：[ContentView.swift](<Easy Swift/ContentView.swift>) 只是 `MainView()` 的跳板，合并掉可少一层；但删文件要改工程文件，单独做
- [x] **闪退捕获与记录**（2026-10-23 完成）
      - 实现：`CrashRecorder` —— `NSSetUncaughtExceptionHandler` 记 ObjC 异常；信号处理器覆盖 `SIGABRT/SIGSEGV/SIGBUS/SIGILL/SIGFPE/SIGTRAP`，只做 `write` 到启动时打开的 fd（async-signal-safe）
      - 展示：启动时读一次 → 弹「上次闪退（SIGABRT…）」→ 读完**清空文件**（不是删除），保证只提示一次
      - 模拟器实测：对进程 `kill -ABRT` → 文件写入 16 字节（信号 6 + 时间戳）→ 重启弹窗正确 → 再启动不弹
      - 踩坑记录：
        - `load(fromByteOffset:)` 读偏移 4 的 Int64 会因**未对齐**直接 trap（`load from misaligned raw pointer`）→ 改 `loadUnaligned`
        - 读完必须 `ftruncate` 而不是 `unlink`：文件被删后 fd 指向不可见的 inode，下一次崩溃会写丢
        - 启动时打开 fd 不能用 `O_TRUNC`，否则每次启动都把上次的记录清掉
      - 未覆盖：`MetricKit`（系统级崩溃诊断，次日回调）；ObjC 异常路径没有真实样本验证过

- [ ] **解析历史记录**（新需求）
      - 目标：解析过的链接留痕，能回看、能重新打开结果
      - 存储：SwiftData 模型（链接、平台、标题、封面 URL、图片/视频/动图数量、解析时间），列表同样只读 `@Query`，不另存一份数组
      - 去重：同一条链接只保留最新一条（短链展开后按最终 URL 去重，先 insert 再合并）
      - 交互：解析页顶部入口或独立页面；点进去重新解析（历史里的直链会过期，不能直接当结果用）
      - 清理：单条删除 + 清空 + 上限裁剪（例如最近 200 条）
      - 验收：写入 → 杀进程 → 重开后仍在；列表顺序按时间倒序；重复解析同一链接不产生两条

- [x] **动图导出为 Live Photo 存相册**（2026-10-23 实现并提交 `2127ca6`）
      - 实现：[PhotoLibrarySaver.swift](<Easy Swift/Services/PhotoLibrarySaver.swift>) —— 静态图写 `MakerApple[17]`、视频走 `AVAssetExportSession` 导 `.mov` 写 `com.apple.quicktime.content.identifier`，两侧同一个 UUID → `PHAssetCreationRequest` 的 `.photo` + `.pairedVideo`
      - 权限：`NSPhotoLibraryAddUsageDescription`（保存）+ `NSPhotoLibraryUsageDescription`（回读校验）已进工程，两者缺一个都会在保存/校验时被 TCC 直接 trap（`SIGABRT`）
      - 回读：`verifyLatestIsLivePhoto()` 比对 `mediaSubtypes.contains(.photoLive)`；**没有读权限时返回 `nil`**（我们只申请 `.addOnly`），此时不再说"无法确认"，而是靠 `LivePhotoPair` 的配对回读给结论："已保存为实况照片（配对标识已校验；去相册长按确认）"
      - 交互：逐张「保存到相册」+ 「全部保存」确认弹窗（预告"N 张图片（其中 M 张动图会存成实况照片）"）；权限类错误整批停下并给设置路径，`.restricted` 单独文案（去设置也改不了，不能骗用户）
      - **真机验证（2026-10-24，iPhone 15 Pro / iOS 27.2）**：`v.douyin.com/JK1uPOwMU5w` 解析出 7 图 7 动图，保存后 **7/7 全部为实况照片**，每张都有独立的 `实况照片配对标识一致: <UUID>`（7 个不同 UUID），整批耗时 6 秒（00:02:12→00:02:18）
      - 配对这一步另用仓库外 harness 单独证过：`MediaDownloader` + `LivePhotoPair.make` 产出的 JPEG `MakerApple[17]` 与 MOV `quicktime.content.identifier` 完全一致
      - **人眼确认（2026-10-24 通过）**：相册里长按保存下来的图**会动** —— 实况照片这条链路从解析、配对、写入到相册归类，全链路真机验证完毕
      - 过程中补的防线：`LivePhotoPair.make` 写完**回读两侧标识再比对**，不一致就抛错（否则会静默存成"一张照片 + 一段孤儿视频"）；界面文案从"无法确认"改成"配对标识已校验"

- [x] **链接解析页的状态提示可再细**（2026-10-23 完成）
      - 做法：解析层新增 `LinkParseStage` + `LinkParseProgress`（[LinkParser.swift](<Easy Swift/Services/LinkParser/LinkParser.swift>)），解析器在**真实发生**的节点上报；界面显示阶段文案 + 「已等 N 秒」
      - 阶段：展开短链 → 请求页面 / 请求页面+启用浏览器内核 → （HTTP 线死了）浏览器已打开，等待页面数据 → （HTTP 拿到图、浏览器还活着）已拿到 N 张图，正在补动图 → 校验原图
      - 关键约定：**文案只能描述还活着的那条线**。两条路线竞速，各自存活状态单独记，死掉的那条不能再出现在提示里（否则会出现"浏览器已关闭，却在说补动图"）
      - 实测（iPhone 18 Pro 模拟器 + 真链接 `v.douyin.com/JK1uPOwMU5w`，截图留证）：
        - 「浏览器已打开，等待页面数据…」→ 之后 6.17s 完成，7 图 7 动图
        - 「已拿到 7 张图，正在补动图… 2 秒」→ 隔 1.46s 再拍变「3 秒」「4 秒」，秒数按真实时间走
        - CLI/GUI 双 harness：跨线程上报 → 主线程状态 3/3 全部落地；GUI harness 走通了隐藏 WebView 全程（输出与 App 内一致）
      - 踩坑：**`TimelineView(.periodic(from:by:))` 的秒数会永远落后**。schedule 从 `from`（解析开始时刻）起发条目，而视图是几秒后才建的，实测显示「3 秒」时实际已等 7 秒 —— 换成 `.task(id: parseStartedAt)` 里每秒 `Date().timeIntervalSince(start)` 重算
      - **未验证**：小红书只用了一条无 `xsec_token` 的笔记 URL（CLI 里读钥匙串取 cookie 会卡住，未跑完），小红书的两条阶段文案仍待在真机上确认

### 外部库（SwiftUtils 仓库）待办 —— 下次动库时记得先看这里

- [ ] **`PermissionUtil.requiredInfoPlistKeys(for: .photoLibraryAddOnly)` 要求过严**（2026-10-24 记录）
      - 现状：它返回 `["NSPhotoLibraryAddUsageDescription", "NSPhotoLibraryUsageDescription"]`，两个键缺一个就 `request` 直接返回 `.unavailable`（不弹框、不崩溃）
      - 问题：按 `.addOnly` 的语义只需要 `NSPhotoLibraryAddUsageDescription`。只做"保存到相册"、不读相册的宿主工程会莫名其妙被判成「系统相册不可用」
      - 改法：`.photoLibraryAddOnly` 只要求 Add 那个键；`.photoLibraryReadWrite` 才要 `NSPhotoLibraryUsageDescription`
      - 本工程暂时不受影响（两个键都在，因为回读 `verifyLatestIsLivePhoto()` 需要读权限），但**一旦有人删掉读权限的键，保存就会整体失败** —— 改库时要连带检查这一条
      - 顺带确认：`PermissionUtil` 的 `request` 回调是否仍固定在主队列（App 侧现在是 `Task { @MainActor in … }` 兜住，但库的契约最好写清并在测试里钉住）

### CrashKit 抽库（计划 B → A）

- [x] **B：仓库内独立模块**（2026-10-24 完成）
      - [Packages/CrashKit](Packages/CrashKit)：`CrashKit` 模块 + 16 个测试（全绿），README 里写了接入方式、能力边界、四条硬约束
      - Easy Swift 侧：删掉 `Services/CrashRecorder.swift`，`project.pbxproj` 加 `XCLocalSwiftPackageReference`；`Easy_SwiftApp` 用 `CrashRecorder.shared.install(options:)`，`ContentView` 只多一行 `import CrashKit`
      - 端到端验证：模拟器里 `kill -ABRT` → 容器 `pending-signal.bin` 16 字节（`CK01` + 信号 6 + 时间戳）→ 重启弹「上次闪退（SIGABRT）」→ 文件被清空（保留文件、fd 不断）
      - 版本号规则：从这次开始 Easy Swift 每批改动都动 `MARKETING_VERSION` / `CURRENT_PROJECT_VERSION`（本次定位 **0.2.0 (2)**）
- [x] **包挪出工程**（2026-10-24）：已移到 `../CrashKit`（与 Easy Swift 同级，独立 git 仓库，
      commit `067310e` + tag `0.1.0`），工程用 `XCLocalSwiftPackageReference` 的 `relativePath = ../CrashKit` 引用；
      工作区里的 `Packages/` 已删除，`Package.resolved` 里记的是 `CrashKit: … @ local`
      - 注意：改这个包等于改另一个仓库，需要工作区外的读写权限
- [x] **A：推成独立仓库**（2026-10-24 完成）：已推到 https://github.com/zhihaofans/CrashKit（tag `0.1.0`，
      commit `067310e`）；工程切到 `XCRemoteSwiftPackageReference` + `exactVersion 0.1.0`，
      `Package.resolved` 里是 `crashkit 0.1.0 / 067310e0610b`；三档构建全绿，模拟器里仍打印
      `[CrashKit] 已安装，目录=CrashKit，信号=[6, 11, 10, 4, 8, 5]，fd=4`
      - 改库流程（AGENTS §2 也写了）：本地副本 `../CrashKit` 改 → `swift test` → 提交 → 打 tag → 推 →
        回来抬 `exactVersion` + `-resolvePackageDependencies`

## 四、需要决策（先别动）

- [x] 部署目标从 iOS 26 / macOS 26 提到 **27**（2026-10-24 定）：本机没有 27 以下的设备，不必为兼容留 `#available` 分支，已顺手删掉 `LivePhotoPair` 里那段 iOS 18 / macOS 15 的兜底
      - 实测：Duo 跑 27.2，26.0 目标的 App 本来就能装能跑 —— **版本不是 Duo 的问题**；提到 27 之后重装，窗口模式依旧（只占约 81% 宽，右侧竖条是系统状态栏），说明要改的是尺寸/声明，不是版本号
      - 附带确认：Duo 用的运行时是独立的 `SimRuntime.iOS-27-2-iPhone19-4`（24B91014），与普通 27.2（24B114）不是同一个
- [ ] 抖音「视频走 HTTP（1 秒）/ 图文等 WebView（5–18 秒）」这个不对称要不要给用户解释，或做成"图文优先用 HTTP 的静态图、动图后台补"的两段式
- [ ] 链接解析是否抽成独立 target / 本地 SPM 包，方便脱离 App 测

---

## 五、已完成（近期，供回溯）

### 链接解析重写（抖音 + 小红书）

- [x] **解析层骨架**：新增 [VideoHTTP.swift](<Easy Swift/Services/LinkParser/VideoHTTP.swift>)（UA 分档 / finalURL / HEAD 探测 / 短链展开 / Cookie 注入）；`LinkParseResult` 加 `notice`、`motions`；`LinkParseError` 扩到 7 类且各自有用户文案
- [x] **小红书纯 HTTP 重写**：[XiaohongshuParser.swift](<Easy Swift/Services/LinkParser/XiaohongshuParser.swift>) —— 登录墙/风控只看 `finalURL`；`__INITIAL_STATE__` 先清洗 `undefined`；去水印 `fileId` + 并发 HEAD（只认 404/410）；视频流按 `h265→h264→av1→h266` 取 `masterUrl`
- [x] **抖音**：新增 [DouyinWebExtractor.swift](<Easy Swift/Services/LinkParser/DouyinWebExtractor.swift>)（1×1 隐藏 WebView + document-start 注入 + XHR/fetch 钩子 + `RENDER_DATA→钩子→DOM` 三级取数）；[DouyinParser.swift](<Easy Swift/Services/LinkParser/DouyinParser.swift>) 改为 **HTTP 与 WebView 按作品类型分流竞速**
- [x] **UI 接线**：[LinkParserView.swift](<Easy Swift/Views/LinkParserView.swift>) 按错误类型给不同出路、展示 `notice`、动图角标与播放；[WebParserView.swift](<Easy Swift/Views/WebParserView.swift>) 新增 `WebParserMode` 复用同一套脚本
- [x] **小红书登录**：新增 [XiaohongshuSession.swift](<Easy Swift/Services/LinkParser/XiaohongshuSession.swift>)（cookie 进钥匙串 + **行为探测**校验）与 [XhsLoginView.swift](<Easy Swift/Views/XhsLoginView.swift>)（可见 WebView 登录 + 自动检测）；解析自动带登录态
- [x] **键盘体验**：输入框支持回车解析，点「解析链接」或上下滑动结果区自动收起键盘

**真机验证记录（2026-10-22，iPhone 15 Pro）**

| 场景 | 结果 |
|---|---|
| 抖音视频 `v.douyin.com/SlcOoQ_DRSg` | 1 条 `douyinvod.com` mp4，HEAD `206 / video/mp4` |
| 抖音图文 `v.douyin.com/JK1uPOwMU5w` | 先经 WebView 拿到 **7 图 + 7 动图**；改竞速后改为等 WebView 补动图 |
| 抖音被限流的两条 | 竞速改造后 HTTP 路线 1 秒出结果，不再 40 秒转圈 |
| 小红书图文 / 视频各一条 | 200，带登录态，解析成功 |
| 小红书登录 | 网页登录后自动探测 `/explore` → 200 / 236KB → 存钥匙串成功；随后解析日志出现 `登录态: 有` |

**过程中修掉的真问题**：验证码误判（隐藏 iframe）、`RENDER_DATA` 存在≠有数据、XHR 钩子 URL 白名单漏接口、图文配乐被当成视频、假 cookie 被探测请求的 500 骗过、`NSApp` 隐式解包在非 GUI 进程直接 trap。

### 抖音动图链路（2026-10-23 真机逐张核对）

- [x] **动图能播但"点开是 jpeg"**：预览落盘时用 `url.pathExtension` 猜扩展名，抖音直链没有扩展名 → 兜底成 `jpg`，mp4 被当图片打开。改为 **Content-Type → 文件头魔数 → URL 已知扩展名** 三层判定
- [x] **隐藏 WebView 被限流**：持久化会话里的匿名 `ttwid` 被标记后，页面能打开但 `hook/render/work 全 0`。改用 `.nonPersistent()`，每次解析一个干净会话
- [x] **失败冷却**：WebView 超时后 5 分钟内直接走 HTTP，不再让用户干等 18 秒
- [x] **超时状态快照**：超时日志打印 `hook/render/work/captcha/login`，用来区分「平台不给数据」和「判据写错」
- [x] **配乐误判成动图/视频**：图文作品的 `video` 字段（笔记级与图片级）可能是 `ies-music` 的 mp3，按 URL 特征过滤
- [x] **动图下标日志**：`动图下标(0 起)=[…]` + 每个动图的时长与 URL，用于和平台侧逐张核对

**核对结果**：18 图作品解析出 **9 个动图**（下标 0 起 `[1,3,5,7,13,14,15,16,17]`），逐个下载均为 `Content-Type: video/mp4`、时长 1.6–2.8 秒；用户手工清单为 8 个，缺的是第 4 张——实为真动图。

### macOS 钥匙串弹窗（2026-10-23，SwiftUtils 0.0.27）

- [x] **现象**：macOS 端频繁弹「Easy Swift 想要使用您储存在钥匙串中的机密信息」，点不允许后 GitHub / 小红书登录态"莫名丢失"
- [x] **定位证据**：统一日志 `subsystem == com.apple.securityd` 里，两次 `SecItemCopyMatching` 之后各跟一条 `CSSM Exception: -2147415839 CSSMERR_CSP_USER_CANCELED`（22:45:39、22:45:53）—— 是**读**的时候弹框、用户取消，不是启动就弹
- [x] **根因**：`KeychainUtil` 走 macOS 老文件钥匙串，每条记录绑 ACL，ACL 记的是「哪个签名的 App 能读」；重签后读取就要授权，`SecItemCopyMatching` 返回 USER_CANCELED，上层只看到 `nil`
- [x] **修复（库侧 0.0.27）**：四个查询统一 `kSecUseDataProtectionKeychain` + 同一个 `kSecAttrService`；老记录用 `LAContext.interactionNotAllowed` 静默试读，能读到就迁移、读不到当没存过，**不再弹窗**；宿主缺 entitlement（-34018）时回退旧钥匙串并打 error 日志
- [x] **工程侧**：[Easy_Swift.entitlements](<Easy Swift/Easy_Swift.entitlements>) 增加 `keychain-access-groups = $(AppIdentifierPrefix)me.zzhhoo.easyswift`（Xcode 的 Keychain Sharing 能力），否则 `SecItemAdd` 返回 `errSecMissingEntitlement(-34018)` 又退回老钥匙串
- [x] **验证**：签名后的 macOS 产物 entitlements 含 `com.apple.application-identifier` 与 `keychain-access-groups`；App 内跑一次往返（临时探针，已回退）→ 日志 `keychain.save: 写入数据保护钥匙串成功` / 读回值一致 / 删除成功，同期 securityd **零** `CSSMERR_CSP_USER_CANCELED`；iOS 设备签名构建 + macOS 签名构建均通过
- 副作用：升级后老记录若 ACL 不允许静默读取，不会被迁移 —— 表现为第一次需要重新登录一次 GitHub / 小红书

### 其他

- [x] SwiftUtils `0.0.22 → 0.0.26`，`HttpUtil` 迁到纯 Foundation，工程不再依赖 Alamofire
- [x] SwiftUtils `0.0.26 → 0.0.27`（钥匙串改数据保护钥匙串，见上）
- [x] 相册权限判断收敛到 SwiftUtils `PermissionUtil`（2026-10-24）：`ensureAddAccess` 不再自己 switch `PHAuthorizationStatus`，只保留「状态 → 错误」的纯函数 `accessError(for:)`；新增 `.libraryUnavailable`（平台不支持 / 缺用法说明），`isPermissionProblem` 一并覆盖
- [x] SwiftUtils `0.0.27 → 0.0.28`（2026-10-24）：补齐 `PermissionUtil`（权限状态分档 / 能力探测 / Info.plist 键检查），`CameraUtil().checkCameraPermissions(success:fail:)` 改为它的封装、签名不变。钥匙串部分无改动，0.0.27 的真机结论仍然有效
- [x] `debugPrint` 每行 `fflush(stdout)`（2026-10-24）：真机 stdout 是管道、按块缓冲，日志会攒到 4KB 才吐 —— 真机排查相册保存时最后 3 条成功日志一直不出现，差点被当成"保存卡死"
- [x] 真机调试三条命令（`devicectl`）：`process launch --console` 抓日志、`capture screenshot` 截屏、`pasteboard copy/paste` 塞/取剪贴板；注意 `--console` 会绑定进程生命周期，结束 devicectl 会把 App 一起结束
- [x] `ClipboardView` 的 `@State` 初始化顺序编译错误
- [x] GitHub Token 从 UserDefaults 迁到钥匙串（含旧明文迁移、写失败提示）
- [x] 二维码生成移出 `body`（`.task(id:)` + 150ms 防抖），去掉 3 处强解包
- [x] 剪贴板去掉 `clipList` / `ClipItemView.path` 死状态与双写，`clipContentList` 改由 `@Query` 派生
- [x] GitHub 起始日期改 UTC 计算，`DateFormatter` 补 `locale` / `timeZone`
- [x] 搜索关键词改用 `EncodeUtil().urlEncode`（`.urlQueryAllowed` 含 `&=?+`）
- [x] 新增 [AGENTS.md](AGENTS.md)、[TODO.md](TODO.md)
