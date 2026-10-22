# TODO · Easy Swift

> 本文件是**待办清单**，不是设计文档。硬约束与验证方式见 [AGENTS.md](AGENTS.md)，架构见源码。
>
> 用法：做完就把 `[ ]` 改 `[x]`；新增条目要写清「改哪里 + 怎么算做完」。**不要**在这里记录本机绝对路径、账号、Token。

最后更新：2026-10-22

---

## 一、进行中：链接解析重写（抖音 / 小红书）

方案已确认：**动图一起做**，**抖音走隐藏 WebView**（失败再弹可见页兜底），**小红书要加登录能力**。

### 1. 解析层骨架 — [Services/LinkParser/](<Easy Swift/Services/LinkParser>)

- [x] `LinkParseResult` 增加 `notice: String?`（成功但有话说：去水印回退、动图缺失）与 `motions: [URL]`（与 `images` 同下标）
- [x] `LinkParseError` 从 3 个 case 扩到 7 个：`unsupported / needLogin / network / blocked / notFound / emptyResult / unknown(String)`，每个自带用户文案（不把 HTTP 状态码甩给用户）
- [x] 网络失败单独一个 `network`（原计划漏了，否则超时/断网会被压成「平台改版」）
- [x] 新增 `VideoHTTP`：桌面 Chrome / iOS Safari 两套 UA、`get()` 返回 `(finalURL, status, body)`、`head()` 探测、`expandShortLink()`（≤5 跳）
- [x] `VideoHTTP` 支持注入 Cookie（登录态解析要用）
- [ ] 清理 `HTMLFetcher` / `OGMetaExtractor`：只保留抖音回退路线还在用的部分（`HTMLFetcher` 已收成 `VideoHTTP` 的薄壳，待步骤 3 完成后整段删除）

**完成标准**：`LinkParserRegistry` 之外无新的抓取入口；错误类型能通过 `LocalizedError` 直接展示。

### 2. 小红书（纯 HTTP，整体重写）

- [x] 识别：`xhslink.com` / `xhslink.cn` 短链、`explore/<id>`、`discovery/item/<id>`
- [x] 短链展开后**连查询串一起保留**（`xsec_token` 丢了就是 404 风控页）
- [x] 请求：iOS UA + `Origin` + `X-Requested-With`；命中登录墙换桌面 UA 重试一次
- [x] 失败判定只看 `finalURL`：`/login`、`website-login`、`captcha` → `needLogin`；`/404/sec_` 或响应含 `300031` → `notFound`
- [x] 解析 `__INITIAL_STATE__`：`undefined` → `null` 后 JSON 解析，取 `noteData.data.noteData`（兼容 `note.noteDetailMap[<id>].note`）
- [x] 图片：`fileId` → `https://sns-img-bd.xhscdn.com/<fileId>`；无 `fileId` 时按「丢前两段路径 + 截掉 `!`」换算；并发 HEAD，只有 404/410 回退原图并写 `notice`
- [x] 视频：`video.media.stream` 按 `h265 → h264 → av1 → h266` 取 `masterUrl`（兼容 `master_url`）；有 `video` 无地址直接报错，不退回封面
- [x] 动图：`imageList[].livePhoto == true` 且有 `stream` → 收进 `motions`

**完成标准**：两条真实分享链能出标题 + 作者 + 图片数 + 去水印地址（2026-10-22 已用 `xhslink.cn/o/A0mSzFJK8FP`、`xhslink.cn/o/4OdWYCxfMVz` 实测通过：1 图 + 1 动图 / 11 图）；把 UA 换成桌面 Chrome 时给出的是「需要登录」而不是「内容不存在」。

### 3. 抖音（WebView 主路线 + HTTP 回退）

- [x] 识别 + 短链展开（`v.douyin.com` 用 iOS UA）→ 提取 aweme id
- [x] 新增 `DouyinWebExtractor`：1×1 透明 WKWebView 挂到前台窗口
- [x] document-start 注入：`navigator.platform` 覆盖 + XHR/fetch 钩子（同时读 `responseText` 和 `response`）
- [x] 就绪判据：钩子有数据 **或** DOM 出现真作品图（`douyinpic.com` + `biz_tag=aweme_images|tplv-dy-aweme-images`，排除 `pcweb_cover` / `WEBPC_RELATED`）
- [x] 取数优先级：SSR `RENDER_DATA`（图 + 动图）→ 钩子（视频直链）→ DOM 兜底
- [x] 40s 超时；拿不到前台窗口时给可操作提示，不伪装成「作品已删除」
- [x] HTTP 回退：`iesdouyin/share/{video|note|slides}/<id>` + `_ROUTER_DATA`，`playwm` → `play`
- [x] 全局只允许一个隐藏 WebView 存活（防批量粘贴连开多个）

**完成标准**：一条真实 `v.douyin.com` 分享链能出视频直链或图文清单；被风控时落到「可见页 + 手动过验证」而不是干等 40 秒。

**当前进度（2026-10-22 已用真实链接验证）**：
- 视频作品：`v.douyin.com/kSzSjXvfhoI` → 标题「又是一年秋」+ 1 条 `douyinvod.com` 的 mp4（HEAD 206 / video/mp4）
- 图文作品：`v.douyin.com/YYQdzdhLDsk` → 标题「祝自由。#姐系穿搭法则…」+ 2 张图（HEAD 200 / image/webp）
- 隐藏 WebView 实测 4–7 秒出结果；无前台窗口、验证码、登录墙三种情况都走对了分支
- 动图（Live Photo）：这条图文没有动图资源，**动图链路仍未被真实样本覆盖**

