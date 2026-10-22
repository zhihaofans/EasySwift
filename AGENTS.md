# AGENTS.md · Easy Swift

> 本文件面向 AI 编码代理（DSH 会话开始时自动加载）。这里只放**硬约束、最短路径、验证方式**，不复制代码里已有的东西；架构细节以源码为准。
>
> **仓库内一律用相对路径。个人隐私不得写入或提交**：本机绝对路径、私人账号、密码/令牌、手机号、设备标识等。工程标识（bundle id、仓库地址）属于项目信息，可以保留。

## 0. 开始前

- 先 `git status`。工作区常有用户未提交的改动，**不要** `reset` / `checkout --` / `stash` / 覆盖。
- 改代码前先读对应文件；**以源码与构建结果为准**，不凭记忆。文档与代码冲突时在回复里指出，别静默二选一。
- **Git 提交、推送由用户自己做**：agent 只改文件、跑构建、报告结果；不执行 `git commit` / `git push`，也不擅自 `git add`。
- 没跑过的构建/验证如实说"没跑"，**不要声称"已通过"**。
- 不擅自升级依赖、不新增第三方 SDK；确需改动先问。

## 1. 项目速览

- 单 target 的 SwiftUI 多平台工具集：**iOS 26 / macOS 26**，Swift 5 语言模式，各功能页互不依赖。
- 入口 [Easy_SwiftApp.swift](<Easy Swift/Easy_SwiftApp.swift>) → [ContentView.swift](<Easy Swift/ContentView.swift>) → [MainView.swift](<Easy Swift/Views/MainView.swift>)；新功能页在 `MainView.mainList()` 里注册 `NavigationLink` 才会出现在首页。
- 分层：[Views/](<Easy Swift/Views>)（页面）、[Views/Componets/](<Easy Swift/Views/Componets>)（共用小件）、[Services/](<Easy Swift/Services>)（网络与解析）、[Models/](<Easy Swift/Models>)（SwiftData + Codable）、[Utils/](<Easy Swift/Utils>)（平台差异、日志、分享）。
- 依赖：**SwiftUtils（exactVersion 0.0.26）+ swift-log**。SwiftUtils 0.0.26 起已剥离 Alamofire，工程不再依赖它；`HttpUtil` 是纯 Foundation 实现，`setHeader` 收 `[String: String]`，回调固定在主队列。
- 版本唯一真相源是 `MARKETING_VERSION` / `CURRENT_PROJECT_VERSION`；代码只经 `AppUtil().getAppVersion()` / `getAppBuild()` 读 `Bundle`，不写常量。
- 文案走 String Catalog（[Localizable.xcstrings](<Easy Swift/Localizable.xcstrings>)，源语言 `zh-Hans`）：直接写中文即可，构建时自动收集，不要手写英文再翻译。
- **没有测试 target**（见 §5 的替代验证手段）。

## 2. 命令

```bash
# 三档构建（改完至少跑前两档，涉及发版/设备再跑第三档）
xcodebuild build -project "Easy Swift.xcodeproj" -scheme "Easy Swift" \
  -destination 'platform=iOS Simulator,name=<任选可用模拟器>' -configuration Debug CODE_SIGNING_ALLOWED=NO

xcodebuild build -project "Easy Swift.xcodeproj" -scheme "Easy Swift" \
  -destination 'platform=macOS,arch=arm64' -configuration Debug CODE_SIGNING_ALLOWED=NO

xcodebuild build -project "Easy Swift.xcodeproj" -scheme "Easy Swift" \
  -destination 'generic/platform=iOS' -configuration Release CODE_SIGNING_ALLOWED=NO

# 依赖解析（Package.resolved 与工程 pin 不一致、或 clean 之后）
xcodebuild -resolvePackageDependencies -project "Easy Swift.xcodeproj" -scheme "Easy Swift"

# 模拟器冒烟（比"能编译"多一层保障）
xcrun simctl list devices available            # 选一个 iPhone
xcrun simctl boot "<设备名>"; xcrun simctl bootstatus "<设备名>" -b
xcrun simctl install "<设备名>" "<BUILT_PRODUCTS_DIR>/Easy Swift.app"
xcrun simctl launch "<设备名>" me.zzhhoo.easyswift
xcrun simctl io "<设备名>" screenshot /tmp/easy-swift.png
```

- 产物路径别写死本机 DerivedData：用
  `xcodebuild -showBuildSettings -project "Easy Swift.xcodeproj" -scheme "Easy Swift" -destination '...' | grep -m1 BUILT_PRODUCTS_DIR`。
