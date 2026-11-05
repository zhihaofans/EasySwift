# TODO · Easy Swift

> **只放待办。** 已完成的事按版本记在 [CHANGELOG.md](CHANGELOG.md)；硬约束与验证方式见 [AGENTS.md](AGENTS.md)；架构以源码为准。
> 新增条目要写清：**改哪里 + 怎么算做完**。不要记录本机绝对路径、账号、Token。

最后更新：2026-11-05 · 待办 5 条

| 分区 | 含义 | 条数 |
|---|---|---|
| [P2 等条件](#p2--等条件) | 缺设备、缺权限、或上架才需要 | 5 |

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

---
