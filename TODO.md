# TODO · Easy Swift

> **只放待办。** 已完成的事按版本记在 [CHANGELOG.md](CHANGELOG.md)；硬约束与验证方式见 [AGENTS.md](AGENTS.md)；架构以源码为准。
> 新增条目要写清：**改哪里 + 怎么算做完**。不要记录本机绝对路径、账号、Token。

最后更新：2026-11-18 · 待办 10 条

| 分区 | 含义 | 条数 |
|---|---|---|
| [P1 可直接做](#p1--可直接做改法明确不牵涉决策) | 改法明确，不牵涉决策 | 5 |
| [P2 等条件](#p2--等条件缺设备缺权限或上架才需要) | 缺设备、缺权限、或上架才需要 | 5 |

---

## P1 · 可直接做（改法明确，不牵涉决策）

- [ ] **单元测试 target（Swift Testing）** —— `SharerResolver` 解码、`InboxClassifier` 分类、`LinkHistoryStore` 去重/裁剪、
      `PhotoLibrarySaver.accessError` 都是纯函数，把这几轮现写的 harness 断言直接搬成 `@Test` / `#expect`
      （OMF 有 24 个测试文件可照结构）。**算完**：⌘U 能跑并覆盖上述 4 处
- [ ] **图片缩略图加缓存 + EXIF 归一** —— 历史页/解析页缩略图每次滚动都重新下载（`URLSession.shared.data` 直连）；
      `ImageUtil` 已提供"按 EXIF 方向转正、清掉旧像素尺寸"的缩略图 API。**算完**：同一 URL 二次进入不重复下载
- [ ] **时间显示换 `RelativeTimeFormatter`** —— 收件箱/历史现在用 `.formatted(date:time:)`；库里是本地化相对时间
      （未来时间不会显示成"刚刚"）。**算完**：列表显示"3 分钟前"，边界有断言
- [ ] **超时/重试收口** —— `DouyinWebExtractor` 手写 deadline、`VideoHTTP` 各自设 timeout、解析器里零散重试 →
      统一用 `withTimeout` / `RetryPolicy`。**算完**：超时路径有可复现用例
- [ ] **文件写入换 `FileUtil`** —— `InboxShared` 自己写原子写/唯一名、`MediaDownloader` 手拼临时文件名；
      0.0.33 提供 `FileUtil` 原子读写 + `createUniqueFile`（内核级判重）。**算完**：并发保存不互相覆盖

## P2 · 等条件（缺设备、缺权限或上架才需要）

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
      现成模板可看 `~/Xcode/OhMyFile` 的 app + 扩展两份（需你同意后引用其结构，不复制文件）
- [ ] **可选：App 锁（Face ID / Touch ID）** —— 剪贴板与收件箱里是私人内容。参考 OMF 的 `AppLockController`
      （`LAContext` + `biometryInfo`），0.0.33 的 `AuthUtil` 已把可用性与类型收敛好。
      **算完**：开启后冷启动 / 回前台需生物识别，关闭后不打扰
- [ ] **分享扩展支持图片**（现在只收 text / url）—— OMF 用 `NSExtensionActivationSupportsImageWithMaxCount` 收图片。
      要做需先定去处（相册 or 解析历史），否则收进来无处可放
- [ ] **等真实样本的两条**（构造不出来，遇到再看日志）：
      - `noteLoginWall()`：解析撞墙把 valid 降级 expired —— 私密/仅关注可见的笔记才撞墙，而这类笔记复制不出链接
      - 「已登录 / 过期」三态在**小红书**上的界面文案 —— 抖音侧已截过图

---
