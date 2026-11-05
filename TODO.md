# TODO · Easy Swift

> **只放待办。** 已完成的事按版本记在 [CHANGELOG.md](CHANGELOG.md)；硬约束与验证方式见 [AGENTS.md](AGENTS.md)；架构以源码为准。
> 新增条目要写清：**改哪里 + 怎么算做完**。不要记录本机绝对路径、账号、Token。

最后更新：2026-10-29 · 待办 7 条

| 分区 | 含义 | 条数 |
|---|---|---|
| [P1 需要拍板](#p1--需要你拍板) | 值不值得做 / 做成什么样，要先定 | 1 |
| [P2 等条件](#p2--等条件) | 缺设备、缺权限、或上架才需要 | 5 |
| [附A 小红书](#附a-小红书解析细节与已知限制) | 细节多，单独放（表格 3 项 + 已知限制 2 条） | — |
| [附B 外部库](#外部库swiftutils-仓库待办--下次动库时记得先看这里) | 下次动 SwiftUtils 时一起改 | 1 |

---

## P1 · 需要你拍板

- [ ] **解析历史记录**（新功能）—— 解析过的链接留痕、能回看、能重新解析。
      - 存储：SwiftData（链接、平台、标题、封面 URL、图片/视频/动图数量、解析时间），列表只读 `@Query`
      - 去重：同一条链接只留最新（短链展开后按最终 URL 去重）
      - 交互：解析页顶部入口或独立页；点进去**重新解析**（历史直链会过期，不能当结果用）
      - 清理：单条删除 + 清空 + 上限裁剪（如最近 200 条）
      - **算完**：写入 → 杀进程 → 重开仍在；倒序；重复解析同一链接不产生两条

---

## P2 · 等条件

- [ ] **iPhone Duo 适配** —— 现状：App 在 Duo 上**以手机宽度窗口运行**，内容挤左、右侧大片留白，工具栏被压中间。
      已确认与部署目标无关（提到 27 后重装仍如此），下一步查 Info.plist / Scene 声明或 `UIRequiresFullScreen`。
      要做时按这套基线检查：
      1. 机型基线：常规 iPhone（SE / 标准 / Pro Max）+ Duo（`iPhone19,4`，最低 iOS 27.1）
      2. 不用固定宽度/写死高度：`maxWidth: .infinity` + `GridItem(.adaptive(minimum:))`
      3. 尺寸变化要重排（`GeometryReader` + `.onChange`，或 `horizontalSizeClass`），不缓存首帧尺寸
      4. `@State` / SwiftData 不因窗口变化重建
      5. 安全区走 `safeAreaInset` / `ignoresSafeArea`，不写死 padding
      6. 横竖屏 + 分屏：列表/网格/工具栏不裁切、按钮不被遮挡
      7. 每次改动跑一次 Duo 并截图（截图必须带 `--display=1`）
- [ ] **`PrivacyInfo.xcprivacy`** —— 用了 UserDefaults（CA92.1）等 Required Reason API，上架前必须补（ITMS-91053）。
- [ ] **测试 target** —— 目前只有仓库外 `swiftc` harness；若要长期维护，加 unit test 覆盖解析纯函数、日期换算、参数编码、收件箱分类。
- [ ] **分享扩展无法拉起主 App** —— 实测：`extensionContext.open` 回调 false、responder 链 `openURL:` 被系统忽略。
      待探索：① 扩展写入后由 App 发本地通知、点通知进 App（需通知权限）；② Action Extension / 快捷指令；③ 等新 API。
      **别再放一个点了没反应的按钮。**
- [ ] **等真实样本的两条**（构造不出来，遇到再看日志）：
      - `noteLoginWall()`：解析撞墙把 valid 降级 expired —— 私密/仅关注可见的笔记才撞墙，而这类笔记复制不出链接
      - 「已登录 / 过期」三态在**小红书**上的界面文案 —— 抖音侧已截过图

### 外部库（SwiftUtils 仓库）待办 —— 下次动库时记得先看这里

- [ ] **`PermissionUtil.requiredInfoPlistKeys(for: .photoLibraryAddOnly)` 要求过严**
      - 现状：返回 `["NSPhotoLibraryAddUsageDescription", "NSPhotoLibraryUsageDescription"]`，缺一个就 `.unavailable`
      - 问题：`.addOnly` 语义上只需要 Add 那个键；只保存不读的宿主会莫名被判「系统相册不可用」
      - 改法：`.photoLibraryAddOnly` 只要求 Add 键；`.photoLibraryReadWrite` 才要读权限键
      - 本工程暂时不受影响（两个键都在），但**一旦有人删掉读权限的键，保存就整体失败**
      - 顺带确认：`request` 回调是否仍固定在主队列（App 侧现在用 `Task { @MainActor in … }` 兜住）

---

## 附A · 小红书解析（细节与已知限制）

> 资料来源：`xhs-parser-src-20261026.tar.gz`、`dsh-xhs-plugin-0.2.0.tgz`、《小红书搜索抓取复现指南（含 API 登录搜索附章）》。
> 它们是 Node/Python 实现，**不能直接搬进 App**，但实测结论可以拿来改 [`XiaohongshuParser.swift`](<Easy Swift/Services/LinkParser/XiaohongshuParser.swift>)。
> 对照结论：我们的能力（`__INITIAL_STATE__` 解析、explore/discovery 双形态、去水印、视频流优先级、原图 HEAD 探测、
> `/notification` 登录探测）与参考实现基本对齐。

**待办**

| 项 | 要点 |
|---|---|
| 错误码分类对齐 | `BAD_LINK` / `LOGIN_REQUIRED` / `NOT_FOUND` / `NO_STATE` / `BLOCKED` / `NETWORK` ↔ 我们 7 类（够用，主要补文案与判据） |
| `note.time` 是毫秒 | 用历史记录/展示时间时记得 `/1000` |
| 游客态要不要单独标 | `web_session` 前缀 `04` 真登录、`03` 游客态（能解析单条、搜索接口一律 `-104`） |

**已决定不做**

- **API 路线（x-s / x-t 签名）**：参考实现靠 Python `xhshow` + 签名脚本，App 内嵌不了，Swift 复刻是大工程。只解析分享链接，不做搜索 API。
- **"下载到目录 + meta.json"**：桌面场景，App 里对应"保存到相册"，不照搬。

**别回退的判据**

- 登录判定用 `/notification`，不用「`/explore` 是否 302 到 `/login`」—— 游客态访问 `/explore` 也返回 200。

**已知限制：作者主页解析（试过，别再盲目重来）**

「粘贴主页链接 → 列笔记 → 选一条解析」实现过、真机跑不通、已整体回退（见 CHANGELOG 0.4.1）。三条实测事实：

1. SSR 的 `profile.noteData[].id` 与 SPA 会话里的笔记 id **不是同一套**（`d9e4bc26…` vs `6a8be922…`，一个都对不上）
2. 主页 SSR 与渲染后的 DOM 卡片链接**都不带 `xsecToken`**；从 `__INITIAL_STATE__` 递归扫到的 token 属于**推荐流**
3. 无 token 的笔记页打不开：`/explore/<id>` 一律落到 `/website-login/error?error_code=300011`（`error_msg=账号异常`），
   WKWebView 打开也一样（`title: 安全限制`）—— **不是 cookie 过期**

若以后还要做，方向是「在页面上下文里调用它自己的签名函数」（`window._webmsxyw` 之类）请求
`note detail` / `user_posted` 接口，或移植签名（工作量大）。
