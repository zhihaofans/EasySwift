# TODO · Easy Swift

> 本文件是**待办清单**，不是设计文档。硬约束与验证方式见 [AGENTS.md](AGENTS.md)，架构见源码。
>
> 用法：做完就把 `[ ]` 改 `[x]`；新增条目要写清「改哪里 + 怎么算做完」。**不要**在这里记录本机绝对路径、账号、Token。

最后更新：2026-10-22

---

## 一、收尾（链接解析重写已完成，剩三件小事）

- [x] **删掉 `HTMLFetcher` 兼容层**（2026-10-23）：连同 `OGMetaExtractor` 一起删除，全项目零引用，`LinkParser.swift` 196 → 143 行
- [x] **抖音图文动图真机复测**（2026-10-23 通过）：日志 `HTTP 先拿到 7 张图（无动图），继续等 WebView 补动图` → `解析成功(hook) 图=7 动图=7 视频=0`
      —— 期间发现的真因：隐藏 WebView 用了持久化存储，同一个匿名 `ttwid` 被平台标记后连续 `hook/render/work 全 0`；改成每次 `.nonPersistent()` 新会话 + 失败冷却 5 分钟后恢复
- [x] **小红书登录过期路径**（2026-10-23）：新增三态 `unknown / valid / expired` + 解析撞墙时自动降级；新增「手动填写 Cookie」入口（保存前强制探测）
      - 过程中修掉两个判据问题：`/explore` 游客态也返回 200（不能当登录判据，改用 `/notification`）；5xx 不能判过期（平台限流时会误杀登录态）
- [ ] **在真机上确认三态文案**：设置页在真实登录态下应显示「已登录」；把钥匙串里的 cookie 改坏后解析，应显示「登录已过期」而不是「需要登录」

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

- [ ] **iPad 方向配置笔误**：`project.pbxproj` 的 `INFOPLIST_KEY_UISupportedInterfaceOrientations_iPad` 末尾多了 `Easy Swift`，Release 构建因此报 *"All interface orientations must be supported..."*；删掉即消除
- [ ] **二维码内容与「复制文字」不一致**：[QrcodeView.swift](<Easy Swift/Views/QrcodeView.swift>) 生成前做了 `EncodeUtil().urlDecode`，复制却是原文；二选一统一
- [ ] **隐私清单** `PrivacyInfo.xcprivacy`：用了 UserDefaults（CA92.1）等 Required Reason API，上架前必须补（当前不打算上架，优先级最低）
- [ ] **测试 target**：目前只能靠仓库外 `swiftc` harness 验；若要长期维护，考虑加 unit test target，先覆盖链接解析纯函数、日期换算、参数编码
- [ ] **删除文件需要动 pbxproj**：[ContentView.swift](<Easy Swift/ContentView.swift>) 只是 `MainView()` 的跳板，合并掉可少一层；但删文件要改工程文件，单独做
- [ ] **解析历史记录**（新需求）
      - 目标：解析过的链接留痕，能回看、能重新打开结果
      - 存储：SwiftData 模型（链接、平台、标题、封面 URL、图片/视频/动图数量、解析时间），列表同样只读 `@Query`，不另存一份数组
      - 去重：同一条链接只保留最新一条（短链展开后按最终 URL 去重，先 insert 再合并）
      - 交互：解析页顶部入口或独立页面；点进去重新解析（历史里的直链会过期，不能直接当结果用）
      - 清理：单条删除 + 清空 + 上限裁剪（例如最近 200 条）
      - 验收：写入 → 杀进程 → 重开后仍在；列表顺序按时间倒序；重复解析同一链接不产生两条

- [ ] **动图导出为 Live Photo 存相册**（新需求）
      - 目标：解析结果里的动图（`motions[i]` + `images[i]`）能一键存成相册里的实况照片，而不是一张静态图 + 一段孤立视频
      - 技术路径：`PHLivePhoto.request(withResourceFileURLs:placeholderImage:targetSize:contentMode:)` 先合成 → `PHPhotoLibrary.performChanges` 里用 `PHAssetCreationRequest` 分别 `addResource(with: .photo)` 与 `addResource(with: .pairedVideo)`
      - 前置：工程目前**没有** `INFOPLIST_KEY_NSPhotoLibraryAddUsageDescription`，需要先补（否则保存直接失败且无明显提示）
      - 坑：静态图与视频的时长/尺寸要成对匹配，否则相册侧可能只认成普通照片；视频要落成 `.mov`（mp4 也能试，但要验证）
      - 验收：保存后**回读相册**（`PHAsset` 的 `mediaSubtypes` 含 `.photoLive`）确认是实况照片，不能只看 `performChanges` 没抛错
      - 交互：结果页逐张「存为实况照片」，以及「全部保存」；权限被拒要给可操作提示（区分"未决定"和"已拒绝去设置里开"）

- [ ] **链接解析页的状态提示可再细**：现在只有「正在解析…」，抖音图文要等 WebView 5–18 秒，可以加一句「正在用浏览器内核加载」区分阶段

## 四、需要决策（先别动）

- [ ] 部署目标是否从 iOS 26 提到 iOS 27：Duo 要 27.1 才跑得起来，若要求「必须有 Duo 体验」就得提；不要求则只在可用机型上验证
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

### 其他

- [x] SwiftUtils `0.0.22 → 0.0.26`，`HttpUtil` 迁到纯 Foundation，工程不再依赖 Alamofire
- [x] `ClipboardView` 的 `@State` 初始化顺序编译错误
- [x] GitHub Token 从 UserDefaults 迁到钥匙串（含旧明文迁移、写失败提示）
- [x] 二维码生成移出 `body`（`.task(id:)` + 150ms 防抖），去掉 3 处强解包
- [x] 剪贴板去掉 `clipList` / `ClipItemView.path` 死状态与双写，`clipContentList` 改由 `@Query` 派生
- [x] GitHub 起始日期改 UTC 计算，`DateFormatter` 补 `locale` / `timeZone`
- [x] 搜索关键词改用 `EncodeUtil().urlEncode`（`.urlQueryAllowed` 含 `&=?+`）
- [x] 新增 [AGENTS.md](AGENTS.md)、[TODO.md](TODO.md)