验证过程中发现并修掉的 4 个问题：
1. 验证码误判：页面常驻一个**隐藏的** captcha iframe，按选择器命中就报 `blocked` → 改成必须"看得见"才算
2. `RENDER_DATA` 存在 ≠ 有数据：登录墙页也有 200KB 的 RENDER_DATA → 改成必须解析出 `app.videoDetail` 才能算就绪
3. XHR 钩子按 URL 白名单过滤：笔记页接口路径不同 → 去掉白名单，改为按响应内容判定
4. 图文作品的 `detail.video.play_addr` 指向**配乐 mp3** → 有图片时不再把它当视频返回

### 4. UI 接线 — [LinkParserView.swift](<Easy Swift/Views/LinkParserView.swift>)

- [x] 按新错误类型出对应文案（需要登录 / 被风控 / 内容不存在 / 改版）
- [x] 结果页展示 `notice`
- [x] 动图入口：缩略图角标 + 点击播放
- [x] `.blocked` / `.emptyResult` 时复用可见页兜底，抖音模式复用同一套注入与取数脚本

**完成标准**：四种失败态在界面上文案互不相同；成功态里 `notice` 可见。

### 5. 小红书登录（新增）

- [x] 登录入口：设置页「账号」分区 + 解析页的「需要登录」弹窗，用 WKWebView 打开发布端登录页（**桌面 UA**；移动 UA 下登录页会 404）
- [x] 登录页风控兜底：验证码/滑块由用户在可见 WebView 里自己过，不做自动识别
- [x] 取登录态：页面每次加载完成后从 `WKWebsiteDataStore.httpCookieStore` 取 cookie（`web_session` 等）
- [x] **不要按 cookie 名判登录**：游客态也会种同名 cookie，必须请求一个只有登录态才通的页面看 `finalURL` 落点
- [x] 存储：cookie 序列化后进 `KeychainUtil`，不落 UserDefaults（遵循 AGENTS.md §3.2）
- [x] 解析时带上 cookie；与 `VideoHTTP` 的 Cookie 注入打通
- [x] 失效区分：`needLogin` 统一给「去登录」出口（已登录过 = 可能过期，弹窗里写清）；登录过期 → 提示「登录已失效，请重新登录」，别和「内容不存在」混在一起
- [x] 登录态可见 + 支持退出登录（设置页）（清钥匙串里的 cookie）
- [x] 重启 App 后登录态仍有效（cookie 在钥匙串，读回契约有测试）（读回来验证一次，不只看内存）

**完成标准**：未登录时解析需要登录的笔记给「去登录」；登录后同一条笔记能出图；杀掉 App 重开后仍能解析；退出登录后回到未登录文案。

**当前进度**：会话层 10 项契约测试全过（序列化往返 / Cookie 头 / 域名过滤 / 空 cookie / 假 cookie / 存取清除）。**没有真实账号，登录本身没走通过**——「登录成功后能出图」这一条仍需你用自己的账号验一次。

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

**已知问题**：本机两个 iPhone Duo 模拟器首次启动都报 `Data Migration Failed`，需 `xcrun simctl erase <udid>` 后重建；重建后再把内外屏尺寸补进本节。

---

## 三、待办（体检遗留）

- [ ] **iPad 方向配置笔误**：`project.pbxproj` 的 `INFOPLIST_KEY_UISupportedInterfaceOrientations_iPad` 末尾多了 `Easy Swift`，Release 构建因此报 *"All interface orientations must be supported..."*；删掉即消除
- [ ] **二维码内容与「复制文字」不一致**：[QrcodeView.swift](<Easy Swift/Views/QrcodeView.swift>) 生成前做了 `EncodeUtil().urlDecode`，复制却是原文；二选一统一
- [ ] **隐私清单** `PrivacyInfo.xcprivacy`：用了 UserDefaults（CA92.1）等 Required Reason API，上架前必须补（当前不打算上架，优先级最低）
- [ ] **测试 target**：目前只能靠仓库外 `swiftc` harness 验；若要长期维护，考虑加 unit test target，先覆盖链接解析纯函数、日期换算、参数编码
- [ ] **删除文件需要动 pbxproj**：[ContentView.swift](<Easy Swift/ContentView.swift>) 只是 `MainView()` 的跳板，合并掉可少一层；但删文件要改工程文件，单独做

## 四、需要决策（先别动）

- [ ] 部署目标是否从 iOS 26 提到 iOS 27：Duo 要 27.1 才跑得起来，若要求「必须有 Duo 体验」就得提；不要求则只在可用机型上验证
- [ ] 抖音解析 5–40 秒，要不要加进度提示或允许取消？
- [ ] 链接解析是否抽成独立 target / 本地 SPM 包，方便脱离 App 测？

---

## 五、已完成（近期，供回溯）

- [x] SwiftUtils `0.0.22 → 0.0.26`，`HttpUtil` 迁到纯 Foundation，工程不再依赖 Alamofire
- [x] `ClipboardView` 的 `@State` 初始化顺序编译错误
- [x] GitHub Token 从 UserDefaults 迁到钥匙串（含旧明文迁移、写失败提示）
- [x] 二维码生成移出 `body`（`.task(id:)` + 150ms 防抖），去掉 3 处强解包
- [x] 剪贴板去掉 `clipList` / `ClipItemView.path` 死状态与双写，`clipContentList` 改由 `@Query` 派生
- [x] GitHub 起始日期改 UTC 计算，`DateFormatter` 补 `locale` / `timeZone`
- [x] 搜索关键词改用 `EncodeUtil().urlEncode`（`.urlQueryAllowed` 含 `&=?+`）
- [x] 新增 [AGENTS.md](AGENTS.md)、[TODO.md](TODO.md)