- 构建需要能写 `~/Library/Developer`（DerivedData）与 SwiftPM 缓存。受限沙箱里会报
  `Operation not permitted ... ModuleCache` 或 `Missing package product 'SwiftUtils'`——那是**环境权限问题，不是代码问题**，先说清楚再动手。
- 只跑 `xcodebuild` 不算验证（见 §5）。

## 3. 不可违反的约定

### 3.1 SwiftData：`@Query` 是唯一数据源

- 列表只读 `@Query`，**不要**再维护一份 `@State` 数组同步（历史代码里 `clipList`、`ClipItemView.path` 就是这么废掉的：赋值了但没人读，看起来在同步列表）。
- 需要派生值（如去重用文本）写成**计算属性**从 `clips` 派生，不要另存一份再想办法同步。
- 编辑已存在对象：先用 `id` 从 `modelContext` 重新 `fetch` 再改（见 [ClipboardView.swift](<Easy Swift/Views/ClipboardView.swift>) 的 `ClipboardEditorView.saveText`），**不要**直接改跨视图传进来的旧对象。
- 新增 `@Model` 后要在 `.modelContainer(for:)` 里登记，否则静默不落库。

### 3.2 凭据只进钥匙串

- Token / 密码走 `KeychainUtil`，**不进** `UserDefaults`、`@AppStorage`、日志。
- 写入失败必须显式暴露（返回 `Bool` 并在 UI 提示），否则表现是"显示已登录，下次启动读不回来"。
- 做数据迁移时：**读失败不能拿空值覆盖已有真值**（[GithubSettingView.swift](<Easy Swift/Views/GIthub/GithubSettingView.swift>) 用 `loadedToken` 兜底的原因）。

### 3.3 日期

- 时区一律 `TimeZone(identifier:)`；`TimeZone(abbreviation:)` 返回 `nil` 且不报错。
- `DateFormatter` 的 `locale`（`en_US_POSIX`）、`calendar`、`timeZone` 三件套显式写全。
- 与网络接口有关的筛选日期按 **UTC** 算（GitHub `created:>` 就是这样），不要用 `Calendar.current`。
- 存 `Date`，不要存"看起来像日期"的字符串。

### 3.4 URL 参数编码

- 关键词/参数值用 `EncodeUtil().urlEncode`；`.urlQueryAllowed` 包含 `& = ? +`，会把 `a&admin=true` 原样拼成新参数。

### 3.5 并发与回调

- 回调式 API 的闭包参数标 `@escaping @Sendable`；`HttpUtil` 的回调已经固定在主队列，不要在别处再包一层 `DispatchQueue.main.async` 假装线程安全。
- 新代码优先 `async/await`。限流/去重这类闸门用 `actor`，并且**先占位再 `await`**。

### 3.6 视图：`body` 里不干活

- `body` 里不做生成、IO、网络：二维码曾经在 `body` 里生成，输入框每敲一个字就跑一遍 CoreImage。放 `.task(id:)` / `@State` + `.onChange`，必要时加防抖。
- 联动刷新走单一入口，别让两个 `.onChange`/`.onAppear` 写同一份状态。
- `@State` 且写了自定义 `init` 时：**先初始化存储属性，再 `_x = State(wrappedValue: ...)`**；直接 `self.x = ...` 会报 `variable 'self.y' used before being initialized`。

### 3.7 平台差异收口

- iOS/macOS 的差异收口到 [PlatformTypes.swift](<Easy Swift/Utils/PlatformTypes.swift>)（`PlatformImage` / `PlatformColor`）或单个类型里，**不要**让 `#if os(...)` 散落到每个调用点。
- `INFOPLIST_KEY_*` 的平台专属键必须带 `[sdk=iphoneos*]` / `[sdk=macosx*]` 之类的限定，否则污染另一个平台的 Info.plist。
- 能力探测三层都要：编译期 `#available` / 设备是否支持 / 权限是否给了。少一层就会"显示不支持，用户明明有"。

### 3.8 失败不许被默认值吞掉

- `try?` 只证明错误变成了 `nil`；`(try? decode(...)) ?? 默认值` 会把「首次启动」「数据损坏」「老格式」压成同一种，下次保存就把默认值写回磁盘。
- 解析/解码失败时先留证（`debugPrint` 出关键字段与 `finalURL`），再决定是报错还是降级。
- 调试输出统一用 [DebugLog.swift](<Easy Swift/Utils/DebugLog.swift>) 的 `debugPrint`（Release 下空操作），不要用系统 `print`。

## 4. 修改地图与边界

| 需求 | 改这里 |
|---|---|
| 加功能页 | 新建 `Views/XxxView.swift` + 在 [MainView.swift](<Easy Swift/Views/MainView.swift>) 的 `mainList()` 注册 |
| 共用 UI 小件（空态/双行列表/输入弹窗） | [Views/Componets/](<Easy Swift/Views/Componets>) |
| SwiftData 模型 / 新表 | [Models/](<Easy Swift/Models>) + 对应页面的 `.modelContainer(for:)` |
| 网络请求 | [Services/](<Easy Swift/Services>)，统一走 `HttpUtil` |
| 新增可解析的网站 | [Services/LinkParser/](<Easy Swift/Services/LinkParser>)：实现 `LinkParser` 协议 + 注册到 `LinkParserRegistry` |
| 平台差异类型 | [PlatformTypes.swift](<Easy Swift/Utils/PlatformTypes.swift>) |
| 调试输出 | [DebugLog.swift](<Easy Swift/Utils/DebugLog.swift>) |
| 版本号 | `project.pbxproj` 的 `MARKETING_VERSION` / `CURRENT_PROJECT_VERSION`（改完回读产物里的版本号） |
| macOS 分享 | [MacShareSupport.swift](<Easy Swift/Utils/MacShareSupport.swift>) |

边界：

- 功能页之间**不互相调用**；需要的共享逻辑放 `Services/` 或 `Utils/`。
- 玻璃风格统一用 `.glassEffect(.regular, in:)` / `.buttonStyle(.glassProminent)`，不要自己拼材质和边框。
- 不删 [Assets.xcassets](<Easy Swift/Assets.xcassets>)、[Preview Content](<Easy Swift/Preview%20Content>)；`Package.resolved` 必须提交。
- 不修改工作区之外的文件。

## 5. 验证与完成标准

- **没有测试 target**，所以"编译通过"不是完成标准。按改动类型选验证方式：
  - 纯逻辑（解析、编码、日期换算）：抽成不依赖 UI 的函数，用仓库外的临时 harness（`swiftc` 直接编真实源文件 + 断言）跑，并把"验证了什么"写进回复。
  - 网络/解析：**必须用真实链接跑一次**，贴出关键字段（标题、作者、图片数、`finalURL`）。只看编译不算。
  - UI/数据：模拟器安装启动 + 截图，确认页面渲染、列表非空、无 crash 日志。
- 修 bug 时优先补一条"它回来就会红"的用例或可复现步骤；别只断言 `!isEmpty`。
- 完成标准：iOS + macOS 构建绿、无新增 warning；涉及解析/网络再加真实链接验证；涉及数据再加"重建实例后仍能读到"的验证。
- 验证不了的部分，明确写"未验证 + 原因"，不要留一句模糊的"应该没问题"。

## 6. 安全与隐私

- 不写入/提交个人隐私：本机绝对路径、私人账号、Token、手机号、设备标识、私人部署地址。
- 不提交构建产物、抓包日志、导出的用户数据；日志里有个人信息先脱敏。
- Token 只在钥匙串；调试输出不得打印完整 Token。
- 当前**缺少 `PrivacyInfo.xcprivacy`**（用了 UserDefaults 等 Required Reason API）。虽然暂不上架，但涉及提交 App Store 前必须先补，否则是 ITMS-91053。

## 7. 快速排错

| 现象 | 先查 |
|---|---|
| `variable 'self.x' used before being initialized` | `@State` 初始化写法（§3.6） |
| 列表空了 / 数据"存了读不回来" | 是不是 `@Query` 之外又存了一份数组；`modelContext.save()` 是否真的调了 |
| 显示已登录、重启后没了 | 钥匙串写入返回 `false`（有日志）、迁移是否被空值覆盖 |
| 解析结果为空 | 先打 `finalURL`：被重定向到登录页 / 风控页，和"内容真的不存在"是两回事 |
| 目录里 `xcodebuild` 报 `Missing package product` | 依赖未解析或缓存目录不可写（§2），先 `-resolvePackageDependencies` |
| 模拟器里装不上 | bundle id 用 `me.zzhhoo.easyswift`；先 `simctl bootstatus` 等设备就绪 |
| 改了没效果 | 确认跑的是新构建产物；模拟器要重新 `install` 才会更新 |
